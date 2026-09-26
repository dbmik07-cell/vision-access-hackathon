"""Comparison helper (contract section 4), on small hand-made examples."""

import numpy as np
import pytest

from contract import compare


@pytest.fixture(scope="module")
def tol(contract):
    return contract.tolerances


def test_tolerances_come_from_the_parameters_file(contract, tol):
    assert tol.published_absolute == contract.param("tolerances", "publishedAbsolute")
    assert tol.intermediate_absolute == contract.param("tolerances", "intermediateAbsolute")
    assert tol.intermediate_relative == contract.param("tolerances", "intermediateRelative")


@pytest.mark.parametrize(
    "field", ["ci95", "logMAR", "logCS", "fontSizeCssPx", "minTextContrast", "minUIContrast"]
)
def test_published_fields_use_absolute_published_tolerance(tol, field):
    expected = {field: 12.0}
    assert compare({field: 12.0 + 0.5 * tol.published_absolute}, expected, tol) == []
    assert compare({field: 12.0 + 2 * tol.published_absolute}, expected, tol) != []


def test_published_tolerance_applies_inside_ci95_list(tol):
    expected = {"ci95": [0.3, 0.5]}
    assert compare({"ci95": [0.3, 0.5 - 0.5 * tol.published_absolute]}, expected, tol) == []
    mismatches = compare({"ci95": [0.3, 0.5 - 2 * tol.published_absolute]}, expected, tol)
    assert len(mismatches) == 1 and "ci95[1]" in mismatches[0]


def test_published_tolerance_applies_to_nested_published_field(tol):
    expected = {"text": {"fontSizeCssPx": 20.0}}
    assert compare({"text": {"fontSizeCssPx": 20.0 + 0.5 * tol.published_absolute}}, expected, tol) == []


def test_other_floats_use_intermediate_tolerance(tol):
    b = 1000.0
    limit = tol.intermediate_absolute + tol.intermediate_relative * abs(b)
    assert compare({"mean": b + 0.5 * limit}, {"mean": b}, tol) == []
    assert compare({"mean": b + 2 * limit}, {"mean": b}, tol) != []


def test_intermediate_tolerance_is_relative_to_expected(tol):
    # Near zero only the absolute part is left.
    b = 0.0
    assert compare({"sd": 0.5 * tol.intermediate_absolute}, {"sd": b}, tol) == []
    assert compare({"sd": 2 * tol.intermediate_absolute}, {"sd": b}, tol) != []


def test_float_that_passes_published_tolerance_fails_elsewhere(tol):
    # A difference allowed on a published output is too large for an intermediate value.
    delta = 0.5 * tol.published_absolute
    assert compare({"logMAR": 0.5 + delta}, {"logMAR": 0.5}, tol) == []
    assert compare({"median": 0.5 + delta}, {"median": 0.5}, tol) != []


def test_integers_and_floats_compare_as_numbers(tol):
    assert compare({"letterSizeDeg": [3.0]}, {"letterSizeDeg": [3]}, tol) == []


@pytest.mark.parametrize(
    ("actual", "expected"),
    [
        ({"reliability": "doubtful"}, {"reliability": "reliable"}),
        ({"stop": False}, {"stop": True}),
        ({"stimulusIndex": 2}, {"stimulusIndex": 1}),
        ({"trials": 13}, {"trials": 12}),
        ({"background": None}, {"background": "#121212"}),
        ({"background": "#121212"}, {"background": None}),
        ({"admissibleIndices": [14, 16]}, {"admissibleIndices": [14, 15]}),
    ],
)
def test_discrete_fields_are_exact(tol, actual, expected):
    assert compare(actual, expected, tol) != []


@pytest.mark.parametrize(
    ("actual", "expected"),
    [
        ({"trials": 12.0}, {"trials": 12}),
        ({"stimulusIndex": 1.0000000001}, {"stimulusIndex": 1}),
        ({"admissibleIndices": [14.0, 15]}, {"admissibleIndices": [14, 15]}),
        ({"trials": True}, {"trials": 1}),
    ],
)
def test_index_and_count_fields_must_be_exact_integers(tol, actual, expected):
    assert compare(actual, expected, tol) != []


def test_boolean_is_not_a_number(tol):
    assert compare({"stop": 1}, {"stop": True}, tol) != []
    assert compare({"stop": 0}, {"stop": False}, tol) != []


def test_numpy_values_compare_like_python_values(tol):
    actual = {"stop": np.bool_(True), "trials": np.int64(12), "marginal": np.array([0.25, 0.75])}
    expected = {"stop": True, "trials": 12, "marginal": [0.25, 0.75]}
    assert compare(actual, expected, tol) == []


def test_equal_discrete_fields_match(tol):
    value = {"reliability": "reliable", "stop": False, "trials": 12, "flags": [], "x": None}
    assert compare(value, dict(value), tol) == []


def test_structure_is_exact(tol):
    assert compare({"a": 1, "b": 2}, {"a": 1}, tol) != []
    assert compare({"a": 1}, {"a": 1, "b": 2}, tol) != []
    assert compare({"ci95": [0.3]}, {"ci95": [0.3, 0.5]}, tol) != []
    assert compare({"a": [1]}, {"a": {"0": 1}}, tol) != []


def test_mismatches_name_the_path(tol):
    mismatches = compare({"text": {"lineHeight": 2}}, {"text": {"lineHeight": 1.5}}, tol)
    assert mismatches and mismatches[0].startswith("$.text.lineHeight")
