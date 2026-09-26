"""The single test seam: every golden case under shared/examples/ (contract section 10).

Cases are discovered from the folders, so a new case folder is a new test. A case whose
entry point is not implemented yet is reported as skipped, never as passed.
"""

import importlib
import json

import pytest

from contract import compare
from tests.golden_cases import discover_cases

CATEGORIES = ("rules", "summary", "geometry", "quest")

# Public entry point exercised by each category of golden cases, as (module, attribute).
# attribute None means the category's runner uses several functions of the module.
ENTRY_POINTS = {
    "rules": ("adaptation", "build_plan"),
    "summary": ("adaptation", "derive_summary"),
    "geometry": ("geometry", None),
    "quest": ("quest", "run_trace"),
}


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def entry_point(category):
    """The category's entry point, or a skip if it does not exist yet.

    Only a missing module or attribute skips: an import error raised inside an existing
    module is a real failure.
    """
    module_name, attribute = ENTRY_POINTS[category]
    name = module_name if attribute is None else f"{module_name}.{attribute}"
    try:
        module = importlib.import_module(module_name)
    except ModuleNotFoundError as error:
        if error.name != module_name:
            raise
        pytest.skip(f"entry point {name} not implemented yet")
    if attribute is None:
        if getattr(module, "__file__", None) is None:  # folder without __init__.py
            pytest.skip(f"entry point {name} not implemented yet")
        return module
    if not hasattr(module, attribute):
        pytest.skip(f"entry point {name} not implemented yet")
    return getattr(module, attribute)


def run_rules(case_dir, build_plan, contract):
    plan = build_plan(read_json(case_dir / "profile.json"), read_json(case_dir / "context.json"))
    contract.validate_plan(plan)
    assert compare(plan, read_json(case_dir / "expected-plan.json"), contract.tolerances) == []


GEOMETRY_CASE_KEYS = {
    "angle": {"distanceMm", "angleArcmin", "ppi", "nativeScale"},
    "admissible": {"distanceMm", "ppi", "screenShortSideDevicePx"},
}


def geometry_input_shape(given):
    """geometry/ inputs come in three shapes, told apart by their exact keys."""
    if given.keys() == {"acuityCi95UpperLogMAR"}:
        return "letter"
    if given.keys() == {"cases"}:
        for shape, keys in GEOMETRY_CASE_KEYS.items():
            if all(case.keys() == keys for case in given["cases"]):
                return shape
    return None


def run_geometry(case_dir, geometry, contract):
    given = read_json(case_dir / "input.json")
    shape = geometry_input_shape(given)
    if shape == "letter":
        sizes = [geometry.contrast_letter_size(contract, upper) for upper in given["acuityCi95UpperLogMAR"]]
        actual = {
            "letterSizeDeg": [s.letter_size_deg for s in sizes],
            "contrastLetterSizeCapped": [s.capped for s in sizes],
        }
    elif shape == "angle":
        actual = {"cases": []}
        for case in given["cases"]:
            mm = geometry.angle_to_mm(case["distanceMm"], case["angleArcmin"])
            actual["cases"].append(
                {
                    "mm": mm,
                    "devicePx": geometry.mm_to_device_px(contract, mm, case["ppi"]),
                    "cssPx": geometry.mm_to_css_px(contract, mm, case["ppi"], case["nativeScale"]),
                }
            )
    elif shape == "admissible":
        actual = {"cases": []}
        for case in given["cases"]:
            stimuli = geometry.admissible_acuity_stimuli(
                contract, case["distanceMm"], case["ppi"], case["screenShortSideDevicePx"]
            )
            actual["cases"].append(
                {
                    "admissibleIndices": list(stimuli.indices),
                    "displayLimitLogMAR": stimuli.display_limit_logmar,
                }
            )
    else:
        pytest.fail(f"unrecognised geometry input structure in {case_dir.name}")
    assert compare(actual, read_json(case_dir / "expected.json"), contract.tolerances) == []


# Categories whose golden runner is written together with their entry point.
RUNNERS = {"rules": run_rules, "geometry": run_geometry}


def case_params():
    return [
        pytest.param(category, case_dir, id=f"{category}/{case_dir.name}")
        for category in CATEGORIES
        for case_dir in discover_cases(category)
    ]


@pytest.mark.parametrize("category", CATEGORIES)
def test_every_category_has_cases(category):
    assert discover_cases(category), f"no golden cases found under shared/examples/{category}/"


@pytest.mark.parametrize(
    "case_dir", [pytest.param(d, id=d.name) for d in discover_cases("rules")]
)
@pytest.mark.parametrize("file_name", ["profile.json", "expected-plan.json"])
def test_rules_golden_files_match_schema(contract, case_dir, file_name):
    document = read_json(case_dir / file_name)
    if file_name == "profile.json":
        contract.validate_profile(document)
    else:
        contract.validate_plan(document)


@pytest.mark.parametrize(("category", "case_dir"), case_params())
def test_golden_case(contract, category, case_dir):
    implementation = entry_point(category)
    runner = RUNNERS.get(category)
    if runner is None:
        pytest.fail(f"{category}: entry point exists but its golden runner is not wired in RUNNERS")
    runner(case_dir, implementation, contract)
