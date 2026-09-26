"""The measured acuity block of the VisualProfile (contract sections 6 and 8)."""

import pytest

from acuity import measured_block
from contract import compare
from quest import Result
from tests.golden_cases import EXAMPLES_DIR, read_json


def result(estimate=0.52, ci95=(0.42, 0.61), reliability="reliable", flags=(), trials=3):
    return Result(trials=trials, estimate=estimate, ci95=ci95, reliability=reliability, flags=flags)


def with_acuity(block):
    """A full golden profile with its acuity block replaced, for schema validation."""
    profile = read_json(EXAMPLES_DIR / "rules" / "mild-acuity" / "profile.json")
    return {**profile, "acuity": block}


def test_block_publishes_the_engine_result_and_validates(contract):
    block = measured_block(contract, result(), [-0.02, -0.02, -0.02])
    contract.validate_profile(with_acuity(block))
    expected = {
        "source": "measured",
        "logMAR": 0.52,
        "ci95": [0.42, 0.61],
        "reliability": "reliable",
        "flags": [],
        "whoCategory": "moderate",
        "trials": 3,
        "displayLimitLogMAR": -0.02,
        "censoredAtDisplayLimit": False,
    }
    assert compare(block, expected, contract.tolerances) == []


def test_flags_and_doubtful_reliability_are_carried_over(contract):
    engine_result = result(reliability="doubtful", flags=("wideInterval", "maxTrialsReached"))
    block = measured_block(contract, engine_result, [0.0, 0.0, 0.0])
    contract.validate_profile(with_acuity(block))
    assert (block["reliability"], block["flags"]) == ("doubtful", ["wideInterval", "maxTrialsReached"])


def test_who_category_comes_from_the_median_not_the_interval(contract):
    block = measured_block(contract, result(estimate=0.3, ci95=(0.1, 0.6)), [0.0, 0.0, 0.0])
    assert block["whoCategory"] == "none"


def test_display_limit_is_the_minimum_over_trials(contract):
    block = measured_block(contract, result(), [0.1, -0.04, 0.02])
    assert compare(block["displayLimitLogMAR"], -0.04, contract.tolerances) == []


def test_median_below_the_display_limit_is_censored(contract):
    block = measured_block(contract, result(estimate=-0.1, ci95=(-0.3, 0.0)), [0.0, -0.08, 0.0])
    assert block["censoredAtDisplayLimit"] is True


def test_median_at_the_display_limit_is_not_censored(contract):
    block = measured_block(contract, result(estimate=-0.08, ci95=(-0.3, 0.0)), [-0.08, -0.08, -0.08])
    assert block["censoredAtDisplayLimit"] is False


def test_one_display_limit_per_trial_is_required(contract):
    with pytest.raises(ValueError, match="trial"):
        measured_block(contract, result(trials=3), [0.0, 0.0])
