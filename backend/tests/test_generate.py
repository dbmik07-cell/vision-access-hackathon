"""Generate mode: candidate outputs for the pending acuity traces (issue #12)."""

import copy
import json

import pytest

from contract import compare
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
from tests.test_acuity import with_acuity

MAX_TRIALS_STOPS_EARLY = pytest.mark.xfail(
    strict=True,
    reason="stops at n = 18 by the SD rule: the inversions need review with Rocco before freezing (#12)",
)


def read_trace(name):
    return read_json(EXAMPLES_DIR / "quest" / name / "trace.json")


def candidate(contract, name):
    return generate(contract, {name: read_trace(name)}, read_trace("tiny-hand-computed"))[0]


def failed_checks(contract, name, output):
    return [c.description for c in plausibility_checks(contract, name, read_trace(name), output) if not c.passed]


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
        generate(contract, {"contrast-reaches-sd": read_trace("contrast-reaches-sd")}, read_trace("tiny-hand-computed"))


def test_acuity_reaches_sd_candidate_passes_its_plausibility_checks(contract):
    assert failed_checks(contract, "acuity-reaches-sd", candidate(contract, "acuity-reaches-sd").output) == []


@MAX_TRIALS_STOPS_EARLY
def test_acuity_max_trials_candidate_reaches_max_trials(contract):
    assert candidate(contract, "acuity-max-trials").checks[0].passed


def test_acuity_max_trials_candidate_reliability_depends_only_on_width(contract):
    assert candidate(contract, "acuity-max-trials").checks[1].passed


@pytest.mark.parametrize("name", sorted(PLAUSIBILITY_CHECKS))
def test_candidate_acuity_block_validates_against_the_profile_schema(contract, name):
    block = candidate(contract, name).acuity_block
    contract.validate_profile(with_acuity(block))
    trace = read_trace(name)
    display_limit = min(contract.resolve_stimuli(trace["stimuli"])[i] for i in trace["admissibleIndices"])
    assert compare(block["displayLimitLogMAR"], display_limit, contract.tolerances) == []


def test_checks_catch_a_run_that_stopped_at_max_trials(contract):
    output = copy.deepcopy(candidate(contract, "acuity-reaches-sd").output)
    output["final"]["flags"] = ["maxTrialsReached"]
    assert failed_checks(contract, "acuity-reaches-sd", output)


def test_checks_catch_reliability_not_decided_by_width(contract):
    output = copy.deepcopy(candidate(contract, "acuity-max-trials").output)
    output["final"]["reliability"] = "doubtful"
    assert failed_checks(contract, "acuity-max-trials", output)


def test_candidates_are_written_as_json_outside_shared(contract, tmp_path):
    result = candidate(contract, "acuity-reaches-sd")
    paths = write_candidates([result], tmp_path)
    written = json.loads(paths[0].read_text(encoding="utf-8"))
    assert written["trace"] == "acuity-reaches-sd"
    assert compare(written["steps"], result.output["steps"], contract.tolerances) == []
    assert compare(written["final"], result.output["final"], contract.tolerances) == []
    assert compare(written["acuityBlock"], result.acuity_block, contract.tolerances) == []
    assert all(check["passed"] for check in written["checks"])
    assert SHARED_DIR.resolve() not in DEFAULT_OUTPUT_DIR.resolve().parents
