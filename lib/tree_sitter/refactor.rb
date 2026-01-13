# frozen_string_literal: true

require_relative "query_rewriter"
require_relative "transformer"
require_relative "inserter"

module TreeSitter
  # High-level refactoring operations built on QueryRewriter and Transformer.
  # These methods provide common code transformation patterns with a simple API.
  #
  # @example Rename a function throughout the code
  #   TreeSitter::Refactor.rename_symbol(source, tree, lang,
  #     from: "old_name", to: "new_name")
  #
  module Refactor
    class << self
      # Rename a symbol (function, variable, type) throughout the code
      #
      # @param source [String] Source code
      # @param tree [Tree] Parsed syntax tree
      # @param language [Language] Language for queries
      # @param from [String] Original name
      # @param to [String] New name
      # @param kind [Symbol] Type of symbol (:identifier, :function, :type, :variable)
      # @return [String] Modified source code
      def rename_symbol(source, tree, language, from:, to:, kind: :identifier)
        query_pattern = build_rename_query(kind)

        QueryRewriter.new(source, tree, language)
          .query(query_pattern)
          .where { |m| match_has_text?(m, from) }
          .replace("@name") { to }
          .rewrite
      end

      # Rename a struct/class field and its usages
      #
      # @param source [String] Source code
      # @param tree [Tree] Parsed syntax tree
      # @param language [Language] Language for queries
      # @param struct_name [String, nil] Name of struct/class (nil for all)
      # @param from [String] Old field name
      # @param to [String] New field name
      # @return [String] Modified source code
      def rename_field(source, tree, language, struct_name: nil, from:, to:)
        # Query for field declarations and field accesses
        query_pattern = <<~QUERY
          [
            (field_declaration name: (field_identifier) @name)
            (field_expression field: (field_identifier) @name)
            (field_identifier) @name
          ]
        QUERY

        QueryRewriter.new(source, tree, language)
          .query(query_pattern)
          .where { |m| match_has_text?(m, from) }
          .replace("@name") { to }
          .rewrite
      end

      # Extract code into a new function
      #
      # @param source [String] Source code
      # @param tree [Tree] Parsed syntax tree
      # @param language [Language] Language for queries
      # @param node [Node] Node to extract
      # @param name [String] Name for extracted function
      # @param parameters [Array<String>] Parameter names
      # @param insert_after [Node, nil] Where to insert the new function
      # @return [String] Modified source code
      def extract_function(source, tree, language, node:, name:, parameters: [], insert_after: nil)
        # Build function call
        param_list = parameters.join(", ")
        call_reference = parameters.empty? ? "#{name}()" : "#{name}(#{param_list})"

        # Build function definition
        node_text = source[node.start_byte...node.end_byte]
        param_decl = parameters.map { |p| "#{p}: _" }.join(", ")
        fn_def = "fn #{name}(#{param_decl}) {\n    #{node_text}\n}"

        # Determine where to insert
        insert_target = insert_after || find_enclosing_function(node) || tree.root_node

        Transformer.new(source, tree)
          .extract(node, to: insert_target, reference: call_reference) { fn_def }
          .rewrite
      end

      # Inline a variable (replace usages with its value)
      #
      # @param source [String] Source code
      # @param tree [Tree] Parsed syntax tree
      # @param language [Language] Language for queries
      # @param name [String] Variable name to inline
      # @param scope [Node, nil] Scope to limit inlining (nil for entire tree)
      # @return [String] Modified source code
      def inline_variable(source, tree, language, name:, scope: nil)
        # Find the variable declaration and its value
        decl_query = "(let_declaration pattern: (identifier) @var_name value: (_) @value)"

        query = TreeSitter::Query.new(language, decl_query)
        cursor = TreeSitter::QueryCursor.new
        root = scope || tree.root_node
        matches = cursor.matches(query, root, source)

        # Find the declaration for our variable
        decl_match = matches.find do |m|
          m.captures.any? { |c| c.name == "var_name" && c.node.text == name }
        end

        return source unless decl_match

        # Get the value to inline
        value_capture = decl_match.captures.find { |c| c.name == "value" }
        return source unless value_capture

        value_text = value_capture.node.text

        # Find all usages and replace
        usage_query = "(identifier) @usage"

        QueryRewriter.new(source, tree, language)
          .query(usage_query)
          .where { |m| match_has_text?(m, name) && !declaration?(m, source) }
          .replace("@usage") { value_text }
          .rewrite
      end

      # Add an attribute/annotation to items matching a query
      #
      # @param source [String] Source code
      # @param tree [Tree] Parsed syntax tree
      # @param language [Language] Language for queries
      # @param query_pattern [String] Query to match items
      # @param attribute [String] Attribute to add (e.g., "#[derive(Debug)]")
      # @return [String] Modified source code
      def add_attribute(source, tree, language, query_pattern:, attribute:)
        QueryRewriter.new(source, tree, language)
          .query(query_pattern)
          .insert_before("@item") { "#{attribute}\n" }
          .rewrite
      end

      # Remove items matching a query
      #
      # @param source [String] Source code
      # @param tree [Tree] Parsed syntax tree
      # @param language [Language] Language for queries
      # @param query_pattern [String] Query to match items to remove
      # @param capture_name [String] Name of capture to remove
      # @return [String] Modified source code
      def remove_matching(source, tree, language, query_pattern:, capture_name: "@item")
        QueryRewriter.new(source, tree, language)
          .query(query_pattern)
          .remove(capture_name)
          .rewrite
      end

      private

      def build_rename_query(kind)
        case kind
        when :function
          <<~QUERY
            [
              (function_item name: (identifier) @name)
              (call_expression function: (identifier) @name)
            ]
          QUERY
        when :type
          <<~QUERY
            [
              (struct_item name: (type_identifier) @name)
              (enum_item name: (type_identifier) @name)
              (type_identifier) @name
            ]
          QUERY
        when :variable
          "(identifier) @name"
        else
          "(identifier) @name"
        end
      end

      def match_has_text?(match, text)
        match.captures.any? { |c| c.node.text == text }
      end

      DECLARATION_TYPES = ["let_declaration", "parameter", "function_item"].freeze

      def declaration?(match, _source)
        # Check if this identifier is part of a declaration pattern
        match.captures.any? do |c|
          parent = c.node.parent
          next false unless parent

          # Common declaration patterns
          DECLARATION_TYPES.include?(parent.type)
        end
      end

      def find_enclosing_function(node)
        current = node.parent
        while current
          return current if current.type == "function_item"

          current = current.parent
        end
        nil
      end
    end
  end
end
