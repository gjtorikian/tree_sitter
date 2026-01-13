# frozen_string_literal: true

require_relative "formatting"

module TreeSitter
  # Syntax-aware insertions that respect indentation and formatting.
  #
  # @example Insert a new statement with proper indentation
  #   Inserter.new(source, tree)
  #     .at_end_of(block_node)
  #     .insert_statement("return result;")
  #     .rewrite
  #
  # @example Insert a sibling function
  #   Inserter.new(source, tree)
  #     .after(existing_fn)
  #     .insert_sibling("fn new_func() {}")
  #     .rewrite
  #
  class Inserter
    # Represents a pending insertion
    Insertion = Struct.new(:byte_pos, :content, :newline_before, :newline_after, keyword_init: true)

    attr_reader :source, :tree

    # Initialize a new Inserter
    #
    # @param source [String] The source code
    # @param tree [TreeSitter::Tree] The parsed syntax tree
    # @param parser [TreeSitter::Parser, nil] Optional parser for re-parsing
    def initialize(source, tree, parser: nil)
      @source = source.dup.freeze
      @tree = tree
      @parser = parser
      @indent_detector = Formatting::IndentationDetector.new(source)
      @insertions = []
      @insertion_point = nil
      @insertion_context = nil
    end

    # Set insertion point at the beginning of a node's content (inside the node)
    #
    # @param node [TreeSitter::Node] Container node (e.g., a block)
    # @return [self] For method chaining
    def at_start_of(node)
      # Find the first child's start, or just after the opening
      # For blocks like { ... }, we want to insert after the opening brace
      @insertion_context = :inside_start
      @insertion_node = node
      @target_indent_level = @indent_detector.level_at_byte(node.start_byte) + 1

      # Find position just after opening delimiter
      first_child = node.named_child(0)
      if first_child
        @insertion_point = first_child.start_byte
      else
        # Empty block - find end of opening line or after opening brace
        node_text = @source[node.start_byte...node.end_byte]
        @insertion_point = if (brace_pos = node_text.index("{"))
          node.start_byte + brace_pos + 1
        else
          node.start_byte + 1
        end
      end

      self
    end

    # Set insertion point at the end of a node's content (inside the node)
    #
    # @param node [TreeSitter::Node] Container node
    # @return [self] For method chaining
    def at_end_of(node)
      @insertion_context = :inside_end
      @insertion_node = node
      @target_indent_level = @indent_detector.level_at_byte(node.start_byte) + 1

      # Find position just before closing delimiter
      node_text = @source[node.start_byte...node.end_byte]
      @insertion_point = if (brace_pos = node_text.rindex("}"))
        node.start_byte + brace_pos
      else
        node.end_byte
      end

      self
    end

    # Set insertion point before a node (as sibling)
    #
    # @param node [TreeSitter::Node] Reference node
    # @return [self] For method chaining
    def before(node)
      @insertion_context = :before
      @insertion_node = node
      @insertion_point = node.start_byte
      @target_indent_level = @indent_detector.level_at_byte(node.start_byte)
      self
    end

    # Set insertion point after a node (as sibling)
    #
    # @param node [TreeSitter::Node] Reference node
    # @return [self] For method chaining
    def after(node)
      @insertion_context = :after
      @insertion_node = node
      @insertion_point = node.end_byte
      @target_indent_level = @indent_detector.level_at_byte(node.start_byte)
      self
    end

    # Insert a statement with automatic indentation
    #
    # @param content [String] The statement to insert
    # @param newline_before [Boolean] Add newline before (default: context-dependent)
    # @param newline_after [Boolean] Add newline after (default: true)
    # @return [self] For method chaining
    def insert_statement(content, newline_before: nil, newline_after: true)
      raise "No insertion point set. Call at_start_of, at_end_of, before, or after first." unless @insertion_point

      # Determine newline_before based on context
      newline_before = newline_before? if newline_before.nil?

      # Adjust indentation of content
      adjusted_content = adjust_content_indentation(content)

      @insertions << Insertion.new(
        byte_pos: @insertion_point,
        content: adjusted_content,
        newline_before: newline_before,
        newline_after: newline_after,
      )
      self
    end

    # Insert raw content without indentation adjustment
    #
    # @param content [String] The content to insert
    # @return [self] For method chaining
    def insert_raw(content)
      raise "No insertion point set. Call at_start_of, at_end_of, before, or after first." unless @insertion_point

      @insertions << Insertion.new(
        byte_pos: @insertion_point,
        content: content,
        newline_before: false,
        newline_after: false,
      )
      self
    end

    # Insert a sibling node with matching indentation
    #
    # @param content [String] The sibling content
    # @param separator [String] Separator between siblings (default: newlines based on context)
    # @return [self] For method chaining
    def insert_sibling(content, separator: nil)
      raise "No insertion point set. Call before or after first." unless @insertion_point

      separator ||= "\n\n" # Default to blank line between top-level items

      # Adjust indentation of content
      adjusted_content = adjust_content_indentation(content)

      # For after insertion, add separator before content
      # For before insertion, add separator after content
      full_content = case @insertion_context
      when :after
        separator + adjusted_content
      when :before
        adjusted_content + separator
      else
        adjusted_content
      end

      @insertions << Insertion.new(
        byte_pos: @insertion_point,
        content: full_content,
        newline_before: false,
        newline_after: false,
      )
      self
    end

    # Insert a block with proper indentation (for block constructs)
    #
    # @param header [String] The block header (e.g., "if condition")
    # @param body [String] The block body content (will be indented)
    # @param open_brace [String] Opening delimiter (default: " {")
    # @param close_brace [String] Closing delimiter (default: "}")
    # @return [self] For method chaining
    def insert_block(header, body, open_brace: " {", close_brace: "}")
      raise "No insertion point set. Call at_start_of, at_end_of, before, or after first." unless @insertion_point

      indent = @indent_detector.indent_string_for_level(@target_indent_level)
      body_indent = @indent_detector.indent_string_for_level(@target_indent_level + 1)

      # Build the block with proper indentation
      indented_body = body.lines.map do |line|
        if line.strip.empty?
          line
        else
          body_indent + line.lstrip
        end
      end.join

      block_content = "#{indent}#{header}#{open_brace}\n#{indented_body}\n#{indent}#{close_brace}"

      newline_before = newline_before?

      @insertions << Insertion.new(
        byte_pos: @insertion_point,
        content: block_content,
        newline_before: newline_before,
        newline_after: true,
      )
      self
    end

    # Apply all insertions
    #
    # @return [String] The source with insertions
    def rewrite
      return @source if @insertions.empty?

      # Sort by position descending to apply from end to start
      sorted = @insertions.sort_by { |ins| -ins.byte_pos }

      result = @source.dup
      sorted.each do |insertion|
        content = insertion.content
        content = "\n#{content}" if insertion.newline_before
        content = "#{content}\n" if insertion.newline_after

        result.insert(insertion.byte_pos, content)
      end
      result
    end

    # Apply insertions and return both source and new tree
    #
    # @return [Array<String, Tree>] The new source and re-parsed tree
    def rewrite_with_tree
      new_source = rewrite

      parser = @parser || create_parser_from_tree
      raise "No parser available for re-parsing" unless parser

      new_tree = parser.parse(new_source)
      [new_source, new_tree]
    end

    # Reset insertion point to allow setting a new one
    #
    # @return [self] For method chaining
    def reset_position
      @insertion_point = nil
      @insertion_context = nil
      @insertion_node = nil
      @target_indent_level = nil
      self
    end

    private

    def newline_before?
      case @insertion_context
      when :inside_start
        # After opening brace, usually need newline
        # But check if there's already content on the same line
        true
      when :inside_end
        # Before closing brace, check if we need newline
        # Look at what's before the insertion point
        before_text = @source[0...@insertion_point]
        last_newline = before_text.rindex("\n")
        content_after_newline = last_newline ? before_text[(last_newline + 1)..] : before_text
        # If there's only whitespace after the last newline, we might not need another
        !content_after_newline.strip.empty?
      when :before, :after
        # Siblings usually don't need newline before (handled by separator)
        false
      else
        true
      end
    end

    def adjust_content_indentation(content)
      return content if content.strip.empty?

      @indent_detector.adjust_indentation(content.strip, @target_indent_level, current_level: 0)
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
