# frozen_string_literal: true

module TreeSitter
  # Rewriter class for applying edits to parsed source code.
  # Inspired by Parser::TreeRewriter from the parser gem.
  #
  # @example Basic usage
  #   tree = TreeSitter::Parser.new.tap { |p| p.language = "rust" }.parse(source)
  #   fn_name = tree.root_node.child(0).child_by_field_name("name")
  #
  #   new_source = TreeSitter::Rewriter.new(source, tree)
  #     .replace(fn_name, "new_name")
  #     .rewrite
  #
  class Rewriter
    # Represents a single edit operation
    Edit = Struct.new(:start_byte, :end_byte, :replacement, keyword_init: true)

    attr_reader :source, :tree, :edits

    # Initialize a new Rewriter
    #
    # @param source [String] The source code to rewrite
    # @param tree [TreeSitter::Tree, nil] Optional parsed tree (will parse if not provided)
    # @param parser [TreeSitter::Parser, nil] Optional parser for re-parsing (needed if tree not provided)
    def initialize(source, tree = nil, parser: nil)
      @source = source.dup.freeze
      @tree = tree
      @parser = parser
      @edits = []
    end

    # Remove the text at the given node or range
    #
    # @param node_or_range [TreeSitter::Node, TreeSitter::Range] The node or range to remove
    # @return [self] Returns self for method chaining
    def remove(node_or_range)
      replace(node_or_range, "")
    end

    # Replace the text at the given node or range with new content
    #
    # @param node_or_range [TreeSitter::Node, TreeSitter::Range] The node or range to replace
    # @param content [String] The replacement content
    # @return [self] Returns self for method chaining
    def replace(node_or_range, content)
      range = normalize_range(node_or_range)
      @edits << Edit.new(
        start_byte: range.start_byte,
        end_byte: range.end_byte,
        replacement: content.to_s,
      )
      self
    end

    # Insert text before the given node or range
    #
    # @param node_or_range [TreeSitter::Node, TreeSitter::Range] The node or range
    # @param content [String] The content to insert
    # @return [self] Returns self for method chaining
    def insert_before(node_or_range, content)
      range = normalize_range(node_or_range)
      @edits << Edit.new(
        start_byte: range.start_byte,
        end_byte: range.start_byte,
        replacement: content.to_s,
      )
      self
    end

    # Insert text after the given node or range
    #
    # @param node_or_range [TreeSitter::Node, TreeSitter::Range] The node or range
    # @param content [String] The content to insert
    # @return [self] Returns self for method chaining
    def insert_after(node_or_range, content)
      range = normalize_range(node_or_range)
      @edits << Edit.new(
        start_byte: range.end_byte,
        end_byte: range.end_byte,
        replacement: content.to_s,
      )
      self
    end

    # Wrap the node or range with before and after text
    #
    # @param node_or_range [TreeSitter::Node, TreeSitter::Range] The node or range to wrap
    # @param before_text [String] Text to insert before
    # @param after_text [String] Text to insert after
    # @return [self] Returns self for method chaining
    def wrap(node_or_range, before_text, after_text)
      insert_before(node_or_range, before_text)
      insert_after(node_or_range, after_text)
      self
    end

    # Apply all accumulated edits and return the new source code
    #
    # Edits are applied in reverse order (from end to start) to preserve
    # byte positions of earlier edits.
    #
    # @return [String] The rewritten source code
    def rewrite
      # Sort edits by position descending to apply from end to start
      # This prevents earlier edits from invalidating later positions
      sorted = @edits.sort_by { |e| [-e.start_byte, -e.end_byte] }

      result = @source.dup
      sorted.each do |edit|
        result[edit.start_byte...edit.end_byte] = edit.replacement
      end
      result
    end

    # Apply edits and return both the new source and a new parse tree
    #
    # @return [Array<String, TreeSitter::Tree>] The new source and tree
    # @raise [RuntimeError] If no parser is available for re-parsing
    def rewrite_with_tree
      new_source = rewrite

      parser = @parser || create_parser_from_tree
      raise "No parser available for re-parsing" unless parser

      new_tree = parser.parse(new_source)
      [new_source, new_tree]
    end

    private

    def normalize_range(node_or_range)
      case node_or_range
      when TreeSitter::Node
        node_or_range.range
      when TreeSitter::Range
        node_or_range
      else
        raise ArgumentError,
          "Expected TreeSitter::Node or TreeSitter::Range, got #{node_or_range.class}"
      end
    end

    def create_parser_from_tree
      return unless @tree

      parser = TreeSitter::Parser.new
      lang = @tree.language
      parser.language = lang.name if lang
      parser
    rescue StandardError
      nil
    end
  end
end
