ARTIFACT     := cpp-tool
BUILD_DIR    := build
REPORTS_DIR  := test_reports
MKDOCS_IMAGE := registry.gitlab.com/hzahnlei/build-images/mkdocs:1.5.3

# Every recipe gets bash's -e/-u/pipefail semantics for free
# instead of each one declaring it: a failing command aborts the recipe immediately, an unset
# variable is an error, and a failing command inside a pipe is no longer silently swallowed by
# the pipe's last command's exit code.
SHELL         := bash
.SHELLFLAGS   := -eu -o pipefail -c

VERSION    := $(shell git describe --tags --always --dirty 2>/dev/null || echo "0.0.0")
COMMIT     := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_TIME := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

.PHONY: phony

all: build

# Run once after cloning, or after adding/removing dependencies.
init: phony
	# Implement if required. Remove otherwise.

# Debug and Release builds use separate directories so both can coexist
# (the Merge-to-main CI tier builds Release without discarding a Debug build).
BUILD_DEBUG_DIR   := $(BUILD_DIR)/debug
BUILD_RELEASE_DIR := $(BUILD_DIR)/release

# `build` collides with $(BUILD_DIR) (both named "build"); without this, `test`/`lint` (which
# depend on `build`) would fall back to comparing build/'s own directory mtime against theirs
# instead of always rebuilding — build/'s mtime doesn't necessarily change just because files
# deep inside it do, so adding e.g. a new file under test/ could make `make test` silently skip
# ctest while still reporting success.
.PHONY: build

# Debug build: all warnings enabled, address and UB sanitizers active, no optimizations.
# Compiler flags (Wall, Wextra, Wpedantic, sanitizers) are configured in CMakeLists.txt.
build: phony
	mkdir -p $(BUILD_DEBUG_DIR)
	conan profile path default >/dev/null 2>&1 || conan profile detect
	conan install . --output-folder=$(BUILD_DEBUG_DIR) --build=missing \
	    -s build_type=Debug \
	    -s compiler.cppstd=23
	cmake -B $(BUILD_DEBUG_DIR) \
	      -DCMAKE_BUILD_TYPE=Debug \
	      -DCMAKE_TOOLCHAIN_FILE=$(BUILD_DEBUG_DIR)/conan_toolchain.cmake \
	      -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
	cmake --build $(BUILD_DEBUG_DIR) --parallel

# Release build: full optimizations, no debug symbols, no sanitizers.
release-build: phony
	mkdir -p $(BUILD_RELEASE_DIR)
	conan profile path default >/dev/null 2>&1 || conan profile detect
	conan install . --output-folder=$(BUILD_RELEASE_DIR) --build=missing \
	    -s build_type=Release \
	    -s compiler.cppstd=23
	cmake -B $(BUILD_RELEASE_DIR) \
	      -DCMAKE_BUILD_TYPE=Release \
	      -DCMAKE_TOOLCHAIN_FILE=$(BUILD_RELEASE_DIR)/conan_toolchain.cmake
	cmake --build $(BUILD_RELEASE_DIR) --parallel

# Run the debug build. Arguments can be passed via ARGS: make run ARGS="--help"
run: phony
	$(BUILD_DEBUG_DIR)/src/$(ARTIFACT) $(ARGS)

# Run all tests with Catch2 via CTest.
# Produces JUnit XML report for CI integration.
# Requires build to have been run first.
test: build
	mkdir -p $(REPORTS_DIR)/test
	ctest --test-dir $(BUILD_DEBUG_DIR) \
	      --output-junit $(CURDIR)/$(REPORTS_DIR)/test/test_results.xml \
	      --output-on-failure \
	      --parallel

# Measure code coverage with gcovr.
# main.cpp is excluded: it is thin wiring (argument/route setup delegating to greeter/app), not
# unit-testable in a meaningful way — counting it would penalize exactly the thin-entrypoint
# style the architecture calls for.
# Produces Cobertura XML (for CI) and HTML (for local review).
# The last line, `Coverage: <n>%`, is what the pipeline reads; gcovr's exit status is deferred so
# the figure still prints below the threshold.
# Requires: devbox shell (gcovr is included as a devbox package).
# gcov note-file format is compiler-specific: the glibc build image's c++ is Clang (needs
# llvm-cov's gcov-compatible mode), the musl one is GCC (needs plain gcov) — detect instead
# of hardcoding one, or coverage silently breaks on whichever image isn't hardcoded.
GCOV_EXECUTABLE := $(shell c++ --version 2>/dev/null | grep -qi clang && echo "llvm-cov gcov" || echo gcov)

