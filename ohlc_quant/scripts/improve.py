from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from ohlc_quant.analysis.metrics import compute_metrics
from ohlc_quant.analysis.montecarlo import monte_carlo
from ohlc_quant.analysis.walkforward import evaluate_many
from ohlc_quant.data.bars import build_market
from ohlc_quant.data.dukascopy import load_m1
from ohlc_quant.engine.backtest import run_backtest
from ohlc_quant.engine.params import BrokerSpec, EAParams, ServerClock

DEPOSIT = float(sys.argv[1]) if len(sys.argv) > 1 else 5000.0
IS_END = "2025-06-01"
m1 = load_m1("XAUUSD", ROOT / "data" / "bars")
md = build_market(m1, ServerClock(2, "us"))
B = BrokerSpec()
base = EAParams()
explicit = dict(atr_sl_mult=2.2, atr_tp_mult=4.0, high_spread_threshold=75.0)
r5 = dict(custom_min_signal_strength=5, trend_lookback=20)
CANDS = {
    "R0_base": base,
    "R5": base.with_(**r5),
    "R5+lookback10": base.with_(**r5, structure_lookback=10),
    "R5+trend24": base.with_(custom_min_signal_strength=5, trend_lookback=24),
    "R5+sinExp": base.with_(**r5, prefer_expansion_break=False),
    "R5+riesgo0.5-1.5": base.with_(**r5, min_risk_pct=0.5, max_risk_pct=1.5),
    "R5+riesgoFijo1.0": base.with_(**r5, min_risk_pct=1.0, max_risk_pct=1.0),
    "R5+maxTrades3": base.with_(**r5, max_trades_per_day=3),
    "R5+wick0.42": base.with_(**r5, max_against_wick_ratio=0.42),
    "R5+customM15": base.with_(**r5, tf_fast="M15"),
    "R5+str5fijo": base.with_(**r5, min_signal_strength=5),
}
years = sorted(set(md.m1.index.year))
rows = []
for name, p in CANDS.items():
    full = run_backtest(md, p, B, DEPOSIT)
    mf = compute_metrics(full.trades, DEPOSIT, full.equity.values)
    mis = compute_metrics(*[(r.trades, DEPOSIT, r.equity.values) for r in [run_backtest(md, p, B, DEPOSIT, end=IS_END)]][0])
    r_oos = run_backtest(md, p, B, DEPOSIT, start=IS_END)
    moos = compute_metrics(r_oos.trades, DEPOSIT, r_oos.equity.values)
    mc = monte_carlo(full.trades, DEPOSIT, runs=5000, mode="bootstrap") if len(full.trades) > 10 else None
    row = {"cand": name, "n": mf.n, "net": mf.net, "pf": mf.profit_factor, "exp": mf.expectancy, "dd": mf.max_dd_pct,
           "ret/dd": mf.return_pct / max(mf.max_dd_pct, 0.1), "mc_dd95": mc.dd_p95 if mc else np.nan,
           "IS_pf": mis.profit_factor, "OOS_n": moos.n, "OOS_pf": moos.profit_factor, "OOS_net": moos.net, "OOS_dd": moos.max_dd_pct}
    for y in years:
        r = run_backtest(md, p, B, DEPOSIT, start=f"{y}-01-01", end=f"{y + 1}-01-01")
        row[f"pf{y}"] = compute_metrics(r.trades, DEPOSIT, r.equity.values).profit_factor
    rows.append(row)
    print(".", end="", flush=True)
df = pd.DataFrame(rows).set_index("cand")
win_rows = []
edges = pd.date_range("2023-01-01", "2026-11-01", freq="2MS")
for name, p in CANDS.items():
    nets = []
    for a, b in zip(edges[:-1], edges[1:]):
        r = run_backtest(md, p, B, DEPOSIT, start=str(a), end=str(b))
        nets.append(r.trades["pnl"].sum())
    nets = np.array(nets)
    win_rows.append({"cand": name, "ventanas": len(nets), "pct_positivas": (nets > 0).mean() * 100, "peor_ventana": nets.min(), "mediana": np.median(nets), "p10": np.quantile(nets, 0.1)})
wdf = pd.DataFrame(win_rows).set_index("cand")
df = df.join(wdf)
pd.set_option("display.width", 260)
print(f"\nDepósito ${DEPOSIT:.0f} · IS hasta {IS_END} · OOS desde {IS_END}\n")
print(df.round(2).to_string())
df.to_csv(ROOT / "reports" / f"improve_candidates_{sys.argv[2] if len(sys.argv) > 2 else 'r2'}.csv")
