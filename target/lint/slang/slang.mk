# Copyright Fondazione Chips-IT
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#

SLANG  ?= slang
SLANG_TOP ?= cheshire

SV_STD         ?= 1800-2017
TIMESCALE      ?= 1ns/1ps

# ---- Slang Args-------------------------------------------------------------
SLANG_STRICT := -Wextra -Werror --error-limit=0

SLANG_ARGS := \
	--std $(SV_STD) \
	--timescale=$(TIMESCALE) \
	$(if $(SINGLE_UNIT),--single-unit,) \
	--top $(SLANG_TOP) \
	$(SLANG_STRICT) \
	$(SLANG_EXTRA)

SLANG_EXTRA ?=

# ============================================================================
.PHONY: chs-slang-lint chs-slang-parse
.DEFAULT_GOAL := slang-lint

## lint  : full slang analisys (strict parse + elaboration)
chs-slang-lint: $(CHS_ROOT)/target/lint/slang/slang.lint.log
$(CHS_ROOT)/target/lint/slang/slang.lint.log:
	@echo ">> [slang] Analysing $(SLANG_TOP)"
	$(SLANG) -f $(CHS_ROOT)/target/lint/slang/parse.cheshire_soc.f $(SLANG_ARGS) 2>&1 | tee $@
	@echo ">> [slang] Design is clean"

## parse : just syntactic parsing (faster, less restrictive)
chsslang-parse: $(CHS_ROOT)/target/lint/slang/slang.parse.log
$(CHS_ROOT)/target/lint/slang/slang.parse.log:
	@echo ">> [slang] Parsing $(SLANG_TOP)"
	$(SLANG) -f $(CHS_ROOT)/target/lint/slang/parse.cheshire_soc.f --std $(SV_STD) --parse-only $(SLANG_STRICT) $(SLANG_EXTRA) 2>&1 | tee $@

chs-slang-clean:
	rm -rf $(CHS_ROOT)/target/lint/slang/slang.parse.log $(CHS_ROOT)/target/lint/slang/slang.lint.log $(CHS_ROOT)/target/lint/slang/parse.cheshire_soc.f
