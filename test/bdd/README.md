# BDD Test Suite

pytest-bdd scenarios for this CLI tool live in `docs/verification/acceptance/`, derived from the
acceptance criteria of the _Capability Specifications_ in `docs/requirements/capabilities/`. Each
`CAP-NNN_<name>.feature` has its step definitions in `test_<name>.py`; shared fixtures live in
`conftest.py`. The steps drive the built binary at the `binary` fixture via `subprocess.run`
(standard library — no extra dependency). Unlike a service, there is no process to start or stop:
each scenario invokes the binary once.
