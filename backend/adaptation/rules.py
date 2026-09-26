"""VisualProfile -> AdaptationPlan with rules R0-R8 (docs/data-contracts.md section 9).

No rounding anywhere: rounding happens only in adapter.js. Every number comes from the contract.
"""

from adaptation.summary import contrast_band
from contract import Contract, load_contract
from geometry import angle_to_mm, mm_to_css_px

NOT_RELIABLE = ("doubtful", "unreliable")
# Optional blocks build_plan does not handle yet (userAdjustments is handled by R1).
UNSUPPORTED_BLOCKS = ("reading", "amsler", "visualField", "light")


class UnsupportedProfileError(NotImplementedError):
    """The profile has an optional block build_plan does not support yet; never silently ignored."""


def _clamp(value: float, low: float, high: float) -> float:
    return min(max(value, low), high)


def _prudent_shift(contract: Contract, block: dict) -> float:
    """R0: a further step toward legibility for doubtful and unreliable blocks."""
    return contract.param("rules", "prudentShiftWhenNotReliable") if block["reliability"] in NOT_RELIABLE else 0.0


def _font_size_css_px(contract: Contract, profile: dict, context: dict) -> float:
    """R1 at the reference distance; no critical-print-size margin and no normal-vision special case."""
    acuity = profile["acuity"]
    offset = profile.get("userAdjustments", {}).get("textSizeOffsetLogMAR", 0)
    s_target = (
        acuity["ci95"][1]
        + _prudent_shift(contract, acuity)
        + contract.param("rules", "acuityReserveLogMAR")
        + offset
    )
    x_height_arcmin = contract.param("rules", "xHeightArcminAtZero") * 10**s_target
    h_x_mm = angle_to_mm(context["referenceDistanceMm"], x_height_arcmin)
    font_size_mm = h_x_mm / contract.param("font", "xHeightRatio")
    return mm_to_css_px(contract, font_size_mm, context["ppi"], context["nativeScale"])


def _min_text_contrast(contract: Contract, profile: dict) -> float:
    """R3: four-band table on the prudent contrast bound, linear inside the reduced band."""
    contrast = profile["contrast"]
    x = contrast["ci95"][0] - _prudent_shift(contract, contrast)
    by_band = contract.param("rules", "minTextContrastByBand")
    band = contrast_band(contract, x)
    if band != "reduced":
        return by_band[band]
    bounds = contract.param("contrast", "bandLowerBoundsInclusive")
    slope = (by_band["reducedAtUpperEdge"] - by_band["reducedAtLowerEdge"]) / (bounds["borderline"] - bounds["reduced"])
    return by_band["reducedAtLowerEdge"] + slope * (x - bounds["reduced"])


def build_plan(profile: dict, context: dict, contract: Contract | None = None) -> dict:
    """A complete AdaptationPlan; "do not touch" fields are explicit null. Pure: inputs are not modified."""
    contract = contract or load_contract()
    present = [name for name in UNSUPPORTED_BLOCKS if name in profile]
    if present:
        raise UnsupportedProfileError(f"optional profile blocks {present} are not yet supported by build_plan")
    reference_mm = contract.param("geometry", "referenceDistanceMm")
    if context["referenceDistanceMm"] != reference_mm:
        raise ValueError(
            f"context referenceDistanceMm {context['referenceDistanceMm']} differs from the contract's {reference_mm}"
        )

    font_size = _font_size_css_px(contract, profile, context)
    min_text_contrast = _min_text_contrast(contract, profile)
    ui = contract.param("rules", "minUIContrast")
    target = contract.param("rules", "minTargetPt")
    spacing = contract.param("rules", "spacingBase")

    return {
        "schemaVersion": contract.plan_schema["properties"]["schemaVersion"]["const"],
        "context": {
            "referenceDistanceMm": context["referenceDistanceMm"],
            "ppi": context["ppi"],
            "nativeScale": context["nativeScale"],
        },
        "text": {
            "fontFamily": contract.param("font", "family"),
            "fontSizeCssPx": font_size,
            "lineHeight": spacing["lineHeight"],
            "letterSpacingEm": spacing["letterSpacingEm"],
            "wordSpacingEm": spacing["wordSpacingEm"],
            "paragraphSpacingEm": spacing["paragraphSpacingEm"],
            "align": "left",
        },
        "layout": {
            "singleColumn": True,
            "maxLineWidthCh": contract.param("rules", "maxLineWidthCh")["max"],
            "mode": "normal",
            "moveEdgeElements": False,
        },
        "color": {
            "theme": "original",
            "background": None,
            "text": None,
            "minTextContrast": min_text_contrast,
            "minUIContrast": max(ui["floor"], min_text_contrast * ui["scaleFromText"]),
            "preserveHue": True,
            "imageBrightness": 1,
        },
        "controls": {
            "underlineLinks": True,
            "minTargetPt": _clamp(target["base"] * font_size / target["referenceFontCssPx"], target["base"], target["max"]),
            "focusOutlinePx": contract.param("rules", "focusOutlinePx"),
        },
        "cleanup": {"removeCookieBanners": True, "stopAnimations": True, "useReadability": True},
        "speech": {"tapToSpeak": False, "rateWpm": None},
        "screen": {"brightness": None},
    }