# Coverage-instrumented build in a directory of its own, so that the debug build stays free of
# instrumentation and neither inherits the other's flags from CMake's cache. It reuses the debug
# build's Conan dependencies. Deleting the counters of earlier runs makes bdd-test and coverage
# count the current run only; before the build, it also keeps stale counters from breaking Catch2's
# test discovery, which runs the freshly built test executable.
BUILD_COVERAGE_DIR := $(BUILD_DIR)/coverage

coverage-build: phony
	mkdir -p $(BUILD_DEBUG_DIR)
	conan profile path default >/dev/null 2>&1 || conan profile detect
	conan install . --output-folder=$(BUILD_DEBUG_DIR) --build=missing \
	    -s build_type=Debug \
	    -s compiler.cppstd=23
	cmake -B $(BUILD_COVERAGE_DIR) \
	      -DCMAKE_BUILD_TYPE=Debug \
	      -DCMAKE_TOOLCHAIN_FILE=$(CURDIR)/$(BUILD_DEBUG_DIR)/conan_toolchain.cmake \
	      -DCMAKE_CXX_FLAGS="--coverage" \
	      -DCMAKE_EXE_LINKER_FLAGS="--coverage"
	find $(BUILD_COVERAGE_DIR) -name '*.gcda' -delete
	cmake --build $(BUILD_COVERAGE_DIR) --parallel
	find $(BUILD_COVERAGE_DIR) -name '*.gcda' -delete

coverage: coverage-build phony
	mkdir -p $(REPORTS_DIR)/coverage
	ctest --test-dir $(BUILD_COVERAGE_DIR) --output-on-failure --parallel
	gcovr \
	    --root . \
	    --exclude '$(BUILD_DIR)/' \
	    --exclude 'test/' \
	    --exclude '\.conan' \
	    --exclude 'src/main.cpp' \
	    --gcov-executable='$(GCOV_EXECUTABLE)' \
	    --txt $(REPORTS_DIR)/coverage/coverage.txt \
	    --fail-under-line 80 \
	    --xml-pretty --output $(REPORTS_DIR)/coverage/coverage.xml \
	    --html-details $(REPORTS_DIR)/coverage/coverage.html \
	    $(BUILD_COVERAGE_DIR) || STATUS=$$?; \
	  cat $(REPORTS_DIR)/coverage/coverage.txt; \
	  awk '/^TOTAL/ { print "Coverage: " $$NF }' $(REPORTS_DIR)/coverage/coverage.txt; \
	  exit "$${STATUS:-0}"

# Re-run the same test suite against the Release build (optimization can expose/hide bugs
# that Debug builds don't, and sanitizers behave differently under optimization).
release-test: release-build
	mkdir -p $(REPORTS_DIR)/test
	ctest --test-dir $(BUILD_RELEASE_DIR) \
	      --output-junit $(CURDIR)/$(REPORTS_DIR)/test/release_test_results.xml \
	      --output-on-failure \
	      --parallel

# Runs BDD acceptance scenarios (pytest-bdd) as subprocess invocations of a coverage-instrumented
# build of this CLI tool
# in for the native Gherkin runner Go/Java have (Godog/Cucumber). Unlike a service, there is no
# process to start or stop: each scenario invokes the built binary once via subprocess. Reuses
# $(BUILD_COVERAGE_DIR)'s gcov data, so a subsequent `gcovr` pass (see `coverage` above) reports
# coverage contributed by both Catch2 and this subprocess-driven run.
#
# Depends on coverage-build (test_cpp.tmpl) instead of repeating its conan/cmake/build sequence
# here: this target and `coverage` (which lists this target as a prerequisite, below) used to
# each run that sequence separately, building $(BUILD_COVERAGE_DIR) twice per `make coverage`.
bdd-test: coverage-build phony
	mkdir -p $(REPORTS_DIR)/bdd-test
	BDD_BINARY=$(CURDIR)/$(BUILD_COVERAGE_DIR)/src/$(ARTIFACT) \
	  pytest test/bdd --junitxml=$(CURDIR)/$(REPORTS_DIR)/bdd-test/results.xml

# Adds bdd-test as a prerequisite of the coverage target defined above: gcovr must see the
# subprocess-driven run's .gcda hits alongside Catch2's.
coverage: bdd-test

# Enforce Clean Architecture layer dependencies by checking #include directives.
# Fails if a file in a lower-level layer includes from a higher-level layer.
arch-test: phony
	mkdir -p $(REPORTS_DIR)/arch-test
	python3 scripts/arch_check.py > $(REPORTS_DIR)/arch-test/arch-check.txt 2>&1 || STATUS=$$?; \
	  cat $(REPORTS_DIR)/arch-test/arch-check.txt || true; exit "$${STATUS:-0}"

