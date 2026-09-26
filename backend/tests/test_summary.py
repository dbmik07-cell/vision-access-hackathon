"""normalVision rules the summary/ goldens do not reach: the Amsler block (contract section 8)."""

import copy

import pytest

from adaptation import derive_summary
from tests.golden_cases import EXAMPLES_DIR, read_json

CLEAN_EYE = {"distortedAreaDeg2": 0, "missingAreaDeg2": 0, "centralInvolved": False}


@pytest.fixture(scope="module")
def normal_profile():
    """The normal-vision-true golden input: normal vision with no optional block."""
    return read_json(EXAMPLES_DIR / "summary" / "normal-vision-true" / "input.json")


def with_amsler(profile, right):
    profile = copy.deepcopy(profile)
    profile["amsler"] = {"source": "preset", "right": right, "left": dict(CLEAN_EYE)}
    return profile


def test_clean_amsler_does_not_block_normal_vision(contract, normal_profile):
    assert derive_summary(contract, with_amsler(normal_profile, dict(CLEAN_EYE)))["normalVision"] is True


@pytest.mark.parametrize(
    "problem",
    [{"distortedAreaDeg2": 1}, {"missingAreaDeg2": 1}, {"centralInvolved": True}],
)
def test_amsler_problem_blocks_normal_vision(contract, normal_profile, problem):
    profile = with_amsler(normal_profile, {**CLEAN_EYE, **problem})
    summary = derive_summary(contract, profile)
    contract.validate_profile({**profile, "summary": summary})
    assert summary["normalVision"] is False
