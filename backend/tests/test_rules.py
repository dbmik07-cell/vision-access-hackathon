"""Rules R0-R8 behaviour the rules/ goldens do not reach directly (contract section 9)."""

import copy

import pytest

from adaptation import UnsupportedProfileError, build_plan
from contract import compare
from tests.golden_cases import EXAMPLES_DIR, read_json


def golden(case, name):
    return read_json(EXAMPLES_DIR / "rules" / case / name)


@pytest.mark.parametrize(("case", "block"), [("doubtful-acuity", "acuity"), ("doubtful-contrast", "contrast")])
def test_unreliable_shifts_like_doubtful(contract, case, block):
    profile = golden(case, "profile.json")
    profile[block]["reliability"] = "unreliable"
    plan = build_plan(profile, golden(case, "context.json"), contract=contract)
    assert compare(plan, golden(case, "expected-plan.json"), contract.tolerances) == []


@pytest.mark.parametrize("case", ["central-loss", "tunnel-vision", "low-contrast-photophobia"])
def test_optional_preset_blocks_are_not_yet_supported(contract, case):
    with pytest.raises(UnsupportedProfileError, match="not yet supported"):
        build_plan(golden(case, "profile.json"), golden(case, "context.json"), contract=contract)


def test_reading_block_is_not_yet_supported(contract):
    profile = {**golden("mild-acuity", "profile.json"), "reading": {"source": "preset"}}
    contract.validate_profile(profile)
    with pytest.raises(UnsupportedProfileError, match="reading"):
        build_plan(profile, golden("mild-acuity", "context.json"), contract=contract)


def test_context_must_use_the_contract_reference_distance(contract):
    context = golden("mild-acuity", "context.json")
    context["referenceDistanceMm"] = context["referenceDistanceMm"] + 1
    with pytest.raises(ValueError, match="referenceDistanceMm"):
        build_plan(golden("mild-acuity", "profile.json"), context, contract=contract)


def test_build_plan_does_not_modify_its_inputs(contract):
    profile, context = golden("user-offset", "profile.json"), golden("user-offset", "context.json")
    before = copy.deepcopy((profile, context))
    build_plan(profile, context, contract=contract)
    assert (profile, context) == before


def test_build_plan_loads_the_contract_when_not_given(contract):
    profile, context = golden("mild-acuity", "profile.json"), golden("mild-acuity", "context.json")
    assert build_plan(profile, context) == build_plan(profile, context, contract=contract)
