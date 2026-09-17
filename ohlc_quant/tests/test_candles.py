import numpy as np
import pandas as pd

from ohlc_quant.data.dukascopy import candles_to_m1, ticks_to_m1


def _candles(base, n, offset=0.0, vol=5.0):
    t = base + np.arange(n) * 60
    o = 2000 + np.arange(n) * 0.1 + offset
    c = o + 0.05; l = o - 0.2; h = o + 0.3
    return np.column_stack([t, o, c, l, h, np.full(n, vol)])


def test_candles_to_m1_schema_and_spread():
    base = int(pd.Timestamp("2025-02-03", tz="UTC").timestamp())
    bid = _candles(base, 10); ask = _candles(base, 10, offset=0.3)
    m1 = candles_to_m1(bid, ask)
    assert list(m1.columns) == ["open", "high", "low", "close", "ask_open", "ask_close", "spread_mean", "spread_max", "ticks"]
    assert len(m1) == 10 and m1.index[0] == pd.Timestamp("2025-02-03", tz="UTC")
    np.testing.assert_allclose(m1["spread_mean"], 0.3); np.testing.assert_allclose(m1["ask_open"] - m1["open"], 0.3)
    assert (m1["high"] >= m1["low"]).all()


def test_candles_zero_volume_rows_dropped_and_missing_ask():
    base = int(pd.Timestamp("2025-02-03", tz="UTC").timestamp())
    bid = _candles(base, 6); bid[2, 5] = 0.0
    m1 = candles_to_m1(bid, np.empty((0, 6)))
    assert len(m1) == 5 and (m1["spread_mean"] == 0).all()
    assert candles_to_m1(np.empty((0, 6)), np.empty((0, 6))).empty


def test_ticks_to_m1_aggregation():
    base_ms = int(pd.Timestamp("2025-02-03 10:00", tz="UTC").timestamp() * 1000)
    ticks = np.array([[base_ms + 0, 2000.5, 2000.0, 1, 1], [base_ms + 30000, 2001.5, 2001.0, 1, 1], [base_ms + 59000, 2000.9, 2000.4, 1, 1],
                      [base_ms + 60000, 2002.0, 2001.5, 1, 1]])
    m1 = ticks_to_m1(ticks)
    assert len(m1) == 2
    r = m1.iloc[0]
    assert r["open"] == 2000.0 and r["high"] == 2001.0 and r["low"] == 2000.0 and r["close"] == 2000.4 and r["ticks"] == 3
    assert r["ask_open"] == 2000.5 and abs(r["spread_mean"] - 0.5) < 1e-9
