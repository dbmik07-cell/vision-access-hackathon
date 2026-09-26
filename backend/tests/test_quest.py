"""QUEST+ engine and trace runner behaviour tiny-hand-computed does not reach (contract section 5)."""

import copy

import pytest

from quest import ENGINE_STOP, QuestPlus, run_trace
from tests.golden_cases import EXAMPLES_DIR, read_json


def tiny_trace():
    return read_json(EXAMPLES_DIR / "quest" / "tiny-hand-computed" / "trace.json")


def tiny_engine(contract, stimuli=(0.25, 0.75), **overrides):
    spec = {**tiny_trace()["engine"], **overrides}
    return QuestPlus(contract.resolve_engine(spec), list(stimuli))


def test_tied_candidates_go_to_the_lowest_position_in_the_admissible_list(contract):
    engine = tiny_engine(contract, stimuli=(0.75, 0.75, 0.25))
    choice = engine.choose([1, 0, 2])
    assert choice.index == 1
    assert len(choice.expected_entropy) == 3


def test_choice_is_restricted_to_the_admissible_indices(contract):
    engine = tiny_engine(contract)
    assert engine.choose([0]).index == 0


def test_no_stop_before_min_trials_even_below_the_sd_target(contract):
    engine = tiny_engine(contract, minTrials=2, stopSd=10)
    engine.update(0, True)
    assert not engine.should_stop()
    engine.update(0, True)
    assert engine.should_stop()
    assert "maxTrialsReached" not in engine.result().flags


def test_stop_at_max_trials_without_the_sd_target_sets_max_trials_reached(contract):
    engine = tiny_engine(contract, minTrials=1, maxTrials=2, stopSd=0)
    engine.update(0, True)
    assert not engine.should_stop()
    engine.update(1, False)
    assert engine.should_stop()
    result = engine.result()
    assert result.trials == 2
    assert result.flags == ("wideInterval", "maxTrialsReached")


def test_narrow_interval_is_reliable_without_flags(contract):
    engine = tiny_engine(contract, reliableMaxCiWidth=1.0)
    engine.update(1, True)
    result = engine.result()
    assert (result.reliability, result.flags) == ("reliable", ())


def test_marginal_sums_to_one_after_updates(contract):
    engine = tiny_engine(contract)
    for index, correct in [(0, True), (1, False), (1, True)]:
        engine.update(index, correct)
    assert sum(engine.summary().threshold_marginal) == pytest.approx(1, abs=1e-12)


def test_engine_stop_ends_the_trace(contract):
    trace = tiny_trace()
    trace["engine"].update(minTrials=1, stopSd=10)
    trace["observer"]["responses"] = [True, True, True]
    result = run_trace(trace, contract=contract)
    assert [step["stop"] for step in result["steps"]] == [True]
    assert result["final"]["endedBy"] == ENGINE_STOP


def test_deterministic_threshold_observer_inverts_the_listed_trials(contract):
    trace = tiny_trace()
    trace["engine"].update(minTrials=4, maxTrials=4)
    trace["observer"] = {"type": "deterministicThreshold", "thresholdX": 0.5, "invertTrials": [2]}
    steps = run_trace(trace, contract=contract)["steps"]
    assert [step["correct"] for step in steps] == [
        (step["stimulus"] >= 0.5) != (step["trial"] == 2) for step in steps
    ]
    assert len(steps) == 4


def test_unknown_observer_type_is_an_error(contract):
    trace = tiny_trace()
    trace["observer"] = {"type": "random"}
    with pytest.raises(ValueError, match="observer"):
        run_trace(trace, contract=contract)


def test_non_uniform_prior_is_an_error(contract):
    with pytest.raises(ValueError, match="prior"):
        tiny_engine(contract, prior="gaussian")


def test_run_trace_does_not_modify_its_input(contract):
    trace = tiny_trace()
    before = copy.deepcopy(trace)
    run_trace(trace, contract=contract)
    assert trace == before


def test_run_trace_loads_the_contract_when_not_given(contract):
    assert run_trace(tiny_trace()) == run_trace(tiny_trace(), contract=contract)
