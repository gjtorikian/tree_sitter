# frozen_string_literal: true

module TreeSitter
  # Formatting utilities for syntax-aware code manipulation
  module Formatting
    # Detects and works with indentation in source code
    class IndentationDetector
      # Characters considered whitespace for indentation
      INDENT_CHARS = [" ", "\t"].freeze

      attr_reader :source, :indent_string, :indent_size, :style

      # Initialize detector with source code
      #
      # @param source [String] The source code to analyze
      def initialize(source)
        @source = source
        @lines = source.lines
        detect
      end

      # Detect the indentation style used in the source
      #
      # @return [Hash] { style: :spaces|:tabs|:unknown, size: Integer, string: String }
      def detect
        space_indents = []
        tab_count = 0
        space_count = 0

        @lines.each do |line|
          next if line.strip.empty?

          leading = line[/\A[ \t]*/]
          next if leading.empty?

          if leading.include?("\t")
            tab_count += 1
          else
            space_count += 1
            # Track indent sizes for space-indented lines
            space_indents << leading.length if leading.length.positive?
          end
        end

        if tab_count > space_count
          @style = :tabs
          @indent_size = 1
          @indent_string = "\t"
        elsif space_count.positive?
          @style = :spaces
          @indent_size = detect_space_indent_size(space_indents)
          @indent_string = " " * @indent_size
        else
          # Default to 4 spaces
          @style = :spaces
          @indent_size = 4
          @indent_string = "    "
        end

        { style: @style, size: @indent_size, string: @indent_string }
      end

      # Get indentation level (count) at a specific line
      #
      # @param line_number [Integer] Zero-based line number
      # @return [Integer] Number of indentation units
      def level_at_line(line_number)
        return 0 if line_number < 0 || line_number >= @lines.length

        line = @lines[line_number]
        leading = line[/\A[ \t]*/] || ""

        return leading.count("\t") if @style == :tabs

        leading.length / [@indent_size, 1].max
      end

      # Get raw indentation string at a specific line
      #
      # @param line_number [Integer] Zero-based line number
      # @return [String] The indentation whitespace
      def raw_indentation_at_line(line_number)
        return "" if line_number < 0 || line_number >= @lines.length

        line = @lines[line_number]
        line[/\A[ \t]*/] || ""
      end

      # Get indentation string at a specific byte position
      #
      # @param byte_pos [Integer] Byte position in source
      # @return [String] The indentation whitespace for that line
      def indentation_at_byte(byte_pos)
        line_number = byte_to_line(byte_pos)
        raw_indentation_at_line(line_number)
      end

      # Get indentation level at a specific byte position
      #
      # @param byte_pos [Integer] Byte position in source
      # @return [Integer] Indentation level
      def level_at_byte(byte_pos)
        line_number = byte_to_line(byte_pos)
        level_at_line(line_number)
      end

      # Create indentation string for a given level
      #
      # @param level [Integer] Indentation level
      # @return [String] Indentation whitespace
      def indent_string_for_level(level)
        return "" if level <= 0

        @indent_string * level
      end

      # Adjust indentation of content to a target level
      #
      # @param content [String] Content to adjust
      # @param target_level [Integer] Target indentation level
      # @param current_level [Integer, nil] Current base level (auto-detected if nil)
      # @return [String] Re-indented content
      def adjust_indentation(content, target_level, current_level: nil)
        content_lines = content.lines
        return content if content_lines.empty?

        # Auto-detect current level from first non-empty line
        if current_level.nil?
          first_content_line = content_lines.find { |l| !l.strip.empty? }
          if first_content_line
            leading = first_content_line[/\A[ \t]*/] || ""
            current_level = if @style == :tabs
              leading.count("\t")
            else
              leading.length / [@indent_size, 1].max
            end
          else
            current_level = 0
          end
        end

        level_diff = target_level - current_level

        content_lines.map do |line|
          if line.strip.empty?
            line
          else
            leading = line[/\A[ \t]*/] || ""
            rest = line[leading.length..]

            # Calculate this line's level relative to base
            line_level = if @style == :tabs
              leading.count("\t")
            else
              leading.length / [@indent_size, 1].max
            end

            # Apply the level difference
            new_level = [line_level + level_diff, 0].max
            indent_string_for_level(new_level) + rest
          end
        end.join
      end

      # Increase indentation of all lines by one level
      #
      # @param content [String] Content to indent
      # @return [String] Indented content
      def indent(content)
        content.lines.map do |line|
          if line.strip.empty?
            line
          else
            @indent_string + line
          end
        end.join
      end

      # Decrease indentation of all lines by one level
      #
      # @param content [String] Content to dedent
      # @return [String] Dedented content
      def dedent(content)
        content.lines.map do |line|
          if line.strip.empty?
            line
          elsif @style == :tabs && line.start_with?("\t")
            line[1..]
          elsif @style == :spaces && line.start_with?(@indent_string)
            line[@indent_size..]
          else
            line
          end
        end.join
      end

      private

      # Detect the most common space indent size
      def detect_space_indent_size(indents)
        return 4 if indents.empty?

        # Find GCD of all indent sizes to determine base unit
        differences = []
        sorted = indents.uniq.sort

        sorted.each_cons(2) do |a, b|
          differences << (b - a)
        end

        # Also consider the smallest non-zero indent
        differences << sorted.first if sorted.first&.positive?

        return 4 if differences.empty?

        # Find GCD
        gcd = differences.reduce { |a, b| a.gcd(b) }
        gcd = 4 if gcd.nil? || gcd <= 0 || gcd > 8

        gcd
      end

      # Convert byte position to line number (zero-based)
      def byte_to_line(byte_pos)
        current_byte = 0
        @lines.each_with_index do |line, idx|
          line_end = current_byte + line.bytesize
          return idx if byte_pos < line_end

          current_byte = line_end
        end
        [@lines.length - 1, 0].max
      end
    end
  end
end
