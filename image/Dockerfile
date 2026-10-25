# Multi-stage build: builder compiles the CLI tool; runtime is a minimal distroless image.
# SSL is disabled in conanfile.py; all Conan deps are linked statically so the binary
# only requires glibc and libstdc++, which are present in distroless/cc.

# ── Stage 1: Build ─────────────────────────────────────────────────────────────
# Hermetic build image: clang, cmake, ninja, and conan (profile pre-detected) are
# already present — matches the same image used by CI's default/test/build jobs, so the
# Dockerfile build and the CI-tested build use an identical toolchain.
FROM registry.gitlab.com/hzahnlei/build-images/cpp-build-glibc:1.3.0 AS builder

ARG VERSION=dev
ARG COMMIT=unknown

WORKDIR /src

COPY conanfile.py .
RUN conan install . \
	--build=missing \
	-s build_type=Release \
	-s compiler.cppstd=23 \
	-o "*:shared=False" \
	--output-folder=build

COPY CMakeLists.txt .
COPY src/ src/
RUN cmake -B build \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_TOOLCHAIN_FILE=build/conan_toolchain.cmake \
	-DBUILD_TESTING=OFF && \
	cmake --build build --parallel && \
	cmake --install build --prefix /install

# ── Stage 2: Production runtime (distroless, no shell) ─────────────────────────
FROM gcr.io/distroless/cc-debian13:nonroot AS release

COPY --from=builder /install/bin/cpp-tool /app/cpp-tool

ENTRYPOINT ["/app/cpp-tool"]

# ── Stage 3: Debug runtime (bash and investigation tools) ─────────────────────
FROM debian:13.5-slim AS debug

# Investigation tools for an engineer inside the container (containerization guideline).
COPY --from=mikefarah/yq:4.54.1 /usr/bin/yq /usr/local/bin/yq
RUN apt-get update -qq && \
    apt-get upgrade -y -qq && \
    apt-get install -y --no-install-recommends ca-certificates curl jq procps ripgrep vim-tiny && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /install/bin/cpp-tool /app/cpp-tool
COPY image/entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
