import numpy as np
import pandas as pd
import pytest
from hypothesis import given, settings, strategies as st

from ohlc_quant.data.bars import build_market
from ohlc_quant.engine.backtest import run_backtest
from ohlc_quant.engine.params import BrokerSpec, EAParams, ServerClock
from ohlc_quant.engine.signals import SignalSet
from tests.conftest import make_m1


def _md(prices, **kw):
    m1 = make_m1(prices, **kw)
    m1.index = m1.index.tz_localize("UTC")
    return build_market(m1, ServerClock(0, "none"))


def _sig(md, t_idx, direction=1, strength=6, atr=5.0, set_id=0):
    t = md.m1_t[t_idx]
    return SignalSet(np.array([t]), np.array([direction], np.int8), np.array([strength], np.int8), np.array([set_id], np.int8),
                     np.array([atr]), np.array([1], np.int8))


def _p(**kw):
    base = dict(use_progressive_protection=False, use_session_filter=False, use_daily_loss_limit=False, use_loss_streak_guard=False,
                use_total_drawdown_limit=False, sizing_mode="v141", allow_minlot_above_cap=True)
    base.update(kw)
    return EAParams(**base)


def test_buy_hits_tp():
    prices = [2000.0] * 5 + [2000 + i * 2 for i in range(30)]
    md = _md(prices)
    r = run_backtest(md, _p(), BrokerSpec(), 10000.0, _sig(md, 5, atr=5.0))
    assert len(r.trades) == 1
    t = r.trades.iloc[0]
    assert t["exit"] == "TP" and t["type"] == "buy"
    assert abs((t["tp0"] - t["open_price"]) - 5.0 * 3.2 * 1.35) < 1e-9
    assert t["pnl"] > 0


def test_buy_hits_sl_pessimistic_and_gap():
    prices = [2000.0] * 5 + [1990.0] * 5
    md = _md(prices)
    r = run_backtest(md, _p(atr_sl_mult=0.5, min_sl_points=1), BrokerSpec(), 10000.0, _sig(md, 4, atr=2.0))
    t = r.trades.iloc[0]
    assert t["exit"] == "SL"
    assert t["close_price"] <= t["sl0"]
    assert t["close_time"] == pd.Timestamp("2024-03-04 08:04")
    assert t["pnl"] < 0


def test_sell_uses_ask_and_spread():
    prices = [2000.0] * 5 + [2000 - i * 2 for i in range(30)]
    md = _md(prices, spread=0.5)
    r = run_backtest(md, _p(), BrokerSpec(), 10000.0, _sig(md, 5, direction=-1, atr=5.0))
    t = r.trades.iloc[0]
    assert t["type"] == "sell" and t["exit"] == "TP"
    assert t["open_price"] == pytest.approx(2000.0)


def test_one_position_at_a_time_and_priority():
    prices = [2000.0] * 40
    md = _md(prices)
    T = md.m1_t[5]
    sig = SignalSet(np.array([T, T, T + 60]), np.array([1, -1, 1], np.int8), np.array([6, 6, 6], np.int8), np.array([1, 0, 0], np.int8),
                    np.array([5.0, 5.0, 5.0]), np.array([1, 1, 1], np.int8))
    order = np.lexsort((sig.set_id, sig.t))
    sig = SignalSet(sig.t[order], sig.direction[order], sig.strength[order], sig.set_id[order], sig.atr[order], sig.trend[order])
    r = run_backtest(md, _p(cooldown_seconds=0), BrokerSpec(), 10000.0, sig)
    assert len(r.trades) == 1
    assert r.trades.iloc[0]["set"] == "FIJO" and r.trades.iloc[0]["type"] == "sell"
    assert r.stats["skip_busy"] == 2


