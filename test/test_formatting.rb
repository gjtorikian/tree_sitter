# frozen_string_literal: true

require "test_helper"

class TestFormatting < Minitest::Test
  include TestHelper

  def test_detect_spaces_indentation
    source = <<~CODE
      fn main() {
          let x = 1;
          if true {
              let y = 2;
          }
      }
    CODE

    detector = TreeSitter::Formatting::IndentationDetector.new(source)
    result = detector.detect

    assert_equal(:spaces, result[:style])
    assert_equal(4, result[:size])
    assert_equal("    ", result[:string])
  end

  def test_detect_tabs_indentation
    source = "fn main() {\n\tlet x = 1;\n\tif true {\n\t\tlet y = 2;\n\t}\n}\n"

    detector = TreeSitter::Formatting::IndentationDetector.new(source)
    result = detector.detect

    assert_equal(:tabs, result[:style])
    assert_equal(1, result[:size])
    assert_equal("\t", result[:string])
  end

  def test_detect_two_space_indentation
    source = <<~CODE
      fn main() {
        let x = 1;
        if true {
          let y = 2;
        }
      }
    CODE

    detector = TreeSitter::Formatting::IndentationDetector.new(source)
    result = detector.detect

    assert_equal(:spaces, result[:style])
    assert_equal(2, result[:size])
    assert_equal("  ", result[:string])
  end

  def test_level_at_line
    source = <<~CODE
      fn main() {
          let x = 1;
          if true {
              let y = 2;
          }
      }
    CODE

    detector = TreeSitter::Formatting::IndentationDetector.new(source)

    assert_equal(0, detector.level_at_line(0))  # fn main()
    assert_equal(1, detector.level_at_line(1))  # let x = 1;
    assert_equal(1, detector.level_at_line(2))  # if true {
    assert_equal(2, detector.level_at_line(3))  # let y = 2;
    assert_equal(1, detector.level_at_line(4))  # }
    assert_equal(0, detector.level_at_line(5))  # }
  end

  def test_raw_indentation_at_line
    source = <<~CODE
      fn main() {
          let x = 1;
      }
    CODE

    detector = TreeSitter::Formatting::IndentationDetector.new(source)

    assert_equal("", detector.raw_indentation_at_line(0))
    assert_equal("    ", detector.raw_indentation_at_line(1))
  end

  def test_indent_string_for_level
    source = "fn main() {\n    let x = 1;\n}"
    detector = TreeSitter::Formatting::IndentationDetector.new(source)

    assert_equal("", detector.indent_string_for_level(0))
    assert_equal("    ", detector.indent_string_for_level(1))
    assert_equal("        ", detector.indent_string_for_level(2))
  end

  def test_adjust_indentation_increase
    source = "fn main() {\n    let x = 1;\n}"
    detector = TreeSitter::Formatting::IndentationDetector.new(source)

    content = "let y = 2;"
    adjusted = detector.adjust_indentation(content, 2, current_level: 0)

    assert_equal("        let y = 2;", adjusted)
  end

  def test_adjust_indentation_decrease
    source = "fn main() {\n    let x = 1;\n}"
    detector = TreeSitter::Formatting::IndentationDetector.new(source)

    content = "        let y = 2;"
    adjusted = detector.adjust_indentation(content, 1, current_level: 2)

    assert_equal("    let y = 2;", adjusted)
  end

  def test_adjust_indentation_multiline
    source = "fn main() {\n    let x = 1;\n}"
    detector = TreeSitter::Formatting::IndentationDetector.new(source)

    content = "let a = 1;\nlet b = 2;"
    adjusted = detector.adjust_indentation(content, 1, current_level: 0)

    lines = adjusted.lines

    assert_equal("    let a = 1;\n", lines[0])
    assert_equal("    let b = 2;", lines[1])
  end

  def test_indent
    source = "fn main() {\n    let x = 1;\n}"
    detector = TreeSitter::Formatting::IndentationDetector.new(source)

    content = "let y = 2;\nlet z = 3;"
    indented = detector.indent(content)

    lines = indented.lines

    assert(lines[0].start_with?("    "))
    assert(lines[1].start_with?("    "))
  end

  def test_dedent
    source = "fn main() {\n    let x = 1;\n}"
    detector = TreeSitter::Formatting::IndentationDetector.new(source)

    content = "    let y = 2;\n    let z = 3;"
    dedented = detector.dedent(content)

    lines = dedented.lines

    refute(lines[0].start_with?("    "))
    refute(lines[1].start_with?("    "))
  end

  def test_indentation_at_byte
    source = "fn main() {\n    let x = 1;\n}"
    detector = TreeSitter::Formatting::IndentationDetector.new(source)

    # Byte position in first line (no indent)
    assert_equal("", detector.indentation_at_byte(5))

    # Byte position in second line (4-space indent)
    # "fn main() {\n" is 12 bytes, so byte 15 is in the second line
    assert_equal("    ", detector.indentation_at_byte(15))
  end

  def test_level_at_byte
    source = "fn main() {\n    let x = 1;\n}"
    detector = TreeSitter::Formatting::IndentationDetector.new(source)

    assert_equal(0, detector.level_at_byte(5))  # In first line
    assert_equal(1, detector.level_at_byte(15)) # In second line
  end

  def test_handles_empty_lines
    source = <<~CODE
      fn main() {

          let x = 1;

      }
    CODE

    detector = TreeSitter::Formatting::IndentationDetector.new(source)
    result = detector.detect

    assert_equal(:spaces, result[:style])
    assert_equal(4, result[:size])
  end

  def test_handles_no_indentation
    source = "fn main() {}\nfn other() {}"
    detector = TreeSitter::Formatting::IndentationDetector.new(source)
    result = detector.detect

    # Should default to spaces with size 4
    assert_equal(:spaces, result[:style])
  end
end
