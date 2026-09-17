from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd

from ohlc_quant.engine.params import BrokerSpec, EAParams


@dataclass
class SizingResult:
    volume: float
    risk_money: float
    risk_pct: float
    skipped: bool
    reason: str


def calc_volume(sl_dist: float, risk_pct: float, balance: float, equity: float, p: EAParams, b: BrokerSpec) -> SizingResult:
    mppu = b.money_per_price_unit_per_lot()
    mrpl = sl_dist * mppu
    if mrpl <= 0:
        return SizingResult(0, 0, 0, True, "sl_dist<=0")
    step = b.volume_step or b.volume_min
    if p.sizing_mode == "v140":
        base = balance
        vol = np.floor(balance * risk_pct / 100 / mrpl / step + 1e-9) * step
        vol = max(vol, b.volume_min)
        vol = min(vol, b.volume_max)
        return SizingResult(vol, vol * mrpl, vol * mrpl / base * 100, False, "v140")
    base = min(balance, equity) if p.size_on_equity else balance
    cap = base * p.hard_risk_cap_pct / 100
    vol = np.floor(base * min(risk_pct, p.hard_risk_cap_pct) / 100 / mrpl / step + 1e-9) * step
    if vol < b.volume_min:
        if b.volume_min * mrpl > cap and not p.allow_minlot_above_cap:
            return SizingResult(0, b.volume_min * mrpl, b.volume_min * mrpl / base * 100, True, "minlot>cap")
        vol = b.volume_min
    cap_vol = np.floor(cap / mrpl / step + 1e-9) * step
    if cap_vol >= b.volume_min and vol > cap_vol:
        vol = cap_vol
    vol = min(vol, b.volume_max)
    money = vol * mrpl
    if money > cap + 1e-8 and not p.allow_minlot_above_cap:
        return SizingResult(0, money, money / base * 100, True, "real>cap")
    return SizingResult(vol, money, money / base * 100, False, "ok")


def capital_required(sl_dist: float, risk_pct: float, b: BrokerSpec) -> float:
    return b.volume_min * sl_dist * b.money_per_price_unit_per_lot() / (risk_pct / 100)


def capital_table(atr_values: np.ndarray, p: EAParams, b: BrokerSpec, risk_levels=(0.5, 1.0, 1.25, 2.5)) -> pd.DataFrame:
    qs = np.quantile(atr_values[~np.isnan(atr_values)], [0.1, 0.25, 0.5, 0.75, 0.9])
    rows = []
    for q, a in zip(("p10", "p25", "p50", "p75", "p90"), qs):
        sl = a * p.atr_sl_mult
        row = {"atr_quantil": q, "atr": a, "sl_dist": sl, "riesgo_minlot_$": b.volume_min * sl * b.money_per_price_unit_per_lot()}
        for r in risk_levels:
            row[f"capital_{r}%"] = capital_required(sl, r, b)
        rows.append(row)
    return pd.DataFrame(rows)


def min_lot_risk_profile(trades: pd.DataFrame, deposit: float) -> dict:
    if len(trades) == 0:
        return {}
    losses = trades[trades["pnl"] < 0]
    rp = losses["risk_pct_real"].dropna() if "risk_pct_real" in losses else (-losses["pnl"] / losses["balance_before"] * 100)
    return {"n_perdedoras": int(len(losses)), "riesgo_real_mediana_pct": float(rp.median()) if len(rp) else 0.0,
            "riesgo_real_p90_pct": float(rp.quantile(0.9)) if len(rp) else 0.0, "riesgo_real_max_pct": float(rp.max()) if len(rp) else 0.0,
            "volumenes": sorted(set(np.round(trades["vol"], 3))) if "vol" in trades else []}
