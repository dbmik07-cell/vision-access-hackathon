"""Trace runner: drives the engine through a shared trace.json (shared/examples/README.md)."""

from collections.abc import Callable

from contract import Contract, load_contract
from quest.engine import QuestPlus

# endedBy values (shared/examples/README.md, agreed in issue #14).
ENGINE_STOP = "engineStop"
RESPONSES_EXHAUSTED = "responsesExhausted"

# (trial numbered from 1, chosen stimulus x) -> correct.
Observer = Callable[[int, float], bool]


def _observer(spec: dict) -> tuple[Observer, int | None]:
    """The observer and how many responses it has (None: it never runs out)."""
    if spec["type"] == "scripted":
        responses = list(spec["responses"])
        return (lambda trial, x: responses[trial - 1]), len(responses)
    if spec["type"] == "deterministicThreshold":
        threshold, inverted = spec["thresholdX"], frozenset(spec["invertTrials"])
        return (lambda trial, x: (x >= threshold) != (trial in inverted)), None
    raise ValueError(f"unknown observer type {spec['type']!r}")


def run_trace(trace: dict, contract: Contract | None = None) -> dict:
    """Per-step outputs and the final block in the golden format; engine-space values throughout.

    stimulusIndex indexes the full stimulus list; expectedEntropy follows the admissible-list order.
    """
    contract = contract or load_contract()
    stimuli = contract.resolve_stimuli(trace["stimuli"])
    engine = QuestPlus(contract.resolve_engine(trace["engine"]), stimuli)
    admissible = list(trace["admissibleIndices"])
    observer, response_count = _observer(trace["observer"])

    steps = []
    ended_by = ENGINE_STOP
    while not engine.should_stop():
        trial = engine.trials + 1
        if response_count is not None and trial > response_count:
            ended_by = RESPONSES_EXHAUSTED
            break
        choice = engine.choose(admissible)
        x = stimuli[choice.index]
        correct = observer(trial, x)
        engine.update(choice.index, correct)
        summary = engine.summary()
        steps.append(
            {
                "trial": trial,
                "expectedEntropy": list(choice.expected_entropy),
                "stimulusIndex": choice.index,
                "stimulus": x,
                "correct": correct,
                "thresholdMarginal": list(summary.threshold_marginal),
                "mean": summary.mean,
                "sd": summary.sd,
                "median": summary.median,
                "ci95": list(summary.ci95),
                "stop": engine.should_stop(),
            }
        )

    result = engine.result()
    return {
        "steps": steps,
        "final": {
            "trials": result.trials,
            "endedBy": ended_by,
            "estimate": result.estimate,
            "ci95": list(result.ci95),
            "reliability": result.reliability,
            "flags": list(result.flags),
        },
    }
