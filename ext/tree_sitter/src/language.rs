use libloading::{Library, Symbol};
use magnus::{Error, Ruby};
use once_cell::sync::Lazy;
use std::collections::HashMap;
use std::sync::RwLock;
use tree_sitter_language::LanguageFn;

// Global registry of loaded languages
static LANGUAGES: Lazy<RwLock<HashMap<String, LoadedLanguage>>> =
    Lazy::new(|| RwLock::new(HashMap::new()));

struct LoadedLanguage {
    language: tree_sitter::Language,
    #[allow(dead_code)]
    library: Library, // Keep library alive!
}

// Safety: tree_sitter::Language is thread-safe
unsafe impl Send for LoadedLanguage {}
unsafe impl Sync for LoadedLanguage {}

/// Register a language from a shared library path
pub fn register_language(name: String, library_path: String) -> Result<(), Error> {
    let ruby = Ruby::get().unwrap();

    // Load the shared library
    let library = unsafe { Library::new(&library_path) }.map_err(|e| {
        Error::new(
            ruby.exception_runtime_error(),
            format!("Failed to load library '{}': {}", library_path, e),
        )
    })?;

    // The symbol name follows tree-sitter convention: tree_sitter_{language}
    let symbol_name = format!("tree_sitter_{}", name);
    let language_fn: Symbol<LanguageFn> =
        unsafe { library.get(symbol_name.as_bytes()) }.map_err(|e| {
            Error::new(
                ruby.exception_runtime_error(),
                format!(
                    "Failed to find symbol '{}' in '{}': {}",
                    symbol_name, library_path, e
                ),
            )
        })?;

    let language: tree_sitter::Language = (*language_fn).into();

    // Store language function in registry
    let mut registry = LANGUAGES.write().map_err(|_| {
        Error::new(
            ruby.exception_runtime_error(),
            "Failed to acquire language registry lock",
        )
    })?;

    registry.insert(name, LoadedLanguage { language, library });

    Ok(())
}

/// Get a registered language by name
pub fn get_language(name: String) -> Result<Language, Error> {
    let ruby = Ruby::get().unwrap();

    let registry = LANGUAGES.read().map_err(|_| {
        Error::new(
            ruby.exception_runtime_error(),
            "Failed to acquire language registry lock",
        )
    })?;

    let loaded = registry.get(&name).ok_or_else(|| {
        Error::new(
            ruby.exception_arg_error(),
            format!(
                "Language '{}' not registered. Call TreeSitter.register_language first.",
                name
            ),
        )
    })?;

    Ok(Language {
        name: name.clone(),
        inner: loaded.language.clone(),
    })
}

/// List all registered language names
pub fn list_languages() -> Result<Vec<String>, Error> {
    let ruby = Ruby::get().unwrap();

    let registry = LANGUAGES.read().map_err(|_| {
        Error::new(
            ruby.exception_runtime_error(),
            "Failed to acquire language registry lock",
        )
    })?;

    Ok(registry.keys().cloned().collect())
}

/// Get a language from the registry (internal use).
/// Returns the raw `tree_sitter::Language` instead of the wrapped `Language` struct,
/// avoiding redundant wrapping when callers just need the inner type (e.g., for
/// `parser.set_language()`). Also takes `&str` to avoid allocation.
pub fn get_language_internal(name: &str) -> Result<tree_sitter::Language, Error> {
    let ruby = Ruby::get().unwrap();

    let registry = LANGUAGES.read().map_err(|_| {
        Error::new(
            ruby.exception_runtime_error(),
            "Failed to acquire language registry lock",
        )
    })?;

    let loaded = registry.get(name).ok_or_else(|| {
        Error::new(
            ruby.exception_arg_error(),
            format!(
                "Language '{}' not registered. Call TreeSitter.register_language first.",
                name
            ),
        )
    })?;

    Ok(loaded.language.clone())
}

#[magnus::wrap(class = "TreeSitter::Language")]
#[derive(Clone)]
pub struct Language {
    pub name: String,
    pub inner: tree_sitter::Language,
}

impl Language {
    pub fn name(&self) -> &str {
        &self.name
    }

    pub fn version(&self) -> usize {
        self.inner.abi_version()
    }

    /// Returns the number of distinct node types (kinds) defined in this language's grammar.
    /// Each node in a syntax tree has a kind like "function_definition" or "identifier".
    /// Can be useful for allocation or iteration over all kinds.
    pub fn node_kind_count(&self) -> usize {
        self.inner.node_kind_count()
    }
}
