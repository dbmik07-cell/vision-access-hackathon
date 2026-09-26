"""Generate mode: candidate outputs for the pending QUEST+ traces (shared/examples/README.md).

Only after tiny-hand-computed passes, each pending trace is run and checked against the
manual-oracle plausibility checks of its README. Candidates are written to a backend-local
folder, never to shared/: freezing them is a shared PR with Rocco. Each candidate also
carries the measured profile block its final result would publish.

    cd backend; python -m quest.generate
"""

import json
import sys
from collections.abc import Callable, Iterable, Mapping
from dataclasses import dataclass
from pathlib import Path

import acuity
import contrast
from contract import Contract, compare, load_contract
from quest.engine import Result
from quest.trace import ENGINE_STOP, run_trace

DEFAULT_OUTPUT_DIR = Path(__file__).resolve().parent / "output"
TINY_TRACE = "tiny-hand-computed"
LETTER_SIZE_ACUITY_TRACE = "acuity-reaches-sd"

# Manual-oracle ranges, copied from the README of each trace (not contract parameters).
# quest/acuity-reaches-sd: the final median must fall in this range.
REACHES_SD_MEDIAN_RANGE = (0.46, 0.56)
# quest/contrast-reaches-sd: the observer threshold (x = -1.51) lies between -1.52 and -1.50,
# so the published logCS must fall in this range.
CONTRAST_LOGCS_RANGE = (1.46, 1.56)


class GenerateRefused(Exception):
    """tiny-hand-computed does not pass: no candidate may be proposed for freezing."""


@dataclass(frozen=True)
class Check:
    description: str
    passed: bool


@dataclass(frozen=True)
class Candidate:
    trace: str
    output: dict  # steps and final, in the golden format (engine space)
    profile_block: dict  # the measured acuity or contrast block of the final result
    checks: tuple[Check, ...]

    @property
    def passed(self) -> bool:
        return all(check.passed for check in self.checks)


PlausibilityCheck = Callable[[Contract, dict, dict, dict], list[Check]]


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


def _stops_by_sd_rule(contract: Contract, trace: dict, output: dict) -> Check:
    engine = contract.resolve_engine(trace["engine"])
    final, last = output["final"], output["steps"][-1]
    return Check(
        f"stops by the SD rule (sd {last['sd']:.4f} < {engine.stop_sd}) "
        f"with {engine.min_trials} <= n = {final['trials']} < {engine.max_trials}, no maxTrialsReached",
        final["endedBy"] == ENGINE_STOP
        and last["sd"] < engine.stop_sd
        and engine.min_trials <= final["trials"] < engine.max_trials
        and "maxTrialsReached" not in final["flags"],
    )


def _acuity_reaches_sd(contract: Contract, trace: dict, output: dict, block: dict) -> list[Check]:
    engine = contract.resolve_engine(trace["engine"])
    final = output["final"]
    low, high = final["ci95"]
    median_low, median_high = REACHES_SD_MEDIAN_RANGE
    threshold = trace["observer"]["thresholdX"]
    return [
        Check(
            f"median {final['estimate']:.4f} in [{median_low}, {median_high}]",
            median_low <= final["estimate"] <= median_high,
        ),
        _stops_by_sd_rule(contract, trace, output),
        Check(f"ci95 [{low:.4f}, {high:.4f}] contains {threshold}", low <= threshold <= high),
        Check(
            f"ci95 width {high - low:.4f} <= {engine.reliable_max_ci_width}, reliable",
            high - low <= engine.reliable_max_ci_width and final["reliability"] == "reliable",
        ),
    ]


def _acuity_max_trials(contract: Contract, trace: dict, output: dict, block: dict) -> list[Check]:
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


def _contrast_reaches_sd(contract: Contract, trace: dict, output: dict, block: dict) -> list[Check]:
    """Catches an inverted sign: a published logCS near 0.6 or 2 instead of about 1.5."""
    final = output["final"]
    log_cs_low, log_cs_high = CONTRAST_LOGCS_RANGE
    engine_low, engine_high = final["ci95"]
    published_low, published_high = block["ci95"]
    return [
        Check(
            f"published logCS {block['logCS']:.4f} = -t (engine median {final['estimate']:.4f}) "
            f"in [{log_cs_low}, {log_cs_high}]",
            compare(block["logCS"], -final["estimate"], contract.tolerances) == []
            and log_cs_low <= block["logCS"] <= log_cs_high,
        ),
        Check(
            f"published ci95 [{published_low:.4f}, {published_high:.4f}] = [-q_0.975, -q_0.025] "
            f"of the engine ci95 [{engine_low:.4f}, {engine_high:.4f}]",
            compare(block["ci95"], [-engine_high, -engine_low], contract.tolerances) == [],
        ),
        _stops_by_sd_rule(contract, trace, output),
        Check(f"censoredAtCeiling = {block['censoredAtCeiling']}", block["censoredAtCeiling"] is False),
    ]


