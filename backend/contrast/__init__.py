"""The measured contrast block of the VisualProfile (docs/data-contracts.md sections 5, 6 and 8).

The engine works in the ease variable x = log10(C_Weber); logCS = -t is applied only here,
when the block is written, so the ci95 ends swap. No age correction.
"""

from collections.abc import Sequence

import geometry
from adaptation import contrast_band
from contract import Contract
from quest.engine import Result

LETTER_SIZE_CAPPED = "contrastLetterSizeCapped"


def measured_block(
    contract: Contract,
    result: Result,
    trial_hardest_stimuli: Sequence[float],
    acuity_ci95_upper_logmar: float,
) -> dict:
    """The contrast block from a contrast QUEST+ result.

    trial_hardest_stimuli: the lowest admissible x (weakest contrast) of each trial, in trial
    order, as given by the caller; Python does not model which levels the display can show.
    acuity_ci95_upper_logmar: sets the letter size, and so contrastLetterSizeCapped.
    """
    if len(trial_hardest_stimuli) != result.trials:
        raise ValueError(
            f"expected one hardest stimulus per trial ({result.trials}), got {len(trial_hardest_stimuli)}"
        )
    low, high = result.ci95
    log_cs = -result.estimate
    ceiling = -min(trial_hardest_stimuli)
    flags = list(result.flags)
    if geometry.contrast_letter_size(contract, acuity_ci95_upper_logmar).capped:
        flags.append(LETTER_SIZE_CAPPED)
    return {
        "source": "measured",
        "logCS": log_cs,
        "ci95": [-high, -low],
        "reliability": result.reliability,
        "flags": flags,
        "band": contrast_band(contract, log_cs),
        "trials": result.trials,
        "ceilingLogCS": ceiling,
        "censoredAtCeiling": log_cs > ceiling,
    }
