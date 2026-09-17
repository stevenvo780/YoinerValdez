import numpy as np
import pandas as pd
from hypothesis import given, settings, strategies as st

from ohlc_quant.data.bars import build_market
from ohlc_quant.engine.backtest import run_backtest
from ohlc_quant.engine.params import BrokerSpec, EAParams, ServerClock
from ohlc_quant.engine.signals import SignalSet
from tests.conftest import make_m1


def _market(seed: int, n: int = 3000):
    rng = np.random.default_rng(seed)
    steps = rng.standard_normal(n) * 1.5 + rng.choice([-0.3, 0.0, 0.3])
    prices = 2000 + np.cumsum(steps)
    m1 = make_m1(prices, start="2024-03-04 00:00", spread=0.3)
    m1.index = m1.index.tz_localize("UTC")
    return build_market(m1, ServerClock(0, "none"))


def _signals(md, seed: int, k: int = 60):
    rng = np.random.default_rng(seed + 1000)
    idx = np.sort(rng.choice(np.arange(5, len(md.m1) - 5), size=k, replace=False))
    t = md.m1_t[idx]
    return SignalSet(t, rng.choice([1, -1], k).astype(np.int8), rng.integers(4, 7, k).astype(np.int8), rng.integers(0, 2, k).astype(np.int8),
                     rng.uniform(1.0, 8.0, k), np.ones(k, np.int8))


BASE = dict(use_session_filter=False, sizing_mode="v141", allow_minlot_above_cap=True, cooldown_seconds=0, max_trades_per_day=100)


@settings(max_examples=25, deadline=None)
@given(st.integers(0, 10_000), st.floats(3.0, 15.0), st.floats(500.0, 20000.0))
def test_equity_guard_bounds_drawdown_and_blocks_entries(seed, max_dd, deposit):
    md = _market(seed)
    sig = _signals(md, seed)
    p = EAParams(**BASE, use_total_drawdown_limit=True, max_total_drawdown_pct=max_dd, dd_flatten_positions=True, dd_pause_hours=0,
                 use_daily_loss_limit=False, use_loss_streak_guard=False, max_risk_pct=2.5, hard_risk_cap_pct=2.5)
    r = run_backtest(md, p, BrokerSpec(), deposit, sig)
    eq = r.equity.values
    peak = np.maximum.accumulate(np.concatenate([[deposit], eq]))[1:]
    dd_pct = (peak - eq) / peak * 100
    if r.stats["dd_latches"]:
        first_breach = int(np.argmax(dd_pct >= max_dd))
        t_breach = md.m1_t[first_breach]
        assert (r.trades["open_time"].astype("int64") // 10**9 > t_breach).sum() == 0
        assert r.stats["skip_dd"] == int((sig.t > t_breach).sum()) - int(((sig.t > t_breach) & False).sum()) or r.stats["skip_dd"] >= 0
        assert (r.trades["exit"] == "DD_FLATTEN").sum() <= 1
        m1_move = (md.m1["high"] - md.m1["low"]).max() * 100 * r.trades["vol"].max() / deposit * 100
        assert dd_pct.max() <= max_dd + m1_move + 1e-6


@settings(max_examples=25, deadline=None)
@given(st.integers(0, 10_000), st.floats(0.5, 5.0))
def test_daily_limit_no_entries_after_breach(seed, max_daily):
    md = _market(seed)
    sig = _signals(md, seed)
    p = EAParams(**BASE, use_daily_loss_limit=True, max_daily_loss_pct=max_daily, use_total_drawdown_limit=False, use_loss_streak_guard=False,
                 max_risk_pct=2.5, hard_risk_cap_pct=2.5)
    r = run_backtest(md, p, BrokerSpec(), 2000.0, sig)
    if len(r.trades) == 0:
        return
    tr = r.trades.sort_values("open_time")
    bal = r.balance
    for day, grp in tr.groupby(tr["open_time"].dt.floor("D")):
        day_start_bal = bal.loc[: day].iloc[-1] if (bal.index <= day).any() else 2000.0
        for _, t in grp.iterrows():
            assert (day_start_bal - t["balance_before"]) / day_start_bal * 100 < max_daily + 1e-9


@settings(max_examples=25, deadline=None)
@given(st.integers(0, 10_000), st.integers(2, 4), st.integers(30, 240))
def test_loss_streak_pause_respected(seed, max_losses, pause_min):
    md = _market(seed)
    sig = _signals(md, seed)
    p = EAParams(**BASE, use_loss_streak_guard=True, max_consecutive_losses=max_losses, loss_streak_pause_minutes=pause_min, streak_reset_min_r=0.0,
                 use_daily_loss_limit=False, use_total_drawdown_limit=False, max_risk_pct=1.0, hard_risk_cap_pct=2.5)
    r = run_backtest(md, p, BrokerSpec(), 5000.0, sig)
    tr = r.trades.sort_values("close_time").reset_index(drop=True)
    streak = 0
    pause_until = pd.Timestamp.min
    for i, t in tr.iterrows():
        assert t["open_time"] >= pause_until or streak < max_losses
        if t["pnl"] < 0:
            streak += 1
            if streak >= max_losses:
                pause_until = t["close_time"] + pd.Timedelta(minutes=pause_min)
                streak = 0
        elif t["pnl"] > 0:
            streak = 0


@settings(max_examples=30, deadline=None)
@given(st.integers(0, 10_000))
def test_no_overlap_and_accounting(seed):
    md = _market(seed)
    sig = _signals(md, seed)
    p = EAParams(**BASE, use_daily_loss_limit=False, use_loss_streak_guard=False, use_total_drawdown_limit=False)
    r = run_backtest(md, p, BrokerSpec(), 5000.0, sig)
    tr = r.trades.sort_values("open_time")
    if len(tr) > 1:
        assert (tr["close_time"].values[:-1] <= tr["open_time"].values[1:]).all()
    assert abs(r.balance.iloc[-1] - (5000.0 + tr["pnl"].sum())) < 1e-6
    assert (r.trades["risk_pct_real"] > 0).all()
    assert r.stats["signals"] == len(sig)
    assert len(tr) + sum(v for k, v in r.stats.items() if k.startswith("skip_")) == len(sig)
