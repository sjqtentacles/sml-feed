# sml-feed build
#
#   make            build the test binary with MLton (default)
#   make test       build + run tests under MLton
#   make test-poly  run tests under Poly/ML (use-and-run; no link step)
#   make all-tests  run the suite under both compilers
#   make example    build + run examples/demo.sml
#   make clean      remove build artifacts
#
# Layout B (dependent): own sources live in src/; sml-xml is vendored under lib/
# and loaded first. sml-xml bundles its own copy of sml-unicode (the single
# consistent unicode copy), which loads before the XML sources. sml-datetime is
# vendored alongside. The Feed facade loads last.

MLTON      ?= mlton
POLY       ?= poly
BIN        := bin
XMLDIR     := lib/github.com/sjqtentacles/sml-xml
UNICODE    := $(XMLDIR)/lib/github.com/sjqtentacles/sml-unicode
DTDIR      := lib/github.com/sjqtentacles/sml-datetime
TEST_MLB   := test/test.mlb
SRCS       := $(wildcard $(UNICODE)/*.sml $(UNICODE)/*.sig $(UNICODE)/*.mlb) \
              $(wildcard $(XMLDIR)/src/*.sml $(XMLDIR)/src/*.sig $(XMLDIR)/src/*.mlb) \
              $(wildcard $(DTDIR)/*.sml $(DTDIR)/*.sig $(DTDIR)/*.mlb) \
              $(wildcard src/*.sml src/*.sig src/*.mlb) \
              $(wildcard test/*.sml) $(TEST_MLB)

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

# Poly/ML has no native .mlb support; the suite runs at top level and exits on
# its own. Load the vendored sml-unicode first, then sml-xml, then sml-datetime,
# then the Feed facade, then the test driver (all in dependency order).
poly test-poly:
	printf 'use "$(UNICODE)/data.sml";\nuse "$(UNICODE)/unicode.sig";\nuse "$(UNICODE)/unicode.sml";\nuse "$(XMLDIR)/src/xml.sig";\nuse "$(XMLDIR)/src/xml.sml";\nuse "$(DTDIR)/datetime.sig";\nuse "$(DTDIR)/datetime.sml";\nuse "src/feed.sig";\nuse "src/feed.sml";\nuse "test/harness.sml";\nuse "test/test.sml";\nuse "test/entry.sml";\nuse "test/main.sml";\n' | $(POLY) -q --error-exit

all-tests: test test-poly

$(BIN):
	mkdir -p $(BIN)

clean:
	rm -f $(BIN)/test-mlton $(BIN)/demo
