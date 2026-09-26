"""Contract geometry (docs/data-contracts.md sections 6-7). Every constant comes from the contract."""

import math
from dataclasses import dataclass

from contract import Contract, ThresholdGrid

ARCMIN_PER_DEG = 60  # unit definition, not a contract parameter


@dataclass(frozen=True)
class AdmissibleStimuli:
    indices: tuple[int, ...]  # ascending indices into the acuity threshold grid
    display_limit_logmar: float | None  # smallest admissible stimulus; None if nothing fits


@dataclass(frozen=True)
class ContrastLetterSize:
    letter_size_deg: float
    capped: bool  # contrastLetterSizeCapped: the uncapped size exceeded the maximum


def angle_to_mm(distance_mm: float, angle_arcmin: float) -> float:
    """Small angle: h_mm = d_mm * theta_rad."""
    return distance_mm * math.radians(angle_arcmin / ARCMIN_PER_DEG)


def mm_to_device_px(contract: Contract, mm: float, ppi: float) -> float:
    return mm * ppi / contract.param("geometry", "mmPerInch")


def mm_to_css_px(contract: Contract, mm: float, ppi: float, native_scale: float) -> float:
    return mm * ppi / (contract.param("geometry", "mmPerInch") * native_scale)


def letter_height_device_px(contract: Contract, distance_mm: float, ppi: float, logmar: float) -> float:
    """Height of the acuity letter (5' * 10^x) in device px at the given distance."""
    height_arcmin = contract.param("acuity", "letterHeightArcminAtZero") * 10**logmar
    return mm_to_device_px(contract, angle_to_mm(distance_mm, height_arcmin), ppi)


def admissible_acuity_stimuli(
    contract: Contract, distance_mm: float, ppi: float, screen_short_side_device_px: float
) -> AdmissibleStimuli:
    """Grid points whose letter stroke is at least the minimum device px and whose letter fits the screen."""
    stroke_fraction = contract.param("acuity", "strokeFraction")
    min_stroke_px = contract.param("acuity", "minStrokeDevicePx")
    grid = ThresholdGrid.from_json(contract.param("acuity", "thresholdGrid")).points()

    indices = []
    for i, x in enumerate(grid):
        height_px = letter_height_device_px(contract, distance_mm, ppi, x)
        if stroke_fraction * height_px >= min_stroke_px and height_px <= screen_short_side_device_px:
            indices.append(i)
    return AdmissibleStimuli(tuple(indices), grid[indices[0]] if indices else None)


def contrast_letter_size(contract: Contract, acuity_ci95_upper_logmar: float) -> ContrastLetterSize:
    """max(letterMinDeg, 5' * 10^(upper + offset)), capped at letterMaxDeg."""
    height_at_zero = contract.param("acuity", "letterHeightArcminAtZero")
    offset = contract.param("contrast", "letterAcuityOffsetLogMAR")
    min_deg = contract.param("contrast", "letterMinDeg")
    max_deg = contract.param("contrast", "letterMaxDeg")

    uncapped = max(min_deg, height_at_zero * 10 ** (acuity_ci95_upper_logmar + offset) / ARCMIN_PER_DEG)
    return ContrastLetterSize(min(uncapped, max_deg), uncapped > max_deg)
