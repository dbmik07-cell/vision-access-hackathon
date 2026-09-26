"""Profile derivations that do not go through the plan (docs/data-contracts.md sections 6 and 8)."""

from contract import Contract

# Worst last (contract section 8): reliable < doubtful < unreliable.
RELIABILITY_ORDER = ("reliable", "doubtful", "unreliable")
EYES = ("right", "left")


def who_category(contract: Contract, median_logmar: float) -> str:
    """The highest WHO category whose exclusive lower bound the median strictly exceeds, else 'none'."""
    bounds = contract.param("acuity", "whoCategoryLowerBoundsExclusive")
    category = "none"
    for name, bound in sorted(bounds.items(), key=lambda item: item[1]):
        if median_logmar > bound:
            category = name
    return category


def contrast_band(contract: Contract, median_logcs: float) -> str:
    """The contrast band whose inclusive lower bound the median reaches, else 'severelyReduced'."""
    bounds = contract.param("contrast", "bandLowerBoundsInclusive")
    for name, bound in sorted(bounds.items(), key=lambda item: item[1], reverse=True):
        if median_logcs >= bound:
            return name
    return "severelyReduced"


def _any_optional_block_abnormal(profile: dict) -> bool:
    amsler = profile.get("amsler")
    if amsler is not None and any(
        amsler[eye]["distortedAreaDeg2"] > 0 or amsler[eye]["missingAreaDeg2"] > 0 or amsler[eye]["centralInvolved"]
        for eye in EYES
    ):
        return True
    field = profile.get("visualField")
    return field is not None and any(field[eye]["pattern"] != "none" for eye in EYES)


def _measured_reliabilities(profile: dict) -> list[str]:
    """The block-level reliability of every measured block; presets never count."""
    return [
        block["reliability"]
        for block in profile.values()
        if isinstance(block, dict) and block.get("source") == "measured" and "reliability" in block
    ]


def derive_summary(contract: Contract, profile: dict) -> dict:
    """summary.normalVision and summary.overallReliability; presets never count toward reliability."""
    normal_vision = (
        profile["acuity"]["ci95"][1] < contract.param("summary", "normalVisionAcuityUpperBelow")
        and profile["contrast"]["ci95"][0] >= contract.param("summary", "normalVisionContrastLowerAtLeast")
        and not _any_optional_block_abnormal(profile)
    )
    reliabilities = _measured_reliabilities(profile)
    overall = max(reliabilities, key=RELIABILITY_ORDER.index) if reliabilities else None
    return {"normalVision": normal_vision, "overallReliability": overall}
