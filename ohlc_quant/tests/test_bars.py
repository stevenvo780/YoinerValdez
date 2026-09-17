import numpy as np
import pandas as pd

from ohlc_quant.data.bars import build_market, to_server_time
from ohlc_quant.data.synthetic import synthetic_m1
from ohlc_quant.engine.params import ServerClock


def test_server_time_offset_us_dst():
    idx = pd.to_datetime(["2024-01-15 12:00", "2024-03-10 06:00", "2024-03-10 07:30", "2024-07-01 12:00", "2024-11-03 05:30", "2024-11-03 06:30"], utc=True)
    df = pd.DataFrame({"open": 1.0, "high": 1, "low": 1, "close": 1, "ask_open": 1, "ask_close": 1, "spread_mean": 0, "spread_max": 0, "ticks": 1}, index=idx)
    out, off = to_server_time(df, ServerClock(2, "us"))
    assert list(off // 3600) == [2, 3, 3, 3, 2, 2]
    assert out.index[0] == pd.Timestamp("2024-01-15 14:00")


def test_server_time_no_dst_and_eu():
    idx = pd.to_datetime(["2024-03-30 12:00", "2024-03-31 12:00", "2024-10-27 12:00"], utc=True)
    df = pd.DataFrame({"open": 1.0, "high": 1, "low": 1, "close": 1, "ask_open": 1, "ask_close": 1, "spread_mean": 0, "spread_max": 0, "ticks": 1}, index=idx)
    assert list(to_server_time(df, ServerClock(2, "none"))[1] // 3600) == [2, 2, 2]
    assert list(to_server_time(df, ServerClock(2, "eu"))[1] // 3600) == [2, 3, 2]


def test_resample_alignment_and_ohlc():
    m1 = synthetic_m1(days=10, seed=1)
    md = build_market(m1, ServerClock(2, "none"))
    h4 = md.tf("H4"); d1 = md.tf("D1"); h1 = md.tf("H1")
    assert ((h4.t % 14400) == 0).all() and ((d1.t % 86400) == 0).all() and ((h1.t % 3600) == 0).all()
    srv = md.m1
    first = pd.Timestamp(h1.t[5], unit="s")
    chunk = srv.loc[first: first + pd.Timedelta(minutes=59)]
    assert h1.o[5] == chunk["open"].iloc[0] and h1.c[5] == chunk["close"].iloc[-1]
    assert h1.h[5] == chunk["high"].max() and h1.l[5] == chunk["low"].min()
    assert (h4.h >= h4.l).all() and (h4.h >= h4.o).all() and (h4.l <= h4.c).all()


def test_bar0_index_semantics():
    m1 = synthetic_m1(days=5, seed=2)
    md = build_market(m1, ServerClock(0, "none"))
    h1 = md.tf("H1")
    T = h1.t[10]
    assert h1.bar0_index(np.array([T]))[0] == 10
    assert h1.bar0_index(np.array([T + 1800]))[0] == 10
    assert h1.bar0_index(np.array([T - 1]))[0] == 9
