from __future__ import annotations

from dataclasses import replace

import pandas as pd

from ohlc_quant.analysis.metrics import compute_metrics, metrics_table
from ohlc_quant.data.bars import MarketData, build_market
from ohlc_quant.engine.backtest import run_backtest
from ohlc_quant.engine.params import BrokerSpec, EAParams, ServerClock
from ohlc_quant.engine.signals import SignalSet, all_signals


def _delayed(sig: SignalSet, seconds: int) -> SignalSet:
    return SignalSet(sig.t + seconds, sig.direction, sig.strength, sig.set_id, sig.atr, sig.trend)


def stress_suite(md: MarketData, p: EAParams, broker: BrokerSpec, deposit: float, start=None, end=None, m1_utc=None) -> pd.DataFrame:
    sig = all_signals(md, p)
    rows = {}

    def add(name, r):
        rows[name] = compute_metrics(r.trades, deposit, r.equity.values)

    add("base", run_backtest(md, p, broker, deposit, sig, True, start, end))
    add("path_optimista", run_backtest(md, p, broker, deposit, sig, False, start, end))
    add("spread_x0.5_raw", run_backtest(md, p, replace(broker, spread_multiplier=0.5), deposit, sig, True, start, end))
    add("spread_x1.5", run_backtest(md, p, replace(broker, spread_multiplier=1.5), deposit, sig, True, start, end))
    add("spread_x2", run_backtest(md, p, replace(broker, spread_multiplier=2.0), deposit, sig, True, start, end))
    add("spread_+20pts", run_backtest(md, p, replace(broker, spread_add_points=20), deposit, sig, True, start, end))
    add("slippage_10pts", run_backtest(md, p, replace(broker, slippage_points_fill=10), deposit, sig, True, start, end))
    add("slippage_30pts", run_backtest(md, p, replace(broker, slippage_points_fill=30), deposit, sig, True, start, end))
    add("comision_7$/lot", run_backtest(md, p, replace(broker, commission_per_lot=7.0), deposit, sig, True, start, end))
    add("latencia_1min", run_backtest(md, p, broker, deposit, _delayed(sig, 60), True, start, end))
    add("latencia_2min", run_backtest(md, p, broker, deposit, _delayed(sig, 120), True, start, end))
    add("stops_level_30", run_backtest(md, p, replace(broker, stops_level_points=30), deposit, sig, True, start, end))
    add("sin_PP", run_backtest(md, p.with_(use_progressive_protection=False), broker, deposit, sig, True, start, end))
    add("solo_fijo", run_backtest(md, p.with_(use_custom_pair=False), broker, deposit, None, True, start, end))
    add("solo_custom", run_backtest(md, p.with_(use_fixed_set=False), broker, deposit, None, True, start, end))
    add("sin_sesion", run_backtest(md, p.with_(use_session_filter=False), broker, deposit, None, True, start, end))
    add("sin_tendencia", run_backtest(md, p.with_(require_trend_alignment=False), broker, deposit, None, True, start, end))
    add("sin_mtf", run_backtest(md, p.with_(require_higher_tf_confirm=False), broker, deposit, None, True, start, end))
    add("cierre_viernes", run_backtest(md, p.with_(close_before_weekend=True, friday_entry_cutoff_hour=18), broker, deposit, None, True, start, end))
    if m1_utc is not None:
        for name, clock in (("reloj_UTC+0", ServerClock(0, "none")), ("reloj_UTC+2_sinDST", ServerClock(2, "none")), ("reloj_UTC+3_EU", ServerClock(2, "eu"))):
            md2 = build_market(m1_utc, clock)
            add(name, run_backtest(md2, p, broker, deposit, None, True, start, end))
    tab = metrics_table(rows)
    base = rows["base"]
    tab["exp_vs_base_pct"] = [round((m.expectancy / base.expectancy - 1) * 100, 1) if base.expectancy else None for m in rows.values()]
    return tab


def deposit_sweep(md: MarketData, p: EAParams, broker: BrokerSpec, deposits=(300, 500, 1000, 2000, 5000, 10000), start=None, end=None) -> pd.DataFrame:
    sig = all_signals(md, p)
    rows, skips = {}, []
    for d in deposits:
        r = run_backtest(md, p, broker, float(d), sig, True, start, end)
        rows[f"${d}"] = compute_metrics(r.trades, float(d), r.equity.values)
        skips.append(r.stats["skip_minlot"])
    tab = metrics_table(rows)
    tab["skip_minlot"] = skips
    return tab


def broker_sweep(md: MarketData, p: EAParams, deposit: float, start=None, end=None) -> pd.DataFrame:
    sig = all_signals(md, p)
    specs = {
        "raw_0.01lot_7$": BrokerSpec(commission_per_lot=7.0),
        "std_0.01lot_spread+15": BrokerSpec(spread_add_points=15),
        "micro_0.001lot": BrokerSpec(volume_min=0.001, volume_step=0.001),
        "cent_0.01lot_x100": BrokerSpec(tick_value=0.01),
    }
    rows = {}
    for k, b in specs.items():
        r = run_backtest(md, p, b, deposit, sig, True, start, end)
        rows[k] = compute_metrics(r.trades, deposit, r.equity.values)
    return metrics_table(rows)
