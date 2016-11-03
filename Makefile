.PHONY: tests unit proxy clean compile build

SOLC      = solc
BUILDDIR  = tests
SOLCFLAGS = --bin --abi --optimize -o $(BUILDDIR)/

SOURCES=$(shell find contracts -name "*.sol")
NAMES=$(notdir $(SOURCES))
OBJECTS=$(NAMES:%.sol=%.bin) $(NAMES:%.sol=%.abi)
TARGETS=$(addprefix $(BUILDDIR)/,$(OBJECTS))

tests: compile
	pytest tests

build: compile

compile: $(TARGETS)

combine: $(SOURCES)

$(BUILDDIR)/%.bin	$(BUILDDIR)/%.abi: contracts/%.sol
		$(SOLC) $(SOLCFLAGS) $^

unit: compile
	pytest $(BUILDDIR)/test_gnt.py

proxy: compile
	pytest $(BUILDDIR)/test_proxy.py

clean:
	rm -f $(BUILDDIR)/*.bin $(BUILDDIR)/*.abi
