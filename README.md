# TreeSitter

Ruby bindings for [tree-sitter](https://tree-sitter.github.io/) with code transformation and refactoring capabilities. Parse source code using tree-sitter with a Ruby-friendly API, supporting multiple languages via dynamic grammar loading. Written in Rust, wrapped in Ruby.

## Features

- **Multi-language support** - Load any tree-sitter grammar dynamically
- **Full AST navigation** - Traverse nodes, access children, siblings, parents
- **Query support** - Pattern-based node searching using S-expressions
- **Rewriter API** - Programmatic code transformations (replace, remove, insert, wrap)
- **Query-based editing** - Bulk edits using tree-sitter queries
- **Transforms** - Move, copy, swap, and reorder nodes
- **Insertions** - Syntax-aware insertions with automatic indentation

The main difference with this gem and others like it is that this focuses on parsing once, transforming, and outputting. It doesn't really work as well for live syntax highlighting or fitting into tools that need sub-millisecond updates (as a user is typing, for instance).

## Installation

Add to your Gemfile:

```ruby
gem "tree_sitter"
```

Then run:

```bash
bundle install
```

**Note:** You need tree-sitter grammar shared libraries (`.so` or `.dylib` files) for the languages you want to parse. See [Grammar Setup](#grammar-setup) below.

## Usage

### Basic Parsing

```ruby
require "tree_sitter"

# Register a language from a shared library
TreeSitter.register_language("ruby", "path/to/libtree-sitter-ruby.{so,dylib}")

# Create a parser and set the language
parser = TreeSitter::Parser.new
parser.language = "rust"

# Parse source code
source = "fn add(a: i32, b: i32) -> i32 { a + b }"
tree = parser.parse(source)

# Navigate the AST
root = tree.root_node
puts root.kind          # => "source_file"
puts root.child_count   # => 1

fn_item = root.child(0)
puts fn_item.kind       # => "function_item"

fn_name = fn_item.child_by_field_name("name")
puts fn_name.text       # => "add"

# Access the original source and language from the tree
puts tree.source        # => "fn add(a: i32, b: i32) -> i32 { a + b }"
puts tree.language.name # => "rust"

# Set a parse timeout (in microseconds) to prevent hanging on large inputs
parser.timeout_micros = 1_000_000  # 1 second
tree = parser.parse(very_large_source)  # Returns nil if timeout exceeded
```

### Multi-Language Support

```ruby
# Register multiple languages
TreeSitter.register_language("ruby", ENV["TREE_SITTER_RUBY_PATH"])
TreeSitter.register_language("python", ENV["TREE_SITTER_PYTHON_PATH"])

# Parse Ruby code
ruby_parser = TreeSitter::Parser.new
ruby_parser.language = "ruby"
ruby_tree = ruby_parser.parse("def hello; puts 'hi'; end")

# Parse Python code
python_parser = TreeSitter::Parser.new
python_parser.language = "python"
python_tree = python_parser.parse("def hello():\n    print('hi')")

# List registered languages
TreeSitter.languages # => ["ruby", "python"]

# Language metadata
lang = TreeSitter.language("ruby")
lang.name            # => "ruby"
lang.version         # => 15 (ABI version)
lang.node_kind_count # => 200 (number of node types in the grammar)
```

### Node Operations

Once you have a node from the AST, you can navigate, inspect, and extract information:

```ruby
# Get nodes to work with
root = tree.root_node
fn_item = root.child(0)
fn_name = fn_item.child_by_field_name("name")

# === Navigation ===
fn_item.parent                        # => #<TreeSitter::Node kind="source_file" ...>
fn_item.child(0)                      # => #<TreeSitter::Node kind="fn" ...>
fn_item.child_count                   # => 6
fn_item.children                      # => [#<Node>, #<Node>, ...] (array of all children)
fn_item.named_child(0)                # => #<TreeSitter::Node kind="identifier" ...>
fn_item.named_child_count             # => 4
fn_item.named_children                # => [#<Node>, ...] (array of named children only)
fn_item.child_by_field_name("name")   # => #<TreeSitter::Node kind="identifier" ...>

# Sibling navigation (using parameters as example)
params = fn_item.child_by_field_name("parameters")
first_param = params.named_child(0)
first_param.next_sibling              # => #<TreeSitter::Node kind="," ...>
first_param.next_named_sibling        # => #<TreeSitter::Node kind="parameter" ...>

# === Properties ===
fn_item.kind                # => "function_item"
fn_item.type                # => "function_item" (alias for kind)
fn_item.kind_id             # => 188
fn_item.named?              # => true (not anonymous like "{" or ")")
fn_item.missing?            # => false (not inserted by parser for error recovery)
fn_item.extra?              # => false (not extra like comments)
fn_item.error?              # => false (not an ERROR node)
fn_item.has_error?          # => false (no errors in subtree)
fn_item.has_changes?        # => false (not changed in incremental parse)

# === Position ===
fn_name.start_byte          # => 3
fn_name.end_byte            # => 6
fn_name.start_point         # => #<TreeSitter::Point row=0 column=3>
fn_name.end_point           # => #<TreeSitter::Point row=0 column=6>
fn_name.range               # => #<TreeSitter::Range start_byte=3 end_byte=6 size=3>

# === Text & Display ===
fn_name.text                # => "add"
fn_name.to_sexp             # => "(identifier)"
fn_name.to_s                # => "(identifier)" (alias for to_sexp)
fn_name.inspect             # => "#<TreeSitter::Node kind=\"identifier\" start_byte=3 end_byte=6>"

# === Comparison ===
root == tree.root_node      # => true
root.eql?(tree.root_node)   # => true
```

### Point and Range

Nodes provide position information via `Point` and `Range` objects:

```ruby
# Point represents a position (row/column)
point = fn_name.start_point
point.row                   # => 0
point.column                # => 3
point.to_a                  # => [0, 3]
point.inspect               # => "#<TreeSitter::Point row=0 column=3>"

# Create points directly
point = TreeSitter::Point.new(0, 3)
point == fn_name.start_point  # => true

# Range represents a span with byte offsets and points
range = fn_name.range
range.start_byte            # => 3
range.end_byte              # => 6
range.size                  # => 3
range.start_point           # => #<TreeSitter::Point row=0 column=3>
range.end_point             # => #<TreeSitter::Point row=0 column=6>
range.inspect               # => "#<TreeSitter::Range start_byte=3 end_byte=6 size=3>"
```

### Query-Based Node Finding

Use tree-sitter queries to find nodes matching patterns:

```ruby
# Create a query with capture names (@fn_name, @fn)
lang = TreeSitter.language("rust")
query = TreeSitter::Query.new(lang, "(function_item name: (identifier) @fn_name) @fn")

# Query properties
query.pattern_count           # => 1
query.capture_names           # => ["fn_name", "fn"]

# Execute query with a cursor
cursor = TreeSitter::QueryCursor.new

# Get all matches (each match contains all captures for one pattern match)
matches = cursor.matches(query, tree.root_node, source)
matches.length                # => 4 (one per function in file)

match = matches.first
match.pattern_index           # => 0
match.captures                # => [#<QueryCapture>, #<QueryCapture>]
match.captures.length         # => 2

# Get all captures directly (flattened list)
cursor = TreeSitter::QueryCursor.new  # create new cursor
captures = cursor.captures(query, tree.root_node, source)
captures.length               # => 8 (2 captures x 4 functions)

capture = captures.first
capture.name                  # => "fn"
capture.node                  # => #<TreeSitter::Node kind="function_item" ...>
capture.node.text             # => "fn add(a: i32, b: i32) -> i32 {\n    a + b\n}"

# Iterate over captures
captures.each do |cap|
  puts "#{cap.name}: #{cap.node.text[0..20]}..." if cap.name == "fn_name"
end
# => fn_name: add...
# => fn_name: new...
# => fn_name: distance...
# => fn_name: main...
```

### Code Rewriting

```ruby
source = <<~RUST
  fn add(a: i32, b: i32) -> i32 {
      a + b
  }
RUST

tree = parser.parse(source)
fn_item = tree.root_node.child(0)
fn_name = fn_item.child_by_field_name("name")

# Create a rewriter and apply edits
new_source = TreeSitter::Rewriter.new(source, tree)
  .replace(fn_name, "sum")
  .insert_before(fn_item, "#[inline]\n")
  .rewrite

puts new_source
# => #[inline]
# => fn sum(a: i32, b: i32) -> i32 {
# =>     a + b
# => }
```

#### Rewriter Operations

```ruby
rewriter = TreeSitter::Rewriter.new(source, tree)

# Replace a node's text
rewriter.replace(node, "new_text")

# Remove a node
rewriter.remove(node)

# Insert before/after a node
rewriter.insert_before(node, "prefix ")
rewriter.insert_after(node, " suffix")

# Wrap a node
rewriter.wrap(node, "/* ", " */")

# All methods return self for chaining
rewriter
  .replace(name_node, "new_name")
  .insert_before(fn_node, "// Comment\n")
  .rewrite
```

### Query-Based Editing

Use `QueryRewriter` to find and transform multiple nodes at once:

```ruby
source = <<~RUST
  fn main() {
      old_func();
      old_func();
      other_func();
  }
RUST

tree = parser.parse(source)
lang = TreeSitter.language("rust")

# Rename all calls to old_func
new_source = TreeSitter::QueryRewriter.new(source, tree, lang)
  .query('(call_expression function: (identifier) @fn)')
  .where { |m| m.captures.any? { |c| c.node.text == "old_func" } }
  .replace("@fn") { "new_func" }
  .rewrite

# Add #[derive(Debug)] to all structs
new_source = TreeSitter::QueryRewriter.new(source, tree, lang)
  .query('(struct_item) @struct')
  .insert_before("@struct") { "#[derive(Debug)]\n" }
  .rewrite

# Remove all comments
new_source = TreeSitter::QueryRewriter.new(source, tree, lang)
  .query('(line_comment) @comment')
  .remove("@comment")
  .rewrite
```

### Transforms

Use `Transformer` to move, copy, swap, or reorder nodes:

```ruby
# Swap two parameters
transformer = TreeSitter::Transformer.new(source, tree)
  .swap(param_a, param_b)
  .rewrite

# Move a function after another
transformer = TreeSitter::Transformer.new(source, tree)
  .move(first_fn, after: third_fn)
  .rewrite

# Copy a node
transformer = TreeSitter::Transformer.new(source, tree)
  .copy(struct_node, after: fn_node)
  .rewrite

# Duplicate with transformation
transformer = TreeSitter::Transformer.new(source, tree)
  .duplicate(fn_node) { |text| text.gsub("original", "copy") }
  .rewrite
```

### Insertions

Use `Inserter` for syntax-aware insertions that respect indentation:

```ruby
# Insert at end of a block with proper indentation
new_source = TreeSitter::Inserter.new(source, tree)
  .at_end_of(fn_body)
  .insert_statement("println!(\"done\");")
  .rewrite

# Insert a sibling function
new_source = TreeSitter::Inserter.new(source, tree)
  .after(existing_fn)
  .insert_sibling("fn new_func() {\n    // body\n}")
  .rewrite

# Insert at start of block
new_source = TreeSitter::Inserter.new(source, tree)
  .at_start_of(fn_body)
  .insert_statement("let start = Instant::now();")
  .rewrite
```

### Refactor

Use the `Refactor` module for common refactoring operations:

```ruby
# Rename a symbol (function, variable, type)
new_source = TreeSitter::Refactor.rename_symbol(
  source, tree, lang,
  from: "old_name",
  to: "new_name",
  kind: :function  # or :variable, :type, :identifier
)

# Rename a struct field
new_source = TreeSitter::Refactor.rename_field(
  source, tree, lang,
  from: "old_field",
  to: "new_field"
)

# Add attributes to matching items
new_source = TreeSitter::Refactor.add_attribute(
  source, tree, lang,
  query_pattern: "(struct_item) @item",
  attribute: "#[derive(Debug)]"
)

# Remove items matching a pattern
new_source = TreeSitter::Refactor.remove_matching(
  source, tree, lang,
  query_pattern: "(line_comment) @item"
)

# For regexp matching, use QueryRewriter directly
new_source = TreeSitter::QueryRewriter.new(source, tree, lang)
  .query('(function_item name: (identifier) @name)')
  .where { |m| m.captures.any? { |c| c.node.text =~ /^test_/ } }
  .replace("@name") { |node| node.text.sub(/^test_/, "spec_") }
  .rewrite
```

## Grammar Setup

TreeSitter requires grammar shared libraries for each language you want to parse.

### Using a Makefile

A sample Makefile is included in the gem which builds all supported grammars locally:

```bash
make grammars
```

This clones and compiles grammars into `.tree-sitter-grammars/` with the correct extension for your platform (`.dylib` on macOS, `.so` on Linux, `.dll` on Windows).

Build individual grammars:

```bash
make rust        # Just Rust
make ruby python # Ruby and Python
```

**You can use this Makefile as a reference for your own project! The gem does NOT ship with any grammars!**

### Using ts-grammar-action

For GitHub Actions, use [kettle-rb/ts-grammar-action](https://github.com/kettle-rb/ts-grammar-action):

```yaml
- uses: kettle-rb/ts-grammar-action@v1
  with:
    grammars: |
      rust
      ruby
      python
      javascript
```

This sets environment variables like `TREE_SITTER_RUST_PATH` pointing to the installed grammars.

### Custom Grammar Paths

You can override grammar locations with environment variables:

```bash
export TREE_SITTER_RUST_PATH="/path/to/libtree-sitter-rust.dylib"
export TREE_SITTER_RUBY_PATH="/path/to/libtree-sitter-ruby.so"
```

Environment variables take precedence over auto-discovered grammars.

## Supported Languages

This gem supports any language with a tree-sitter grammar. The test suite validates:

- Rust
- Ruby
- Python
- JavaScript
- Go
- PHP
- Java
- C#

## Development

After checking out the repo:

```bash
bin/setup          # Install dependencies
make grammars      # Compile the test grammars
rake compile       # Compile the Rust extension
rake test          # Run tests (requires grammar libraries)
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/gjtorikian/tree_sitter.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
