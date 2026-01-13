# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "tree_sitter"

require "minitest/autorun"
require "minitest/pride"
require "minitest/focus"

module TestHelper
  FIXTURES_PATH = File.expand_path("fixtures", __dir__)
  GRAMMAR_DIR = File.expand_path("../.tree-sitter-grammars", __dir__)

  # Grammar name mappings (env var suffix => directory name)
  GRAMMAR_MAPPINGS = {
    "rust" => "rust",
    "ruby" => "ruby",
    "python" => "python",
    "javascript" => "javascript",
    "go" => "go",
    "php" => "php",
    "java" => "java",
    "c_sharp" => "c_sharp",
  }.freeze

  class << self
    # Platform-specific shared library extension
    def library_extension
      case RbConfig::CONFIG["host_os"]
      when /darwin/i
        "dylib"
      when /mswin|mingw|cygwin/i
        "dll"
      else
        "so"
      end
    end

    # Auto-discover and set grammar paths from local directory
    def setup_grammar_paths!
      ext = library_extension
      GRAMMAR_MAPPINGS.each do |name, dir|
        env_var = "TREE_SITTER_#{name.upcase}_PATH"
        next if ENV[env_var] # Don't override if already set

        lib_path = File.join(GRAMMAR_DIR, dir, "libtree-sitter-#{dir}.#{ext}")
        ENV[env_var] = lib_path if File.exist?(lib_path)
      end
    end
  end

  def fixture_path(filename)
    File.join(FIXTURES_PATH, filename)
  end

  def fixture_content(filename)
    File.read(fixture_path(filename))
  end

  # Register a language from environment variable
  def register_language(name)
    env_var = "TREE_SITTER_#{name.upcase}_PATH"
    path = ENV[env_var]

    raise "#{name} grammar not available (set #{env_var} or run 'make grammars')" unless path && File.exist?(path)

    TreeSitter.register_language(name, path)
  end
end

# Auto-setup grammar paths when test helper is loaded
require "rbconfig"
TestHelper.setup_grammar_paths!
