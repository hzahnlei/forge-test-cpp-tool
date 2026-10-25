#include "greeter.hpp"

#include <format>

namespace cpp_tool {

	auto greet(std::string_view name) -> std::string { return std::format("Hello, {}!", name); }

} // namespace cpp_tool
