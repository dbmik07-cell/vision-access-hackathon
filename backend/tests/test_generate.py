"""Generate mode: candidate outputs for the pending QUEST+ traces (issues #12, #13)."""

import copy
import json

import pytest

from contract import compare
from contract.loader import SHARED_DIR
from quest.generate import (
    DEFAULT_OUTPUT_DIR,
    GenerateRefused,
    generate,
    plausibility_checks,
    write_candidates,
)
from tests.golden_cases import EXAMPLES_DIR, read_json
from tests.test_acuity import with_acuity
from tests.test_contrast import UNCAPPED_ACUITY_UPPER, with_contrast


def read_trace(name):
    return read_json(EXAMPLES_DIR / "quest" / name / "trace.json")


def candidate(contract, name):
    tiny = read_trace("tiny-hand-computed")
    return generate(contract, {name: read_trace(name)}, tiny, acuity_ci95_upper_logmar=UNCAPPED_ACUITY_UPPER)[0]


def failed_checks(contract, name, output, block):
    checks = plausibility_checks(contract, name, read_trace(name), output, block)
    return [check.description for check in checks if not check.passed]


def test_generate_refuses_when_tiny_hand_computed_does_not_pass(contract):
    tiny = read_trace("tiny-hand-computed")
    tiny["expected"]["steps"][0]["stimulusIndex"] = 0
    with pytest.raises(GenerateRefused, match="tiny-hand-computed"):
        generate(contract, {"acuity-reaches-sd": read_trace("acuity-reaches-sd")}, tiny)


def test_generate_refuses_when_tiny_hand_computed_is_not_final(contract):
    tiny = read_trace("tiny-hand-computed")
    tiny["expected"]["status"] = "pending"
    with pytest.raises(GenerateRefused, match="tiny-hand-computed"):
        generate(contract, {"acuity-reaches-sd": read_trace("acuity-reaches-sd")}, tiny)


def test_generate_refuses_a_trace_without_plausibility_checks(contract):
    with pytest.raises(ValueError, match="plausibility"):
        generate(contract, {"unknown": read_trace("acuity-reaches-sd")}, read_trace("tiny-hand-computed"))


def test_generate_needs_the_acuity_upper_bound_for_a_contrast_trace(contract):
    with pytest.raises(ValueError, match="acuity"):
        generate(contract, {"contrast-reaches-sd": read_trace("contrast-reaches-sd")}, read_trace("tiny-hand-computed"))


@pytest.mark.parametrize("name", ["acuity-reaches-sd", "contrast-reaches-sd"])
def test_reaches_sd_candidate_passes_its_plausibility_checks(contract, name):
    assert [check.description for check in candidate(contract, name).checks if not check.passed] == []


def test_acuity_max_trials_candidate_reaches_max_trials(contract):
    assert candidate(contract, "acuity-max-trials").checks[0].passed


def test_acuity_max_trials_candidate_reliability_depends_only_on_width(contract):
    assert candidate(contract, "acuity-max-trials").checks[1].passed


@pytest.mark.parametrize("name", ["acuity-reaches-sd", "acuity-max-trials"])
def test_candidate_acuity_block_validates_against_the_profile_schema(contract, name):
    block = candidate(contract, name).profile_block
    contract.validate_profile(with_acuity(block))
    trace = read_trace(name)
    display_limit = min(contract.resolve_stimuli(trace["stimuli"])[i] for i in trace["admissibleIndices"])
    assert compare(block["displayLimitLogMAR"], display_limit, contract.tolerances) == []


def test_candidate_contrast_block_is_published_in_logcs(contract):
    result = candidate(contract, "contrast-reaches-sd")
    block, final = result.profile_block, result.output["final"]
    contract.validate_profile(with_contrast(block))
    trace = read_trace("contrast-reaches-sd")
    hardest = min(contract.resolve_stimuli(trace["stimuli"])[i] for i in trace["admissibleIndices"])
    expected = {"logCS": -final["estimate"], "ci95": [-final["ci95"][1], -final["ci95"][0]], "ceilingLogCS": -hardest}
    assert compare({key: block[key] for key in expected}, expected, contract.tolerances) == []


def test_checks_catch_a_run_that_stopped_at_max_trials(contract):
    result = candidate(contract, "acuity-reaches-sd")
    output = copy.deepcopy(result.output)
    output["final"]["flags"] = ["maxTrialsReached"]
    assert failed_checks(contract, "acuity-reaches-sd", output, result.profile_block)


def test_checks_catch_reliability_not_decided_by_width(contract):
    result = candidate(contract, "acuity-max-trials")
    output = copy.deepcopy(result.output)
    output["final"]["reliability"] = "doubtful"
    assert failed_checks(contract, "acuity-max-trials", output, result.profile_block)


@pytest.mark.parametrize(
    "tamper",
    [
        pytest.param({"logCS": 0.48}, id="inverted-sign"),
        pytest.param("engine-space-ci95", id="engine-space-ci95"),
        pytest.param({"censoredAtCeiling": True}, id="censored"),
    ],
)
def test_contrast_checks_catch_a_wrong_published_block(contract, tamper):
    result = candidate(contract, "contrast-reaches-sd")
    if tamper == "engine-space-ci95":
        tamper = {"ci95": result.output["final"]["ci95"]}
    assert failed_checks(contract, "contrast-reaches-sd", result.output, {**result.profile_block, **tamper})


def test_candidates_are_written_as_json_outside_shared(contract, tmp_path):
    result = candidate(contract, "acuity-reaches-sd")
    paths = write_candidates([result], tmp_path)
    written = json.loads(paths[0].read_text(encoding="utf-8"))
    assert written["trace"] == "acuity-reaches-sd"
    assert compare(written["steps"], result.output["steps"], contract.tolerances) == []
    assert compare(written["final"], result.output["final"], contract.tolerances) == []
    assert compare(written["profileBlock"], result.profile_block, contract.tolerances) == []
    assert all(check["passed"] for check in written["checks"])
    assert SHARED_DIR.resolve() not in DEFAULT_OUTPUT_DIR.resolve().parents
