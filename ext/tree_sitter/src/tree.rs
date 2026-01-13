use crate::language::{get_language_internal, Language};
use crate::node::Node;
use magnus::Error;
use std::sync::Arc;

#[magnus::wrap(class = "TreeSitter::Tree")]
pub struct Tree {
    pub inner: Arc<tree_sitter::Tree>,
    pub source: Arc<String>,
    pub language_name: String,
}

impl Tree {
    pub fn new(tree: tree_sitter::Tree, source: String, language_name: String) -> Self {
        Self {
            inner: Arc::new(tree),
            source: Arc::new(source),
            language_name,
        }
    }

    pub fn root_node(&self) -> Node {
        let ts_node = self.inner.root_node();
        Node::new(ts_node, self.source.clone(), self.inner.clone())
    }

    pub fn source(&self) -> String {
        (*self.source).clone()
    }

    pub fn language(&self) -> Result<Language, Error> {
        let ts_lang = get_language_internal(&self.language_name)?;
        Ok(Language {
            name: self.language_name.clone(),
            inner: ts_lang,
        })
    }
}
