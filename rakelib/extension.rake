# frozen_string_literal: true

require "rb_sys/extensiontask"

RbSys::ExtensionTask.new("tree_sitter", TREE_SITTER_SPEC) do |ext|
  ext.lib_dir = File.join("lib", "tree_sitter")
end

desc "Build native extension for a given platform (i.e. `rake 'native[x86_64-linux]'`)"
task :native, [:platform] do |_t, platform:|
  sh "bundle", "exec", "rb-sys-dock", "--platform", platform, "--build"
end

desc "Compile and build native extension for a given platform (i.e. `rake 'native[x86_64-linux]'`)"
task build: :compile
