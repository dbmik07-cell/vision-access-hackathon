"""The measured acuity block of the VisualProfile (docs/data-contracts.md sections 6 and 8)."""

from collections.abc import Sequence

from adaptation import who_category
from contract import Contract
from quest import Result


def measured_block(contract: Contract, result: Result, trial_display_limits: Sequence[float]) -> dict:
    """The acuity block from an acuity QUEST+ result; engine x is logMAR, so t is published as is.

    trial_display_limits: the smallest admissible stimulus of each trial, in trial order.
    """
    if len(trial_display_limits) != result.trials:
        raise ValueError(
            f"expected one display limit per trial ({result.trials}), got {len(trial_display_limits)}"
        )
    display_limit = min(trial_display_limits)
    return {
        "source": "measured",
        "logMAR": result.estimate,
        "ci95": list(result.ci95),
        "reliability": result.reliability,
        "flags": list(result.flags),
        "whoCategory": who_category(contract, result.estimate),
        "trials": result.trials,
        "displayLimitLogMAR": display_limit,
        "censoredAtDisplayLimit": result.estimate < display_limit,
    }
