# frozen_string_literal: true

module TreeSitter
  # Structural transformations for syntax tree nodes.
  # Provides operations for moving, copying, swapping, and reordering nodes.
  #
  # @example Swap two function arguments
  #   Transformer.new(source, tree)
  #     .swap(arg1_node, arg2_node)
  #     .rewrite
  #
  # @example Move a function to a different location
  #   Transformer.new(source, tree)
  #     .move(fn_node, after: other_fn_node)
  #     .rewrite
  #
  class Transformer
    # Represents a pending structural operation
    Operation = Struct.new(:type, :params, keyword_init: true)

    attr_reader :source, :tree, :operations

    # Initialize a new Transformer
    #
    # @param source [String] The source code to transform
    # @param tree [TreeSitter::Tree] The parsed syntax tree
    # @param parser [TreeSitter::Parser, nil] Optional parser for re-parsing
    def initialize(source, tree, parser: nil)
      @source = source.dup.freeze
      @tree = tree
      @parser = parser
      @operations = []
    end

    # Move a node to a new location (removes from original, inserts at target)
    #
    # @param node [TreeSitter::Node] The node to move
    # @param before [TreeSitter::Node, nil] Insert before this node
    # @param after [TreeSitter::Node, nil] Insert after this node
    # @param separator [String] Separator to use (default: newline)
    # @return [self] For method chaining
    def move(node, before: nil, after: nil, separator: "\n")
      raise ArgumentError, "Must specify either before: or after:" if before.nil? && after.nil?
      raise ArgumentError, "Cannot specify both before: and after:" if before && after

      @operations << Operation.new(
        type: :move,
        params: { node: node, before: before, after: after, separator: separator },
      )
      self
    end

    # Copy a node to a new location (original remains)
    #
    # @param node [TreeSitter::Node] The node to copy
    # @param before [TreeSitter::Node, nil] Insert before this node
    # @param after [TreeSitter::Node, nil] Insert after this node
    # @param separator [String] Separator to use (default: newline)
    # @return [self] For method chaining
    def copy(node, before: nil, after: nil, separator: "\n")
      raise ArgumentError, "Must specify either before: or after:" if before.nil? && after.nil?
      raise ArgumentError, "Cannot specify both before: and after:" if before && after

      @operations << Operation.new(
        type: :copy,
        params: { node: node, before: before, after: after, separator: separator },
      )
      self
    end

    # Swap two nodes
    #
    # @param node_a [TreeSitter::Node] First node
    # @param node_b [TreeSitter::Node] Second node
    # @return [self] For method chaining
    def swap(node_a, node_b)
      validate_non_overlapping(node_a, node_b)

      @operations << Operation.new(
        type: :swap,
        params: { node_a: node_a, node_b: node_b },
      )
      self
    end

    # Reorder children of a parent node
    #
    # @param parent [TreeSitter::Node] The parent node
    # @param order [Array<Integer>] New order as array of indices
    # @return [self] For method chaining
    # @example Reverse first three children: reorder_children(parent, [2, 1, 0, 3, 4])
    def reorder_children(parent, order)
      @operations << Operation.new(
        type: :reorder,
        params: { parent: parent, order: order },
      )
      self
    end

    # Extract node content to a new location with a reference
    #
    # @param node [TreeSitter::Node] Node to extract
    # @param to [TreeSitter::Node] Where to place extracted content (inserted after)
    # @param reference [String] Reference to leave in place of original
    # @yield [String] Optional block to transform extracted content
    # @return [self] For method chaining
    def extract(node, to:, reference:, &wrapper)
      @operations << Operation.new(
        type: :extract,
        params: { node: node, to: to, reference: reference, wrapper: wrapper },
      )
      self
    end

    # Duplicate a node immediately after itself
    #
    # @param node [TreeSitter::Node] Node to duplicate
    # @param separator [String] Separator between original and copy
    # @yield [String] Optional block to transform the copy
    # @return [self] For method chaining
    def duplicate(node, separator: "\n", &transformer)
      @operations << Operation.new(
        type: :duplicate,
        params: { node: node, separator: separator, transformer: transformer },
      )
      self
    end

    # Apply all accumulated operations
    #
    # @return [String] The transformed source code
    def rewrite
      edits = build_edits
      apply_edits(edits)
    end

    # Apply operations and return both source and new tree
    #
    # @return [Array<String, Tree>] The new source and re-parsed tree
    def rewrite_with_tree
      new_source = rewrite

      parser = @parser || create_parser_from_tree
      raise "No parser available for re-parsing" unless parser

      new_tree = parser.parse(new_source)
      [new_source, new_tree]
    end

    private

    def build_edits
      edits = []

      @operations.each do |op|
        case op.type
        when :swap
          edits.concat(build_swap_edits(op.params))
        when :move
          edits.concat(build_move_edits(op.params))
        when :copy
          edits.concat(build_copy_edits(op.params))
        when :reorder
          edits.concat(build_reorder_edits(op.params))
        when :extract
          edits.concat(build_extract_edits(op.params))
        when :duplicate
          edits.concat(build_duplicate_edits(op.params))
        end
      end

      edits
    end

    def build_swap_edits(params)
      node_a = params[:node_a]
      node_b = params[:node_b]

      text_a = node_text(node_a)
      text_b = node_text(node_b)

      [
        { start_byte: node_a.start_byte, end_byte: node_a.end_byte, replacement: text_b },
        { start_byte: node_b.start_byte, end_byte: node_b.end_byte, replacement: text_a },
      ]
    end

    def build_move_edits(params)
      node = params[:node]
      before = params[:before]
      after = params[:after]
      separator = params[:separator]

      text = node_text(node)
      edits = []

      # Remove from original location
      edits << { start_byte: node.start_byte, end_byte: node.end_byte, replacement: "" }

      # Insert at new location
      if before
        edits << { start_byte: before.start_byte, end_byte: before.start_byte, replacement: text + separator }
      elsif after
        edits << { start_byte: after.end_byte, end_byte: after.end_byte, replacement: separator + text }
      end

      edits
    end

    def build_copy_edits(params)
      node = params[:node]
      before = params[:before]
      after = params[:after]
      separator = params[:separator]

      text = node_text(node)

      if before
        [{ start_byte: before.start_byte, end_byte: before.start_byte, replacement: text + separator }]
      elsif after
        [{ start_byte: after.end_byte, end_byte: after.end_byte, replacement: separator + text }]
      else
        []
      end
    end

    def build_reorder_edits(params)
      parent = params[:parent]
      order = params[:order]

      # Get all named children
      children = []
      parent.named_children.each { |child| children << child }

      return [] if children.empty?

      # Validate order indices
      raise ArgumentError, "Order indices out of range" unless order.all? { |i| i >= 0 && i < children.length }

      # Build content for each position in new order
      new_contents = order.map { |i| node_text(children[i]) }

      # Create edits to replace each child with its new content
      edits = []
      children.each_with_index do |child, idx|
        new_text = new_contents[idx] || node_text(child)
        next if new_text == node_text(child)

        edits << { start_byte: child.start_byte, end_byte: child.end_byte, replacement: new_text }
      end

      edits
    end

    def build_extract_edits(params)
      node = params[:node]
      to = params[:to]
      reference = params[:reference]
      wrapper = params[:wrapper]

      text = node_text(node)
      extracted = wrapper ? wrapper.call(text) : text

      [
        # Replace original with reference
        { start_byte: node.start_byte, end_byte: node.end_byte, replacement: reference },
        # Insert extracted content at target
        { start_byte: to.end_byte, end_byte: to.end_byte, replacement: "\n\n" + extracted },
      ]
    end

    def build_duplicate_edits(params)
      node = params[:node]
      separator = params[:separator]
      transformer = params[:transformer]

      text = node_text(node)
      copy_text = transformer ? transformer.call(text) : text

      [{ start_byte: node.end_byte, end_byte: node.end_byte, replacement: separator + copy_text }]
    end

    def apply_edits(edits)
      # Sort by position descending to apply from end to start
      sorted = edits.sort_by { |e| [-e[:start_byte], -e[:end_byte]] }

      result = @source.dup
      sorted.each do |edit|
        result[edit[:start_byte]...edit[:end_byte]] = edit[:replacement]
      end
      result
    end

    def node_text(node)
      @source[node.start_byte...node.end_byte]
    end

    def validate_non_overlapping(*nodes)
      ranges = nodes.map { |n| (n.start_byte...n.end_byte) }

      ranges.combination(2).each do |r1, r2|
        if ranges_overlap?(r1, r2)
          raise ArgumentError, "Nodes must not overlap"
        end
      end
    end

    def ranges_overlap?(r1, r2)
      r1.cover?(r2.begin) || r1.cover?(r2.end - 1) ||
        r2.cover?(r1.begin) || r2.cover?(r1.end - 1)
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
