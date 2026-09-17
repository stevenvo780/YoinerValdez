from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd

from ohlc_quant.engine.params import TF_SECONDS, ServerClock


@dataclass
class TFBars:
    tf: str
    seconds: int
    t: np.ndarray
    o: np.ndarray
    h: np.ndarray
    l: np.ndarray
    c: np.ndarray

    def __len__(self) -> int:
        return len(self.t)

    def bar0_index(self, ts: np.ndarray) -> np.ndarray:
        return np.searchsorted(self.t, ts, side="right") - 1


@dataclass
class MarketData:
    m1: pd.DataFrame
    tfs: dict[str, TFBars]
    server_offset_seconds: np.ndarray

    @property
    def m1_t(self) -> np.ndarray:
        return self.m1.index.values.astype("datetime64[s]").astype(np.int64)

    def tf(self, name: str) -> TFBars:
        if name not in self.tfs:
            self.tfs[name] = resample_tf(self.m1, name)
        return self.tfs[name]


def to_server_time(m1_utc: pd.DataFrame, clock: ServerClock) -> tuple[pd.DataFrame, np.ndarray]:
    idx = m1_utc.index
    if idx.tz is None:
        idx = idx.tz_localize("UTC")
    utc_s = idx.values.astype("datetime64[s]").astype(np.int64)
    years = idx.year.values
    offsets = np.empty(len(idx), dtype=np.int64)
    if clock.dst_rule == "none":
        offsets[:] = clock.base_offset_hours * 3600
    else:
        offsets[:] = clock.base_offset_hours * 3600
        for y in np.unique(years):
            if clock.dst_rule == "us":
                from ohlc_quant.engine.params import _nth_sunday
                s, e = _nth_sunday(int(y), 3, 2), _nth_sunday(int(y), 11, 1)
            else:
                from ohlc_quant.engine.params import _last_sunday
                s, e = _last_sunday(int(y), 3), _last_sunday(int(y), 10)
            s_ts = pd.Timestamp(s, tz="UTC").value // 10**9
            e_ts = pd.Timestamp(e, tz="UTC").value // 10**9
            m = (years == y) & (utc_s >= s_ts) & (utc_s < e_ts)
            offsets[m] += 3600
    server = pd.to_datetime(utc_s + offsets, unit="s")
    out = m1_utc.copy()
    out.index = server
    out.index.name = "server_time"
    return out, offsets


def resample_tf(m1: pd.DataFrame, tf: str) -> TFBars:
    sec = TF_SECONDS[tf]
    if tf == "M1":
        g = m1
        t = m1.index.values.astype("datetime64[s]").astype(np.int64)
        return TFBars(tf, sec, t, g["open"].values, g["high"].values, g["low"].values, g["close"].values)
    rule = f"{sec}s"
    r = m1.resample(rule, label="left", closed="left")
    o = r["open"].first(); h = r["high"].max(); l = r["low"].min(); c = r["close"].last()
    keep = o.notna().values
    t = o.index.values.astype("datetime64[s]").astype(np.int64)[keep]
    return TFBars(tf, sec, t, o.values[keep], h.values[keep], l.values[keep], c.values[keep])


def build_market(m1_utc: pd.DataFrame, clock: ServerClock = ServerClock(), tfs=("M5", "H1", "H4", "D1")) -> MarketData:
    m1, offsets = to_server_time(m1_utc, clock)
    md = MarketData(m1=m1, tfs={}, server_offset_seconds=offsets)
    for tf in tfs:
        md.tfs[tf] = resample_tf(m1, tf)
    return md
