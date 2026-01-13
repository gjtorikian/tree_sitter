# frozen_string_literal: true

require "test_helper"

class TestParser < Minitest::Test
  include TestHelper

  def setup
    register_language("rust")
    @parser = TreeSitter::Parser.new
    @parser.language = "rust"
  end

  def test_parse_simple_function
    source = "fn main() {}"
    tree = @parser.parse(source)

    refute_nil(tree)
    assert_equal("source_file", tree.root_node.kind)
  end

  def test_parse_with_syntax_error
    source = "fn main( {}" # Missing closing paren
    tree = @parser.parse(source)

    refute_nil(tree)
    assert_predicate(tree.root_node, :has_error?)
  end

  def test_parse_preserves_source
    source = "fn add(a: i32) -> i32 { a }"
    tree = @parser.parse(source)

    assert_equal(source, tree.source)
  end

  def test_tree_language
    tree = @parser.parse("fn main() {}")

    lang = tree.language

    refute_nil(lang)
    assert_equal("rust", lang.name)
  end

  def test_parse_returns_nil_without_language
    parser = TreeSitter::Parser.new
    assert_raises(RuntimeError) { parser.parse("fn main() {}") }
  end

  def test_language_assignment
    parser = TreeSitter::Parser.new
    parser.language = "rust"

    lang = parser.language

    refute_nil(lang)
    assert_equal("rust", lang.name)
  end

  def test_language_version
    lang = TreeSitter.language("rust")

    assert_kind_of(Integer, lang.version)
    assert_operator(lang.version, :>, 0)
  end

  def test_language_node_kind_count
    lang = TreeSitter.language("rust")

    assert_kind_of(Integer, lang.node_kind_count)
    assert_operator(lang.node_kind_count, :>, 0)
  end

  def test_timeout_micros_getter_setter
    @parser.timeout_micros = 1_000_000

    assert_equal(1_000_000, @parser.timeout_micros)
  end

  def test_timeout_micros_default_is_zero
    parser = TreeSitter::Parser.new

    assert_equal(0, parser.timeout_micros)
  end

  def test_parse_succeeds_with_sufficient_timeout
    @parser.timeout_micros = 10_000_000 # 10 seconds
    tree = @parser.parse("fn main() {}")

    refute_nil(tree)
    assert_equal("source_file", tree.root_node.kind)
  end

  def test_timeout_can_be_set_and_cleared
    @parser.timeout_micros = 5_000_000

    assert_equal(5_000_000, @parser.timeout_micros)

    # Clearing the timeout (set to 0) should allow normal parsing
    @parser.timeout_micros = 0

    assert_equal(0, @parser.timeout_micros)

    tree = @parser.parse("fn main() {}")

    refute_nil(tree)
  end

  def test_reset
    @parser.reset
    # Should not raise
    tree = @parser.parse("fn main() {}")

    refute_nil(tree)
  end
end
