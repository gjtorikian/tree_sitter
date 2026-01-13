# frozen_string_literal: true

require "test_helper"

class TestNode < Minitest::Test
  include TestHelper

  def setup
    register_language("rust")
    @parser = TreeSitter::Parser.new
    @parser.language = "rust"
    @source = fixture_content("sample.rs")
    @tree = @parser.parse(@source)
    @root = @tree.root_node
  end

  def test_root_node_kind
    assert_equal("source_file", @root.kind)
  end

  def test_child_access
    first_child = @root.child(0)

    refute_nil(first_child)
    assert_equal("function_item", first_child.kind)
  end

  def test_child_count
    assert_predicate(@root.child_count, :positive?)
  end

  def test_named_child_access
    first_named = @root.named_child(0)

    refute_nil(first_named)
    assert_predicate(first_named, :named?)
  end

  def test_named_child_count
    named_count = @root.named_child_count

    assert_kind_of(Integer, named_count)
    assert_operator(named_count, :<=, @root.child_count)
    assert_equal(@root.named_children.length, named_count)
  end

  def test_children
    children = @root.children

    assert_kind_of(Array, children)
    assert_equal(children.length, @root.child_count)
  end

  def test_named_children
    named = @root.named_children
    unnamed_count = @root.children.count { |element| !element.named? }

    assert_equal(named.length, @root.child_count - unnamed_count)
  end

  def test_child_by_field_name
    fn_item = @root.child(0)
    fn_name = fn_item.child_by_field_name("name")

    refute_nil(fn_name)
    assert_equal("identifier", fn_name.kind)
    assert_equal("add", fn_name.text)
  end

  def test_node_text
    fn_item = @root.child(0)
    fn_name = fn_item.child_by_field_name("name")

    assert_equal("add", fn_name.text)
  end

  def test_node_positions
    fn_item = @root.child(0)
    fn_name = fn_item.child_by_field_name("name")

    # "fn " = 3 bytes, so name starts at byte 3
    assert_equal(3, fn_name.start_byte)
    # "add" = 3 bytes, so end is at byte 6
    assert_equal(6, fn_name.end_byte)
  end

  def test_start_point
    fn_item = @root.child(0)
    fn_name = fn_item.child_by_field_name("name")

    point = fn_name.start_point

    assert_equal(0, point.row)
    assert_equal(3, point.column)
  end

  def test_end_point
    fn_item = @root.child(0)
    fn_name = fn_item.child_by_field_name("name")

    point = fn_name.end_point

    assert_equal(0, point.row)
    assert_equal(6, point.column)
  end

  def test_range
    fn_item = @root.child(0)
    fn_name = fn_item.child_by_field_name("name")

    range = fn_name.range

    assert_equal(3, range.start_byte)
    assert_equal(6, range.end_byte)
    assert_equal(3, range.size)
  end

  def test_range_start_point
    fn_item = @root.child(0)
    fn_name = fn_item.child_by_field_name("name")

    range = fn_name.range
    start_point = range.start_point

    assert_kind_of(TreeSitter::Point, start_point)
    assert_equal(0, start_point.row)
    assert_equal(3, start_point.column)
  end

  def test_range_end_point
    fn_item = @root.child(0)
    fn_name = fn_item.child_by_field_name("name")

    range = fn_name.range
    end_point = range.end_point

    assert_kind_of(TreeSitter::Point, end_point)
    assert_equal(0, end_point.row)
    assert_equal(6, end_point.column)
  end

  def test_range_inspect
    fn_item = @root.child(0)
    fn_name = fn_item.child_by_field_name("name")

    range = fn_name.range
    inspect_str = range.inspect

    assert_includes(inspect_str, "TreeSitter::Range")
    assert_includes(inspect_str, "start_byte=3")
    assert_includes(inspect_str, "end_byte=6")
  end

  def test_point_new
    point = TreeSitter::Point.new(5, 10)

    assert_equal(5, point.row)
    assert_equal(10, point.column)
  end

  def test_point_to_a
    fn_item = @root.child(0)
    fn_name = fn_item.child_by_field_name("name")

    point = fn_name.start_point
    array = point.to_a

    assert_kind_of(Array, array)
    assert_equal([0, 3], array)
  end

  def test_point_inspect
    fn_item = @root.child(0)
    fn_name = fn_item.child_by_field_name("name")

    point = fn_name.start_point
    inspect_str = point.inspect

    assert_includes(inspect_str, "TreeSitter::Point")
    assert_includes(inspect_str, "row=0")
    assert_includes(inspect_str, "column=3")
  end

  def test_point_equality
    point1 = TreeSitter::Point.new(0, 3)
    point2 = TreeSitter::Point.new(0, 3)
    point3 = TreeSitter::Point.new(1, 5)

    assert_equal(point1, point2)
    refute_equal(point1, point3)
  end

  def test_is_named
    fn_item = @root.child(0)

    assert_predicate(fn_item, :named?)
  end

  def test_kind_id
    fn_item = @root.child(0)

    assert_kind_of(Integer, fn_item.kind_id)
  end

  def test_to_sexp
    sexp = @root.to_sexp

    assert_includes(sexp, "source_file")
    assert_includes(sexp, "function_item")
  end

  def test_inspect
    inspect_str = @root.inspect

    assert_includes(inspect_str, "TreeSitter::Node")
    assert_includes(inspect_str, "source_file")
  end

  def test_equality
    root1 = @tree.root_node
    root2 = @tree.root_node

    assert_equal(root1, root2)
    assert(root1.eql?(root2))
  end

  def test_sibling_navigation
    children = @root.children
    return if children.length < 2

    first = children[0]
    second = children[1]

    assert_equal(second.kind, first.next_sibling&.kind)
    assert_equal(first.kind, second.prev_sibling&.kind)
  end

  def test_named_sibling_navigation
    named_children = @root.named_children
    return if named_children.length < 2

    first = named_children[0]
    second = named_children[1]

    assert_equal(second.kind, first.next_named_sibling&.kind)
    assert_equal(first.kind, second.prev_named_sibling&.kind)
  end

  def test_parent_navigation
    fn_item = @root.child(0)
    fn_name = fn_item.child_by_field_name("name")

    parent = fn_name.parent

    refute_nil(parent)
    assert_equal("function_item", parent.kind)
  end

  def test_type_alias
    fn_item = @root.child(0)

    assert_equal(fn_item.kind, fn_item.type)
    assert_equal("function_item", fn_item.type)
  end

  def test_to_s_alias
    sexp_result = @root.to_sexp
    to_s_result = @root.to_s

    assert_equal(sexp_result, to_s_result)
  end

  def test_missing_predicate
    # Normal nodes should not be missing
    fn_item = @root.child(0)

    refute_predicate(fn_item, :missing?)
  end

  def test_extra_node
    # Comments are typically "extra" nodes in tree-sitter
    parser = TreeSitter::Parser.new
    parser.language = "rust"
    tree = parser.parse("// comment\nfn main() {}")

    root = tree.root_node
    comment = root.children.find { |c| c.kind == "line_comment" }

    if comment
      assert_predicate(comment, :extra?)
    else
      # If no comment found as extra, just verify the method works
      refute_predicate(root, :extra?)
    end
  end

  def test_error_node
    parser = TreeSitter::Parser.new
    parser.language = "rust"
    tree = parser.parse("fn @@@@ {}") # Invalid syntax

    root = tree.root_node
    has_error_node = find_error_node(root)

    assert(has_error_node, "Should find an error node in invalid code")
  end

  def test_has_changes
    # Fresh parse should not have changes
    refute_predicate(@root, :has_changes?)
  end

  private

  def find_error_node(node)
    return true if node.error?

    node.children.any? { |child| find_error_node(child) }
  end
end
