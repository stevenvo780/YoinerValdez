from __future__ import annotations

import itertools
import os
from concurrent.futures import ProcessPoolExecutor
from dataclasses import dataclass

import numpy as np
import pandas as pd

from ohlc_quant.analysis.metrics import Metrics, compute_metrics
from ohlc_quant.data.bars import MarketData
from ohlc_quant.engine.backtest import run_backtest
from ohlc_quant.engine.params import BrokerSpec, EAParams

_MD: MarketData | None = None
_BROKER: BrokerSpec = BrokerSpec()
_DEPOSIT: float = 300.0


def _init(md, broker, deposit):
    global _MD, _BROKER, _DEPOSIT
    _MD, _BROKER, _DEPOSIT = md, broker, deposit


def _eval(args):
    p, start, end = args
    r = run_backtest(_MD, p, _BROKER, _DEPOSIT, start=start, end=end)
    span = (pd.Timestamp(end) - pd.Timestamp(start)).days if start and end else None
    m = compute_metrics(r.trades, _DEPOSIT, r.equity.values, span)
    return p, m


def param_grid(base: EAParams, grid: dict[str, list]) -> list[EAParams]:
    keys = list(grid)
    return [base.with_(**dict(zip(keys, combo))) for combo in itertools.product(*[grid[k] for k in keys])]


def evaluate_many(md: MarketData, params: list[EAParams], broker: BrokerSpec, deposit: float,
                  start=None, end=None, workers: int | None = None) -> list[tuple[EAParams, Metrics]]:
    workers = workers or max(1, min(os.cpu_count() or 1, len(params)))
    jobs = [(p, start, end) for p in params]
    if workers == 1 or len(params) == 1:
        _init(md, broker, deposit)
        return [_eval(j) for j in jobs]
    with ProcessPoolExecutor(max_workers=workers, initializer=_init, initargs=(md, broker, deposit)) as ex:
        return list(ex.map(_eval, jobs, chunksize=max(1, len(jobs) // (workers * 4))))


def objective_value(m: Metrics, objective: str = "expectancy_x_n") -> float:
    if m.n == 0:
        return -1e9
    if objective == "net":
        return m.net
    if objective == "profit_factor":
        return min(m.profit_factor, 10.0)
    if objective == "expectancy":
        return m.expectancy
    if objective == "recovery":
        return min(m.recovery_factor, 50.0)
    if objective == "expectancy_x_n":
        return m.expectancy * np.sqrt(m.n)
    if objective == "return_dd":
        return m.return_pct / max(m.max_dd_pct, 1.0)
    raise ValueError(objective)


@dataclass
class WFWindow:
    is_start: pd.Timestamp
    is_end: pd.Timestamp
    oos_end: pd.Timestamp
    best_params: dict
    is_metrics: Metrics
    oos_metrics: Metrics
    efficiency: float


def walk_forward(md: MarketData, base: EAParams, grid: dict[str, list], broker: BrokerSpec, deposit: float,
                 is_months: int = 6, oos_months: int = 2, step_months: int = 2, anchored: bool = False,
                 objective: str = "expectancy_x_n", workers: int | None = None, min_is_trades: int = 20) -> list[WFWindow]:
    t0 = md.m1.index.min().normalize()
    t_end = md.m1.index.max()
    params = param_grid(base, grid)
    windows: list[WFWindow] = []
    is_start = t0
    is_end = is_start + pd.DateOffset(months=is_months)
    while is_end + pd.DateOffset(months=oos_months) <= t_end + pd.Timedelta(days=1):
        oos_end = is_end + pd.DateOffset(months=oos_months)
        res = evaluate_many(md, params, broker, deposit, str(is_start), str(is_end), workers)
        scored = [(objective_value(m, objective) if m.n >= min_is_trades else -1e9, p, m) for p, m in res]
        scored.sort(key=lambda x: x[0], reverse=True)
        _, bp, bm = scored[0]
        (_, om), = evaluate_many(md, [bp], broker, deposit, str(is_end), str(oos_end), 1)
        eff = (om.expectancy / bm.expectancy) if bm.expectancy > 0 and om.n > 0 else (0.0 if om.n == 0 else -1.0)
        eff = float(np.clip(eff, -3.0, 3.0))
        diff = {k: getattr(bp, k) for k in grid}
        windows.append(WFWindow(is_start, is_end, oos_end, diff, bm, om, float(eff)))
        if not anchored:
            is_start = is_start + pd.DateOffset(months=step_months)
        is_end = is_end + pd.DateOffset(months=step_months)
    return windows


def wf_table(windows: list[WFWindow]) -> pd.DataFrame:
    rows = []
    for w in windows:
        rows.append({"is_start": w.is_start.date(), "is_end": w.is_end.date(), "oos_end": w.oos_end.date(), **{f"p:{k}": v for k, v in w.best_params.items()},
                     "is_n": w.is_metrics.n, "is_pf": round(w.is_metrics.profit_factor, 2), "is_exp": round(w.is_metrics.expectancy, 2),
                     "oos_n": w.oos_metrics.n, "oos_pf": round(w.oos_metrics.profit_factor, 2), "oos_exp": round(w.oos_metrics.expectancy, 2),
                     "oos_net": round(w.oos_metrics.net, 2), "oos_dd_pct": round(w.oos_metrics.max_dd_pct, 2), "efficiency": round(w.efficiency, 2)})
    return pd.DataFrame(rows)


def wf_summary(windows: list[WFWindow]) -> dict:
    if not windows:
        return {}
    eff = np.array([w.efficiency for w in windows])
    oos_net = sum(w.oos_metrics.net for w in windows)
    oos_n = sum(w.oos_metrics.n for w in windows)
    gp = sum(w.oos_metrics.gross_profit for w in windows); gl = sum(w.oos_metrics.gross_loss for w in windows)
    return {"ventanas": len(windows), "eficiencia_media": float(eff.mean()), "eficiencia_mediana": float(np.median(eff)),
            "pct_ventanas_eff>=0.5": float((eff >= 0.5).mean() * 100),
            "pct_ventanas_oos_positivas": float(np.mean([w.oos_metrics.net > 0 for w in windows]) * 100),
            "oos_neto_total": float(oos_net), "oos_trades": int(oos_n), "oos_pf_concatenado": float(gp / gl) if gl > 0 else float("inf"),
            "estabilidad_params": _param_stability(windows)}


def _param_stability(windows: list[WFWindow]) -> dict:
    out = {}
    keys = windows[0].best_params.keys()
    for k in keys:
        vals = [w.best_params[k] for w in windows]
        out[k] = {"distintos": len(set(vals)), "moda": max(set(vals), key=vals.count)}
    return out


def oos_split(md: MarketData, oos_fraction: float = 0.3) -> tuple[tuple[str, str], tuple[str, str]]:
    t0 = md.m1.index.min(); t1 = md.m1.index.max()
    cut = t0 + (t1 - t0) * (1 - oos_fraction)
    return (str(t0), str(cut)), (str(cut), str(t1 + pd.Timedelta(minutes=1)))
