from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
import pandas as pd

from ohlc_quant.data.bars import MarketData
from ohlc_quant.engine.indicators import rolling_max_shifted, rolling_min_shifted
from ohlc_quant.engine.params import BrokerSpec, EAParams
from ohlc_quant.engine.signals import SignalSet, all_signals, atr_series
from ohlc_quant.engine.simulator import TR_COLS, pack_broker, pack_params, run_sim

STAT_NAMES = ["skip_minlot", "skip_spread", "skip_pause", "skip_daily", "skip_dd", "skip_cooldown", "skip_maxday",
              "skip_busy", "dd_latches", "pp_mods", "skip_high_spread", "skip_margin", "signals"]
EXIT_NAMES = {1: "SL", 2: "TP", 3: "DD_FLATTEN", 4: "DAILY_FLATTEN", 5: "WEEKEND", 6: "END"}


@dataclass
class BacktestResult:
    trades: pd.DataFrame
    balance: pd.Series
    equity: pd.Series
    stats: dict
    params: EAParams
    broker: BrokerSpec
    deposit: float
    signals: int = 0
    extra: dict = field(default_factory=dict)

    @property
    def net(self) -> float:
        return float(self.trades["pnl"].sum()) if len(self.trades) else 0.0


def _trades_frame(arr: np.ndarray) -> pd.DataFrame:
    df = pd.DataFrame(arr, columns=TR_COLS)
    df["open_time"] = pd.to_datetime(df["open_t"], unit="s")
    df["close_time"] = pd.to_datetime(df["close_t"], unit="s")
    df["type"] = np.where(df["type"] == 1, "buy", "sell")
    df["set"] = np.where(df["set"] == 0, "FIJO", "CUSTOM")
    df["exit"] = df["exit_reason"].map(EXIT_NAMES)
    df["strength"] = df["strength"].astype(int)
    return df.drop(columns=["open_t", "close_t", "exit_reason"])


def run_backtest(md: MarketData, p: EAParams, broker: BrokerSpec = BrokerSpec(), deposit: float = 300.0,
                 signals: SignalSet | None = None, pessimistic: bool = True, start: str | None = None,
                 end: str | None = None) -> BacktestResult:
    if signals is None:
        signals = all_signals(md, p)
    m1 = md.m1
    t = md.m1_t
    lo, hi = 0, len(t)
    if start is not None:
        lo = int(np.searchsorted(t, pd.Timestamp(start).value // 10**9))
    if end is not None:
        hi = int(np.searchsorted(t, pd.Timestamp(end).value // 10**9))
    sl_ = slice(lo, hi)
    ev_mask = (signals.t >= t[lo]) & (signals.t < (t[hi - 1] + 1 if hi > lo else t[lo]))
    atr_tf, atr = atr_series(md, p)
    atr_idx0 = atr_tf.bar0_index(t[sl_]).astype(np.int64)
    atr_closed = np.nan_to_num(np.concatenate([[0.0], atr[:-1]]))
    lb = p.pp_trail_structure_lookback
    trail_low = rolling_min_shifted(atr_tf.l, lb, 1)
    trail_high = rolling_max_shifted(atr_tf.h, lb, 1)
    tr, bal, eq, st = run_sim(
        t[sl_].astype(np.float64), m1["open"].values[sl_], m1["high"].values[sl_], m1["low"].values[sl_], m1["close"].values[sl_],
        m1["ask_open"].values[sl_], np.nan_to_num(m1["spread_mean"].values[sl_]),
        signals.t[ev_mask].astype(np.float64), signals.direction[ev_mask].astype(np.int64), signals.strength[ev_mask].astype(np.int64),
        signals.set_id[ev_mask].astype(np.int64), signals.atr[ev_mask].astype(np.float64),
        atr_idx0, atr_closed, trail_low, trail_high,
        pack_params(p, pessimistic), pack_broker(broker), float(deposit))
    idx = m1.index[sl_]
    stats = {k: int(v) for k, v in zip(STAT_NAMES, st[: len(STAT_NAMES)])}
    return BacktestResult(_trades_frame(tr), pd.Series(bal, index=idx), pd.Series(eq, index=idx), stats, p, broker, deposit,
                          signals=int(ev_mask.sum()))
