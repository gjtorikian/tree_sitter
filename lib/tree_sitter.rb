# frozen_string_literal: true

require_relative "tree_sitter/version"

# Load the native extension
begin
  RUBY_VERSION =~ /(\d+\.\d+)/
  require "tree_sitter/#{Regexp.last_match(1)}/tree_sitter"
rescue LoadError
  require "tree_sitter/tree_sitter"
end

# Load pure Ruby components
require_relative "tree_sitter/rewriter"
require_relative "tree_sitter/formatting"
require_relative "tree_sitter/query_rewriter"
require_relative "tree_sitter/inserter"
require_relative "tree_sitter/transformer"
require_relative "tree_sitter/refactor"

module TreeSitter
  class Error < StandardError; end
  class ParseError < Error; end
  class QueryError < Error; end
end
