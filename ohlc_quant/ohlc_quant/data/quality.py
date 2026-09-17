from __future__ import annotations

import numpy as np
import pandas as pd


def data_quality(m1: pd.DataFrame) -> dict:
    idx = m1.index
    if idx.tz is None:
        idx = idx.tz_localize("UTC")
    diffs = np.diff(idx.values.astype("datetime64[s]").astype(np.int64))
    wd = idx.weekday.values
    hour = idx.hour.values
    weekend_gap = (wd[:-1] == 4) & (diffs > 3600 * 20)
    big_gaps = [{"desde": str(idx[i]), "minutos": int(diffs[i] // 60)} for i in np.where((diffs > 3600 * 3) & ~weekend_gap)[0][:20]]
    bad = m1[(m1["high"] < m1["low"]) | (m1["high"] < m1["open"]) | (m1["low"] > m1["close"]) | (m1["close"] <= 0)]
    sp = m1["spread_mean"].dropna()
    days = pd.Series(1, index=idx).resample("1D").sum()
    trading_days = days[days > 0]
    return {
        "inicio": str(idx.min()), "fin": str(idx.max()), "velas_m1": int(len(m1)), "dias_con_datos": int(len(trading_days)),
        "velas_por_dia_mediana": float(trading_days.median()), "dias_incompletos(<1000_velas,_sin_domingos)": [str(d.date()) for d in trading_days[(trading_days < 1000) & (trading_days.index.weekday != 6)].index[:30]],
        "huecos_>3h_fuera_de_finde": big_gaps, "n_huecos_>3h": int(len(big_gaps)),
        "velas_ohlc_invalidas": int(len(bad)), "duplicados": int(idx.duplicated().sum()),
        "spread_pts_p50": float(sp.quantile(0.5) * 100), "spread_pts_p90": float(sp.quantile(0.9) * 100), "spread_pts_p99": float(sp.quantile(0.99) * 100),
        "spread_pts_max": float(sp.max() * 100), "velas_spread_0": int((sp <= 0).sum()),
        "velas_sabado": int((wd == 5).sum()), "velas_domingo_antes_22": int(((wd == 6) & (hour < 21)).sum()),
        "rango_m1_p99_pts": float(((m1["high"] - m1["low"]) * 100).quantile(0.99)), "precio_min": float(m1["low"].min()), "precio_max": float(m1["high"].max()),
    }
