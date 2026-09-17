from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from ohlc_quant.data.bars import MarketData, TFBars
from ohlc_quant.engine.indicators import atr_wilder, rolling_max_shifted, rolling_min_shifted, structure_trend
from ohlc_quant.engine.params import EAParams

SET_FIXED = 0
SET_CUSTOM = 1
MAX_STRENGTH = 6


@dataclass
class SignalSet:
    t: np.ndarray
    direction: np.ndarray
    strength: np.ndarray
    set_id: np.ndarray
    atr: np.ndarray
    trend: np.ndarray

    def __len__(self) -> int:
        return len(self.t)

    @staticmethod
    def merge(a: "SignalSet", b: "SignalSet") -> "SignalSet":
        t = np.concatenate([a.t, b.t]); s = np.concatenate([a.set_id, b.set_id])
        order = np.lexsort((s, t))
        return SignalSet(t[order], np.concatenate([a.direction, b.direction])[order],
                         np.concatenate([a.strength, b.strength])[order], s[order],
                         np.concatenate([a.atr, b.atr])[order], np.concatenate([a.trend, b.trend])[order])

    @staticmethod
    def empty() -> "SignalSet":
        z = np.zeros(0)
        return SignalSet(z.astype(np.int64), z.astype(np.int8), z.astype(np.int8), z.astype(np.int8), z, z.astype(np.int8))


def _rolling_mean_shifted(x: np.ndarray, window: int, shift: int) -> np.ndarray:
    c = np.cumsum(np.insert(x, 0, 0.0))
    n = len(x)
    out = np.full(n, np.nan)
    i = np.arange(n)
    end = i - shift
    start = end - window + 1
    ok = start >= 0
    out[ok] = (c[end[ok] + 1] - c[start[ok]]) / window
    return out


def atr_series(md: MarketData, p: EAParams) -> tuple[TFBars, np.ndarray]:
    tf = md.tf(p.atr_timeframe)
    return tf, atr_wilder(tf.h, tf.l, tf.c, p.atr_period)


