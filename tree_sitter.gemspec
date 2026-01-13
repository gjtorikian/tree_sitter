# frozen_string_literal: true

require_relative "lib/tree_sitter/version"

Gem::Specification.new do |spec|
  spec.name = "tree_sitter"
  spec.version = TreeSitter::VERSION
  spec.authors = ["Garen J. Torikian"]
  spec.email = ["gjtorikian@users.noreply.github.com"]

  spec.summary = "Ruby bindings for tree-sitter with code transformation and refactoring capabilities. Written in Rust, wrapped in Ruby."
  spec.description = "Parse and rewrite source code using tree-sitter with a Ruby-friendly API. " \
    "Supports multiple languages via dynamic grammar loading. "
  spec.homepage = "https://github.com/gjtorikian/tree_sitter"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.2", "< 5"
  spec.required_rubygems_version = ">= 3.4"

  spec.files = Dir.glob([
    "lib/**/*.rb",
    "ext/**/*.{rs,toml,rb}",
    "LICENSE.txt",
    "README.md",
    "CHANGELOG.md",
    "Makefile",
  ])

  spec.require_paths = ["lib"]
  spec.extensions = ["ext/tree_sitter/extconf.rb"]

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "funding_uri" => "https://github.com/sponsors/gjtorikian/",
    "source_code_uri" => "https://github.com/gjtorikian/tree_sitter",
    "rubygems_mfa_required" => "true",
  }

  spec.add_dependency("rb_sys", "~> 0.9")

  spec.add_development_dependency("rake", "~> 13.0")
  spec.add_development_dependency("rake-compiler", "~> 1.2")
end
