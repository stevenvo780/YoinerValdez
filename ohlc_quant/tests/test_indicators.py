import numpy as np
import pandas as pd
from hypothesis import given, settings, strategies as st

from ohlc_quant.engine.indicators import atr_wilder, rolling_max_shifted, rolling_min_shifted, structure_trend


def ref_atr(h, l, c, n):
    tr = np.empty(len(h)); tr[0] = h[0] - l[0]
    for i in range(1, len(h)):
        tr[i] = max(h[i] - l[i], abs(h[i] - c[i - 1]), abs(l[i] - c[i - 1]))
    out = np.full(len(h), np.nan); out[n - 1] = tr[:n].mean()
    for i in range(n, len(h)):
        out[i] = (out[i - 1] * (n - 1) + tr[i]) / n
    return out


def test_atr_matches_reference():
    rng = np.random.default_rng(0)
    c = 2000 + np.cumsum(rng.standard_normal(300))
    h = c + rng.random(300) * 2; l = c - rng.random(300) * 2
    a = atr_wilder(h, l, c, 14)
    np.testing.assert_allclose(a[13:], ref_atr(h, l, c, 14)[13:], rtol=1e-12)
    assert np.isnan(a[:13]).all()


def test_rolling_shifted_matches_pandas():
    x = np.random.default_rng(1).random(200)
    s = pd.Series(x)
    np.testing.assert_allclose(rolling_max_shifted(x, 12, 1)[13:], s.rolling(12).max().shift(1).values[13:])
    np.testing.assert_allclose(rolling_min_shifted(x, 12, 2)[14:], s.rolling(12).min().shift(2).values[14:])
    assert np.isnan(rolling_max_shifted(x, 12, 1)[:12]).all()


def ref_trend(h, l, i, lookback, min_conf):
    seg = max(lookback // 3, 2)
    def hi(s, e): return h[s:e + 1].max()
    def lo(s, e): return l[s:e + 1].min()
    e1 = i; s1 = e1 - seg + 1; e2 = s1 - 1; s2 = e2 - seg + 1; e3 = s2 - 1; s3 = e3 - seg + 1
    if s3 < 0 or i + 1 < lookback + 5:
        return 0
    h1, l1, h2, l2, h3, l3 = hi(s1, e1), lo(s1, e1), hi(s2, e2), lo(s2, e2), hi(s3, e3), lo(s3, e3)
    bull = int(h1 > h2 and l1 > l2) + int(h2 > h3 and l2 > l3) + int(h1 > h3 and l1 > l3)
    bear = int(h1 < h2 and l1 < l2) + int(h2 < h3 and l2 < l3) + int(h1 < h3 and l1 < l3)
    if bull >= min_conf and bull > bear: return 1
    if bear >= min_conf and bear > bull: return -1
    return 0


@settings(max_examples=40, deadline=None)
@given(st.integers(6, 40), st.integers(1, 3), st.integers(0, 1000))
def test_structure_trend_matches_reference(lookback, min_conf, seed):
    rng = np.random.default_rng(seed)
    c = 2000 + np.cumsum(rng.standard_normal(120) * 3)
    h = c + rng.random(120) * 2; l = c - rng.random(120) * 2
    out = structure_trend(h, l, lookback, min_conf)
    for i in range(0, 120, 7):
        assert out[i] == ref_trend(h, l, i, lookback, min_conf)


def test_structure_trend_direction_on_monotone():
    h = np.arange(100, dtype=float) + 1; l = np.arange(100, dtype=float)
    assert structure_trend(h, l, 28, 2)[-1] == 1
    assert structure_trend(h[::-1].copy(), l[::-1].copy(), 28, 2)[-1] == -1
    assert (structure_trend(h, l, 5, 2) == 0).all()
