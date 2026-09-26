"""VisualProfile -> AdaptationPlan with rules R0-R8 (docs/data-contracts.md section 9).

No rounding anywhere: rounding happens only in adapter.js. Every number comes from the contract.
"""

import math

from adaptation.summary import contrast_band
from contract import Contract, load_contract
from geometry import angle_to_mm, mm_to_css_px

NOT_RELIABLE = ("doubtful", "unreliable")
# Optional blocks build_plan does not handle yet (reading is post-MVP).
UNSUPPORTED_BLOCKS = ("reading",)


class UnsupportedProfileError(NotImplementedError):
    """The profile has an optional block build_plan does not support yet; never silently ignored."""


def _clamp(value: float, low: float, high: float) -> float:
    return min(max(value, low), high)


def _prudent_shift(contract: Contract, block: dict) -> float:
    """R0: a further step toward legibility for doubtful and unreliable blocks."""
    return contract.param("rules", "prudentShiftWhenNotReliable") if block["reliability"] in NOT_RELIABLE else 0.0


def _font_size_mm(contract: Contract, profile: dict, context: dict) -> float:
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
    return h_x_mm / contract.param("font", "xHeightRatio")


def _has_field_loss(profile: dict) -> bool:
    field = profile.get("visualField")
    return field is not None and any(field[eye]["pattern"] != "none" for eye in ("right", "left"))


def _max_line_width_ch(contract: Contract, profile: dict, context: dict, font_size_mm: float) -> float:
    """R2: line length from the better eye's field radius; independent of the distance."""
    bounds = contract.param("rules", "maxLineWidthCh")
    if not _has_field_loss(profile):
        return bounds["max"]
    field = profile["visualField"]
    radius_deg = max(field["right"]["fieldRadiusDeg"], field["left"]["fieldRadiusDeg"])
    l_max_mm = (
        2 * context["referenceDistanceMm"] * math.tan(math.radians(radius_deg))
        * contract.param("rules", "lineLengthFieldFactor")
    )
    return _clamp(l_max_mm / (font_size_mm * contract.param("font", "zeroWidthEm")), bounds["min"], bounds["max"])


def _spacing(contract: Contract, profile: dict) -> dict:
    """R2: wider spacing when either eye has central involvement on the Amsler grid."""
    amsler = profile.get("amsler")
    central = amsler is not None and any(amsler[eye]["centralInvolved"] for eye in ("right", "left"))
    return contract.param("rules", "spacingCentralLoss" if central else "spacingBase")


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


def _theme(contract: Contract, profile: dict) -> dict:
    """R4: theme, its colours, image dimming and screen brightness."""
    light = profile.get("light", {})
    photophobia = light.get("photophobia", False)
    theme = light.get("preferredTheme", "dark" if photophobia else "original")
    if theme == "light":
        raise NotImplementedError("light theme not yet defined in the contract (rules.lightTheme is null)")
    colours = contract.param("rules", "darkTheme") if theme == "dark" else {"background": None, "text": None}
    dimmed = photophobia or theme == "dark"
    return {
        "theme": theme,
        "background": colours["background"],
        "text": colours["text"],
        "imageBrightness": contract.param("rules", "imageBrightnessDimmed") if dimmed else 1,
        "brightness": light.get("preferredBrightness"),
    }


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

    font_size_mm = _font_size_mm(contract, profile, context)
    font_size = mm_to_css_px(contract, font_size_mm, context["ppi"], context["nativeScale"])
    min_text_contrast = _min_text_contrast(contract, profile)
    ui = contract.param("rules", "minUIContrast")
    target = contract.param("rules", "minTargetPt")
    spacing = _spacing(contract, profile)
    theme = _theme(contract, profile)

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
            "maxLineWidthCh": _max_line_width_ch(contract, profile, context, font_size_mm),
            "mode": "normal",
            "moveEdgeElements": _has_field_loss(profile),
        },
        "color": {
            "theme": theme["theme"],
            "background": theme["background"],
            "text": theme["text"],
            "minTextContrast": min_text_contrast,
            "minUIContrast": max(ui["floor"], min_text_contrast * ui["scaleFromText"]),
            "preserveHue": True,
            "imageBrightness": theme["imageBrightness"],
        },
        "controls": {
            "underlineLinks": True,
            "minTargetPt": _clamp(target["base"] * font_size / target["referenceFontCssPx"], target["base"], target["max"]),
            "focusOutlinePx": contract.param("rules", "focusOutlinePx"),
        },
        "cleanup": {"removeCookieBanners": True, "stopAnimations": True, "useReadability": True},
        "speech": {"tapToSpeak": False, "rateWpm": None},
        "screen": {"brightness": theme["brightness"]},
    }
