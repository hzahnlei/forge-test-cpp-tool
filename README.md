# C++ CLI Tool

C++ CLI Tool example.

## Prerequisites

- [Devbox](https://devbox.sh/) installed locally
- PWD is the project root

```sh
devbox shell   # activate tooling
```

## Getting Started

```sh
make init   # Optional: run once after cloning; `make build` also fetches dependencies via Conan
```

```sh
make build   # debug build for development
```

> **IDE tip:** run `make build` once before opening this project in an IDE with CMake
> integration (VSCode CMake Tools, CLion, ...). Conan writes `CMakeUserPresets.json` during
> that first build, which is how the IDE finds the right compiler/toolchain automatically —
> configuring the IDE before that file exists is the usual cause of a "package not found"-style
> error.

## Next Steps

- Replace the `TODO` markers in the generated files.

Write specifications for the project in `docs/requirements/capabilities/` first.
Then implement the code to make the specifications pass. Always in this order.

## Development

```sh
make test   # run tests and linters
```

See [docs/index.md](docs/index.md) for the documentation: requirements, design, verification,
and manuals.

## Build and View Documentation Locally

Uses a self-contained Docker image — no local Python or Java installation required.

```sh
# Live-reload preview at http://localhost:8000
docker run --rm -p 8000:8000 -v "$PWD:/docs" \
  registry.gitlab.com/hzahnlei/build-images/mkdocs:1.5.3 \
  serve --dev-addr=0.0.0.0:8000

# Build static site into site/
docker run --rm -v "$PWD:/docs" \
  registry.gitlab.com/hzahnlei/build-images/mkdocs:1.5.3 \
  build
```

All files below the groups of `docs/` are included automatically — no manual configuration
needed when adding new Markdown, feature, API spec, or IDL files.

> **Note:** The MkDocs image is built, scanned, and published by the
> [build-images](https://gitlab.com/hzahnlei/build-images) repository's own CI pipeline.
> The version above is pinned; bump it deliberately (here and in `Makefile`'s `MKDOCS_IMAGE`)
> when a newer image is available.

## License

This project is licensed under the terms in [LICENSE](LICENSE).

## Acknowledgements

This project thankfully uses the following open source and/or free tools and services:

- [Bash](https://www.gnu.org/software/bash/) — Unix shell and scripting language
- [Docker](https://www.docker.com) — container platform
- [GitHub](https://github.com) — source code hosting and CI/CD platform
- [GitLab](https://gitlab.com) — free source code hosting and CI/CD platform
- [Git](https://git-scm.com) — distributed version control system
- [GNU Make](https://www.gnu.org/software/make/) — build automation tool
- [Visual Studio Code](https://code.visualstudio.com) — open-source code editor
- [Python](https://www.python.org) — general-purpose scripting and tooling language

## Commonly Used Libraries

This project has no business dependencies yet — these are examples of widely
used C++ libraries and tools you may reach for as the project grows, not dependencies already
in use:

- [CMake](https://cmake.org) — cross-platform build system generator
- [Conan](https://conan.io) — C/C++ package manager, with [Conan Center](https://conan.io/center) as
  its central package repository
- [spdlog](https://github.com/gabime/spdlog) — fast C++ logging library
- [cpp-httplib](https://github.com/yhirose/cpp-httplib) — header-only C++ HTTP server and client
- [Drogon](https://drogon.org) — C++ HTTP application framework
- [Catch2](https://github.com/catchorg/Catch2) — C++ test framework
- [pytest-bdd](https://pytest-bdd.readthedocs.io) — BDD framework for Python (acceptance tests, over
  HTTP for services or subprocess for CLI tools/libraries)
