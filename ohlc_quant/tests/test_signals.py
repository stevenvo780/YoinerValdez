import numpy as np
import pandas as pd

from ohlc_quant.data.bars import build_market
from ohlc_quant.engine.params import EAParams, ServerClock
from ohlc_quant.engine.signals import SET_CUSTOM, SET_FIXED, all_signals, compute_signals


def test_signals_sorted_and_within_session(md_syn):
    p = EAParams()
    s = all_signals(md_syn, p)
    assert len(s) > 0
    assert (np.diff(s.t) >= 0).all()
    hours = (s.t % 86400) // 3600
    assert ((hours >= p.session_start_hour) & (hours < p.session_end_hour)).all()
    assert (s.strength >= p.min_signal_strength).all()
    assert set(np.unique(s.set_id)) <= {SET_FIXED, SET_CUSTOM}


def test_fixed_set_on_hour_boundaries(md_syn):
    s = compute_signals(md_syn, EAParams(), "H1", "H4", "D1", SET_FIXED)
    assert ((s.t % 3600) == 0).all()
    c = compute_signals(md_syn, EAParams(), "M5", "H4", "H4", SET_CUSTOM)
    assert ((c.t % 300) == 0).all()


def test_no_lookahead_future_bars_do_not_change_past_signals(m1_syn):
    clock = ServerClock(2, "us")
    md_full = build_market(m1_syn, clock)
    cut = m1_syn.index[len(m1_syn) // 2]
    md_half = build_market(m1_syn.loc[:cut], clock)
    p = EAParams()
    full = all_signals(md_full, p); half = all_signals(md_half, p)
    cut_srv = pd.Timestamp(md_half.m1.index[-1]).value // 10**9 - 86400
    f = full.t[full.t <= cut_srv]; h = half.t[half.t <= cut_srv]
    np.testing.assert_array_equal(f, h)
    np.testing.assert_array_equal(full.direction[full.t <= cut_srv], half.direction[half.t <= cut_srv])
    np.testing.assert_array_equal(full.strength[full.t <= cut_srv], half.strength[half.t <= cut_srv])


def test_perturbing_future_does_not_change_signal_at_T(m1_syn):
    clock = ServerClock(2, "none")
    p = EAParams(use_custom_pair=False)
    base = all_signals(build_market(m1_syn, clock), p)
    assert len(base) > 3
    T = base.t[len(base) // 2]
    T_utc = pd.Timestamp(T, unit="s") - pd.Timedelta(hours=2)
    m2 = m1_syn.copy()
    fut = m2.index >= T_utc.tz_localize("UTC")
    m2.loc[fut, ["open", "high", "low", "close", "ask_open", "ask_close"]] *= 1.05
    alt = all_signals(build_market(m2, clock), p)
    assert T in set(alt.t)
    np.testing.assert_array_equal(base.t[base.t <= T], alt.t[alt.t <= T])


def test_disable_sets(md_syn):
    assert len(all_signals(md_syn, EAParams(use_fixed_set=False, use_custom_pair=False))) == 0
    only_f = all_signals(md_syn, EAParams(use_custom_pair=False))
    assert (only_f.set_id == SET_FIXED).all()


def test_filters_reduce_signal_count(md_syn):
    loose = EAParams(require_trend_alignment=False, require_higher_tf_confirm=False, min_signal_strength=1, use_session_filter=False)
    strict = EAParams()
    assert len(all_signals(md_syn, loose)) >= len(all_signals(md_syn, strict))


def test_score_bounds(md_syn):
    s = all_signals(md_syn, EAParams(min_signal_strength=1, require_trend_alignment=False))
    assert s.strength.min() >= 1 and s.strength.max() <= 6
