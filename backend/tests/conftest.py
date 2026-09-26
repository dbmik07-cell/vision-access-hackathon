import pytest

from contract import load_contract


@pytest.fixture(scope="session")
def contract():
    return load_contract()
