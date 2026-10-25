#include "greeter.hpp"

#include <CLI/CLI.hpp>
#include <iostream>
#include <string>

// PROJECT_VERSION is injected at compile time via CMakeLists.txt.
#ifndef PROJECT_VERSION
#define PROJECT_VERSION "0.0.0"
#endif

auto main(int argc, char **argv) -> int {
	CLI::App app{"C++ CLI Tool example.", "cpp-tool"};
	app.set_version_flag("--version", PROJECT_VERSION);

	std::string name{"World"};
	app.add_option("-n,--name", name, "Optionally: Your name.");

	CLI11_PARSE(app, argc, argv);

	std::cout << cpp_tool::greet(name) << "\n";
	return 0;
}
