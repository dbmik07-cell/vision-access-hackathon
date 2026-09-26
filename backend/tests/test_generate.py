"""Generate mode: candidate outputs for the pending acuity traces (issue #12)."""

import copy
import json

import pytest

from contract.loader import SHARED_DIR
from quest.generate import (
    DEFAULT_OUTPUT_DIR,
    PLAUSIBILITY_CHECKS,
    GenerateRefused,
    generate,
    plausibility_checks,
    write_candidates,
)
from tests.golden_cases import EXAMPLES_DIR, read_json

MAX_TRIALS_STOPS_EARLY = pytest.mark.xfail(
    strict=True,
    reason="stops at n = 18 by the SD rule: the inversions need review with Rocco before freezing (#12)",
)


def read_trace(name):
    return read_json(EXAMPLES_DIR / "quest" / name / "trace.json")


def candidate(contract, name):
    return generate(contract, {name: read_trace(name)}, read_trace("tiny-hand-computed"))[0]


def test_generate_refuses_when_tiny_hand_computed_does_not_pass(contract):
    tiny = read_trace("tiny-hand-computed")
    tiny["expected"]["steps"][0]["stimulusIndex"] = 0
    with pytest.raises(GenerateRefused, match="tiny-hand-computed"):
        generate(contract, {"acuity-reaches-sd": read_trace("acuity-reaches-sd")}, tiny)


def test_generate_refuses_a_trace_without_plausibility_checks(contract):
    with pytest.raises(ValueError, match="plausibility"):
        generate(contract, {"contrast-reaches-sd": read_trace("contrast-reaches-sd")}, read_trace("tiny-hand-computed"))


@pytest.mark.parametrize(
    "name",
    [
        "acuity-reaches-sd",
        pytest.param("acuity-max-trials", marks=MAX_TRIALS_STOPS_EARLY),
    ],
)
def test_pending_trace_candidate_passes_its_plausibility_checks(contract, name):
    result = candidate(contract, name)
    assert [check.description for check in result.checks if not check.passed] == []


@pytest.mark.parametrize("name", sorted(PLAUSIBILITY_CHECKS))
def test_candidate_acuity_block_validates_against_the_profile_schema(contract, name):
    block = candidate(contract, name).acuity_block
    profile = read_json(EXAMPLES_DIR / "rules" / "mild-acuity" / "profile.json")
    contract.validate_profile({**profile, "acuity": block})
    assert block["displayLimitLogMAR"] == min(
        contract.resolve_stimuli(read_trace(name)["stimuli"])[i] for i in read_trace(name)["admissibleIndices"]
    )


def test_checks_catch_a_run_that_stopped_at_max_trials(contract):
    trace = read_trace("acuity-reaches-sd")
    output = copy.deepcopy(candidate(contract, "acuity-reaches-sd").output)
    output["final"]["flags"] = ["maxTrialsReached"]
    failed = [check for check in plausibility_checks(contract, "acuity-reaches-sd", trace, output) if not check.passed]
    assert failed


def test_checks_catch_reliability_not_decided_by_width(contract):
    trace = read_trace("acuity-max-trials")
    output = copy.deepcopy(candidate(contract, "acuity-max-trials").output)
    output["final"]["reliability"] = "doubtful"
    failed = [check for check in plausibility_checks(contract, "acuity-max-trials", trace, output) if not check.passed]
    assert failed


def test_candidates_are_written_as_json_outside_shared(contract, tmp_path):
    result = candidate(contract, "acuity-reaches-sd")
    paths = write_candidates([result], tmp_path)
    written = json.loads(paths[0].read_text(encoding="utf-8"))
    assert written["trace"] == "acuity-reaches-sd"
    assert written["steps"] == result.output["steps"]
    assert written["final"] == result.output["final"]
    assert written["acuityBlock"] == result.acuity_block
    assert all(check["passed"] for check in written["checks"])
    assert SHARED_DIR.resolve() not in DEFAULT_OUTPUT_DIR.resolve().parents
