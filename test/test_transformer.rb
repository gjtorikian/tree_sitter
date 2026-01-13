# frozen_string_literal: true

require "test_helper"

class TestTransformer < Minitest::Test
  include TestHelper

  def setup
    register_language("rust")
    @parser = TreeSitter::Parser.new
    @parser.language = "rust"
  end

  def test_swap_function_arguments
    source = "fn add(a: i32, b: i32) -> i32 { a + b }"
    tree = @parser.parse(source)

    # Use query to find parameters reliably
    lang = TreeSitter.language("rust")
    query = TreeSitter::Query.new(lang, "(parameter) @param")
    cursor = TreeSitter::QueryCursor.new
    captures = cursor.captures(query, tree.root_node, source)

    param_a = captures[0].node
    param_b = captures[1].node

    result = TreeSitter::Transformer.new(source, tree)
      .swap(param_a, param_b)
      .rewrite

    assert_includes(result, "fn add(b: i32, a: i32)")
  end

  def test_move_function_after_another
    source = <<~RUST
      fn first() {}
      fn second() {}
      fn third() {}
    RUST
    tree = @parser.parse(source)

    first_fn = tree.root_node.child(0)
    third_fn = tree.root_node.child(2)

    result = TreeSitter::Transformer.new(source, tree)
      .move(first_fn, after: third_fn)
      .rewrite

    # Verify order is now: second, third, first
    second_idx = result.index("fn second")
    third_idx = result.index("fn third")
    first_idx = result.index("fn first")

    assert_operator(second_idx, :<, third_idx, "second should come before third")
    assert_operator(third_idx, :<, first_idx, "third should come before first")
  end

  def test_move_function_before_another
    source = <<~RUST
      fn first() {}
      fn second() {}
      fn third() {}
    RUST
    tree = @parser.parse(source)

    third_fn = tree.root_node.child(2)
    first_fn = tree.root_node.child(0)

    result = TreeSitter::Transformer.new(source, tree)
      .move(third_fn, before: first_fn)
      .rewrite

    # Verify third now comes before first
    third_idx = result.index("fn third")
    first_idx = result.index("fn first")

    assert_operator(third_idx, :<, first_idx, "third should come before first after move")
  end

  def test_copy_struct_definition
    source = <<~RUST
      struct Point { x: i32, y: i32 }
      fn main() {}
    RUST
    tree = @parser.parse(source)

    struct_node = tree.root_node.child(0)
    main_fn = tree.root_node.child(1)

    result = TreeSitter::Transformer.new(source, tree)
      .copy(struct_node, after: main_fn)
      .rewrite

    assert_equal(2, result.scan("struct Point").count)
  end

  def test_reorder_struct_fields
    source = <<~RUST
      struct Point {
          z: i32,
          y: i32,
          x: i32,
      }
    RUST
    tree = @parser.parse(source)

    struct_item = tree.root_node.child(0)
    struct_body = struct_item.child_by_field_name("body")

    # Reorder to x, y, z (indices 2, 1, 0)
    result = TreeSitter::Transformer.new(source, tree)
      .reorder_children(struct_body, [2, 1, 0])
      .rewrite

    # Verify x comes before y, y before z
    x_idx = result.index("x: i32")
    y_idx = result.index("y: i32")
    z_idx = result.index("z: i32")

    assert_operator(x_idx, :<, y_idx, "x should come before y")
    assert_operator(y_idx, :<, z_idx, "y should come before z")
  end

  def test_duplicate_function
    source = "fn original() {}"
    tree = @parser.parse(source)

    # Use query to find function_item reliably
    lang = TreeSitter.language("rust")
    query = TreeSitter::Query.new(lang, "(function_item) @fn")
    cursor = TreeSitter::QueryCursor.new
    captures = cursor.captures(query, tree.root_node, source)
    fn_node = captures.first.node

    result = TreeSitter::Transformer.new(source, tree)
      .duplicate(fn_node)
      .rewrite

    assert_equal(2, result.scan("fn original()").count)
  end

  def test_duplicate_with_transformation
    source = "fn original() {}"
    tree = @parser.parse(source)

    # Use query to find function_item reliably
    lang = TreeSitter.language("rust")
    query = TreeSitter::Query.new(lang, "(function_item) @fn")
    cursor = TreeSitter::QueryCursor.new
    captures = cursor.captures(query, tree.root_node, source)
    fn_node = captures.first.node

    result = TreeSitter::Transformer.new(source, tree)
      .duplicate(fn_node) { |text| text.gsub("original", "copied") }
      .rewrite

    assert_includes(result, "fn original()")
    assert_includes(result, "fn copied()")
  end

  def test_extract_to_function
    source = <<~RUST
      fn main() {
          let x = compute_value();
      }
    RUST
    tree = @parser.parse(source)

    # Use queries to find nodes reliably
    lang = TreeSitter.language("rust")

    fn_query = TreeSitter::Query.new(lang, "(function_item) @fn")
    cursor = TreeSitter::QueryCursor.new
    fn_captures = cursor.captures(fn_query, tree.root_node, source)
    fn_item = fn_captures.first.node

    let_query = TreeSitter::Query.new(lang, "(let_declaration) @let")
    let_captures = cursor.captures(let_query, tree.root_node, source)
    let_stmt = let_captures.first.node

    result = TreeSitter::Transformer.new(source, tree)
      .extract(let_stmt, to: fn_item, reference: "extracted();") { |text| "fn extracted() {\n    #{text}\n}" }
      .rewrite

    assert_includes(result, "extracted();")
    assert_includes(result, "fn extracted()")
  end

  def test_swap_validates_non_overlapping
    source = "fn test() {}"
    tree = @parser.parse(source)

    # Use queries to find nodes reliably
    lang = TreeSitter.language("rust")
    fn_query = TreeSitter::Query.new(lang, "(function_item) @fn")
    cursor = TreeSitter::QueryCursor.new
    fn_captures = cursor.captures(fn_query, tree.root_node, source)
    fn_item = fn_captures.first.node

    name_query = TreeSitter::Query.new(lang, "(function_item name: (identifier) @name)")
    name_captures = cursor.captures(name_query, tree.root_node, source)
    fn_name = name_captures.first.node

    # Trying to swap a node with its parent should fail
    assert_raises(ArgumentError) do
      TreeSitter::Transformer.new(source, tree)
        .swap(fn_item, fn_name)
        .rewrite
    end
  end

  def test_move_requires_target
    source = "fn test() {}"
    tree = @parser.parse(source)

    # Use query to find function_item reliably
    lang = TreeSitter.language("rust")
    query = TreeSitter::Query.new(lang, "(function_item) @fn")
    cursor = TreeSitter::QueryCursor.new
    captures = cursor.captures(query, tree.root_node, source)
    fn_item = captures.first.node

    assert_raises(ArgumentError) do
      TreeSitter::Transformer.new(source, tree)
        .move(fn_item)
        .rewrite
    end
  end

  def test_rewrite_with_tree
    source = "fn a() {}\nfn b() {}"
    tree = @parser.parse(source)

    fn_a = tree.root_node.child(0)
    fn_b = tree.root_node.child(1)

    _new_source, new_tree = TreeSitter::Transformer.new(source, tree, parser: @parser)
      .swap(fn_a, fn_b)
      .rewrite_with_tree

    assert_kind_of(TreeSitter::Tree, new_tree)
    # In the new tree, first function should be "b"
    first_fn_name = new_tree.root_node.child(0).child_by_field_name("name").text

    assert_equal("b", first_fn_name)
  end
end
