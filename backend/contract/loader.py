"""The only reader of the shared contract files (docs/data-contracts.md section 2)."""

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator

SHARED_DIR = Path(__file__).resolve().parents[2] / "shared"

# Parameter names of contract 1.0. Names only: every value is read from parameters.json.
EXPECTED_PARAMETERS = {
    "psychometric": {"gamma", "lambda"},
    "quest": {
        "entropyLogBase", "tieEpsilon", "minTrials", "maxTrials",
        "gridGeneration", "quantileConvention", "ciQuantiles",
    },
    "acuity": {
        "stimulusVariable", "thresholdGrid", "betaGrid", "prior", "stopSd",
        "reliableMaxCiWidth", "letterHeightArcminAtZero", "strokeFraction",
        "minStrokeDevicePx", "whoCategoryLowerBoundsExclusive",
    },
    "contrast": {
        "stimulusVariable", "thresholdGrid", "betaGrid", "prior", "stopSd",
        "reliableMaxCiWidth", "definition", "letterMinDeg",
        "letterAcuityOffsetLogMAR", "letterMaxDeg", "bandLowerBoundsInclusive",
    },
    "geometry": {"mmPerInch", "testBandMm", "referenceDistanceMm"},
    "font": {
        "family", "file", "version", "sha256", "unitsPerEm", "sxHeight",
        "zeroAdvanceWidth", "xHeightRatio", "zeroWidthEm",
    },
    "rules": {
        "prudentShiftWhenNotReliable", "acuityReserveLogMAR",
        "criticalPrintSizeMarginLogMAR", "xHeightArcminAtZero", "spacingBase",
        "spacingCentralLoss", "lineLengthFieldFactor", "maxLineWidthCh",
        "minTextContrastByBand", "minUIContrast", "darkTheme", "lightTheme",
        "imageBrightnessDimmed", "minTargetPt", "focusOutlinePx",
    },
    "summary": {"normalVisionAcuityUpperBelow", "normalVisionContrastLowerAtLeast"},
    "tolerances": {"intermediateRelative", "intermediateAbsolute", "publishedAbsolute"},
}
PARAMETER_FIELDS = {"value", "unit", "source"}
DEVICE_FIELDS = {"name", "ppi", "ppiSource"}
ENGINE_TESTS = ("acuity", "contrast")


class ContractError(Exception):
    """The shared contract is missing something, or has something it should not."""


class UnknownDeviceError(ContractError):
    """The model identifier is not in shared/devices.json; ppi is never estimated."""


@dataclass(frozen=True)
class Parameter:
    value: Any
    unit: str
    source: str


@dataclass(frozen=True)
class Device:
    model_identifier: str
    name: str
    ppi: float
    ppi_source: str


@dataclass(frozen=True)
class Tolerances:
    intermediate_relative: float
    intermediate_absolute: float
    published_absolute: float


@dataclass(frozen=True)
class ThresholdGrid:
    min: float
    max: float
    step: float

    @classmethod
    def from_json(cls, grid: dict) -> "ThresholdGrid":
        return cls(grid["min"], grid["max"], grid["step"])

    def points(self) -> list[float]:
        """t_i = min + i * step with integer i, never by cumulative sums (contract section 5)."""
        count = round((self.max - self.min) / self.step) + 1
        return [self.min + i * self.step for i in range(count)]


@dataclass(frozen=True)
class EngineConfig:
    threshold_grid: ThresholdGrid
    beta_grid: tuple[float, ...]
    gamma: float
    lam: float
    prior: str
    stop_sd: float
    min_trials: int
    max_trials: int
    reliable_max_ci_width: float
    tie_epsilon: float
    ci_quantiles: tuple[float, float]


def _read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _check_parameters(raw: dict) -> dict[str, dict[str, Parameter]]:
    groups = {k: v for k, v in raw.items() if k not in ("schemaVersion", "description")}
    problems = []
    for group in sorted(EXPECTED_PARAMETERS.keys() - groups.keys()):
        problems.append(f"missing parameter group '{group}'")
    for group in sorted(groups.keys() - EXPECTED_PARAMETERS.keys()):
        problems.append(f"unexpected parameter group '{group}'")
    parameters = {}
    for group, expected in EXPECTED_PARAMETERS.items():
        entries = groups.get(group, {})
        for key in sorted(expected - entries.keys()):
            problems.append(f"missing parameter '{group}.{key}'")
        for key in sorted(entries.keys() - expected):
            problems.append(f"unexpected parameter '{group}.{key}'")
        parameters[group] = {}
        for key, entry in entries.items():
            if not isinstance(entry, dict) or entry.keys() != PARAMETER_FIELDS:
                problems.append(f"parameter '{group}.{key}' must have exactly {sorted(PARAMETER_FIELDS)}")
                continue
            parameters[group][key] = Parameter(entry["value"], entry["unit"], entry["source"])
    if problems:
        raise ContractError("shared/parameters.json: " + "; ".join(problems))
    return parameters


