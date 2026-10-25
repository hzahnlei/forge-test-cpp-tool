# greeter: internal library — holds domain logic, independently testable.
add_library(greeter STATIC greeter.cpp)
target_include_directories(greeter PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(greeter PUBLIC project_warnings)

# Main executable
add_executable(cpp-tool main.cpp)
target_link_libraries(cpp-tool PRIVATE greeter CLI11::CLI11 project_warnings)
target_compile_definitions(cpp-tool PRIVATE
    PROJECT_VERSION="${PROJECT_VERSION}"
)

install(TARGETS cpp-tool DESTINATION bin)
