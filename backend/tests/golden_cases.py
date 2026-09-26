"""Discovery of the shared golden cases (shared/examples/<category>/<case>/)."""

from contract.loader import SHARED_DIR

EXAMPLES_DIR = SHARED_DIR / "examples"


def discover_cases(category):
    """Every case folder under shared/examples/<category>/, sorted by name."""
    root = EXAMPLES_DIR / category
    return sorted(p for p in root.iterdir() if p.is_dir()) if root.is_dir() else []