def _check_devices(raw: dict) -> dict[str, Device]:
    entries = raw.get("devices")
    if not isinstance(entries, dict):
        raise ContractError("shared/devices.json: missing 'devices' table")
    problems = []
    devices = {}
    for identifier, entry in entries.items():
        if not isinstance(entry, dict) or entry.keys() != DEVICE_FIELDS:
            problems.append(f"device '{identifier}' must have exactly {sorted(DEVICE_FIELDS)}")
            continue
        ppi = entry["ppi"]
        if isinstance(ppi, bool) or not isinstance(ppi, (int, float)) or ppi <= 0:
            problems.append(f"device '{identifier}' has invalid ppi {ppi!r}")
            continue
        devices[identifier] = Device(identifier, entry["name"], ppi, entry["ppiSource"])
    if problems:
        raise ContractError("shared/devices.json: " + "; ".join(problems))
    return devices


class Contract:
    def __init__(self, shared_dir: Path):
        self.shared_dir = shared_dir
        self._parameters = _check_parameters(_read_json(shared_dir / "parameters.json"))
        self._devices = _check_devices(_read_json(shared_dir / "devices.json"))
        self.profile_schema = _read_json(shared_dir / "visual-profile.schema.json")
        self.plan_schema = _read_json(shared_dir / "adaptation-plan.schema.json")
        self._profile_validator = Draft202012Validator(self.profile_schema)
        self._plan_validator = Draft202012Validator(self.plan_schema)

    def parameter(self, group: str, key: str) -> Parameter:
        try:
            return self._parameters[group][key]
        except KeyError:
            raise ContractError(f"parameter '{group}.{key}' is not in shared/parameters.json") from None

    def param(self, group: str, key: str) -> Any:
        return self.parameter(group, key).value

    @property
    def tolerances(self) -> Tolerances:
        return Tolerances(
            intermediate_relative=self.param("tolerances", "intermediateRelative"),
            intermediate_absolute=self.param("tolerances", "intermediateAbsolute"),
            published_absolute=self.param("tolerances", "publishedAbsolute"),
        )

    def device(self, model_identifier: str) -> Device:
        device = self._devices.get(model_identifier)
        if device is None:
            raise UnknownDeviceError(
                f"model identifier '{model_identifier}' is not in shared/devices.json; "
                "the test cannot start and ppi is never estimated"
            )
        return device

    def validate_profile(self, profile: dict) -> None:
        self._profile_validator.validate(profile)

    def validate_plan(self, plan: dict) -> None:
        self._plan_validator.validate(plan)

    def resolve_engine(self, spec: dict) -> EngineConfig:
        """A trace's `engine`: explicit, or {"fromParameters": "acuity" | "contrast"}."""
        if "fromParameters" in spec:
            test = self._engine_test(spec)
            spec = {
                "gamma": self.param("psychometric", "gamma"),
                "lambda": self.param("psychometric", "lambda"),
                "thresholdGrid": self.param(test, "thresholdGrid"),
                "betaGrid": self.param(test, "betaGrid"),
                "prior": self.param(test, "prior"),
                "stopSd": self.param(test, "stopSd"),
                "minTrials": self.param("quest", "minTrials"),
                "maxTrials": self.param("quest", "maxTrials"),
                "reliableMaxCiWidth": self.param(test, "reliableMaxCiWidth"),
            }
        try:
            return EngineConfig(
                threshold_grid=ThresholdGrid.from_json(spec["thresholdGrid"]),
                beta_grid=tuple(spec["betaGrid"]),
                gamma=spec["gamma"],
                lam=spec["lambda"],
                prior=spec["prior"],
                stop_sd=spec["stopSd"],
                min_trials=spec["minTrials"],
                max_trials=spec["maxTrials"],
                reliable_max_ci_width=spec["reliableMaxCiWidth"],
                tie_epsilon=self.param("quest", "tieEpsilon"),
                ci_quantiles=tuple(self.param("quest", "ciQuantiles")),
            )
        except KeyError as missing:
            raise ContractError(f"engine configuration is missing {missing}") from None

    def resolve_stimuli(self, spec: list | dict) -> list[float]:
        """A trace's `stimuli`: explicit list, or the threshold grid of the named test."""
        if isinstance(spec, list):
            return list(spec)
        test = self._engine_test(spec)
        return ThresholdGrid.from_json(self.param(test, "thresholdGrid")).points()

    @staticmethod
    def _engine_test(spec: dict) -> str:
        test = spec.get("fromParameters")
        if test not in ENGINE_TESTS:
            raise ContractError(f"fromParameters must be one of {ENGINE_TESTS}, got {test!r}")
        return test


def load_contract(shared_dir: Path = SHARED_DIR) -> Contract:
    return Contract(Path(shared_dir))
