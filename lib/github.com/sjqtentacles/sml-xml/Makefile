# sml-xml build
#
#   make            build the test binary with MLton (default)
#   make test       build + run tests under MLton
#   make test-poly  run tests under Poly/ML (use-and-run; no link step)
#   make all-tests  run the suite under both compilers
#   make example    build + run examples/demo.sml
#   make clean      remove build artifacts
#
# Layout B (dependent): own sources live in src/; sml-unicode is vendored under
# lib/ and loaded first, in dependency order.

MLTON      ?= mlton
POLY       ?= poly
BIN        := bin
UNICODEDIR := lib/github.com/sjqtentacles/sml-unicode
TEST_MLB   := test/test.mlb
SRCS       := $(wildcard $(UNICODEDIR)/* src/* test/*.sml) $(TEST_MLB)

.PHONY: all test poly test-poly all-tests example clean

all: $(BIN)/test-mlton

example: $(BIN)/demo
	./$(BIN)/demo

$(BIN)/demo: $(SRCS) examples/demo.sml examples/sources.mlb | $(BIN)
	$(MLTON) -output $@ examples/sources.mlb

$(BIN)/test-mlton: $(SRCS) | $(BIN)
	$(MLTON) -output $@ $(TEST_MLB)

test: $(BIN)/test-mlton
	$(BIN)/test-mlton

poly: test-poly

# Poly/ML has no native .mlb support; the suite runs at top level and exits on
# its own. Load the vendored sml-unicode first (data, sig, impl), then the xml
# sources, then the test driver.
test-poly:
	printf 'use "$(UNICODEDIR)/data.sml";\nuse "$(UNICODEDIR)/unicode.sig";\nuse "$(UNICODEDIR)/unicode.sml";\nuse "src/xml.sig";\nuse "src/xml.sml";\nuse "test/harness.sml";\nuse "test/support.sml";\nuse "test/test_roundtrip.sml";\nuse "test/test_escaping.sml";\nuse "test/test_namespaces.sml";\nuse "test/test_cdata_comments.sml";\nuse "test/test_findall.sml";\nuse "test/entry.sml";\nuse "test/main.sml";\n' | $(POLY) -q --error-exit

all-tests: test test-poly

$(BIN):
	mkdir -p $(BIN)

clean:
	rm -f $(BIN)/test-mlton $(BIN)/demo
