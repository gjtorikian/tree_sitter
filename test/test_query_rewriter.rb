# frozen_string_literal: true

require "test_helper"

class TestQueryRewriter < Minitest::Test
  include TestHelper

  def setup
    register_language("rust")
    @parser = TreeSitter::Parser.new
    @parser.language = "rust"
    @lang = TreeSitter.language("rust")
  end

  def test_rename_all_function_calls
    source = <<~RUST
      fn main() {
          old_func();
          old_func();
          other_func();
      }

      fn old_func() {}
      fn other_func() {}
    RUST
    tree = @parser.parse(source)

    result = TreeSitter::QueryRewriter.new(source, tree, @lang)
      .query("(call_expression function: (identifier) @fn_name)")
      .where { |m| m.captures.any? { |c| c.name == "fn_name" && c.node.text == "old_func" } }
      .replace("@fn_name") { "new_func" }
      .rewrite

    assert_equal(2, result.scan("new_func").count)
    # other_func should be unchanged (both the call and definition)
    assert_includes(result, "other_func();")
    # Original function definition should remain (we only renamed calls)
    assert_includes(result, "fn old_func()")
  end

  def test_remove_all_comments
    source = <<~RUST
      // Comment 1
      fn main() {
          // Comment 2
          let x = 1;
      }
    RUST
    tree = @parser.parse(source)

    result = TreeSitter::QueryRewriter.new(source, tree, @lang)
      .query("(line_comment) @comment")
      .remove("@comment")
      .rewrite

    refute_includes(result, "Comment 1")
    refute_includes(result, "Comment 2")
    assert_includes(result, "fn main()")
    assert_includes(result, "let x = 1")
  end

  def test_wrap_function_bodies
    source = <<~RUST
      fn process() {
          do_work();
      }
    RUST
    tree = @parser.parse(source)

    result = TreeSitter::QueryRewriter.new(source, tree, @lang)
      .query("(function_item body: (block) @body)")
      .wrap("@body", before: "/* start */", after: "/* end */")
      .rewrite

    assert_includes(result, "/* start */")
    assert_includes(result, "/* end */")
  end

  def test_add_derive_to_all_structs
    source = <<~RUST
      struct Point { x: i32, y: i32 }
      struct Rectangle { width: u32, height: u32 }
    RUST
    tree = @parser.parse(source)

    result = TreeSitter::QueryRewriter.new(source, tree, @lang)
      .query("(struct_item) @struct")
      .insert_before("@struct") { "#[derive(Debug)]\n" }
      .rewrite

    assert_equal(2, result.scan("#[derive(Debug)]").count)
    assert_includes(result, "#[derive(Debug)]\nstruct Point")
  end

  def test_filter_by_capture_predicate
    source = <<~RUST
      fn public_fn() {}
      fn private_fn() {}
    RUST
    tree = @parser.parse(source)

    result = TreeSitter::QueryRewriter.new(source, tree, @lang)
      .query("(function_item name: (identifier) @name)")
      .where { |m| m.captures.any? { |c| c.name == "name" && c.node.text.start_with?("public") } }
      .replace("@name") { "renamed_public_fn" }
      .rewrite

    assert_includes(result, "fn renamed_public_fn")
    assert_includes(result, "fn private_fn")
  end

  def test_insert_after_captures
    source = <<~RUST
      fn test() {
          let x = 1;
      }
    RUST
    tree = @parser.parse(source)

    result = TreeSitter::QueryRewriter.new(source, tree, @lang)
      .query("(let_declaration) @let")
      .insert_after("@let") { " // initialized" }
      .rewrite

    assert_includes(result, "let x = 1; // initialized")
  end

  def test_multiple_operations
    source = <<~RUST
      fn old_func() {
          // TODO: implement
      }
    RUST
    tree = @parser.parse(source)

    result = TreeSitter::QueryRewriter.new(source, tree, @lang)
      .query("[
        (function_item name: (identifier) @fn_name)
        (line_comment) @comment
      ]")
      .where { |m| m.captures.any? { |c| c.name == "fn_name" } || m.captures.any? { |c| c.name == "comment" } }
      .replace("@fn_name") { "new_func" }
      .remove("@comment")
      .rewrite

    assert_includes(result, "fn new_func()")
    refute_includes(result, "TODO")
  end

  def test_preview_edits
    source = "fn test() {}"
    tree = @parser.parse(source)

    rewriter = TreeSitter::QueryRewriter.new(source, tree, @lang)
      .query("(function_item name: (identifier) @name)")
      .replace("@name") { "new_name" }

    edits = rewriter.preview_edits

    assert_kind_of(Array, edits)
    assert_predicate(edits.length, :positive?)

    edit = edits.first

    assert_equal("test", edit[:original])
    assert_equal("new_name", edit[:replacement])
  end

  def test_matches_returns_filtered_results
    source = <<~RUST
      fn alpha() {}
      fn beta() {}
      fn gamma() {}
    RUST
    tree = @parser.parse(source)

    matches = TreeSitter::QueryRewriter.new(source, tree, @lang)
      .query("(function_item name: (identifier) @name)")
      .where { |m| m.captures.any? { |c| c.node.text.start_with?("a", "b") } }
      .matches

    assert_equal(2, matches.length)
  end

  def test_rewrite_with_tree
    source = "fn old() {}"
    tree = @parser.parse(source)

    new_source, new_tree = TreeSitter::QueryRewriter.new(source, tree, @lang, parser: @parser)
      .query("(function_item name: (identifier) @name)")
      .replace("@name") { "new" }
      .rewrite_with_tree

    assert_equal("fn new() {}", new_source)
    assert_kind_of(TreeSitter::Tree, new_tree)
    assert_equal("fn new() {}", new_tree.root_node.text)
  end

  def test_dynamic_wrap
    source = "fn test() {}"
    tree = @parser.parse(source)

    result = TreeSitter::QueryRewriter.new(source, tree, @lang)
      .query("(function_item name: (identifier) @name)")
      .wrap("@name") { |_node| ["<", ">"] }
      .rewrite

    assert_includes(result, "<test>")
  end
end
