# frozen_string_literal: true

require "test_helper"

class TestRewriter < Minitest::Test
  include TestHelper

  def setup
    register_language("rust")
    @parser = TreeSitter::Parser.new
    @parser.language = "rust"
    @lang = TreeSitter.language("rust")
    @source = <<~RUST
      fn add(a: i32, b: i32) -> i32 {
          a + b
      }
    RUST
    @tree = @parser.parse(@source)
  end

  def test_replace_function_name
    fn_item = @tree.root_node.child(0)
    fn_name = fn_item.child_by_field_name("name")

    rewriter = TreeSitter::Rewriter.new(@source, @tree)
    rewriter.replace(fn_name, "sum")
    result = rewriter.rewrite

    assert_includes(result, "fn sum(")
    refute_includes(result, "fn add(")
  end

  def test_remove_node
    fn_item = @tree.root_node.child(0)
    fn_name = fn_item.child_by_field_name("name")

    rewriter = TreeSitter::Rewriter.new(@source, @tree)
    rewriter.remove(fn_name)
    result = rewriter.rewrite

    assert_includes(result, "fn (") # Name removed
  end

  def test_insert_before
    fn_item = @tree.root_node.child(0)

    rewriter = TreeSitter::Rewriter.new(@source, @tree)
    rewriter.insert_before(fn_item, "/// Documentation\n")
    result = rewriter.rewrite

    assert(result.start_with?("/// Documentation\n"))
  end

  def test_insert_after
    # Use query to find function_item reliably
    query = TreeSitter::Query.new(@lang, "(function_item) @fn")
    cursor = TreeSitter::QueryCursor.new
    captures = cursor.captures(query, @tree.root_node, @source)
    fn_item = captures.first.node

    rewriter = TreeSitter::Rewriter.new(@source, @tree)
    rewriter.insert_after(fn_item, "\nfn main() {}")
    result = rewriter.rewrite

    assert_includes(result, "}\nfn main() {}")
  end

  def test_wrap_node
    fn_item = @tree.root_node.child(0)
    fn_name = fn_item.child_by_field_name("name")

    rewriter = TreeSitter::Rewriter.new(@source, @tree)
    rewriter.wrap(fn_name, "/* ", " */")
    result = rewriter.rewrite

    assert_includes(result, "fn /* add */(")
  end

  def test_multiple_edits_applied_correctly
    fn_item = @tree.root_node.child(0)
    fn_name = fn_item.child_by_field_name("name")

    rewriter = TreeSitter::Rewriter.new(@source, @tree)
    rewriter.replace(fn_name, "sum")
    rewriter.insert_before(fn_item, "#[inline]\n")
    result = rewriter.rewrite

    assert_includes(result, "#[inline]")
    assert_includes(result, "fn sum(")
  end

  def test_chained_edits
    fn_item = @tree.root_node.child(0)
    fn_name = fn_item.child_by_field_name("name")

    result = TreeSitter::Rewriter.new(@source, @tree)
      .replace(fn_name, "sum")
      .insert_before(fn_item, "// Renamed\n")
      .rewrite

    assert_includes(result, "// Renamed")
    assert_includes(result, "fn sum(")
  end

  def test_rewrite_with_tree
    fn_item = @tree.root_node.child(0)
    fn_name = fn_item.child_by_field_name("name")

    rewriter = TreeSitter::Rewriter.new(@source, @tree, parser: @parser)
    rewriter.replace(fn_name, "sum")

    new_source, new_tree = rewriter.rewrite_with_tree

    assert_includes(new_source, "fn sum(")
    new_fn_name = new_tree.root_node.child(0).child_by_field_name("name")

    assert_equal("sum", new_fn_name.text)
  end

  def test_replace_with_range
    fn_item = @tree.root_node.child(0)
    fn_name = fn_item.child_by_field_name("name")
    range = fn_name.range

    rewriter = TreeSitter::Rewriter.new(@source, @tree)
    rewriter.replace(range, "sum")
    result = rewriter.rewrite

    assert_includes(result, "fn sum(")
  end

  def test_invalid_argument_raises
    rewriter = TreeSitter::Rewriter.new(@source, @tree)

    assert_raises(ArgumentError) do
      rewriter.replace("not a node", "replacement")
    end
  end

  def test_source_is_frozen
    rewriter = TreeSitter::Rewriter.new(@source, @tree)

    assert_predicate(rewriter.source, :frozen?)
  end

  def test_edits_are_tracked
    fn_item = @tree.root_node.child(0)
    fn_name = fn_item.child_by_field_name("name")

    rewriter = TreeSitter::Rewriter.new(@source, @tree)

    assert_equal(0, rewriter.edits.length)

    rewriter.replace(fn_name, "sum")

    assert_equal(1, rewriter.edits.length)

    rewriter.insert_before(fn_item, "// Comment\n")

    assert_equal(2, rewriter.edits.length)
  end
end
