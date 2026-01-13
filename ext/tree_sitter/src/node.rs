use crate::point::Point;
use crate::range::Range;
use magnus::{RArray, Ruby};
use std::sync::Arc;

/// Node wrapper that stores both the node data and a reference to the tree
/// This allows child navigation while keeping the tree alive
#[magnus::wrap(class = "TreeSitter::Node")]
#[derive(Clone)]
pub struct Node {
    // Store the tree to keep nodes valid (public for query.rs)
    pub tree: Arc<tree_sitter::Tree>,

    // Source text for text extraction (public for query.rs)
    pub source: Arc<String>,

    // Node identification via byte range (used to relocate node in tree)
    start_byte: usize,
    end_byte: usize,

    // Cached properties
    kind: String,
    kind_id: u16,
    is_named: bool,
    is_missing: bool,
    is_extra: bool,
    is_error: bool,
    has_error: bool,
    has_changes: bool,
    start_point: Point,
    end_point: Point,
    child_count: usize,
    named_child_count: usize,
    sexp: String,
}

impl Node {
    pub fn new(ts_node: tree_sitter::Node, source: Arc<String>, tree: Arc<tree_sitter::Tree>) -> Self {
        Self {
            tree,
            source,
            start_byte: ts_node.start_byte(),
            end_byte: ts_node.end_byte(),
            kind: ts_node.kind().to_string(),
            kind_id: ts_node.kind_id(),
            is_named: ts_node.is_named(),
            is_missing: ts_node.is_missing(),
            is_extra: ts_node.is_extra(),
            is_error: ts_node.is_error(),
            has_error: ts_node.has_error(),
            has_changes: ts_node.has_changes(),
            start_point: Point::from_ts(ts_node.start_position()),
            end_point: Point::from_ts(ts_node.end_position()),
            child_count: ts_node.child_count(),
            named_child_count: ts_node.named_child_count(),
            sexp: ts_node.to_sexp(),
        }
    }

    /// Relocate the tree-sitter node from the stored tree
    fn get_ts_node(&self) -> Option<tree_sitter::Node<'_>> {
        let root = self.tree.root_node();
        root.descendant_for_byte_range(self.start_byte, self.end_byte)
    }

    /// Public method for query.rs to access the tree-sitter node
    pub fn get_ts_node_pub(&self) -> Option<tree_sitter::Node<'_>> {
        let root = self.tree.root_node();
        root.descendant_for_byte_range(self.start_byte, self.end_byte)
    }

    // Navigation methods

    pub fn parent(&self) -> Option<Node> {
        let ts_node = self.get_ts_node()?;
        ts_node
            .parent()
            .map(|n| Node::new(n, self.source.clone(), self.tree.clone()))
    }

    pub fn child(&self, index: usize) -> Option<Node> {
        let ts_node = self.get_ts_node()?;
        ts_node
            .child(index)
            .map(|n| Node::new(n, self.source.clone(), self.tree.clone()))
    }

    pub fn child_count(&self) -> usize {
        self.child_count
    }

    pub fn named_child(&self, index: usize) -> Option<Node> {
        let ts_node = self.get_ts_node()?;
        ts_node
            .named_child(index)
            .map(|n| Node::new(n, self.source.clone(), self.tree.clone()))
    }

    pub fn named_child_count(&self) -> usize {
        self.named_child_count
    }

    pub fn child_by_field_name(&self, name: String) -> Option<Node> {
        let ts_node = self.get_ts_node()?;
        ts_node
            .child_by_field_name(&name)
            .map(|n| Node::new(n, self.source.clone(), self.tree.clone()))
    }

    pub fn children(&self) -> RArray {
        let ruby = Ruby::get().unwrap();
        let array = ruby.ary_new();
        let Some(ts_node) = self.get_ts_node() else {
            return array;
        };
        let mut cursor = ts_node.walk();
        for n in ts_node.children(&mut cursor) {
            let _ = array.push(Node::new(n, self.source.clone(), self.tree.clone()));
        }
        array
    }

    pub fn named_children(&self) -> RArray {
        let ruby = Ruby::get().unwrap();
        let array = ruby.ary_new();
        let Some(ts_node) = self.get_ts_node() else {
            return array;
        };
        let mut cursor = ts_node.walk();
        for n in ts_node.named_children(&mut cursor) {
            let _ = array.push(Node::new(n, self.source.clone(), self.tree.clone()));
        }
        array
    }

    pub fn next_sibling(&self) -> Option<Node> {
        let ts_node = self.get_ts_node()?;
        ts_node
            .next_sibling()
            .map(|n| Node::new(n, self.source.clone(), self.tree.clone()))
    }

    pub fn prev_sibling(&self) -> Option<Node> {
        let ts_node = self.get_ts_node()?;
        ts_node
            .prev_sibling()
            .map(|n| Node::new(n, self.source.clone(), self.tree.clone()))
    }

    pub fn next_named_sibling(&self) -> Option<Node> {
        let ts_node = self.get_ts_node()?;
        ts_node
            .next_named_sibling()
            .map(|n| Node::new(n, self.source.clone(), self.tree.clone()))
    }

    pub fn prev_named_sibling(&self) -> Option<Node> {
        let ts_node = self.get_ts_node()?;
        ts_node
            .prev_named_sibling()
            .map(|n| Node::new(n, self.source.clone(), self.tree.clone()))
    }

    // Properties
    pub fn kind(&self) -> &str {
        &self.kind
    }

    pub fn kind_id(&self) -> u16 {
        self.kind_id
    }

    pub fn is_named(&self) -> bool {
        self.is_named
    }

    pub fn is_missing(&self) -> bool {
        self.is_missing
    }

    pub fn is_extra(&self) -> bool {
        self.is_extra
    }

    pub fn is_error(&self) -> bool {
        self.is_error
    }

    pub fn has_error(&self) -> bool {
        self.has_error
    }

    pub fn has_changes(&self) -> bool {
        self.has_changes
    }

    // Position
    pub fn start_byte(&self) -> usize {
        self.start_byte
    }

    pub fn end_byte(&self) -> usize {
        self.end_byte
    }

    pub fn start_point(&self) -> Point {
        self.start_point.clone()
    }

    pub fn end_point(&self) -> Point {
        self.end_point.clone()
    }

    pub fn range(&self) -> Range {
        Range::new(
            self.start_byte,
            self.end_byte,
            self.start_point.clone(),
            self.end_point.clone(),
        )
    }

    // Text
    pub fn text(&self) -> &str {
        if self.end_byte <= self.source.len() {
            &self.source[self.start_byte..self.end_byte]
        } else {
            ""
        }
    }

    pub fn to_sexp(&self) -> &str {
        &self.sexp
    }

    pub fn inspect(&self) -> String {
        format!(
            "#<TreeSitter::Node kind={:?} start_byte={} end_byte={}>",
            self.kind, self.start_byte, self.end_byte
        )
    }

    pub fn eq(&self, other: &Node) -> bool {
        self.start_byte == other.start_byte
            && self.end_byte == other.end_byte
            && self.kind == other.kind
    }
}
