mod language;
mod node;
mod parser;
mod point;
mod query;
mod range;
mod tree;

use magnus::{function, method, prelude::*, Error, Ruby};

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("TreeSitter")?;

    module.define_singleton_method(
        "register_language",
        function!(language::register_language, 2),
    )?;
    module.define_singleton_method("language", function!(language::get_language, 1))?;
    module.define_singleton_method("languages", function!(language::list_languages, 0))?;

    let language_class = module.define_class("Language", ruby.class_object())?;
    language_class.define_method("name", method!(language::Language::name, 0))?;
    language_class.define_method("version", method!(language::Language::version, 0))?;
    language_class.define_method(
        "node_kind_count",
        method!(language::Language::node_kind_count, 0),
    )?;

    let parser_class = module.define_class("Parser", ruby.class_object())?;
    parser_class.define_singleton_method("new", function!(parser::Parser::new, 0))?;
    parser_class.define_method("language=", method!(parser::Parser::set_language, 1))?;
    parser_class.define_method("language", method!(parser::Parser::language, 0))?;
    parser_class.define_method("parse", method!(parser::Parser::parse, -1))?;
    parser_class.define_method("timeout_micros", method!(parser::Parser::timeout_micros, 0))?;
    parser_class.define_method(
        "timeout_micros=",
        method!(parser::Parser::set_timeout_micros, 1),
    )?;
    parser_class.define_method("reset", method!(parser::Parser::reset, 0))?;

    let tree_class = module.define_class("Tree", ruby.class_object())?;
    tree_class.define_method("root_node", method!(tree::Tree::root_node, 0))?;
    tree_class.define_method("source", method!(tree::Tree::source, 0))?;
    tree_class.define_method("language", method!(tree::Tree::language, 0))?;

    let node_class = module.define_class("Node", ruby.class_object())?;

    // Navigation
    node_class.define_method("parent", method!(node::Node::parent, 0))?;
    node_class.define_method("child", method!(node::Node::child, 1))?;
    node_class.define_method("child_count", method!(node::Node::child_count, 0))?;
    node_class.define_method("named_child", method!(node::Node::named_child, 1))?;
    node_class.define_method(
        "named_child_count",
        method!(node::Node::named_child_count, 0),
    )?;
    node_class.define_method(
        "child_by_field_name",
        method!(node::Node::child_by_field_name, 1),
    )?;
    node_class.define_method("children", method!(node::Node::children, 0))?;
    node_class.define_method("named_children", method!(node::Node::named_children, 0))?;
    node_class.define_method("next_sibling", method!(node::Node::next_sibling, 0))?;
    node_class.define_method("prev_sibling", method!(node::Node::prev_sibling, 0))?;
    node_class.define_method(
        "next_named_sibling",
        method!(node::Node::next_named_sibling, 0),
    )?;
    node_class.define_method(
        "prev_named_sibling",
        method!(node::Node::prev_named_sibling, 0),
    )?;

    // Properties
    node_class.define_method("kind", method!(node::Node::kind, 0))?;
    node_class.define_method("type", method!(node::Node::kind, 0))?; // Alias
    node_class.define_method("kind_id", method!(node::Node::kind_id, 0))?;
    node_class.define_method("named?", method!(node::Node::is_named, 0))?;
    node_class.define_method("missing?", method!(node::Node::is_missing, 0))?;
    node_class.define_method("extra?", method!(node::Node::is_extra, 0))?;
    node_class.define_method("error?", method!(node::Node::is_error, 0))?;
    node_class.define_method("has_error?", method!(node::Node::has_error, 0))?;
    node_class.define_method("has_changes?", method!(node::Node::has_changes, 0))?;

    // Position
    node_class.define_method("start_byte", method!(node::Node::start_byte, 0))?;
    node_class.define_method("end_byte", method!(node::Node::end_byte, 0))?;
    node_class.define_method("start_point", method!(node::Node::start_point, 0))?;
    node_class.define_method("end_point", method!(node::Node::end_point, 0))?;
    node_class.define_method("range", method!(node::Node::range, 0))?;

    // Text
    node_class.define_method("text", method!(node::Node::text, 0))?;
    node_class.define_method("to_sexp", method!(node::Node::to_sexp, 0))?;
    node_class.define_method("to_s", method!(node::Node::to_sexp, 0))?;
    node_class.define_method("inspect", method!(node::Node::inspect, 0))?;
    node_class.define_method("==", method!(node::Node::eq, 1))?;
    node_class.define_method("eql?", method!(node::Node::eq, 1))?;

    let point_class = module.define_class("Point", ruby.class_object())?;
    point_class.define_singleton_method("new", function!(point::Point::new, 2))?;
    point_class.define_method("row", method!(point::Point::row, 0))?;
    point_class.define_method("column", method!(point::Point::column, 0))?;
    point_class.define_method("to_a", method!(point::Point::to_a, 0))?;
    point_class.define_method("inspect", method!(point::Point::inspect, 0))?;
    point_class.define_method("==", method!(point::Point::eq, 1))?;

    // Range class
    let range_class = module.define_class("Range", ruby.class_object())?;
    range_class.define_method("start_byte", method!(range::Range::start_byte, 0))?;
    range_class.define_method("end_byte", method!(range::Range::end_byte, 0))?;
    range_class.define_method("start_point", method!(range::Range::start_point, 0))?;
    range_class.define_method("end_point", method!(range::Range::end_point, 0))?;
    range_class.define_method("size", method!(range::Range::size, 0))?;
    range_class.define_method("inspect", method!(range::Range::inspect, 0))?;

    let query_class = module.define_class("Query", ruby.class_object())?;
    query_class.define_singleton_method("new", function!(query::Query::new, 2))?;
    query_class.define_method("capture_names", method!(query::Query::capture_names, 0))?;
    query_class.define_method("pattern_count", method!(query::Query::pattern_count, 0))?;

    let cursor_class = module.define_class("QueryCursor", ruby.class_object())?;
    cursor_class.define_singleton_method("new", function!(query::QueryCursor::new, 0))?;
    cursor_class.define_method("matches", method!(query::QueryCursor::matches, 3))?;
    cursor_class.define_method("captures", method!(query::QueryCursor::captures, 3))?;

    let match_class = module.define_class("QueryMatch", ruby.class_object())?;
    match_class.define_method(
        "pattern_index",
        method!(query::QueryMatch::pattern_index, 0),
    )?;
    match_class.define_method("captures", method!(query::QueryMatch::captures, 0))?;

    let capture_class = module.define_class("QueryCapture", ruby.class_object())?;
    capture_class.define_method("name", method!(query::QueryCapture::name, 0))?;
    capture_class.define_method("node", method!(query::QueryCapture::node, 0))?;

    Ok(())
}
