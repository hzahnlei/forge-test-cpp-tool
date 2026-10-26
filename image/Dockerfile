# The images take the executables the pipeline built and tested; they compile nothing. The
# release stage takes the executable of release-build, the debug stage the executable of build,
# with debug symbols and no optimization. Both link the Conan dependencies statically and need only
# glibc and libstdc++. Locally, `make release-image` and `make image` build both in the pipeline's
# build image first.

# ── Release runtime (distroless, no shell) ───────────────────────────────────
FROM gcr.io/distroless/cc-debian13:nonroot AS release

ARG RELEASE_EXECUTABLE=build/release/src/cpp-tool
COPY --chmod=755 ${RELEASE_EXECUTABLE} /app/cpp-tool

ENTRYPOINT ["/app/cpp-tool"]

# ── Debug runtime (bash and investigation tools) ─────────────────────────────
FROM debian:13.5-slim AS debug

# Investigation tools for an engineer inside the container (containerization guideline).
COPY --from=mikefarah/yq:4.54.1 /usr/bin/yq /usr/local/bin/yq
RUN apt-get update -qq && \
    apt-get upgrade -y -qq && \
    apt-get install -y --no-install-recommends ca-certificates curl jq procps ripgrep vim-tiny && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ARG DEBUG_EXECUTABLE=build/debug/src/cpp-tool
COPY --chmod=755 ${DEBUG_EXECUTABLE} /app/cpp-tool
COPY image/entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
