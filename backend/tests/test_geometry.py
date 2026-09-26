"""Geometry rules the goldens do not reach: the screen-fit limit and an empty admissible set."""

import geometry
from contract import ThresholdGrid


def test_letter_must_fit_within_the_screen_short_side(contract):
    grid = ThresholdGrid.from_json(contract.param("acuity", "thresholdGrid")).points()
    distance_mm, ppi = 400, 460  # the rules/ context (contract section 10)
    last_fitting = len(grid) - 10  # well above the stroke limit, below the top of the grid
    # A short side between the letter sizes at last_fitting and the next index admits only the first.
    short_side = (
        geometry.letter_height_device_px(contract, distance_mm, ppi, grid[last_fitting])
        + geometry.letter_height_device_px(contract, distance_mm, ppi, grid[last_fitting + 1])
    ) / 2
    stimuli = geometry.admissible_acuity_stimuli(contract, distance_mm, ppi, short_side)
    assert stimuli.indices[-1] == last_fitting
    assert stimuli.indices == tuple(range(stimuli.indices[0], last_fitting + 1))


def test_no_admissible_stimulus_has_no_display_limit(contract):
    stimuli = geometry.admissible_acuity_stimuli(contract, 400, 460, 1)
    assert stimuli.indices == ()
    assert stimuli.display_limit_logmar is None
