cmake_minimum_required(VERSION 3.28...4.2)
project(cpp-tool
    VERSION 0.1.0
    DESCRIPTION "C++ CLI Tool example."
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

option(ENABLE_SANITIZERS "Enable AddressSanitizer and UBSanitizer (Debug only)" OFF)

# Conan 2 installs packages into the build folder; extend the search path accordingly.
list(APPEND CMAKE_PREFIX_PATH "${CMAKE_BINARY_DIR}")

find_package(CLI11 REQUIRED)

# Interface target: compiler warnings and sanitizers applied to all targets via target_link_libraries.
# -Werror is intentionally omitted from Release to avoid build failures on newer compiler warnings.
add_library(project_warnings INTERFACE)
target_compile_options(project_warnings INTERFACE
    $<$<CXX_COMPILER_ID:Clang,GNU>:-Wall>
    $<$<CXX_COMPILER_ID:Clang,GNU>:-Wextra>
    $<$<CXX_COMPILER_ID:Clang,GNU>:-Wpedantic>
    $<$<AND:$<CXX_COMPILER_ID:Clang,GNU>,$<NOT:$<CONFIG:Release>>>:-Werror>
)
if(ENABLE_SANITIZERS)
    target_compile_options(project_warnings INTERFACE
        $<$<AND:$<CXX_COMPILER_ID:Clang,GNU>,$<CONFIG:Debug>>:-fsanitize=address,undefined>
    )
    target_link_options(project_warnings INTERFACE
        $<$<AND:$<CXX_COMPILER_ID:Clang,GNU>,$<CONFIG:Debug>>:-fsanitize=address,undefined>
    )
endif()

add_subdirectory(src)

include(CTest)
if(BUILD_TESTING)
    find_package(Catch2 REQUIRED)
    add_subdirectory(test)
endif()
