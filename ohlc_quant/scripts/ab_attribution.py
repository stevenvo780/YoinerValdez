from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from ohlc_quant.analysis.metrics import compute_metrics, metrics_table
from ohlc_quant.analysis.montecarlo import monte_carlo
from ohlc_quant.data.bars import build_market
from ohlc_quant.data.dukascopy import load_m1
from ohlc_quant.engine.backtest import run_backtest
from ohlc_quant.engine.params import BrokerSpec, EAParams, ServerClock

DEPOSIT = float(sys.argv[1]) if len(sys.argv) > 1 else 5000.0
m1 = load_m1("XAUUSD", ROOT / "data" / "bars")
md = build_market(m1, ServerClock(2, "us"))
span = (m1.index.max() - m1.index.min()).days

v140 = EAParams.v140()
steps = [
    ("v14.0 (original)", v140),
    ("+ ATR vela cerrada", v140.with_(atr_closed_bar=True)),
    ("+ spread promedio para modo", v140.with_(atr_closed_bar=True, use_avg_spread_for_mode=True)),
    ("+ racha reset >=0.25R", v140.with_(atr_closed_bar=True, use_avg_spread_for_mode=True, streak_reset_min_r=0.25)),
    ("+ sizing v141 (cap, equity)", v140.with_(atr_closed_bar=True, use_avg_spread_for_mode=True, streak_reset_min_r=0.25, sizing_mode="v141",
                                              allow_minlot_above_cap=False, size_on_equity=True)),
    ("+ guardia DD HWM (= v14.1 defaults)", EAParams()),
]
rows = {}
extra = {}
for name, p in steps:
    r = run_backtest(md, p, BrokerSpec(), DEPOSIT)
    m = compute_metrics(r.trades, DEPOSIT, r.equity.values, span)
    rows[name] = m
    mc = monte_carlo(r.trades, DEPOSIT, runs=5000, mode="bootstrap") if len(r.trades) > 10 else None
    extra[name] = {"skip_minlot": r.stats["skip_minlot"], "skip_pause": r.stats["skip_pause"], "dd_latches": r.stats["dd_latches"],
                   "mc_dd_p95": round(mc.dd_p95, 2) if mc else None}
tab = metrics_table(rows)
tab["skip_minlot"] = [extra[k]["skip_minlot"] for k in rows]
tab["skip_pause"] = [extra[k]["skip_pause"] for k in rows]
tab["dd_latches"] = [extra[k]["dd_latches"] for k in rows]
tab["mc_dd_p95"] = [extra[k]["mc_dd_p95"] for k in rows]
pd.set_option("display.width", 250)
print(f"Atribución acumulativa v14.0 → v14.1, depósito ${DEPOSIT:.0f}, {span} días\n")
print(tab.round(2).to_string())
