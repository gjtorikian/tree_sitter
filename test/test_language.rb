# frozen_string_literal: true

require "test_helper"

class TestMultiLanguage < Minitest::Test
  include TestHelper

  # Test each language can parse its fixture file
  LANGUAGES = {
    "rust" => { file: "sample.rs", root: "source_file" },
    "ruby" => { file: "sample.rb", root: "program" },
    "python" => { file: "sample.py", root: "module" },
    "javascript" => { file: "sample.js", root: "program" },
    "go" => { file: "sample.go", root: "source_file" },
    "php" => { file: "sample.php", root: "program" },
    "java" => { file: "sample.java", root: "program" },
    "c_sharp" => { file: "sample.cs", root: "compilation_unit" },
  }.freeze

  LANGUAGES.each do |lang_name, config|
    define_method("test_parse_#{lang_name}") do
      register_language(lang_name)

      parser = TreeSitter::Parser.new
      parser.language = lang_name

      source = fixture_content(config[:file])
      tree = parser.parse(source)

      refute_nil tree, "Failed to parse #{lang_name} source"
      assert_equal config[:root],
        tree.root_node.kind,
        "Unexpected root node for #{lang_name}"
      refute_predicate tree.root_node,
        :has_error?,
        "Parse errors in #{lang_name}: #{tree.root_node.to_sexp}"
    end

    define_method("test_traverse_#{lang_name}") do
      register_language(lang_name)

      parser = TreeSitter::Parser.new
      parser.language = lang_name

      source = fixture_content(config[:file])
      tree = parser.parse(source)
      root = tree.root_node

      # Should be able to get children
      assert_predicate root.child_count,
        :positive?,
        "#{lang_name} root should have children"

      # Should be able to traverse
      first_child = root.child(0)

      refute_nil first_child, "#{lang_name} should have first child"
      assert_kind_of String, first_child.kind
    end

    define_method("test_rewrite_#{lang_name}") do
      register_language(lang_name)

      parser = TreeSitter::Parser.new
      parser.language = lang_name

      source = fixture_content(config[:file])
      tree = parser.parse(source)

      # Simple test: wrap first child in comment
      first_child = tree.root_node.child(0)
      next unless first_child&.named?

      rewriter = TreeSitter::Rewriter.new(source, tree)
      rewriter.insert_before(first_child, "/* start */")
      result = rewriter.rewrite

      assert_includes result,
        "/* start */",
        "Rewrite failed for #{lang_name}"
    end
  end

  def test_register_multiple_languages
    LANGUAGES.each_key do |lang_name|
      register_language(lang_name)
    end

    # Verify all registered languages are listed
    available = TreeSitter.languages

    LANGUAGES.each_key do |lang_name|
      assert_includes(available, lang_name)
    end
  end

  def test_switch_languages
    register_language("rust")
    register_language("ruby")

    parser = TreeSitter::Parser.new

    # Parse Rust
    parser.language = "rust"
    rust_tree = parser.parse("fn main() {}")

    assert_equal("source_file", rust_tree.root_node.kind)

    # Switch to Ruby
    parser.language = "ruby"
    ruby_tree = parser.parse("def main; end")

    assert_equal("program", ruby_tree.root_node.kind)
  end

  def test_register_language_with_nonexistent_path
    error = assert_raises(RuntimeError) do
      TreeSitter.register_language("fake", "/nonexistent/path/to/library.so")
    end

    assert_match(/Failed to load library/, error.message)
  end
end
