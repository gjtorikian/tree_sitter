# frozen_string_literal: true

# Gem Spec
require "bundler/gem_tasks"
TREE_SITTER_SPEC = Bundler.load_gemspec("tree_sitter.gemspec")

# Packaging
require "rubygems/package_task"
gem_path = Gem::PackageTask.new(TREE_SITTER_SPEC).define
desc "Package the Ruby gem"
task "package" => [gem_path]
