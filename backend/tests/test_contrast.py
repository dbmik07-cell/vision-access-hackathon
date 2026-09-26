"""The measured contrast block of the VisualProfile (contract sections 5, 6 and 8)."""

import pytest

from contract import compare
from contrast import measured_block
from quest.engine import Result
from tests.golden_cases import EXAMPLES_DIR, read_json

# Acuity ci95 upper bounds either side of the 8 degree letter cap (geometry/contrast-letter-size).
UNCAPPED_ACUITY_UPPER = 0.6
CAPPED_ACUITY_UPPER = 1.5


def result(estimate=-1.52, ci95=(-1.70, -1.38), reliability="doubtful", flags=("wideInterval",), trials=3):
    """An engine result in the ease variable x = log10(C_Weber)."""
    return Result(trials=trials, estimate=estimate, ci95=ci95, reliability=reliability, flags=flags)


def with_contrast(block):
    """A full golden profile with its contrast block replaced, for schema validation."""
    profile = read_json(EXAMPLES_DIR / "rules" / "mild-acuity" / "profile.json")
    return {**profile, "contrast": block}


def block_for(contract, engine_result=None, hardest=(-2.04, -2.04, -2.04), acuity_upper=UNCAPPED_ACUITY_UPPER):
    return measured_block(contract, engine_result or result(), list(hardest), acuity_upper)


def test_block_publishes_logcs_with_swapped_ci95_and_validates(contract):
    block = block_for(contract)
    contract.validate_profile(with_contrast(block))
    expected = {
        "source": "measured",
        "logCS": 1.52,
        "ci95": [1.38, 1.70],
        "reliability": "doubtful",
        "flags": ["wideInterval"],
        "band": "borderline",
        "trials": 3,
        "ceilingLogCS": 2.04,
        "censoredAtCeiling": False,
    }
    assert compare(block, expected, contract.tolerances) == []


def test_band_comes_from_the_published_median(contract):
    block = block_for(contract, result(estimate=-1.65, ci95=(-1.8, -1.4)))
    assert block["band"] == "normal"


def test_ceiling_is_the_highest_admissible_logcs_over_trials(contract):
    block = block_for(contract, hardest=(-1.8, -2.0, -1.9))
    assert compare(block["ceilingLogCS"], 2.0, contract.tolerances) == []


def test_logcs_above_the_ceiling_is_censored(contract):
    block = block_for(contract, result(estimate=-1.9, ci95=(-2.0, -1.7)), hardest=(-1.8, -1.8, -1.8))
    assert block["censoredAtCeiling"] is True


def test_logcs_at_the_ceiling_is_not_censored(contract):
    block = block_for(contract, result(estimate=-1.8, ci95=(-2.0, -1.7)), hardest=(-1.8, -1.8, -1.8))
    assert block["censoredAtCeiling"] is False


def test_capped_letter_size_adds_the_flag_after_the_engine_flags(contract):
    block = block_for(contract, acuity_upper=CAPPED_ACUITY_UPPER)
    contract.validate_profile(with_contrast(block))
    assert block["flags"] == ["wideInterval", "contrastLetterSizeCapped"]


def test_uncapped_letter_size_adds_no_flag(contract):
    block = block_for(contract, result(reliability="reliable", flags=()))
    assert block["flags"] == []


def test_the_engine_result_is_not_modified(contract):
    engine_result = result()
    block_for(contract, engine_result, acuity_upper=CAPPED_ACUITY_UPPER)
    assert engine_result == result()


def test_one_hardest_stimulus_per_trial_is_required(contract):
    with pytest.raises(ValueError, match="trial"):
        block_for(contract, hardest=(-2.04, -2.04))