def test_v141_skips_when_minlot_exceeds_cap():
    prices = [2000.0] * 40
    md = _md(prices)
    p = _p(allow_minlot_above_cap=False, hard_risk_cap_pct=2.5)
    r = run_backtest(md, p, BrokerSpec(), 300.0, _sig(md, 5, atr=10.0))
    assert len(r.trades) == 0 and r.stats["skip_minlot"] == 1
    r2 = run_backtest(md, p, BrokerSpec(), 3000.0, _sig(md, 5, atr=10.0))
    assert len(r2.trades) == 1 and r2.trades.iloc[0]["risk_pct_real"] <= 2.5


def test_v140_forces_minlot():
    prices = [2000.0] * 40
    md = _md(prices)
    r = run_backtest(md, EAParams.v140().with_(use_session_filter=False), BrokerSpec(), 300.0, _sig(md, 5, atr=10.0))
    assert len(r.trades) == 1 and r.trades.iloc[0]["vol"] == 0.01
    assert r.trades.iloc[0]["risk_pct_real"] > 2.5


@settings(max_examples=60, deadline=None)
@given(st.floats(0.5, 40.0), st.floats(300.0, 50000.0), st.integers(4, 6), st.floats(0.1, 2.5), st.floats(0.5, 5.0))
def test_v141_real_risk_never_exceeds_cap(atr, deposit, strength, max_risk, cap):
    cap = max(cap, max_risk)
    prices = [2000.0] * 40
    md = _md(prices)
    p = _p(allow_minlot_above_cap=False, min_risk_pct=min(0.25, max_risk), max_risk_pct=max_risk, hard_risk_cap_pct=cap)
    r = run_backtest(md, p, BrokerSpec(), deposit, _sig(md, 5, strength=strength, atr=atr))
    if len(r.trades):
        assert r.trades.iloc[0]["risk_pct_real"] <= cap + 1e-6


def test_equity_guard_flattens_and_latches():
    prices = [2000.0] * 5 + [2000 - i * 1.0 for i in range(1, 60)]
    md = _md(prices)
    p = _p(use_total_drawdown_limit=True, max_total_drawdown_pct=5.0, dd_flatten_positions=True, dd_pause_hours=0, atr_sl_mult=20.0)
    T = md.m1_t
    sig = SignalSet(np.array([T[5], T[62]]), np.array([1, 1], np.int8), np.array([6, 6], np.int8), np.array([0, 0], np.int8),
                    np.array([5.0, 5.0]), np.array([1, 1], np.int8))
    r = run_backtest(md, p.with_(max_risk_pct=2.5, hard_risk_cap_pct=2.5), BrokerSpec(), 1000.0, sig)
    assert len(r.trades) == 1 and r.trades.iloc[0]["exit"] == "DD_FLATTEN"
    assert r.stats["dd_latches"] == 1 and r.stats["skip_dd"] == 1
    assert r.equity.min() >= 1000.0 * (1 - 0.05) - 5.0


def test_daily_loss_blocks_new_entries():
    prices = [2000.0] * 5 + [1990.0] * 5 + [1990.0] * 30
    md = _md(prices)
    p = _p(use_daily_loss_limit=True, max_daily_loss_pct=0.3, cooldown_seconds=0)
    T = md.m1_t
    sig = SignalSet(np.array([T[4], T[20]]), np.array([1, 1], np.int8), np.array([6, 6], np.int8), np.array([0, 0], np.int8),
                    np.array([2.0, 2.0]), np.array([1, 1], np.int8))
    r = run_backtest(md, p.with_(max_risk_pct=2.5, hard_risk_cap_pct=2.5), BrokerSpec(), 1000.0, sig)
    assert len(r.trades) == 1 and r.stats["skip_daily"] == 1


def test_streak_pause_and_reset_threshold():
    prices = []
    for _ in range(3):
        prices += [2000.0] * 3 + [1990.0] * 3
    prices += [2000.0] * 30
    md = _md(prices)
    T = md.m1_t
    times = np.array([T[0], T[6], T[12], T[18]])
    sig = SignalSet(times, np.ones(4, np.int8), np.full(4, 6, np.int8), np.zeros(4, np.int8), np.full(4, 2.0), np.ones(4, np.int8))
    p = _p(use_loss_streak_guard=True, max_consecutive_losses=3, loss_streak_pause_minutes=60, cooldown_seconds=0, max_risk_pct=1.0, hard_risk_cap_pct=2.5)
    r = run_backtest(md, p, BrokerSpec(), 5000.0, sig)
    assert len(r.trades) == 3 and r.stats["skip_pause"] == 1