# Run clang-format (style) and clang-tidy (static analysis).
# clang-tidy requires a compilation database, hence the `build` prerequisite.
# Writes per-tool reports to $(REPORTS_DIR)/linting/ for CI artifact collection.
lint-code: build
	mkdir -p $(REPORTS_DIR)/linting
	find src/ \( -name '*.cpp' -o -name '*.hpp' \) \
	    | xargs clang-format --dry-run --Werror \
	    > $(REPORTS_DIR)/linting/clang-format.txt 2>&1 || STATUS=$$?; \
	  cat $(REPORTS_DIR)/linting/clang-format.txt || true; \
	  [ "$${STATUS:-0}" -eq 0 ] || exit "$$STATUS"
	run-clang-tidy -p $(BUILD_DEBUG_DIR) src/ \
	    > $(REPORTS_DIR)/linting/clang-tidy.txt 2>&1 || STATUS=$$?; \
	  cat $(REPORTS_DIR)/linting/clang-tidy.txt || true; exit "$${STATUS:-0}"

# Lint every shell script in the project with ShellCheck from the image the CI pipeline uses.
# Scripts are discovered rather than hardcoded, since which ones exist (container entrypoints,
# Claude hooks, scripts/*.sh) varies by project type — every one of them must still pass. `+`
# batches all matches into one shellcheck invocation and, unlike `$$(find ...)`, runs the command
# zero times (exit 0) instead of blocking on stdin when nothing matches.
SHELL_TOOLS_IMAGE := registry.gitlab.com/hzahnlei/build-images/shell-tools:1.2.1

# In the pipeline, the job already runs in that image.
ifdef CI
SHELL_TOOLS_FIND := find
else
SHELL_TOOLS_FIND := docker run --rm -v "$(CURDIR):/workdir" -w /workdir --entrypoint find $(SHELL_TOOLS_IMAGE)
endif

