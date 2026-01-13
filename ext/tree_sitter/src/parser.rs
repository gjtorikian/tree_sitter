use crate::language::{get_language_internal, Language};
use crate::tree::Tree;
use magnus::{prelude::*, Error, RString, Ruby, TryConvert, Value};
use std::cell::RefCell;
use std::ops::ControlFlow;
use std::time::Instant;

#[magnus::wrap(class = "TreeSitter::Parser")]
pub struct Parser {
    inner: RefCell<tree_sitter::Parser>,
    language_name: RefCell<Option<String>>,
    timeout_micros: RefCell<u64>,
}

impl Parser {
    pub fn new() -> Result<Self, Error> {
        let parser = tree_sitter::Parser::new();
        Ok(Self {
            inner: RefCell::new(parser),
            language_name: RefCell::new(None),
            timeout_micros: RefCell::new(0),
        })
    }

    pub fn set_language(&self, lang: Value) -> Result<(), Error> {
        let name: String = if RString::from_value(lang).is_some() {
            <String as TryConvert>::try_convert(lang)?
        } else {
            // Assume it's a Language object?
            let language: &Language = <&Language as TryConvert>::try_convert(lang)?;
            language.name.clone()
        };

        let ts_language = get_language_internal(&name)?;

        let ruby = Ruby::get().unwrap();
        let mut parser = self.inner.borrow_mut();
        parser.set_language(&ts_language).map_err(|e| {
            Error::new(
                ruby.exception_runtime_error(),
                format!("Failed to set language: {}", e),
            )
        })?;

        *self.language_name.borrow_mut() = Some(name);
        Ok(())
    }

    pub fn language(&self) -> Result<Option<Language>, Error> {
        let name = self.language_name.borrow();
        match &*name {
            Some(n) => {
                let ts_lang = get_language_internal(n)?;
                Ok(Some(Language {
                    name: n.clone(),
                    inner: ts_lang,
                }))
            }
            None => Ok(None),
        }
    }

    pub fn parse(&self, args: &[Value]) -> Result<Option<Tree>, Error> {
        let ruby = Ruby::get().unwrap();

        if args.is_empty() {
            return Err(Error::new(
                ruby.exception_arg_error(),
                "wrong number of arguments",
            ));
        }

        let source: String = <String as TryConvert>::try_convert(args[0])?;
        let old_tree: Option<&Tree> = if args.len() > 1 && !args[1].is_nil() {
            Some(<&Tree as TryConvert>::try_convert(args[1])?)
        } else {
            None
        };

        let language_name = self.language_name.borrow().clone().ok_or_else(|| {
            Error::new(
                ruby.exception_runtime_error(),
                "No language set. Call `parser.language = 'name'` first.",
            )
        })?;

        let mut parser = self.inner.borrow_mut();
        let old_ts_tree = old_tree.map(|t| (*t.inner).clone());

        let timeout = *self.timeout_micros.borrow();
        let result = if timeout > 0 {
            let start = Instant::now();
            let source_bytes = source.as_bytes();
            let mut progress_callback = |_: &tree_sitter::ParseState| {
                if start.elapsed().as_micros() < timeout as u128 {
                    ControlFlow::Continue(())
                } else {
                    ControlFlow::Break(())
                }
            };
            let options =
                tree_sitter::ParseOptions::new().progress_callback(&mut progress_callback);
            let mut source_callback = |offset: usize, _: tree_sitter::Point| {
                if offset < source_bytes.len() {
                    &source_bytes[offset..]
                } else {
                    &[]
                }
            };
            parser.parse_with_options(&mut source_callback, old_ts_tree.as_ref(), Some(options))
        } else {
            parser.parse(&source, old_ts_tree.as_ref())
        };

        match result {
            Some(tree) => Ok(Some(Tree::new(tree, source, language_name))),
            None => Ok(None),
        }
    }

    pub fn timeout_micros(&self) -> u64 {
        *self.timeout_micros.borrow()
    }

    pub fn set_timeout_micros(&self, timeout: u64) {
        *self.timeout_micros.borrow_mut() = timeout;
    }

    pub fn reset(&self) {
        self.inner.borrow_mut().reset();
    }
}
