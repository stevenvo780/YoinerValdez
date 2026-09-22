from __future__ import annotations

import math
from dataclasses import dataclass, asdict

import numpy as np
import pandas as pd


@dataclass
class Metrics:
    n: int = 0
    net: float = 0.0
    gross_profit: float = 0.0
    gross_loss: float = 0.0
    profit_factor: float = 0.0
    win_rate: float = 0.0
    avg_win: float = 0.0
    avg_loss: float = 0.0
    expectancy: float = 0.0
    max_dd: float = 0.0
    max_dd_pct: float = 0.0
    max_loss_streak: int = 0
    max_win_streak: int = 0
    recovery_factor: float = 0.0
    sharpe_trade: float = 0.0
    avg_r: float = 0.0
    final_balance: float = 0.0
    return_pct: float = 0.0
    cagr_pct: float = 0.0
    trades_per_month: float = 0.0
    avg_risk_pct: float = 0.0
    max_risk_pct: float = 0.0

    def as_dict(self) -> dict:
        return asdict(self)


def equity_drawdown(pnls: np.ndarray, deposit: float) -> tuple[float, float]:
    eq = deposit + np.cumsum(pnls)
    peak = np.maximum.accumulate(np.concatenate([[deposit], eq]))[1:]
    dd = peak - eq
    if len(dd) == 0:
        return 0.0, 0.0
    i = int(np.argmax(dd))
    return float(dd[i]), float(dd[i] / peak[i] * 100.0) if peak[i] > 0 else 0.0


def curve_drawdown(equity: np.ndarray) -> tuple[float, float]:
    if len(equity) == 0:
        return 0.0, 0.0
    peak = np.maximum.accumulate(equity)
    dd = peak - equity
    i = int(np.argmax(dd))
    return float(dd[i]), float(dd[i] / peak[i] * 100.0) if peak[i] > 0 else 0.0


def streaks(pnls: np.ndarray) -> tuple[int, int]:
    ls = ws = bl = bw = 0
    for p in pnls:
        if p <= 0:
            ls += 1; ws = 0
        else:
            ws += 1; ls = 0
        bl = max(bl, ls); bw = max(bw, ws)
    return bl, bw


def compute_metrics(trades: pd.DataFrame, deposit: float, equity_curve: np.ndarray | None = None,
                    span_days: float | None = None) -> Metrics:
    m = Metrics()
    if trades is None or len(trades) == 0:
        m.final_balance = deposit
        return m
    pnl = trades["pnl"].to_numpy(dtype=float)
    wins = pnl[pnl > 0]; losses = pnl[pnl <= 0]
    m.n = len(pnl)
    m.net = float(pnl.sum())
    m.gross_profit = float(wins.sum()); m.gross_loss = float(-losses.sum())
    m.profit_factor = m.gross_profit / m.gross_loss if m.gross_loss > 0 else (math.inf if m.gross_profit > 0 else 0.0)
    m.win_rate = len(wins) / m.n * 100.0
    m.avg_win = float(wins.mean()) if len(wins) else 0.0
    m.avg_loss = float(losses.mean()) if len(losses) else 0.0
    m.expectancy = m.net / m.n
    if equity_curve is not None and len(equity_curve):
        m.max_dd, m.max_dd_pct = curve_drawdown(np.asarray(equity_curve, dtype=float))
    else:
        m.max_dd, m.max_dd_pct = equity_drawdown(pnl, deposit)
    m.max_loss_streak, m.max_win_streak = streaks(pnl)
    m.recovery_factor = m.net / m.max_dd if m.max_dd > 0 else (math.inf if m.net > 0 else 0.0)
    sd = pnl.std(ddof=1) if m.n > 1 else 0.0
    m.sharpe_trade = float(pnl.mean() / sd * math.sqrt(m.n)) if sd > 0 else 0.0
    if "r_multiple" in trades:
        m.avg_r = float(trades["r_multiple"].mean())
    m.final_balance = deposit + m.net
    m.return_pct = m.net / deposit * 100.0
    if span_days is None and "open_time" in trades and "close_time" in trades:
        span_days = max((trades["close_time"].max() - trades["open_time"].min()).total_seconds() / 86400.0, 1.0)
    if span_days:
        years = span_days / 365.25
        if years >= 1 / 12 and m.final_balance > 0:
            m.cagr_pct = ((m.final_balance / deposit) ** (1 / years) - 1) * 100.0
        m.trades_per_month = m.n / (span_days / 30.44)
    if "risk_pct_real" in trades:
        m.avg_risk_pct = float(trades["risk_pct_real"].mean()); m.max_risk_pct = float(trades["risk_pct_real"].max())
    return m


