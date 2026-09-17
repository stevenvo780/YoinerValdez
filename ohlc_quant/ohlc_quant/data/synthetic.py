from __future__ import annotations

import numpy as np
import pandas as pd


def synthetic_m1(days: int = 120, start: str = "2024-01-01", seed: int = 0, price0: float = 2300.0,
                 vol_annual: float = 0.16, regime_switch: float = 0.02, jump_prob: float = 0.0005, jump_scale: float = 0.004,
                 spread_base: float = 0.25, weekend_gap_scale: float = 0.004, trend_drift: float = 0.0) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    idx = pd.date_range(start, periods=days * 1440, freq="1min", tz="UTC")
    wd = idx.weekday.values
    hour = idx.hour.values
    open_mask = ~((wd == 5) | ((wd == 4) & (hour >= 22)) | ((wd == 6) & (hour < 22)))
    n = len(idx)
    per_min = vol_annual / np.sqrt(252 * 1440)
    regime = np.ones(n)
    state = 1.0
    for i in range(n):
        if rng.random() < regime_switch / 1440:
            state = rng.choice([0.5, 1.0, 1.8, 2.8])
        regime[i] = state
    hod = 1.0 + 0.6 * np.sin((hour - 8) / 24 * 2 * np.pi).clip(-0.5, 1.0)
    sig = per_min * regime * hod
    r = rng.standard_normal(n) * sig + trend_drift / (252 * 1440)
    jumps = rng.random(n) < jump_prob
    r[jumps] += rng.standard_normal(jumps.sum()) * jump_scale
    gap = np.zeros(n)
    sunday_open = (wd == 6) & (hour == 22) & (idx.minute.values == 0)
    gap[sunday_open] = rng.standard_normal(sunday_open.sum()) * weekend_gap_scale
    r += gap
    logp = np.log(price0) + np.cumsum(r)
    close = np.exp(logp)
    o = np.concatenate([[price0], close[:-1]])
    intrabar = np.abs(rng.standard_normal(n)) * sig * close * 0.8
    h = np.maximum(o, close) + intrabar
    l = np.minimum(o, close) - intrabar
    spread = spread_base * (1.0 + 0.8 * (hour >= 21) + 1.5 * (hour < 1) + 0.3 * rng.random(n)) * (1 + 0.5 * (regime - 1).clip(0))
    df = pd.DataFrame({"open": o, "high": h, "low": l, "close": close, "ask_open": o + spread, "ask_close": close + spread,
                       "spread_mean": spread, "spread_max": spread * 1.3, "ticks": 100}, index=idx)
    return df[open_mask]
