"""Contract loader: parameters, devices, schemas and trace engine resolution."""

import copy
import json

import pytest
from jsonschema import ValidationError

from contract import ContractError, UnknownDeviceError, load_contract
from contract.loader import SHARED_DIR
from tests.golden_cases import discover_cases


@pytest.fixture(scope="module")
def raw_parameters():
    return json.loads((SHARED_DIR / "parameters.json").read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def raw_devices():
    return json.loads((SHARED_DIR / "devices.json").read_text(encoding="utf-8"))


def write_shared_copy(tmp_path, parameters=None, devices=None):
    """A shared/ copy with the given parameters and devices, real files for the rest."""
    for name in ("parameters.json", "devices.json", "visual-profile.schema.json", "adaptation-plan.schema.json"):
        (tmp_path / name).write_bytes((SHARED_DIR / name).read_bytes())
    if parameters is not None:
        (tmp_path / "parameters.json").write_text(json.dumps(parameters), encoding="utf-8")
    if devices is not None:
        (tmp_path / "devices.json").write_text(json.dumps(devices), encoding="utf-8")
    return tmp_path


def test_param_exposes_value_and_keeps_unit_and_source(contract, raw_parameters):
    raw = raw_parameters["acuity"]["stopSd"]
    assert contract.param("acuity", "stopSd") == raw["value"]
    entry = contract.parameter("acuity", "stopSd")
    assert (entry.value, entry.unit, entry.source) == (raw["value"], raw["unit"], raw["source"])


def test_every_parameter_is_exposed(contract, raw_parameters):
    for group, entries in raw_parameters.items():
        if not isinstance(entries, dict):
            continue
        for key, entry in entries.items():
            assert contract.param(group, key) == entry["value"]


def test_unknown_parameter_access_is_an_error(contract):
    with pytest.raises(ContractError, match="acuity.noSuchKey"):
        contract.param("acuity", "noSuchKey")


def test_missing_expected_parameter_key_is_an_error(tmp_path, raw_parameters):
    parameters = copy.deepcopy(raw_parameters)
    del parameters["quest"]["tieEpsilon"]
    with pytest.raises(ContractError, match="quest.tieEpsilon"):
        load_contract(write_shared_copy(tmp_path, parameters))


def test_unexpected_parameter_key_is_an_error(tmp_path, raw_parameters):
    parameters = copy.deepcopy(raw_parameters)
    parameters["quest"]["newKnob"] = {"value": 1, "unit": "none", "source": "test"}
    with pytest.raises(ContractError, match="quest.newKnob"):
        load_contract(write_shared_copy(tmp_path, parameters))


def test_parameter_entry_without_unit_is_an_error(tmp_path, raw_parameters):
    parameters = copy.deepcopy(raw_parameters)
    del parameters["acuity"]["stopSd"]["unit"]
    with pytest.raises(ContractError, match="acuity.stopSd"):
        load_contract(write_shared_copy(tmp_path, parameters))


def test_device_lookup_by_model_identifier(contract):
    raw = json.loads((SHARED_DIR / "devices.json").read_text(encoding="utf-8"))["devices"]
    for identifier, entry in raw.items():
        device = contract.device(identifier)
        assert (device.name, device.ppi, device.ppi_source) == (
            entry["name"],
            entry["ppi"],
            entry["ppiSource"],
        )


@pytest.mark.parametrize("field", ["ppi", "ppiSource", "name"])
def test_device_entry_missing_field_is_an_error(tmp_path, raw_devices, field):
    devices = copy.deepcopy(raw_devices)
    del devices["devices"]["iPhone13,2"][field]
    with pytest.raises(ContractError, match=r"iPhone13,2"):
        load_contract(write_shared_copy(tmp_path, devices=devices))


@pytest.mark.parametrize("ppi", [None, "460", 0, True])
def test_device_entry_invalid_ppi_is_an_error(tmp_path, raw_devices, ppi):
    devices = copy.deepcopy(raw_devices)
    devices["devices"]["iPhone13,2"]["ppi"] = ppi
    with pytest.raises(ContractError, match=r"iPhone13,2"):
        load_contract(write_shared_copy(tmp_path, devices=devices))


@pytest.mark.parametrize("identifier", ["iPhone99,9", "arm64", "iPhone8,4", ""])
def test_unknown_model_identifier_is_an_error(contract, identifier):
    with pytest.raises(UnknownDeviceError):
        contract.device(identifier)


def test_both_schemas_are_exposed(contract):
    for schema in (contract.profile_schema, contract.plan_schema):
        assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"


def test_profile_validation_rejects_extra_field(contract):
    profile = json.loads((discover_cases("rules")[0] / "profile.json").read_text(encoding="utf-8"))
    contract.validate_profile(profile)
    profile["unexpected"] = True
    with pytest.raises(ValidationError, match="unexpected"):
        contract.validate_profile(profile)


@pytest.mark.parametrize("test", ["acuity", "contrast"])
def test_engine_from_parameters(contract, test):
    engine = contract.resolve_engine({"fromParameters": test})
    grid = contract.param(test, "thresholdGrid")
    assert engine.threshold_grid.min == grid["min"]
    assert engine.threshold_grid.max == grid["max"]
    assert engine.threshold_grid.step == grid["step"]
    assert engine.beta_grid == tuple(contract.param(test, "betaGrid"))
    assert engine.gamma == contract.param("psychometric", "gamma")
    assert engine.lam == contract.param("psychometric", "lambda")
    assert engine.prior == contract.param(test, "prior")
    assert engine.stop_sd == contract.param(test, "stopSd")
    assert engine.min_trials == contract.param("quest", "minTrials")
    assert engine.max_trials == contract.param("quest", "maxTrials")
    assert engine.reliable_max_ci_width == contract.param(test, "reliableMaxCiWidth")
    assert engine.tie_epsilon == contract.param("quest", "tieEpsilon")
    assert engine.ci_quantiles == tuple(contract.param("quest", "ciQuantiles"))


@pytest.mark.parametrize("test", ["acuity", "contrast"])
def test_stimuli_from_parameters_are_the_threshold_grid(contract, test):
    grid = contract.param(test, "thresholdGrid")
    stimuli = contract.resolve_stimuli({"fromParameters": test})
    count = round((grid["max"] - grid["min"]) / grid["step"]) + 1
    assert len(stimuli) == count
    assert stimuli == [grid["min"] + i * grid["step"] for i in range(count)]
    assert contract.resolve_engine({"fromParameters": test}).threshold_grid.points() == stimuli


def test_explicit_engine_and_stimuli_pass_through(contract):
    trace_dir = next(d for d in discover_cases("quest") if d.name == "tiny-hand-computed")
    trace = json.loads((trace_dir / "trace.json").read_text(encoding="utf-8"))
    engine = contract.resolve_engine(trace["engine"])
    assert engine.beta_grid == tuple(trace["engine"]["betaGrid"])
    assert engine.threshold_grid.max == trace["engine"]["thresholdGrid"]["max"]
    assert engine.stop_sd == trace["engine"]["stopSd"]
    assert contract.resolve_stimuli(trace["stimuli"]) == trace["stimuli"]


def test_unknown_from_parameters_reference_is_an_error(contract):
    with pytest.raises(ContractError, match="reading"):
        contract.resolve_engine({"fromParameters": "reading"})
    with pytest.raises(ContractError, match="reading"):
        contract.resolve_stimuli({"fromParameters": "reading"})


def test_explicit_engine_with_missing_key_is_an_error(contract):
    with pytest.raises(ContractError, match="stopSd"):
        contract.resolve_engine(
            {
                "gamma": 0.5,
                "lambda": 0.0,
                "thresholdGrid": {"min": 0.0, "max": 1.0, "step": 0.5},
                "betaGrid": [1],
                "prior": "uniform",
                "minTrials": 1,
                "maxTrials": 2,
                "reliableMaxCiWidth": 1.0,
            }
        )
