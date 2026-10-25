Feature: Greeting

  Scenario: AC 1 greeting a named user
    Given a name "Ada"
    When I run the CLI with that name
    Then it prints a greeting for "Ada"
