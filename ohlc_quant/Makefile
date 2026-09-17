PY=.venv/bin/python

venv:
	python3 -m venv .venv && .venv/bin/pip install -e ".[dev]"

data:
	$(PY) scripts/download_candles.py 2023-01-01 2026-09-12 3

test:
	$(PY) -m pytest -q -n 12 -p no:warnings

lint:
	.venv/bin/ruff check ohlc_quant tests scripts --select E,F,W --ignore E501,E731,E741,E402,E701,E702

validate:
	$(PY) scripts/validate_full.py

validate-synthetic:
	$(PY) scripts/validate_full.py --synthetic 420

.PHONY: venv data test lint validate validate-synthetic
