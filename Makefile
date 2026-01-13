# Makefile for building tree-sitter grammars

GRAMMAR_DIR := .tree-sitter-grammars

# Platform detection
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    EXT := dylib
    CC_FLAGS := -shared -fPIC
else ifeq ($(UNAME_S),Linux)
    EXT := so
    CC_FLAGS := -shared -fPIC
else ifeq ($(OS),Windows_NT)
    EXT := dll
    CC_FLAGS := -shared
else
    EXT := so
    CC_FLAGS := -shared -fPIC
endif

GRAMMARS := rust ruby python javascript go php java c_sharp

.PHONY: all grammars clean $(GRAMMARS)

all: grammars

grammars: $(GRAMMARS)

rust: $(GRAMMAR_DIR)/rust/libtree-sitter-rust.$(EXT)
$(GRAMMAR_DIR)/rust/libtree-sitter-rust.$(EXT):
	@mkdir -p $(GRAMMAR_DIR)
	@if [ ! -d "$(GRAMMAR_DIR)/rust" ]; then \
		echo "Cloning tree-sitter-rust..."; \
		git clone --depth 1 https://github.com/tree-sitter/tree-sitter-rust.git $(GRAMMAR_DIR)/rust; \
	fi
	@echo "Building tree-sitter-rust..."
	@cd $(GRAMMAR_DIR)/rust && $(CC) $(CC_FLAGS) -I src src/parser.c src/scanner.c -o libtree-sitter-rust.$(EXT)

ruby: $(GRAMMAR_DIR)/ruby/libtree-sitter-ruby.$(EXT)
$(GRAMMAR_DIR)/ruby/libtree-sitter-ruby.$(EXT):
	@mkdir -p $(GRAMMAR_DIR)
	@if [ ! -d "$(GRAMMAR_DIR)/ruby" ]; then \
		echo "Cloning tree-sitter-ruby..."; \
		git clone --depth 1 https://github.com/tree-sitter/tree-sitter-ruby.git $(GRAMMAR_DIR)/ruby; \
	fi
	@echo "Building tree-sitter-ruby..."
	@cd $(GRAMMAR_DIR)/ruby && $(CC) $(CC_FLAGS) -I src src/parser.c src/scanner.c -o libtree-sitter-ruby.$(EXT)

python: $(GRAMMAR_DIR)/python/libtree-sitter-python.$(EXT)
$(GRAMMAR_DIR)/python/libtree-sitter-python.$(EXT):
	@mkdir -p $(GRAMMAR_DIR)
	@if [ ! -d "$(GRAMMAR_DIR)/python" ]; then \
		echo "Cloning tree-sitter-python..."; \
		git clone --depth 1 https://github.com/tree-sitter/tree-sitter-python.git $(GRAMMAR_DIR)/python; \
	fi
	@echo "Building tree-sitter-python..."
	@cd $(GRAMMAR_DIR)/python && $(CC) $(CC_FLAGS) -I src src/parser.c src/scanner.c -o libtree-sitter-python.$(EXT)

javascript: $(GRAMMAR_DIR)/javascript/libtree-sitter-javascript.$(EXT)
$(GRAMMAR_DIR)/javascript/libtree-sitter-javascript.$(EXT):
	@mkdir -p $(GRAMMAR_DIR)
	@if [ ! -d "$(GRAMMAR_DIR)/javascript" ]; then \
		echo "Cloning tree-sitter-javascript..."; \
		git clone --depth 1 https://github.com/tree-sitter/tree-sitter-javascript.git $(GRAMMAR_DIR)/javascript; \
	fi
	@echo "Building tree-sitter-javascript..."
	@cd $(GRAMMAR_DIR)/javascript && $(CC) $(CC_FLAGS) -I src src/parser.c src/scanner.c -o libtree-sitter-javascript.$(EXT)

go: $(GRAMMAR_DIR)/go/libtree-sitter-go.$(EXT)
$(GRAMMAR_DIR)/go/libtree-sitter-go.$(EXT):
	@mkdir -p $(GRAMMAR_DIR)
	@if [ ! -d "$(GRAMMAR_DIR)/go" ]; then \
		echo "Cloning tree-sitter-go..."; \
		git clone --depth 1 https://github.com/tree-sitter/tree-sitter-go.git $(GRAMMAR_DIR)/go; \
	fi
	@echo "Building tree-sitter-go..."
	@cd $(GRAMMAR_DIR)/go && $(CC) $(CC_FLAGS) -I src src/parser.c -o libtree-sitter-go.$(EXT)

php: $(GRAMMAR_DIR)/php/libtree-sitter-php.$(EXT)
$(GRAMMAR_DIR)/php/libtree-sitter-php.$(EXT):
	@mkdir -p $(GRAMMAR_DIR)
	@if [ ! -d "$(GRAMMAR_DIR)/php" ]; then \
		echo "Cloning tree-sitter-php..."; \
		git clone --depth 1 https://github.com/tree-sitter/tree-sitter-php.git $(GRAMMAR_DIR)/php; \
	fi
	@echo "Building tree-sitter-php..."
	@cd $(GRAMMAR_DIR)/php/php && $(CC) $(CC_FLAGS) -I src src/parser.c src/scanner.c -o ../libtree-sitter-php.$(EXT)

java: $(GRAMMAR_DIR)/java/libtree-sitter-java.$(EXT)
$(GRAMMAR_DIR)/java/libtree-sitter-java.$(EXT):
	@mkdir -p $(GRAMMAR_DIR)
	@if [ ! -d "$(GRAMMAR_DIR)/java" ]; then \
		echo "Cloning tree-sitter-java..."; \
		git clone --depth 1 https://github.com/tree-sitter/tree-sitter-java.git $(GRAMMAR_DIR)/java; \
	fi
	@echo "Building tree-sitter-java..."
	@cd $(GRAMMAR_DIR)/java && $(CC) $(CC_FLAGS) -I src src/parser.c -o libtree-sitter-java.$(EXT)

c_sharp: $(GRAMMAR_DIR)/c_sharp/libtree-sitter-c_sharp.$(EXT)
$(GRAMMAR_DIR)/c_sharp/libtree-sitter-c_sharp.$(EXT):
	@mkdir -p $(GRAMMAR_DIR)
	@if [ ! -d "$(GRAMMAR_DIR)/c_sharp" ]; then \
		echo "Cloning tree-sitter-c-sharp..."; \
		git clone --depth 1 https://github.com/tree-sitter/tree-sitter-c-sharp.git $(GRAMMAR_DIR)/c_sharp; \
	fi
	@echo "Building tree-sitter-c-sharp..."
	@cd $(GRAMMAR_DIR)/c_sharp && $(CC) $(CC_FLAGS) -I src src/parser.c src/scanner.c -o libtree-sitter-c_sharp.$(EXT)

clean:
	rm -rf $(GRAMMAR_DIR)

# Show which extension will be used
info:
	@echo "Platform: $(UNAME_S)"
	@echo "Extension: $(EXT)"
	@echo "Grammar directory: $(GRAMMAR_DIR)"
