"""Python/Swift comparison rules of docs/data-contracts.md section 4."""

from numbers import Integral, Real
from typing import Any

import numpy as np

from contract.loader import Tolerances

# Published outputs: |a - b| <= publishedAbsolute. Matched by field name, also inside lists.
PUBLISHED_FIELDS = frozenset(
    {"ci95", "logMAR", "logCS", "fontSizeCssPx", "minTextContrast", "minUIContrast"}
)


# Indices and counts: exact integers, even when an implementation computes them as floats.
INTEGER_FIELDS = frozenset({"stimulusIndex", "admissibleIndices", "trials", "minTrials", "maxTrials"})


def _is_number(value: Any) -> bool:
    return isinstance(value, Real) and not isinstance(value, bool)


def compare(actual: Any, expected: Any, tolerances: Tolerances) -> list[str]:
    """Every mismatch between actual and expected, as "<path>: <reason>"; empty if they match.

    Published floats use the absolute published tolerance, other floats the intermediate
    tolerance; discrete values (strings, booleans, null, integers, the index and count fields)
    and structure are exact.
    """
    mismatches: list[str] = []
    _compare(actual, expected, tolerances, "$", field=None, out=mismatches)
    return mismatches


def _compare(actual, expected, tol, path, field, out):
    """field: the nearest enclosing key, which list items inherit (e.g. ci95[1] -> "ci95")."""
    if isinstance(actual, np.generic):
        actual = actual.item()  # numpy scalars compare as the Python value they hold
    if isinstance(actual, np.ndarray):
        actual = actual.tolist()
    if isinstance(expected, dict):
        if not isinstance(actual, dict):
            out.append(f"{path}: expected an object, got {actual!r}")
            return
        for key in sorted(expected.keys() - actual.keys()):
            out.append(f"{path}.{key}: missing")
        for key in sorted(actual.keys() - expected.keys()):
            out.append(f"{path}.{key}: unexpected")
        for key in expected.keys() & actual.keys():
            _compare(actual[key], expected[key], tol, f"{path}.{key}", key, out)
    elif isinstance(expected, list):
        if not isinstance(actual, list):
            out.append(f"{path}: expected a list, got {actual!r}")
            return
        if len(actual) != len(expected):
            out.append(f"{path}: expected length {len(expected)}, got {len(actual)}")
            return
        for i, (a, b) in enumerate(zip(actual, expected)):
            _compare(a, b, tol, f"{path}[{i}]", field, out)
    elif field in INTEGER_FIELDS:
        if not (_is_number(actual) and isinstance(actual, Integral)) or actual != expected:
            out.append(f"{path}: expected the integer {expected!r}, got {actual!r}")
    elif _is_number(expected) and _is_number(actual):
        if isinstance(expected, Integral) and isinstance(actual, Integral):
            if actual != expected:
                out.append(f"{path}: expected {expected}, got {actual}")
            return
        diff = abs(float(actual) - float(expected))
        if field in PUBLISHED_FIELDS:
            limit = tol.published_absolute
        else:
            limit = tol.intermediate_absolute + tol.intermediate_relative * abs(float(expected))
        if not diff <= limit:
            out.append(f"{path}: expected {expected!r}, got {actual!r} (|diff| {diff:.3g} > {limit:.3g})")
    elif type(actual) is not type(expected) or actual != expected:
        out.append(f"{path}: expected {expected!r}, got {actual!r}")
