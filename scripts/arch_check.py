#!/usr/bin/env python3
# Enforces Clean Architecture layer dependencies by scanning #include directives.
#
# Dependency rule (inward only): app -> infra -> usecase -> domain
# A file in a lower-level layer must not include headers from a higher-level layer.

import os
import re
import sys

# Layer order: lower index = inner layer (fewer dependencies allowed)
LAYERS = ["domain", "usecase", "infra", "app"]
LAYER_RANK = {layer: i for i, layer in enumerate(LAYERS)}

SRC_ROOT = os.path.join(os.path.dirname(__file__), "..", "src")
INCLUDE_PATTERN = re.compile(r'#include\s+"([^"]+)"')
VIOLATIONS = []


def layer_of(path: str) -> str | None:
    """Return the Clean Architecture layer name for a source file path, or None."""
    parts = os.path.normpath(path).split(os.sep)
    for layer in LAYERS:
        if layer in parts:
            return layer
    return None


def check_file(filepath: str, file_layer: str) -> None:
    with open(filepath, encoding="utf-8") as f:
        for lineno, line in enumerate(f, 1):
            match = INCLUDE_PATTERN.search(line)
            if not match:
                continue
            include = match.group(1)
            # Determine if the include path references a known layer directory
            include_layer = next(
                (layer for layer in LAYERS if include.startswith(f"{layer}/")),
                None,
            )
            if include_layer is None:
                continue
            if LAYER_RANK[include_layer] > LAYER_RANK[file_layer]:
                VIOLATIONS.append(
                    f"{filepath}:{lineno}: '{file_layer}' must not include from '{include_layer}' ({include})"
                )


def main() -> int:
    if not os.path.isdir(SRC_ROOT):
        print(f"arch_check.py: src/ directory not found at {SRC_ROOT} — nothing to check.")
        return 0

    checked = 0
    for dirpath, _, filenames in os.walk(SRC_ROOT):
        for filename in filenames:
            if not (filename.endswith(".cpp") or filename.endswith(".h") or filename.endswith(".hpp")):
                continue
            filepath = os.path.join(dirpath, filename)
            file_layer = layer_of(filepath)
            if file_layer is None:
                continue
            check_file(filepath, file_layer)
            checked += 1

    if VIOLATIONS:
        print("Architecture violations found:")
        for v in VIOLATIONS:
            print(f"  {v}")
        return 1

    print(f"arch_check.py: {checked} file(s) checked — no violations.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
