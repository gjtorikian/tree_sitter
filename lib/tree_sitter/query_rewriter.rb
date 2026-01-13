# frozen_string_literal: true

module TreeSitter
  # Query-based bulk editing for syntax tree nodes.
  # Finds all nodes matching a tree-sitter query and applies transformations.
  #
  # @example Rename all function calls matching a pattern
  #   QueryRewriter.new(source, tree, language)
  #     .query('(call_expression function: (identifier) @fn_name)')
  #     .where { |match| match.captures.any? { |c| c.node.text == "old_name" } }
  #     .replace("@fn_name") { |node| "new_name" }
  #     .rewrite
  #
  # @example Remove all comments
  #   QueryRewriter.new(source, tree, language)
  #     .query('(line_comment) @comment')
  #     .remove("@comment")
  #     .rewrite
  #
  class QueryRewriter
    # Represents a pending operation on a capture
    Operation = Struct.new(:type, :capture_name, :transformer, :before, :after, keyword_init: true)

    attr_reader :source, :tree, :language, :edits

    # Initialize a new QueryRewriter
    #
    # @param source [String] The source code to rewrite
    # @param tree [TreeSitter::Tree] The parsed syntax tree
    # @param language [TreeSitter::Language, String] The language for queries
    # @param parser [TreeSitter::Parser, nil] Optional parser for re-parsing
    def initialize(source, tree, language = nil, parser: nil)
      @source = source.dup.freeze
      @tree = tree
      @language = resolve_language(language)
      @parser = parser
      @query_pattern = nil
      @predicates = []
      @operations = []
      @edits = []
    end

    # Set the query pattern to match against
    #
    # @param pattern [String] Tree-sitter query pattern
    # @return [self] For method chaining
    def query(pattern)
      @query_pattern = pattern
      self
    end

    # Filter matches based on a predicate
    #
    # @yield [QueryMatch] Block that returns true for matches to keep
    # @return [self] For method chaining
    def where(&predicate)
      @predicates << predicate
      self
    end

    # Replace captured nodes with new content
    #
    # @param capture_name [String] The @capture to replace (e.g., "@fn_name" or "fn_name")
    # @yield [Node] Block that returns the replacement text (receives the captured node)
    # @yieldreturn [String] The replacement text
    # @return [self] For method chaining
    def replace(capture_name, &transformer)
      @operations << Operation.new(
        type: :replace,
        capture_name: normalize_capture_name(capture_name),
        transformer: transformer || proc { "" },
      )
      self
    end

    # Remove captured nodes
    #
    # @param capture_name [String] The @capture to remove
    # @return [self] For method chaining
    def remove(capture_name)
      @operations << Operation.new(
        type: :remove,
        capture_name: normalize_capture_name(capture_name),
      )
      self
    end

    # Insert content before captured nodes
    #
    # @param capture_name [String] The @capture reference point
    # @yield [Node] Block that returns the content to insert
    # @yieldreturn [String] The content to insert
    # @return [self] For method chaining
    def insert_before(capture_name, content = nil, &content_generator)
      generator = content_generator || proc { content.to_s }
      @operations << Operation.new(
        type: :insert_before,
        capture_name: normalize_capture_name(capture_name),
        transformer: generator,
      )
      self
    end

    # Insert content after captured nodes
    #
    # @param capture_name [String] The @capture reference point
    # @yield [Node] Block that returns the content to insert
    # @yieldreturn [String] The content to insert
    # @return [self] For method chaining
    def insert_after(capture_name, content = nil, &content_generator)
      generator = content_generator || proc { content.to_s }
      @operations << Operation.new(
        type: :insert_after,
        capture_name: normalize_capture_name(capture_name),
        transformer: generator,
      )
      self
    end

    # Wrap captured nodes with before/after content
    #
    # @param capture_name [String] The @capture to wrap
    # @param before [String, nil] Content before (or use block)
    # @param after [String, nil] Content after
    # @yield [Node] Optional block that returns [before, after] tuple
    # @return [self] For method chaining
    def wrap(capture_name, before: nil, after: nil, &block)
      @operations << if block
        Operation.new(
          type: :wrap_dynamic,
          capture_name: normalize_capture_name(capture_name),
          transformer: block,
        )
      else
        Operation.new(
          type: :wrap,
          capture_name: normalize_capture_name(capture_name),
          before: before.to_s,
          after: after.to_s,
        )
      end
      self
    end

    # Execute the query and collect all matches
    #
    # @return [Array<QueryMatch>] All matches found
    def matches
      return [] unless @query_pattern && @language

      ts_query = TreeSitter::Query.new(@language, @query_pattern)
      cursor = TreeSitter::QueryCursor.new

      all_matches = cursor.matches(ts_query, @tree.root_node, @source)

      # Apply filters
      @predicates.reduce(all_matches) do |matches, predicate|
        matches.select(&predicate)
      end
    end

    # Apply all accumulated edits
    #
    # @return [String] The rewritten source code
    def rewrite
      build_edits
      apply_edits
    end

    # Apply edits and return both source and new tree
    #
    # @return [Array<String, Tree>] The new source and re-parsed tree
    def rewrite_with_tree
      new_source = rewrite

      parser = @parser || create_parser_from_tree
      raise "No parser available for re-parsing" unless parser

      new_tree = parser.parse(new_source)
      [new_source, new_tree]
    end

    # Get a preview of all edits that would be applied
    #
    # @return [Array<Hash>] Array of edit descriptions
    def preview_edits
      build_edits
      @edits.map do |edit|
        {
          start_byte: edit[:start_byte],
          end_byte: edit[:end_byte],
          original: @source[edit[:start_byte]...edit[:end_byte]],
          replacement: edit[:replacement],
        }
      end
    end

    private

    def resolve_language(language)
      case language
      when TreeSitter::Language
        language
      when String
        TreeSitter.language(language)
      when nil
        @tree&.language
      else
        raise ArgumentError, "Invalid language: #{language.class}"
      end
    end

    def normalize_capture_name(name)
      name.to_s.delete_prefix("@")
    end

    def build_edits
      @edits = []
      found_matches = matches

      found_matches.each do |match|
        @operations.each do |operation|
          # Find captures matching this operation
          captures = match.captures.select { |c| c.name == operation.capture_name }

          captures.each do |capture|
            node = capture.node
            range = node.range

            case operation.type
            when :replace
              replacement = operation.transformer.call(node)
              @edits << {
                start_byte: range.start_byte,
                end_byte: range.end_byte,
                replacement: replacement.to_s,
              }

            when :remove
              @edits << {
                start_byte: range.start_byte,
                end_byte: range.end_byte,
                replacement: "",
              }

            when :insert_before
              content = operation.transformer.call(node)
              @edits << {
                start_byte: range.start_byte,
                end_byte: range.start_byte,
                replacement: content.to_s,
              }

            when :insert_after
              content = operation.transformer.call(node)
              @edits << {
                start_byte: range.end_byte,
                end_byte: range.end_byte,
                replacement: content.to_s,
              }

            when :wrap
              @edits << {
                start_byte: range.start_byte,
                end_byte: range.start_byte,
                replacement: operation.before,
              }
              @edits << {
                start_byte: range.end_byte,
                end_byte: range.end_byte,
                replacement: operation.after,
              }

            when :wrap_dynamic
              before_text, after_text = operation.transformer.call(node)
              @edits << {
                start_byte: range.start_byte,
                end_byte: range.start_byte,
                replacement: before_text.to_s,
              }
              @edits << {
                start_byte: range.end_byte,
                end_byte: range.end_byte,
                replacement: after_text.to_s,
              }
            end
          end
        end
      end
    end

    def apply_edits
      # Sort by position descending to apply from end to start
      sorted = @edits.sort_by { |e| [-e[:start_byte], -e[:end_byte]] }

      result = @source.dup
      sorted.each do |edit|
        result[edit[:start_byte]...edit[:end_byte]] = edit[:replacement]
      end
      result
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
