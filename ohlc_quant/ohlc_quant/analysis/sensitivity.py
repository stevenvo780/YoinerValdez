from __future__ import annotations

import pandas as pd

from ohlc_quant.analysis.walkforward import evaluate_many
from ohlc_quant.data.bars import MarketData
from ohlc_quant.engine.params import BrokerSpec, EAParams

NUMERIC_CORE = ["structure_lookback", "min_breakout_atr_mult", "min_body_ratio", "max_against_wick_ratio", "atr_sl_mult", "atr_tp_mult",
                "trend_lookback", "pp_stage2_r", "pp_trail_start_r", "session_start_hour", "session_end_hour", "min_signal_strength"]


def _perturb(base: EAParams, name: str, frac: float):
    v = getattr(base, name)
    if isinstance(v, bool):
        return None
    if isinstance(v, int):
        nv = max(1, int(round(v * (1 + frac))))
        if nv == v:
            nv = v + (1 if frac > 0 else -1)
        if name == "min_signal_strength":
            nv = min(6, max(1, nv))
        if name in ("session_start_hour", "session_end_hour"):
            nv = min(24, max(0, nv))
        return nv
    return v * (1 + frac)


def one_at_a_time(md: MarketData, base: EAParams, broker: BrokerSpec, deposit: float, names=NUMERIC_CORE,
                  fracs=(-0.2, -0.1, 0.1, 0.2), start=None, end=None, workers=None) -> pd.DataFrame:
    variants = [("base", None, base)]
    for n in names:
        for f in fracs:
            nv = _perturb(base, n, f)
            if nv is None:
                continue
            try:
                variants.append((n, f, base.with_(**{n: nv})))
            except Exception:
                continue
    res = evaluate_many(md, [v[2] for v in variants], broker, deposit, start, end, workers)
    base_m = res[0][1]
    rows = []
    for (name, frac, p), (_, m) in zip(variants, res):
        rows.append({"param": name, "delta": frac, "valor": getattr(p, name) if name != "base" else None, "n": m.n, "net": round(m.net, 2),
                     "pf": round(m.profit_factor, 2), "expectancy": round(m.expectancy, 2), "max_dd_pct": round(m.max_dd_pct, 2),
                     "exp_vs_base_pct": round((m.expectancy / base_m.expectancy - 1) * 100, 1) if base_m.expectancy else None})
    return pd.DataFrame(rows)


def grid_2d(md: MarketData, base: EAParams, broker: BrokerSpec, deposit: float, xname: str, xvals, yname: str, yvals,
            metric: str = "expectancy", start=None, end=None, workers=None) -> pd.DataFrame:
    params, keys = [], []
    for x in xvals:
        for y in yvals:
            params.append(base.with_(**{xname: x, yname: y})); keys.append((x, y))
    res = evaluate_many(md, params, broker, deposit, start, end, workers)
    tab = pd.DataFrame(index=list(yvals), columns=list(xvals), dtype=float)
    for (x, y), (_, m) in zip(keys, res):
        tab.loc[y, x] = getattr(m, metric)
    tab.index.name = yname; tab.columns.name = xname
    return tab


def plateau_score(tab: pd.DataFrame) -> float:
    v = tab.to_numpy(dtype=float)
    if v.size == 0:
        return 0.0
    best = v.max()
    if best <= 0:
        return 0.0
    return float((v >= 0.5 * best).mean())
