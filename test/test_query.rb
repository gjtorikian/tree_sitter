# frozen_string_literal: true

require "test_helper"

class TestQuery < Minitest::Test
  include TestHelper

  def setup
    register_language("rust")
    @parser = TreeSitter::Parser.new
    @parser.language = "rust"
    @source = fixture_content("sample.rs")
    @tree = @parser.parse(@source)
    @lang = TreeSitter.language("rust")
  end

  def test_create_query
    query = TreeSitter::Query.new(@lang, "(function_item) @fn")

    refute_nil(query)
    assert_equal(1, query.pattern_count)
  end

  def test_capture_names
    query = TreeSitter::Query.new(@lang, "(function_item name: (identifier) @fn_name) @fn")

    names = query.capture_names

    assert_includes(names, "fn_name")
    assert_includes(names, "fn")
  end

  def test_invalid_query_raises
    assert_raises(SyntaxError) do
      TreeSitter::Query.new(@lang, "(invalid_node_type)")
    end
  end

  def test_query_matches
    query = TreeSitter::Query.new(@lang, "(function_item) @fn")
    cursor = TreeSitter::QueryCursor.new

    matches = cursor.matches(query, @tree.root_node, @source)

    assert_kind_of(Array, matches)
    assert_predicate(matches.length, :positive?)
  end

  def test_query_captures
    query = TreeSitter::Query.new(@lang, "(function_item name: (identifier) @fn_name)")
    cursor = TreeSitter::QueryCursor.new

    captures = cursor.captures(query, @tree.root_node, @source)

    assert_kind_of(Array, captures)
    assert_predicate(captures.length, :positive?)

    fn_names = captures.select { |c| c.name == "fn_name" }.map { |c| c.node.text }

    assert_includes(fn_names, "add")
    assert_includes(fn_names, "main")
  end

  def test_query_match_structure
    query = TreeSitter::Query.new(@lang, "(function_item) @fn")
    cursor = TreeSitter::QueryCursor.new

    matches = cursor.matches(query, @tree.root_node, @source)
    match = matches.first

    assert_respond_to(match, :pattern_index)
    assert_respond_to(match, :captures)
    assert_equal(0, match.pattern_index)
    assert_kind_of(Array, match.captures)
  end

  def test_query_capture_structure
    query = TreeSitter::Query.new(@lang, "(function_item name: (identifier) @fn_name)")
    cursor = TreeSitter::QueryCursor.new

    captures = cursor.captures(query, @tree.root_node, @source)
    capture = captures.first

    assert_respond_to(capture, :name)
    assert_respond_to(capture, :node)
    assert_equal("fn_name", capture.name)
    assert_kind_of(TreeSitter::Node, capture.node)
  end

  def test_find_all_struct_fields
    query = TreeSitter::Query.new(@lang, "(field_declaration name: (field_identifier) @field_name)")
    cursor = TreeSitter::QueryCursor.new

    captures = cursor.captures(query, @tree.root_node, @source)
    field_names = captures.map { |c| c.node.text }

    assert_includes(field_names, "x")
    assert_includes(field_names, "y")
  end
end
