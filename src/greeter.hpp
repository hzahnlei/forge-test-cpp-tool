#pragma once

#include <string>
#include <string_view>

namespace cpp_tool {

	/// Returns a greeting message for the given name.
	[[nodiscard]] auto greet(std::string_view name) -> std::string;

} // namespace cpp_tool