lint-shell: phony
	mkdir -p $(REPORTS_DIR)/linting
	$(SHELL_TOOLS_FIND) \
	    . -type f -name "*.sh" -not -path "./$(BUILD_DIR)/*" -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./.devbox/*" \
	    -not -path "./.go-cache/*" -not -path "./.npm-cache/*" -not -path "./.m2/*" -not -path "./.conan/*" \
	    -exec shellcheck {} + > $(REPORTS_DIR)/linting/shellcheck.txt 2>&1 || STATUS=$$?; \
	  cat $(REPORTS_DIR)/linting/shellcheck.txt; exit "$${STATUS:-0}"

# Check every DBC file with cantools from the image the CI pipeline uses: loading fails on
# a syntax error, on signals that overlap or reach beyond their message, and on a message identifier
# or name used twice. The image exists for amd64 only. Without a DBC file, there is nothing to check.
CANTOOLS_IMAGE := registry.gitlab.com/hzahnlei/build-images/cantools:1.0.1

# In the pipeline, the job already runs in that image.
ifdef CI
CANTOOLS_FIND := find
else
CANTOOLS_FIND := docker run --rm --platform linux/amd64 -v "$(CURDIR):/workdir" -w /workdir --entrypoint find $(CANTOOLS_IMAGE)
endif

lint-dbc: phony
	$(CANTOOLS_FIND) \
	    . -type f -name "*.dbc" -not -path "./$(BUILD_DIR)/*" -not -path "./.git/*" -exec sh -c \
	    'status=0; for f; do cantools dump "$$f" > /dev/null || { echo "$$f: not a valid DBC file" >&2; status=1; }; done; exit "$$status"' \
	    sh {} +

# Run every linter of the project.
lint: lint-code lint-shell lint-markdown lint-dbc

# Lint every Markdown file with markdownlint-cli2 from the image the CI pipeline uses;
# .markdownlint-cli2.jsonc names the files and .markdownlint.json the rules.
MARKDOWNLINT_IMAGE := davidanson/markdownlint-cli2:v0.23.3

lint-markdown: phony
	mkdir -p $(REPORTS_DIR)/linting
	docker run --rm -v "$(CURDIR):/workdir" -w /workdir $(MARKDOWNLINT_IMAGE) \
	    > $(REPORTS_DIR)/linting/markdownlint.txt 2>&1 || STATUS=$$?; \
	  cat $(REPORTS_DIR)/linting/markdownlint.txt; exit "$${STATUS:-0}"

# Lint the GitHub Actions workflows.
ci-lint: phony
	actionlint

# Scan repository for secrets and vulnerabilities with Trivy.
scan: phony
	docker run --rm \
	    -v "$(CURDIR):/workdir" \
	    -w /workdir \
	    aquasec/trivy:0.74.0 \
	    fs --exit-code 1 --severity HIGH,CRITICAL --scanners secret,vuln .

IMAGE_REGISTRY ?= ghcr.io/hzahnlei
IMAGE_NAME     := $(IMAGE_REGISTRY)/$(ARTIFACT)
# The build images exist for amd64 only, and so do the images.
IMAGE_PLATFORM := linux/amd64

# The images take what the builds produced, as in the pipeline, and compile nothing themselves.
# Locally, the builds run in the pipeline's build images first, into a directory of their own, so
# that they never replace the host's executables.
IMAGE_BUILD_DIR := $(BUILD_DIR)/image
IMAGE_BUILD_RUN := docker run --rm --platform $(IMAGE_PLATFORM) -v "$(CURDIR):/src" -w /src \
    -u "$$(id -u):$$(id -g)" -e HOME=/tmp \
    -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0='*'

# Defensive: `image` collides with the real image/ directory (holds the Dockerfile, present from
# generation time, not just after a build) — no target here currently depends on `image`, but if
# one ever does, comparing image/'s own directory mtime against that target's would risk silently
# skipping its recipe (see build_cpp.tmpl for the case where this already bit a target with its
# own recipe).
.PHONY: image

# Debug container image (bash and investigation tools, see the containerization guideline).
# Image name is suffixed with -debug to distinguish from the release image.
image: phony
	$(IMAGE_BUILD_RUN) -e CONAN_HOME=/src/.conan registry.gitlab.com/hzahnlei/build-images/cpp-build-glibc:1.3.0 \
	    make build BUILD_DEBUG_DIR=$(IMAGE_BUILD_DIR)/debug VERSION=$(VERSION) COMMIT=$(COMMIT)
	docker build \
	    --platform $(IMAGE_PLATFORM) \
	    --build-arg DEBUG_EXECUTABLE=$(IMAGE_BUILD_DIR)/debug/src/$(ARTIFACT) \
	    --target debug \
	    -t $(IMAGE_NAME):$(VERSION)-debug \
	    -f image/Dockerfile .

# Release container image (distroless, nonroot — minimal attack surface).
# Tagged with both the version and latest.
release-image: phony
	$(IMAGE_BUILD_RUN) -e CONAN_HOME=/src/.conan registry.gitlab.com/hzahnlei/build-images/cpp-build-glibc:1.3.0 \
	    make release-build BUILD_RELEASE_DIR=$(IMAGE_BUILD_DIR)/release VERSION=$(VERSION) COMMIT=$(COMMIT)
	docker build \
	    --platform $(IMAGE_PLATFORM) \
	    --build-arg RELEASE_EXECUTABLE=$(IMAGE_BUILD_DIR)/release/src/$(ARTIFACT) \
	    --target release \
	    -t $(IMAGE_NAME):$(VERSION) \
	    -t $(IMAGE_NAME):latest \
	    -f image/Dockerfile .

# Scan the release container image for secrets and vulnerabilities with Trivy.
# Two passes, matching the CI job: report everything, then fail only on what has a fix
# available — an unfixed vulnerability cannot be resolved from this repository.
scan-image: phony
	docker run --rm \
	    aquasec/trivy:0.74.0 \
	    image --severity HIGH,CRITICAL --exit-code 0 $(IMAGE_NAME):$(VERSION)
	docker run --rm \
	    aquasec/trivy:0.74.0 \
	    image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 $(IMAGE_NAME):$(VERSION)

# Generate documentation locally with live-reload at http://localhost:8000.
# mkdocs.yml must exist in the repository root. Runs in a named container so `docs-down` can
# always find and stop it, even if Ctrl+C didn't cleanly stop it (the mkdocs image's entrypoint
# doesn't reliably forward SIGINT/SIGTERM to the mkdocs process).
DOCS_CONTAINER := $(ARTIFACT)-docs

docs: phony
	docker run --rm \
	           --name $(DOCS_CONTAINER) \
	           -v "$(CURDIR):/docs" \
	           -p 8000:8000 \
	           $(MKDOCS_IMAGE) serve --dev-addr=0.0.0.0:8000

# Stop a docs server left running in the background (e.g. after Ctrl+C didn't stop it cleanly).
docs-down: phony
	docker stop $(DOCS_CONTAINER) 2>/dev/null || true

# Stop any existing docs server, then start a fresh one.
docs-restart: docs-down docs

# Build the documentation site into SITE_DIR with the mkdocs image the pipeline uses. In the
# pipeline, the job already runs in that image.
SITE_DIR ?= site
ifdef CI
MKDOCS := /usr/local/bin/entrypoint.sh
else
MKDOCS := docker run --rm -v "$(CURDIR):/docs" $(MKDOCS_IMAGE)
endif

docs-build: phony
	$(MKDOCS) build --site-dir $(SITE_DIR)

# Delete all generated build artifacts and test reports.
clean: phony
	rm -rf $(BUILD_DIR) $(REPORTS_DIR)

# This file is generator owned. User defined targets go here:
include Makefile.local

