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


def test_visual_field_with_no_loss_in_either_eye_keeps_the_defaults(contract):
    profile = golden("tunnel-vision", "profile.json")
    for eye in ("right", "left"):
        profile["visualField"][eye]["pattern"] = "none"
    plan = build_plan(profile, golden("tunnel-vision", "context.json"), contract=contract)
    default_width = contract.param("rules", "maxLineWidthCh")["max"]
    assert compare(plan["layout"]["maxLineWidthCh"], default_width, contract.tolerances) == []
    assert plan["layout"]["moveEdgeElements"] is False


def test_line_length_uses_the_better_eye(contract):
    profile = golden("tunnel-vision-10deg", "profile.json")
    profile["visualField"]["left"] = {"fieldRadiusDeg": 5, "pattern": "tunnel"}
    plan = build_plan(profile, golden("tunnel-vision-10deg", "context.json"), contract=contract)
    expected = golden("tunnel-vision-10deg", "expected-plan.json")["layout"]["maxLineWidthCh"]
    assert compare(plan["layout"]["maxLineWidthCh"], expected, contract.tolerances) == []


def test_amsler_without_central_involvement_keeps_base_spacing(contract):
    profile = golden("central-loss", "profile.json")
    profile["amsler"]["right"]["centralInvolved"] = False
    plan = build_plan(profile, golden("central-loss", "context.json"), contract=contract)
    spacing = contract.param("rules", "spacingBase")
    assert compare({key: plan["text"][key] for key in spacing}, spacing, contract.tolerances) == []


def test_light_block_without_photophobia_or_preference_keeps_the_original_theme(contract):
    profile = golden("photophobia-no-preference", "profile.json")
    profile["light"]["photophobia"] = False
    plan = build_plan(profile, golden("photophobia-no-preference", "context.json"), contract=contract)
    assert plan["color"]["theme"] == "original"
    assert (plan["color"]["background"], plan["color"]["text"]) == (None, None)
    assert compare(plan["color"]["imageBrightness"], 1, contract.tolerances) == []
    assert plan["screen"]["brightness"] is None


def test_light_theme_is_not_yet_defined_in_the_contract(contract):
    profile = golden("low-contrast-photophobia", "profile.json")
    profile["light"]["preferredTheme"] = "light"
    contract.validate_profile(profile)
    with pytest.raises(NotImplementedError, match="light theme not yet defined in the contract"):
        build_plan(profile, golden("low-contrast-photophobia", "context.json"), contract=contract)


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
