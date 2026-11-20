# Makefile for RISC-V Doc Template
#
# This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
# International License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-sa/4.0/ or send a letter to
# Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
#
# SPDX-License-Identifier: CC-BY-SA-4.0
#
# Description:
#
# This Makefile is designed to automate the process of building and packaging
# the Doc Template for RISC-V Extensions.

DOCS := \
	riscv-glossary.adoc

# Short name used in the PDF filename: <short>-v<version>-<YYYYMMDD>.pdf
SPEC_SHORT ?= $(basename $(firstword $(DOCS)))

DATE ?= $(shell date +%Y-%m-%d)
DATE_STAMP := $(subst -,,$(DATE))
VERSION ?= $(shell ./scripts/release-info.sh version)
VERSION_NUM := $(patsubst v%,%,$(VERSION))

# .docmode ("spec" default | "doc") -- see scripts/release-info.sh. This repo
# is documentation, so it runs in doc mode: the PDF and HTML targets stay, the
# ratification/phase surface is stripped.
DOC_MODE ?= $(shell ./scripts/release-info.sh mode)

PHASE ?= $(shell ./scripts/release-info.sh phase "$(VERSION)")
PHASE_DISPLAY ?= $(shell ./scripts/release-info.sh display "$(VERSION)")
PHASE_NOTICE ?= $(shell ./scripts/release-info.sh notice "$(VERSION)")
REVMARK ?= $(shell ./scripts/release-info.sh revremark "$(VERSION)")
MILESTONE_ID ?= $(PHASE)

# In doc mode pass a single doc-mode marker attribute; the assembler keys its
# ifdef::doc-mode[] guards off its presence. In spec mode pass the phase and
# milestone attributes instead.
ifeq ($(DOC_MODE),doc)
	PHASE_OPTS := -a doc-mode='doc'
else
	PHASE_OPTS := -a phase='${PHASE}' \
	              -a phase_display='${PHASE_DISPLAY}' \
	              -a phase_notice='${PHASE_NOTICE}' \
	              -a milestone_id='${MILESTONE_ID}' \
	              -a revremark='${REVMARK}'
endif
ifneq ($(SKIP_DOCKER),true)
	DOCKER_CMD := docker run --rm -v ${PWD}:/build -w /build \
	ghcr.io/riscv/riscv-docs-base-container-image:latest \
	/bin/sh -c
	DOCKER_QUOTE := "
endif

SRC_DIR := src
BUILD_DIR := build

DOCS_PDF := $(DOCS:%.adoc=%.pdf)
DOCS_HTML := $(DOCS:%.adoc=%.html)

XTRA_ADOC_OPTS :=
ASCIIDOCTOR_PDF := asciidoctor-pdf
ASCIIDOCTOR_HTML := asciidoctor
OPTIONS := --trace \
           -a compress \
           -a mathematical-format=svg \
           -a revnumber=${VERSION} \
           -a revdate=${DATE} \
           $(PHASE_OPTS) \
           -a spec_short='${SPEC_SHORT}' \
           -a pdf-fontsdir=docs-resources/fonts \
           -a pdf-theme=docs-resources/themes/riscv-pdf.yml \
           $(XTRA_ADOC_OPTS) \
		       -D build \
           --failure-level=ERROR
REQUIRES := --require=asciidoctor-diagram \
            --require=asciidoctor-mathematical \
            --require=./scripts/cross-page-xrefs.rb

.PHONY: all build clean build-container build-no-container build-docs stamp-antora

# Stamp antora.yml with the current VERSION/DATE so the Antora HTML site version
# stays in EXACT lockstep with the PDF (both derive from release-info.sh /
# the git tag). Run at release time -- e.g. `make stamp-antora VERSION=v1.0`.
# No Docker needed; edits antora.yml in place and must be committed.
stamp-antora:
	./scripts/stamp-antora-version.sh "$(VERSION)" "$(DATE)"

all: build

build-docs: $(DOCS_PDF) $(DOCS_HTML)

# PDF name: <basename>-v<version>-<YYYYMMDD>.pdf, so every build (local or CI)
# emits a uniquely identifiable artifact.
ARC_PDF = $(1)-v$(VERSION_NUM)-$(DATE_STAMP).pdf

# Only a build off a clean vX.YY (a tag, or an explicit VERSION= as CI passes)
# is a release build. An untagged build resolves VERSION to <latest>-<sha>.
ARC_EXACT := $(if $(findstring -,$(VERSION)),,yes)

vpath %.adoc $(SRC_DIR)

# AsciiDoctor writes the final name itself (-o is resolved relative to -D);
# renaming build/<basename>.pdf afterwards fails with EPERM on rootful Docker.
%.pdf: %.adoc
	$(DOCKER_CMD) $(DOCKER_QUOTE) $(ASCIIDOCTOR_PDF) $(OPTIONS) $(REQUIRES) -o $(call ARC_PDF,$*) $< $(DOCKER_QUOTE)
	@test -f build/$(call ARC_PDF,$*) || { echo "ERROR: build/$(call ARC_PDF,$*) was not produced" >&2; exit 1; }
	@if [ "$(DOC_MODE)" = "doc" ]; then \
		echo "PDF: build/$(call ARC_PDF,$*)"; \
	elif [ -n "$(ARC_EXACT)" ]; then \
		echo "ARC submission PDF: build/$(call ARC_PDF,$*)"; \
	else \
		echo "Development PDF: build/$(call ARC_PDF,$*)"; \
		echo "  Built from an untagged commit ($(VERSION)) -- NOT an ARC submission artifact."; \
		echo "  Build from a v* tag, or run 'make VERSION=vX.YY', to produce one."; \
	fi

%.html: %.adoc
	$(DOCKER_CMD) $(DOCKER_QUOTE) $(ASCIIDOCTOR_HTML) $(OPTIONS) $(REQUIRES) $< $(DOCKER_QUOTE)

build:
	@echo "Checking if Docker is available..."
	@if command -v docker >/dev/null 2>&1 ; then \
		echo "Docker is available, building inside Docker container..."; \
		$(MAKE) build-container; \
	else \
		echo "Docker is not available, building without Docker..."; \
		$(MAKE) build-no-container; \
	fi

build-container:
	@echo "Starting build inside Docker container..."
	$(MAKE) build-docs
	@echo "Build completed successfully inside Docker container."

build-no-container:
	@echo "Starting build..."
	$(MAKE) SKIP_DOCKER=true build-docs
	@echo "Build completed successfully."

clean:
	@echo "Cleaning up generated files..."
	rm -rf $(BUILD_DIR)
	@echo "Cleanup completed."
