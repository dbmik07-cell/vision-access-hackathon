"""Generate mode: candidate outputs for the pending acuity traces (shared/examples/README.md).

Only after tiny-hand-computed passes, each pending trace is run and checked against the
manual-oracle plausibility checks of its README. Candidates are written to a backend-local
folder, never to shared/: freezing them is a shared PR with Rocco.

    cd backend; python -m quest.generate
"""

import json
import sys
from collections.abc import Callable, Iterable, Mapping
from dataclasses import dataclass
from pathlib import Path

import acuity
from contract import Contract, compare, load_contract
from quest.engine import Result
from quest.trace import ENGINE_STOP, run_trace

DEFAULT_OUTPUT_DIR = Path(__file__).resolve().parent / "output"
TINY = "tiny-hand-computed"

# quest/acuity-reaches-sd/README.md: the final median must fall in this range.
REACHES_SD_MEDIAN_RANGE = (0.46, 0.56)


class GenerateRefused(Exception):
    """tiny-hand-computed does not pass: no candidate may be proposed for freezing."""


@dataclass(frozen=True)
class Check:
    description: str
    passed: bool


@dataclass(frozen=True)
class Candidate:
    trace: str
    output: dict  # steps and final, in the golden format
    acuity_block: dict
    checks: tuple[Check, ...]

    @property
    def passed(self) -> bool:
        return all(check.passed for check in self.checks)


def _reliability_by_width(contract: Contract, trace: dict, final: dict) -> list[Check]:
    width_limit = contract.resolve_engine(trace["engine"]).reliable_max_ci_width
    low, high = final["ci95"]
    wide = high - low > width_limit
    return [
        Check(
            f"reliability from ci95 width only ({high - low:.4f} vs {width_limit}): "
            f"{final['reliability']}, flags {final['flags']}",
            final["reliability"] == ("doubtful" if wide else "reliable")
            and ("wideInterval" in final["flags"]) == wide,
        )
    ]


def _acuity_reaches_sd(contract: Contract, trace: dict, output: dict) -> list[Check]:
    engine = contract.resolve_engine(trace["engine"])
    final, last = output["final"], output["steps"][-1]
    low, high = final["ci95"]
    median_low, median_high = REACHES_SD_MEDIAN_RANGE
    threshold = trace["observer"]["thresholdX"]
    return [
        Check(
            f"median {final['estimate']:.4f} in [{median_low}, {median_high}]",
            median_low <= final["estimate"] <= median_high,
        ),
        Check(
            f"stops by the SD rule (sd {last['sd']:.4f} < {engine.stop_sd}) "
            f"with {engine.min_trials} <= n = {final['trials']} < {engine.max_trials}, no maxTrialsReached",
            final["endedBy"] == ENGINE_STOP
            and last["sd"] < engine.stop_sd
            and engine.min_trials <= final["trials"] < engine.max_trials
            and "maxTrialsReached" not in final["flags"],
        ),
        Check(f"ci95 [{low:.4f}, {high:.4f}] contains {threshold}", low <= threshold <= high),
        Check(
            f"ci95 width {high - low:.4f} <= {engine.reliable_max_ci_width}, reliable",
            high - low <= engine.reliable_max_ci_width and final["reliability"] == "reliable",
        ),
    ]


def _acuity_max_trials(contract: Contract, trace: dict, output: dict) -> list[Check]:
    engine = contract.resolve_engine(trace["engine"])
    final = output["final"]
    return [
        Check(
            f"reaches n = {engine.max_trials} with maxTrialsReached (got n = {final['trials']}, "
            f"endedBy {final['endedBy']}, flags {final['flags']})",
            final["trials"] == engine.max_trials and "maxTrialsReached" in final["flags"],
        ),
        *_reliability_by_width(contract, trace, final),
    ]


# One entry per pending acuity trace, from its README's manual oracle.
PLAUSIBILITY_CHECKS: dict[str, Callable[[Contract, dict, dict], list[Check]]] = {
    "acuity-reaches-sd": _acuity_reaches_sd,
    "acuity-max-trials": _acuity_max_trials,
}


def plausibility_checks(contract: Contract, name: str, trace: dict, output: dict) -> list[Check]:
    return PLAUSIBILITY_CHECKS[name](contract, trace, output)


def _check_tiny(contract: Contract, tiny: dict) -> None:
    expected = tiny["expected"]
    mismatches = compare(
        run_trace(tiny, contract=contract),
        {"steps": expected["steps"], "final": expected["final"]},
        contract.tolerances,
    )
    if expected["status"] != "final" or mismatches:
        raise GenerateRefused(f"{TINY} does not pass: " + ("; ".join(mismatches) or "not final"))


def _acuity_block(contract: Contract, trace: dict, final: dict) -> dict:
    """The admissible stimuli are constant over a trace, so every trial has the same display limit."""
    stimuli = contract.resolve_stimuli(trace["stimuli"])
    display_limit = min(stimuli[i] for i in trace["admissibleIndices"])
    result = Result(
        trials=final["trials"],
        estimate=final["estimate"],
        ci95=tuple(final["ci95"]),
        reliability=final["reliability"],
        flags=tuple(final["flags"]),
    )
    return acuity.measured_block(contract, result, [display_limit] * result.trials)


def generate(contract: Contract, traces: Mapping[str, dict], tiny: dict) -> list[Candidate]:
    """Candidates for the given traces (by case name); refuses unless tiny-hand-computed passes."""
    missing = sorted(traces.keys() - PLAUSIBILITY_CHECKS.keys())
    if missing:
        raise ValueError(f"no plausibility checks for {missing}")
    _check_tiny(contract, tiny)
    candidates = []
    for name, trace in traces.items():
        output = run_trace(trace, contract=contract)
        candidates.append(
            Candidate(
                trace=name,
                output=output,
                acuity_block=_acuity_block(contract, trace, output["final"]),
                checks=tuple(plausibility_checks(contract, name, trace, output)),
            )
        )
    return candidates


def write_candidates(candidates: Iterable[Candidate], output_dir: Path = DEFAULT_OUTPUT_DIR) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    for candidate in candidates:
        path = output_dir / f"{candidate.trace}.json"
        document = {
            "trace": candidate.trace,
            "checks": [{"description": c.description, "passed": c.passed} for c in candidate.checks],
            "acuityBlock": candidate.acuity_block,
            **candidate.output,
        }
        path.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
        paths.append(path)
    return paths


def _read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    """Generates and writes the candidates of every pending trace; exit 1 if any check fails."""
    contract = load_contract()
    examples_dir = contract.shared_dir / "examples" / "quest"
    traces = {}
    for name in PLAUSIBILITY_CHECKS:
        trace = _read_json(examples_dir / name / "trace.json")
        if trace["expected"]["status"] == "pending":
            traces[name] = trace
    candidates = generate(contract, traces, _read_json(examples_dir / TINY / "trace.json"))
    for candidate, path in zip(candidates, write_candidates(candidates)):
        print(f"{candidate.trace}: {'PASS' if candidate.passed else 'FAIL'} -> {path}")
        for check in candidate.checks:
            print(f"  [{'x' if check.passed else ' '}] {check.description}")
    return 0 if all(candidate.passed for candidate in candidates) else 1


if __name__ == "__main__":
    sys.exit(main())
