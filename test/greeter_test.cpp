#include "greeter.hpp"

#include <catch2/catch_test_macros.hpp>

namespace cpp_tool {

SCENARIO("Greeter produces a greeting message") {
        GIVEN("a name") {
                WHEN("the default name is used") {
                        THEN("the greeting addresses the world") {
                                REQUIRE(greet("World") == "Hello, World!");
                        }
                }
                WHEN("a custom name is provided") {
                        THEN("the greeting addresses that name") {
                                REQUIRE(greet("Alice") == "Hello, Alice!");
                        }
                }
        }
}

} // namespace cpp-tool
