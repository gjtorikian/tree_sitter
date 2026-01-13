use crate::language::Language;
use crate::node::Node;
use magnus::{Error, RArray, Ruby};
use std::cell::RefCell;
use streaming_iterator::StreamingIterator;

#[magnus::wrap(class = "TreeSitter::Query")]
pub struct Query {
    inner: tree_sitter::Query,
    capture_names: Vec<String>,
}

impl Query {
    pub fn new(language: &Language, source: String) -> Result<Self, Error> {
        let ruby = Ruby::get().unwrap();

        let query = tree_sitter::Query::new(&language.inner, &source).map_err(|e| {
            Error::new(
                ruby.exception_syntax_error(),
                format!("Query syntax error: {}", e),
            )
        })?;

        let capture_names = query
            .capture_names()
            .iter()
            .map(|s| s.to_string())
            .collect();

        Ok(Self {
            inner: query,
            capture_names,
        })
    }

    pub fn capture_names(&self) -> RArray {
        let ruby = Ruby::get().unwrap();
        let array = ruby.ary_new();
        for name in &self.capture_names {
            let _ = array.push(name.clone());
        }
        array
    }

    pub fn pattern_count(&self) -> usize {
        self.inner.pattern_count()
    }
}

#[magnus::wrap(class = "TreeSitter::QueryCursor")]
pub struct QueryCursor {
    inner: RefCell<tree_sitter::QueryCursor>,
}

impl QueryCursor {
    pub fn new() -> Self {
        Self {
            inner: RefCell::new(tree_sitter::QueryCursor::new()),
        }
    }

    pub fn matches(&self, query: &Query, node: &Node, source: String) -> RArray {
        let ruby = Ruby::get().unwrap();
        let array = ruby.ary_new();
        let Some(ts_node) = node.get_ts_node_pub() else {
            return array;
        };

        let mut cursor = self.inner.borrow_mut();
        let mut matches = cursor.matches(&query.inner, ts_node, source.as_bytes());

        while let Some(m) = matches.next() {
            let captures: Vec<QueryCapture> = m
                .captures
                .iter()
                .map(|c| {
                    let capture_name = query.capture_names[c.index as usize].clone();
                    QueryCapture {
                        name: capture_name,
                        node: Node::new(c.node, node.source.clone(), node.tree.clone()),
                    }
                })
                .collect();

            let _ = array.push(QueryMatch {
                pattern_index: m.pattern_index,
                captures,
            });
        }

        array
    }

    pub fn captures(&self, query: &Query, node: &Node, source: String) -> RArray {
        let ruby = Ruby::get().unwrap();
        let array = ruby.ary_new();
        let Some(ts_node) = node.get_ts_node_pub() else {
            return array;
        };

        let mut cursor = self.inner.borrow_mut();
        let mut captures = cursor.captures(&query.inner, ts_node, source.as_bytes());

        while let Some((m, capture_index)) = captures.next() {
            if let Some(c) = m.captures.get(*capture_index) {
                let capture_name = query.capture_names[c.index as usize].clone();
                let _ = array.push(QueryCapture {
                    name: capture_name,
                    node: Node::new(c.node, node.source.clone(), node.tree.clone()),
                });
            }
        }

        array
    }
}

#[magnus::wrap(class = "TreeSitter::QueryMatch")]
#[derive(Clone)]
pub struct QueryMatch {
    pattern_index: usize,
    captures: Vec<QueryCapture>,
}

impl QueryMatch {
    pub fn pattern_index(&self) -> usize {
        self.pattern_index
    }

    pub fn captures(&self) -> RArray {
        let ruby = Ruby::get().unwrap();
        let array = ruby.ary_new();
        for capture in &self.captures {
            let _ = array.push(capture.clone());
        }
        array
    }
}

#[magnus::wrap(class = "TreeSitter::QueryCapture")]
#[derive(Clone)]
pub struct QueryCapture {
    name: String,
    node: Node,
}

impl QueryCapture {
    pub fn name(&self) -> String {
        self.name.clone()
    }

    pub fn node(&self) -> Node {
        self.node.clone()
    }
}
