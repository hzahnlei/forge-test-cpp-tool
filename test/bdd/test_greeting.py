"""pytest-bdd steps of CAP-001_greeting.feature; the `binary` fixture lives in conftest.py."""

import subprocess

from pytest_bdd import given, parsers, scenarios, then, when

scenarios("CAP-001_greeting.feature")


@given(parsers.parse('a name "{name}"'), target_fixture="name")
def set_name(name):
    return name


@when("I run the CLI with that name", target_fixture="result")
def run_cli(binary, name):
    return subprocess.run(
        [binary, "--name", name],
        capture_output=True,
        text=True,
        timeout=5,
        check=False,
    )


@then(parsers.parse('it prints a greeting for "{name}"'))
def assert_greeting(result, name):
    assert result.returncode == 0, result.stderr
    assert f"Hello, {name}!" in result.stdout, result.stdout
