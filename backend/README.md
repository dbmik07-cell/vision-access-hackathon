# Implementazione di riferimento (Python)

Workspace locale di Michele: implementazione di riferimento del contratto MVP (`docs/data-contracts.md`), non un server.

```powershell
cd backend
py -3.12 -m venv .venv          # qualsiasi Python >= 3.12
.\.venv\Scripts\python -m pip install -e .        # aggiungere ".[sim]" per matplotlib
.\.venv\Scripts\python -m pytest
```

- `contract/`: unico lettore di `shared/` (parametri, dispositivi, schemi) e confronto con le tolleranze della sezione 4.
- `tests/test_golden.py`: scopre ogni caso in `shared/examples/{rules,summary,geometry,quest}/`; i casi il cui punto di ingresso non esiste ancora risultano `skipped` con il motivo.