# One entry per pending trace, from its README's manual oracle.
PLAUSIBILITY_CHECKS: dict[str, PlausibilityCheck] = {
    "acuity-reaches-sd": _acuity_reaches_sd,
    "acuity-max-trials": _acuity_max_trials,
    "contrast-reaches-sd": _contrast_reaches_sd,
}


def plausibility_checks(contract: Contract, name: str, trace: dict, output: dict, block: dict) -> list[Check]:
    return PLAUSIBILITY_CHECKS[name](contract, trace, output, block)


def _check_tiny(contract: Contract, tiny: dict) -> None:
    expected = tiny["expected"]
    mismatches = compare(
        run_trace(tiny, contract=contract),
        {"steps": expected["steps"], "final": expected["final"]},
        contract.tolerances,
    )
    if expected["status"] != "final" or mismatches:
        raise GenerateRefused(f"{TINY_TRACE} does not pass: " + ("; ".join(mismatches) or "not final"))


def _profile_block(contract: Contract, trace: dict, final: dict, acuity_ci95_upper_logmar: float | None) -> dict:
    """The admissible stimuli are constant over a trace, so every trial has the same lowest x."""
    stimuli = contract.resolve_stimuli(trace["stimuli"])
    lowest_x = min(stimuli[i] for i in trace["admissibleIndices"])
    result = Result(
        trials=final["trials"],
        estimate=final["estimate"],
        ci95=tuple(final["ci95"]),
        reliability=final["reliability"],
        flags=tuple(final["flags"]),
    )
    if trace["test"] == "acuity":
        return acuity.measured_block(contract, result, [lowest_x] * result.trials)
    return contrast.measured_block(contract, result, [lowest_x] * result.trials, acuity_ci95_upper_logmar)


def generate(
    contract: Contract,
    traces: Mapping[str, dict],
    tiny: dict,
    acuity_ci95_upper_logmar: float | None = None,
) -> list[Candidate]:
    """Candidates for the given traces (by case name); refuses unless tiny-hand-computed passes.

    acuity_ci95_upper_logmar: required for contrast traces, which carry no acuity result of
    their own; it only sets contrastLetterSizeCapped in the contrast block.
    """
    missing = sorted(traces.keys() - PLAUSIBILITY_CHECKS.keys())
    if missing:
        raise ValueError(f"no plausibility checks for {missing}")
    if acuity_ci95_upper_logmar is None and any(trace["test"] == "contrast" for trace in traces.values()):
        raise ValueError("a contrast trace needs the acuity ci95 upper bound for its letter size")
    _check_tiny(contract, tiny)
    candidates = []
    for name, trace in traces.items():
        output = run_trace(trace, contract=contract)
        block = _profile_block(contract, trace, output["final"], acuity_ci95_upper_logmar)
        candidates.append(
            Candidate(
                trace=name,
                output=output,
                profile_block=block,
                checks=tuple(plausibility_checks(contract, name, trace, output, block)),
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
            "profileBlock": candidate.profile_block,
            **candidate.output,
        }
        path.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
        paths.append(path)
    return paths


def _read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    """Generates and writes the candidates of every pending trace; exit 1 if any check fails.

    The contrast letter size uses the acuity ci95 upper bound of acuity-reaches-sd, the shared
    acuity trace that stops normally: an input of the contrast block, not of its trace.
    """
    contract = load_contract()
    examples_dir = contract.shared_dir / "examples" / "quest"
    traces = {}
    for name in PLAUSIBILITY_CHECKS:
        trace = _read_json(examples_dir / name / "trace.json")
        if trace["expected"]["status"] == "pending":
            traces[name] = trace
    acuity_run = run_trace(_read_json(examples_dir / LETTER_SIZE_ACUITY_TRACE / "trace.json"), contract=contract)
    acuity_upper = acuity_run["final"]["ci95"][1]
    candidates = generate(
        contract, traces, _read_json(examples_dir / TINY_TRACE / "trace.json"), acuity_ci95_upper_logmar=acuity_upper
    )
    print(f"contrast letter size from the {LETTER_SIZE_ACUITY_TRACE} acuity ci95 upper bound {acuity_upper:.4f}")
    for candidate, path in zip(candidates, write_candidates(candidates)):
        print(f"{candidate.trace}: {'PASS' if candidate.passed else 'FAIL'} -> {path}")
        for check in candidate.checks:
            print(f"  [{'x' if check.passed else ' '}] {check.description}")
    return 0 if all(candidate.passed for candidate in candidates) else 1


if __name__ == "__main__":
    sys.exit(main())