def metrics_table(rows: dict[str, Metrics]) -> pd.DataFrame:
    df = pd.DataFrame({k: v.as_dict() for k, v in rows.items()}).T
    cols = ["n", "net", "profit_factor", "win_rate", "expectancy", "max_dd_pct", "max_loss_streak", "recovery_factor", "avg_r", "return_pct", "avg_risk_pct", "max_risk_pct"]
    return df[cols]


def year_profit_factors(trades: pd.DataFrame) -> list[tuple[int, float, int]]:
    """Factor de beneficio por año de cierre, sobre la misma lista de operaciones."""
    if trades is None or len(trades) == 0 or "close_time" not in trades or "pnl" not in trades:
        return []
    rows = []
    years = trades["close_time"].dt.year
    for year, idx in trades.groupby(years).groups.items():
        pnl = trades.loc[idx, "pnl"].to_numpy(dtype=float)
        wins = pnl[pnl > 0].sum()
        losses = -pnl[pnl <= 0].sum()
        if losses > 0:
            pf = float(wins / losses)
        else:
            pf = math.inf if wins > 0 else 0.0
        rows.append((int(year), pf, int(len(pnl))))
    return rows


def by_period(trades: pd.DataFrame, freq: str = "ME") -> pd.DataFrame:
    if len(trades) == 0:
        return pd.DataFrame(columns=["n", "net"])
    g = trades.set_index("open_time").groupby(pd.Grouper(freq=freq))["pnl"]
    return pd.DataFrame({"n": g.count(), "net": g.sum()})


def by_weekday(trades: pd.DataFrame) -> pd.DataFrame:
    if len(trades) == 0:
        return pd.DataFrame(columns=["n", "net"])
    g = trades.groupby(trades["open_time"].dt.weekday)["pnl"]
    df = pd.DataFrame({"n": g.count(), "net": g.sum()})
    df.index = [["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"][i] for i in df.index]
    return df


def by_hour(trades: pd.DataFrame) -> pd.DataFrame:
    if len(trades) == 0:
        return pd.DataFrame(columns=["n", "net"])
    g = trades.groupby(trades["open_time"].dt.hour)["pnl"]
    return pd.DataFrame({"n": g.count(), "net": g.sum()})


def exclusion_analysis(trades: pd.DataFrame, deposit: float) -> dict[str, Metrics]:
    out = {"todo": compute_metrics(trades, deposit)}
    if len(trades) == 0:
        return out
    mon = trades["open_time"].dt.to_period("M")
    best_m = trades.groupby(mon)["pnl"].sum().idxmax()
    wd = trades["open_time"].dt.weekday
    best_d = trades.groupby(wd)["pnl"].sum().idxmax()
    out[f"sin_mejor_mes({best_m})"] = compute_metrics(trades[mon != best_m], deposit)
    out[f"sin_mejor_dia({['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'][best_d]})"] = compute_metrics(trades[wd != best_d], deposit)
    out["sin_ambos"] = compute_metrics(trades[(mon != best_m) & (wd != best_d)], deposit)
    k = max(1, int(round(len(trades) * 0.04)))
    top = trades["pnl"].nlargest(k).index
    out[f"sin_top{k}"] = compute_metrics(trades.drop(top), deposit)
    worst_m = trades.groupby(mon)["pnl"].sum().idxmin()
    out[f"sin_peor_mes({worst_m})"] = compute_metrics(trades[mon != worst_m], deposit)
    return out
