from __future__ import annotations

import itertools
import json
import sys
import time
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from ohlc_quant.analysis.walkforward import evaluate_many
from ohlc_quant.data.bars import build_market
from ohlc_quant.data.dukascopy import load_m1
from ohlc_quant.engine.params import BrokerSpec, EAParams, ServerClock

GRID = {
    "structure_lookback": [8, 10, 12, 14, 16, 20],
    "min_breakout_atr_mult": [0.15, 0.22, 0.28, 0.35, 0.45],
    "min_body_ratio": [0.45, 0.55, 0.65],
    "atr_sl_mult": [1.4, 1.8, 2.2, 2.6],
    "atr_tp_mult": [2.4, 3.2, 4.0],
    "trend_lookback": [20, 28, 40],
    "min_signal_strength": [3, 4, 5],
}


def main():
    start = sys.argv[1] if len(sys.argv) > 1 else None
    end = sys.argv[2] if len(sys.argv) > 2 else None
    preset = sys.argv[3] if len(sys.argv) > 3 else "lean"
    deposit = float(sys.argv[4]) if len(sys.argv) > 4 else 3000.0
    out = ROOT / "reports" / "grid"
    out.mkdir(parents=True, exist_ok=True)
    m1 = load_m1("XAUUSD", ROOT / "data" / "bars")
    md = build_market(m1, ServerClock(2, "us"))
    base = {"lean": EAParams.lean(), "v141": EAParams(), "v140": EAParams.v140()}[preset]
    keys = list(GRID)
    combos = list(itertools.product(*[GRID[k] for k in keys]))
    params = [base.with_(**dict(zip(keys, c))) for c in combos]
    print(f"{len(params)} combinaciones · {start} → {end} · preset {preset} · depósito {deposit}", flush=True)
    t0 = time.time()
    res = evaluate_many(md, params, BrokerSpec(), deposit, start, end)
    rows = [{**{k: getattr(p, k) for k in keys}, **m.as_dict()} for p, m in res]
    df = pd.DataFrame(rows)
    df.to_csv(out / f"grid_{preset}_{(start or 'all')[:10]}_{(end or 'all')[:10]}.csv", index=False)
    print(f"tiempo {time.time() - t0:.0f}s", flush=True)
    ok = df[df["n"] >= 30]
    print("\nTop 15 por expectancy (n>=30):")
    print(ok.sort_values("expectancy", ascending=False).head(15)[keys + ["n", "net", "profit_factor", "expectancy", "max_dd_pct"]].to_string(index=False))
    print("\nDistribución global: % combinaciones con PF>1:", round((df["profit_factor"] > 1).mean() * 100, 1), "| mediana PF:", round(df["profit_factor"].median(), 2),
          "| mediana n:", df["n"].median())
    for k in keys:
        g = ok.groupby(k)["expectancy"].agg(["median", "mean", "count"]).round(2)
        print(f"\n{k}:\n{g.to_string()}")


if __name__ == "__main__":
    main()