def test_max_trades_per_day_and_cooldown():
    prices = [2000.0, 1999.0] * 100
    md = _md(prices, spread=0.0)
    T = md.m1_t
    times = T[np.arange(0, 100, 10)]
    n = len(times)
    sig = SignalSet(times, np.ones(n, np.int8), np.full(n, 6, np.int8), np.zeros(n, np.int8), np.full(n, 0.2), np.ones(n, np.int8))
    p = _p(max_trades_per_day=2, cooldown_seconds=0, atr_sl_mult=0.2, atr_tp_mult=0.2, min_sl_points=1)
    r = run_backtest(md, p, BrokerSpec(), 5000.0, sig)
    assert r.stats["skip_maxday"] >= 1
    assert len(r.trades) <= 2


def test_spread_cap_skips():
    prices = [2000.0] * 40
    md = _md(prices, spread=1.0)
    r = run_backtest(md, _p(max_spread_points=50), BrokerSpec(), 5000.0, _sig(md, 5, atr=5.0))
    assert len(r.trades) == 0 and r.stats["skip_spread"] == 1


def test_progressive_protection_moves_sl_and_locks_profit():
    prices = [2000.0] * 5 + [2000 + i * 0.5 for i in range(1, 60)] + [2000.0] * 40
    md = _md(prices)
    p = _p(use_progressive_protection=True, atr_tp_mult=50.0)
    r = run_backtest(md, p, BrokerSpec(), 10000.0, _sig(md, 5, atr=5.0, strength=4))
    t = r.trades.iloc[0]
    assert r.stats["pp_mods"] > 0
    assert t["exit"] == "SL" and t["pnl"] > 0


def test_weekend_close():
    m1 = make_m1([2000.0] * 600, start="2024-03-08 18:00")
    m1.index = m1.index.tz_localize("UTC")
    md = build_market(m1, ServerClock(0, "none"))
    p = _p(close_before_weekend=True, weekend_close_hour=21, atr_tp_mult=50.0, atr_sl_mult=50.0)
    r = run_backtest(md, p, BrokerSpec(), 10000.0, _sig(md, 5, atr=1.0))
    assert len(r.trades) == 1 and r.trades.iloc[0]["exit"] == "WEEKEND"
    assert pd.Timestamp(r.trades.iloc[0]["close_time"]).hour == 21


def test_equity_curve_consistency(md_syn):
    r = run_backtest(md_syn, EAParams.v140(), BrokerSpec(), 300.0)
    assert len(r.balance) == len(md_syn.m1)
    assert abs(r.balance.iloc[-1] - (300.0 + r.trades["pnl"].sum())) < 1e-6
    assert (r.balance.diff().fillna(0).abs() > 0).sum() <= len(r.trades)


def test_commission_reduces_pnl(md_syn):
    p = EAParams.v140()
    a = run_backtest(md_syn, p, BrokerSpec(), 300.0)
    b = run_backtest(md_syn, p, BrokerSpec(commission_per_lot=7.0), 300.0)
    assert len(a.trades) == len(b.trades)
    assert b.trades["pnl"].sum() < a.trades["pnl"].sum()
    np.testing.assert_allclose(b.trades["commission"], 7.0 * b.trades["vol"])


def test_backtest_window_subset(md_syn):
    p = EAParams.v140()
    full = run_backtest(md_syn, p, BrokerSpec(), 300.0)
    mid = md_syn.m1.index[len(md_syn.m1) // 2]
    part = run_backtest(md_syn, p, BrokerSpec(), 300.0, start=str(mid))
    assert part.trades["open_time"].min() >= mid
    assert len(part.balance) < len(full.balance)
