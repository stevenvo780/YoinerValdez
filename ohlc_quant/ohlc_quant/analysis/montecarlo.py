from __future__ import annotations

from dataclasses import dataclass, asdict

import numpy as np
import pandas as pd


@dataclass
class MCResult:
    mode: str
    runs: int
    k: float
    dd_p50: float
    dd_p95: float
    dd_p99: float
    p_dd_ge_12: float
    p_dd_ge_20: float
    p_dd_ge_30: float
    p_ruin_50: float
    streak_p95: float
    streak_p99: float
    final_p05: float
    final_p50: float
    final_p95: float
    p_net_negative: float
    median_loss_pct: float

    def as_dict(self) -> dict:
        return asdict(self)


def _returns(trades: pd.DataFrame) -> np.ndarray:
    if "balance_before" in trades and (trades["balance_before"] > 0).all():
        return (trades["pnl"] / trades["balance_before"]).to_numpy(dtype=float)
    raise ValueError("se requieren balance_before > 0 para retornos fraccionales")


def _simulate(paths: np.ndarray, deposit: float) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    eq = deposit * np.cumprod(1.0 + paths, axis=1)
    eq = np.concatenate([np.full((paths.shape[0], 1), deposit), eq], axis=1)
    peak = np.maximum.accumulate(eq, axis=1)
    dd = ((peak - eq) / peak * 100.0).max(axis=1)
    ruin = (eq <= deposit * 0.5).any(axis=1)
    final = eq[:, -1]
    loss = paths <= 0
    streak = np.zeros(paths.shape[0], dtype=np.int64)
    cur = np.zeros(paths.shape[0], dtype=np.int64)
    for j in range(paths.shape[1]):
        cur = np.where(loss[:, j], cur + 1, 0)
        streak = np.maximum(streak, cur)
    return dd, ruin, final, streak


def monte_carlo(trades: pd.DataFrame, deposit: float, runs: int = 20000, seed: int = 7, mode: str = "shuffle",
                target_median_loss_pct: float | None = None, block: int = 1) -> MCResult:
    rets = _returns(trades)
    n = len(rets)
    rng = np.random.default_rng(seed)
    losses = np.sort(-rets[rets < 0])
    med_loss = float(losses[len(losses) // 2]) if len(losses) else 0.01
    k = 1.0 if target_median_loss_pct is None else min(1.0, (target_median_loss_pct / 100.0) / med_loss)
    r = rets * k
    if mode == "shuffle":
        idx = np.argsort(rng.random((runs, n)), axis=1)
        paths = r[idx]
    elif mode == "bootstrap":
        paths = r[rng.integers(0, n, size=(runs, n))]
    elif mode == "block":
        nb = int(np.ceil(n / block))
        starts = rng.integers(0, max(1, n - block + 1), size=(runs, nb))
        idx = (starts[:, :, None] + np.arange(block)[None, None, :]).reshape(runs, -1)[:, :n]
        paths = r[np.minimum(idx, n - 1)]
    else:
        raise ValueError(mode)
    dd, ruin, final, streak = _simulate(paths, deposit)
    q = lambda a, p: float(np.quantile(a, p))
    return MCResult(mode, runs, k, q(dd, .5), q(dd, .95), q(dd, .99), float((dd >= 12).mean() * 100), float((dd >= 20).mean() * 100),
                    float((dd >= 30).mean() * 100), float(ruin.mean() * 100), q(streak, .95), q(streak, .99),
                    q(final, .05), q(final, .5), q(final, .95), float((final < deposit).mean() * 100), med_loss * 100)


def mc_suite(trades: pd.DataFrame, deposit: float, runs: int = 20000, seed: int = 7, target_loss_pct: float = 1.0) -> pd.DataFrame:
    rows = []
    for mode, blk in (("shuffle", 1), ("bootstrap", 1), ("block", 5)):
        rows.append(monte_carlo(trades, deposit, runs, seed, mode, None, blk).as_dict())
        rows.append(monte_carlo(trades, deposit, runs, seed, mode, target_loss_pct, blk).as_dict())
    df = pd.DataFrame(rows)
    df.insert(1, "sizing", np.where(df["k"] == 1.0, "tal_cual", f"mediana={target_loss_pct}%"))
    return df


def summary_stats_mc(n_wins: int, n_losses: int, avg_win: float, avg_loss: float, max_win: float, max_loss: float,
                     deposit: float, runs: int = 20000, seed: int = 7) -> MCResult:
    rng = np.random.default_rng(seed)

    def side(n, avg, mx):
        x = np.minimum(rng.exponential(abs(avg), size=(runs, n)), abs(mx))
        x *= abs(avg) * n / x.sum(axis=1, keepdims=True)
        return x

    w = side(n_wins, avg_win, max_win); l = -side(n_losses, avg_loss, max_loss)
    pnl = np.concatenate([w, l], axis=1)
    idx = np.argsort(rng.random(pnl.shape), axis=1)
    pnl = np.take_along_axis(pnl, idx, axis=1)
    eq = deposit + np.cumsum(pnl, axis=1)
    eq = np.concatenate([np.full((runs, 1), deposit), eq], axis=1)
    peak = np.maximum.accumulate(eq, axis=1)
    dd = ((peak - eq) / peak * 100).max(axis=1)
    ruin = (eq <= deposit * 0.5).any(axis=1)
    final = eq[:, -1]
    loss = pnl <= 0
    streak = np.zeros(runs, dtype=np.int64); cur = np.zeros(runs, dtype=np.int64)
    for j in range(pnl.shape[1]):
        cur = np.where(loss[:, j], cur + 1, 0); streak = np.maximum(streak, cur)
    q = lambda a, p: float(np.quantile(a, p))
    return MCResult("summary", runs, 1.0, q(dd, .5), q(dd, .95), q(dd, .99), float((dd >= 12).mean() * 100), float((dd >= 20).mean() * 100),
                    float((dd >= 30).mean() * 100), float(ruin.mean() * 100), q(streak, .95), q(streak, .99), q(final, .05), q(final, .5),
                    q(final, .95), float((final < deposit).mean() * 100), abs(avg_loss) / deposit * 100)