def _atr_at(md: MarketData, p: EAParams, T: np.ndarray, atr_tf: TFBars, atr: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    idx0 = atr_tf.bar0_index(T)
    idx1 = idx0 - 1
    valid = idx1 >= 0
    a_closed = np.full(len(T), np.nan)
    a_closed[valid] = atr[idx1[valid]]
    close1 = np.full(len(T), np.nan)
    close1[valid] = atr_tf.c[idx1[valid]]
    if p.atr_closed_bar:
        return a_closed, close1
    a_form = np.full(len(T), np.nan)
    m1 = md.tf("M1")
    k = m1.bar0_index(T)
    price_now = m1.o[np.clip(k, 0, len(m1) - 1)]
    bar_open = atr_tf.t[np.clip(idx0, 0, len(atr_tf) - 1)]
    k_start = m1.bar0_index(bar_open)
    hp = price_now.copy(); lp = price_now.copy()
    for i in range(len(T)):
        if not valid[i]:
            continue
        ks, ke = k_start[i], k[i]
        if ke > ks:
            hp[i] = max(hp[i], m1.h[ks:ke].max()); lp[i] = min(lp[i], m1.l[ks:ke].min())
    cprev = close1
    tr = np.maximum(hp - lp, np.maximum(np.abs(hp - cprev), np.abs(lp - cprev)))
    a_form[valid] = (a_closed[valid] * (p.atr_period - 1) + tr[valid]) / p.atr_period
    return a_form, price_now


def compute_signals(md: MarketData, p: EAParams, t1: str, t2: str, t3: str, set_id: int,
                    atr_tf: TFBars | None = None, atr: np.ndarray | None = None) -> SignalSet:
    b1 = md.tf(t1); b2 = md.tf(t2); b3 = md.tf(t3)
    if atr_tf is None or atr is None:
        atr_tf, atr = atr_series(md, p)
    n = len(b1)
    L = p.structure_lookback
    if n < L + 8:
        return SignalSet.empty()
    i = np.arange(1, n)
    T = b1.t[i]
    bar1 = i - 1
    o, h, l, c = b1.o[bar1], b1.h[bar1], b1.l[bar1], b1.c[bar1]
    sh = rolling_max_shifted(b1.h, L, 1)[bar1]
    sl = rolling_min_shifted(b1.l, L, 1)[bar1]
    valid = ~np.isnan(sh) & ~np.isnan(sl)
    atr_now, close_ref = _atr_at(md, p, T, atr_tf, atr)
    valid &= ~np.isnan(atr_now) & (atr_now > 0)

    rng = h - l
    body = np.abs(c - o)
    with np.errstate(divide="ignore", invalid="ignore"):
        body_ratio = np.where(rng > 0, body / rng, 0.0)
    avg_rng = _rolling_mean_shifted(b1.h - b1.l, 5, 1)[bar1]
    expansion_ok = np.where(np.isnan(avg_rng), True, rng >= avg_rng * 1.15) if p.prefer_expansion_break else np.ones(len(i), bool)

    def quality(direction: int, level: np.ndarray):
        ok = valid & (rng > 0)
        if p.require_close_beyond:
            ok &= (c > level) if direction == 1 else (c < level)
        ok &= body_ratio >= p.min_body_ratio
        wick = (h - np.maximum(o, c)) if direction == 1 else (np.minimum(o, c) - l)
        with np.errstate(divide="ignore", invalid="ignore"):
            wick_ratio = np.where(body > 0, wick / body, 999.0)
        ok &= wick_ratio <= p.max_against_wick_ratio
        margin = (h - level) if direction == 1 else (level - l)
        ok &= margin >= p.min_breakout_atr_mult * atr_now
        ok &= margin <= p.max_breakout_atr_mult * atr_now
        ok &= expansion_ok
        return ok, margin

    buy = valid & (h > sh) & p.enable_buy
    sell = valid & (l < sl) & p.enable_sell
    qb, margin_b = quality(1, sh)
    qs, margin_s = quality(-1, sl)
    buy &= qb; sell &= qs

    idx3 = b3.bar0_index(T) - 1
    v3 = idx3 >= 0
    h3 = np.full(len(i), np.nan); l3 = np.full(len(i), np.nan)
    h3[v3] = b3.h[idx3[v3]]; l3[v3] = b3.l[idx3[v3]]
    if p.require_higher_tf_confirm:
        mtf_b = v3 & (h > h3); mtf_s = v3 & (l < l3)
        buy &= mtf_b; sell &= mtf_s
    else:
        mtf_b = np.ones(len(i), bool); mtf_s = np.ones(len(i), bool)

    hour = ((T % 86400) // 3600).astype(np.int64)
    dow = ((T // 86400) + 4) % 7
    if p.use_session_filter:
        sess = (hour >= p.session_start_hour) & (hour < p.session_end_hour)
        if p.allow_asia_breakouts:
            sess |= hour < 7
        if p.friday_entry_cutoff_hour < 24:
            sess &= ~((dow == 5) & (hour >= p.friday_entry_cutoff_hour))
        buy &= sess; sell &= sess

    with np.errstate(divide="ignore", invalid="ignore"):
        atr_pct = np.where(close_ref > 0, atr_now / close_ref * 100.0, 0.0)
    if p.use_volatility_filter:
        vol_ok = (atr_pct >= p.atr_min_pct) & (atr_pct <= p.atr_max_pct)
        buy &= vol_ok; sell &= vol_ok

    trend_arr = structure_trend(b2.h, b2.l, p.trend_lookback, p.min_swing_confirmations)
    idx2 = b2.bar0_index(T) - 1
    trend = np.zeros(len(i), np.int8)
    v2 = idx2 >= 0
    trend[v2] = trend_arr[idx2[v2]]
    if p.require_trend_alignment:
        sell &= trend != 1
        buy &= trend != -1
        if p.block_when_no_trend:
            buy &= trend != 0; sell &= trend != 0

    band = p.atr_max_pct - p.atr_min_pct
    sweet = (band > 0) & (atr_pct >= p.atr_min_pct + band * 0.2) & (atr_pct <= p.atr_min_pct + band * 0.8)
    min_str = min(p.min_signal_strength, MAX_STRENGTH)

    def score(direction, margin, mtf):
        s = np.ones(len(i), np.int8)
        s += (trend == direction)
        s += (p.require_higher_tf_confirm & mtf)
        s += margin >= p.min_breakout_atr_mult * 1.8 * atr_now
        s += body_ratio >= p.min_body_ratio + 0.10
        s += sweet
        return s

    sb = score(1, margin_b, mtf_b); ss = score(-1, margin_s, mtf_s)
    buy &= sb >= min_str; sell &= ss >= min_str

    ts, ds, ss_, at, tr = [], [], [], [], []
    for mask, d, s in ((buy, 1, sb), (sell, -1, ss)):
        ts.append(T[mask]); ds.append(np.full(mask.sum(), d, np.int8)); ss_.append(s[mask]); at.append(atr_now[mask]); tr.append(trend[mask])
    out = SignalSet(np.concatenate(ts), np.concatenate(ds), np.concatenate(ss_), np.full(sum(m.sum() for m in (buy, sell)), set_id, np.int8),
                    np.concatenate(at), np.concatenate(tr))
    order = np.lexsort((out.direction, out.t))
    return SignalSet(out.t[order], out.direction[order], out.strength[order], out.set_id[order], out.atr[order], out.trend[order])


def all_signals(md: MarketData, p: EAParams) -> SignalSet:
    atr_tf, atr = atr_series(md, p)
    parts = []
    if p.use_fixed_set:
        parts.append(compute_signals(md, p, "H1", p.trend_timeframe, "D1", SET_FIXED, atr_tf, atr))
    if p.use_custom_pair:
        parts.append(compute_signals(md, p, p.tf_fast, p.tf_slow, p.tf_slow, SET_CUSTOM, atr_tf, atr))
    if not parts:
        return SignalSet.empty()
    out = parts[0]
    for q in parts[1:]:
        out = SignalSet.merge(out, q)
    return out
