# frozen_string_literal: true

require "test_helper"

class TestInserter < Minitest::Test
  include TestHelper

  def setup
    register_language("rust")
    @parser = TreeSitter::Parser.new
    @parser.language = "rust"
  end

  def test_insert_statement_at_end_of_block
    source = <<~RUST
      fn main() {
          let x = 1;
          let y = 2;
      }
    RUST
    tree = @parser.parse(source)

    fn_item = tree.root_node.child(0)
    fn_body = fn_item.child_by_field_name("body")

    result = TreeSitter::Inserter.new(source, tree)
      .at_end_of(fn_body)
      .insert_statement("println!(\"done\");")
      .rewrite

    assert_includes(result, "println!(\"done\");")
    # Should be before the closing brace
    println_idx = result.index("println!(\"done\")")
    close_brace_idx = result.rindex("}")

    assert_operator(println_idx, :<, close_brace_idx)
  end

  def test_insert_statement_at_start_of_block
    source = <<~RUST
      fn main() {
          let result = compute();
      }
    RUST
    tree = @parser.parse(source)

    fn_item = tree.root_node.child(0)
    fn_body = fn_item.child_by_field_name("body")

    result = TreeSitter::Inserter.new(source, tree)
      .at_start_of(fn_body)
      .insert_statement("let start = now();")
      .rewrite

    # Verify new statement comes before existing content
    start_idx = result.index("let start")
    compute_idx = result.index("compute()")

    assert_operator(start_idx, :<, compute_idx, "inserted statement should come before existing code")
  end

  def test_insert_with_correct_indentation_spaces
    source = fixture_content("sample_indentation_spaces.rs")
    tree = @parser.parse(source)

    fn_item = tree.root_node.child(0)
    fn_body = fn_item.child_by_field_name("body")

    result = TreeSitter::Inserter.new(source, tree)
      .at_end_of(fn_body)
      .insert_statement("let z = 3;")
      .rewrite

    # Should use 4-space indentation
    assert_includes(result, "    let z = 3;")
  end

  def test_insert_with_correct_indentation_tabs
    source = fixture_content("sample_indentation_tabs.rs")
    tree = @parser.parse(source)

    fn_item = tree.root_node.child(0)
    fn_body = fn_item.child_by_field_name("body")

    result = TreeSitter::Inserter.new(source, tree)
      .at_end_of(fn_body)
      .insert_statement("let z = 3;")
      .rewrite

    # Should use tab indentation
    assert_includes(result, "\tlet z = 3;")
  end

  def test_insert_sibling_function_after
    source = <<~RUST
      fn existing() {
          // body
      }
    RUST
    tree = @parser.parse(source)

    fn_node = tree.root_node.child(0)

    result = TreeSitter::Inserter.new(source, tree)
      .after(fn_node)
      .insert_sibling("fn new_func() {\n    // new body\n}")
      .rewrite

    assert_includes(result, "fn existing()")
    assert_includes(result, "fn new_func()")
    # new_func should come after existing
    existing_idx = result.index("fn existing")
    new_func_idx = result.index("fn new_func")

    assert_operator(existing_idx, :<, new_func_idx)
  end

  def test_insert_sibling_function_before
    source = <<~RUST
      fn existing() {
          // body
      }
    RUST
    tree = @parser.parse(source)

    fn_node = tree.root_node.child(0)

    result = TreeSitter::Inserter.new(source, tree)
      .before(fn_node)
      .insert_sibling("fn new_func() {}")
      .rewrite

    # new_func should come before existing
    new_func_idx = result.index("fn new_func")
    existing_idx = result.index("fn existing")

    assert_operator(new_func_idx, :<, existing_idx)
  end

  def test_insert_raw
    source = "fn test() {}"
    tree = @parser.parse(source)

    fn_node = tree.root_node.child(0)

    result = TreeSitter::Inserter.new(source, tree)
      .after(fn_node)
      .insert_raw("\n// raw comment")
      .rewrite

    assert_includes(result, "// raw comment")
  end

  def test_insert_block
    source = <<~RUST
      fn main() {
          let x = 1;
      }
    RUST
    tree = @parser.parse(source)

    fn_item = tree.root_node.child(0)
    fn_body = fn_item.child_by_field_name("body")

    result = TreeSitter::Inserter.new(source, tree)
      .at_end_of(fn_body)
      .insert_block("if x > 0", "println!(\"positive\");")
      .rewrite

    assert_includes(result, "if x > 0 {")
    assert_includes(result, "println!(\"positive\");")
  end

  def test_chained_insertions
    source = <<~RUST
      fn test() {
          middle();
      }
    RUST
    tree = @parser.parse(source)

    fn_item = tree.root_node.child(0)
    fn_body = fn_item.child_by_field_name("body")

    result = TreeSitter::Inserter.new(source, tree)
      .at_start_of(fn_body)
      .insert_statement("first();")
      .reset_position
      .at_end_of(fn_body)
      .insert_statement("last();")
      .rewrite

    first_idx = result.index("first();")
    middle_idx = result.index("middle();")
    last_idx = result.index("last();")

    assert_operator(first_idx, :<, middle_idx)
    assert_operator(middle_idx, :<, last_idx)
  end

  def test_requires_insertion_point
    source = "fn test() {}"
    tree = @parser.parse(source)

    inserter = TreeSitter::Inserter.new(source, tree)

    assert_raises(RuntimeError) do
      inserter.insert_statement("x = 1;")
    end
  end

  def test_rewrite_with_tree
    source = "fn test() {}"
    tree = @parser.parse(source)

    # Use query to find function_item reliably
    lang = TreeSitter.language("rust")
    query = TreeSitter::Query.new(lang, "(function_item) @fn")
    cursor = TreeSitter::QueryCursor.new
    captures = cursor.captures(query, tree.root_node, source)
    fn_node = captures.first.node

    new_source, new_tree = TreeSitter::Inserter.new(source, tree, parser: @parser)
      .after(fn_node)
      .insert_sibling("fn other() {}")
      .rewrite_with_tree

    assert_kind_of(TreeSitter::Tree, new_tree)
    # Verify both function definitions exist in the result
    assert_includes(new_source, "fn test()")
    assert_includes(new_source, "fn other()")
  end
end
