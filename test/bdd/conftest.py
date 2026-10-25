"""Shared fixtures of the pytest-bdd step modules (test_*.py).
make bdd-test builds the CLI binary first and exports its path via BDD_BINARY — unlike a service,
there is no running process to wait for, only a build to verify happened.
"""

import os

import pytest


@pytest.fixture
def binary():
    path = os.environ.get("BDD_BINARY")
    if not path:
        raise RuntimeError("BDD_BINARY is not set — run this via `make bdd-test`")
    if not os.path.isfile(path):
        raise RuntimeError(f"BDD_BINARY={path} does not exist — build it first")
    return path
