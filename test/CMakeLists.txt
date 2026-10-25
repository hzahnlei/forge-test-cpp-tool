add_executable(greeter_test greeter_test.cpp)
target_link_libraries(greeter_test PRIVATE greeter Catch2::Catch2WithMain project_warnings)

include(Catch)
# PRE_TEST: discover tests when ctest runs, not at build time.
# This avoids failures when the test binary cannot run during the build phase
# (e.g. cross-compilation, Apple Silicon with mismatched architecture).
# Integrative tests ([it]) need real infrastructure and run apart from `make test`.
catch_discover_tests(greeter_test DISCOVERY_MODE PRE_TEST TEST_SPEC "~[it]")
