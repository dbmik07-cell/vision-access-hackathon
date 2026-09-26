"""Discovery and reading of the shared golden cases (shared/examples/<category>/<case>/)."""

import json

from contract.loader import SHARED_DIR

EXAMPLES_DIR = SHARED_DIR / "examples"


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def discover_cases(category):
    """Every case folder under shared/examples/<category>/, sorted by name."""
    root = EXAMPLES_DIR / category
    return sorted(p for p in root.iterdir() if p.is_dir()) if root.is_dir() else []
