from __future__ import annotations

import concurrent.futures as cf
import datetime as dt
import lzma
import time
from pathlib import Path

import numpy as np
import pandas as pd
import requests

BASE = "https://datafeed.dukascopy.com/datafeed/{sym}/{y}/{m:02d}/{d:02d}/{h:02d}h_ticks.bi5"
HEADERS = {"User-Agent": "Mozilla/5.0"}
PRICE_SCALE = {"XAUUSD": 1000.0, "XAGUSD": 1000.0, "EURUSD": 100000.0, "GBPUSD": 100000.0, "USDJPY": 1000.0}


def _hour_url(sym: str, t: dt.datetime) -> str:
    return BASE.format(sym=sym, y=t.year, m=t.month - 1, d=t.day, h=t.hour)


_RATE_LOCK = None
_RATE_NEXT = 0.0
RATE_LIMIT_RPS = 1.5


def _throttle():
    global _RATE_LOCK, _RATE_NEXT
    import threading
    if _RATE_LOCK is None:
        _RATE_LOCK = threading.Lock()
    with _RATE_LOCK:
        now = time.time()
        wait = _RATE_NEXT - now
        _RATE_NEXT = max(now, _RATE_NEXT) + 1.0 / RATE_LIMIT_RPS
    if wait > 0:
        time.sleep(wait)


def fetch_hour(sym: str, t: dt.datetime, session: requests.Session | None = None, retries: int = 12) -> np.ndarray:
    s = session or requests.Session()
    url = _hour_url(sym, t)
    backoff = 5.0
    for i in range(retries):
        _throttle()
        try:
            r = s.get(url, headers=HEADERS, timeout=30)
            if r.status_code == 404 or (r.status_code == 200 and len(r.content) == 0):
                return np.empty((0, 5))
            if r.status_code in (429, 503, 403):
                time.sleep(backoff)
                backoff = min(backoff * 2, 120.0)
                continue
            r.raise_for_status()
            raw = lzma.decompress(r.content)
            n = len(raw) // 20
            rec = np.frombuffer(raw[: n * 20], dtype=np.dtype(">i4,>i4,>i4,>f4,>f4"))
            scale = PRICE_SCALE.get(sym, 100000.0)
            base_ms = int(t.replace(tzinfo=dt.timezone.utc).timestamp() * 1000)
            return np.column_stack([
                base_ms + rec["f0"].astype(np.int64),
                rec["f1"].astype(np.float64) / scale,
                rec["f2"].astype(np.float64) / scale,
                rec["f3"].astype(np.float64),
                rec["f4"].astype(np.float64),
            ])
        except (requests.RequestException, lzma.LZMAError):
            if i == retries - 1:
                raise
            time.sleep(backoff)
            backoff = min(backoff * 2, 120.0)
    raise RuntimeError(f"sin respuesta válida para {url}")


def ticks_to_m1(ticks: np.ndarray) -> pd.DataFrame:
    if len(ticks) == 0:
        return pd.DataFrame(columns=["open", "high", "low", "close", "ask_open", "ask_close", "spread_mean", "spread_max", "ticks"])
    ts = pd.to_datetime(ticks[:, 0], unit="ms", utc=True)
    df = pd.DataFrame({"ask": ticks[:, 1], "bid": ticks[:, 2]}, index=ts)
    df["spread"] = df["ask"] - df["bid"]
    g = df.resample("1min")
    out = pd.DataFrame({
        "open": g["bid"].first(), "high": g["bid"].max(), "low": g["bid"].min(), "close": g["bid"].last(),
        "ask_open": g["ask"].first(), "ask_close": g["ask"].last(),
        "spread_mean": g["spread"].mean(), "spread_max": g["spread"].max(), "ticks": g["bid"].count(),
    })
    return out.dropna(subset=["open"])


def download_range(sym: str, start: dt.date, end: dt.date, out_dir: Path, workers: int = 48, log=print) -> list[Path]:
    import threading
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    days = [d for d in pd.date_range(start, end, freq="D") if d.weekday() != 5]
    pending = {d: [] for d in days if not (out_dir / f"{sym}_{d.strftime('%Y%m%d')}.parquet").exists()}
    written: list[Path] = [out_dir / f"{sym}_{d.strftime('%Y%m%d')}.parquet" for d in days if d not in pending]
    local = threading.local()
    lock = threading.Lock()
    counts: dict = {d: 0 for d in pending}

    def session() -> requests.Session:
        if not hasattr(local, "s"):
            local.s = requests.Session()
        return local.s

    def task(day: pd.Timestamp, hour: int):
        arr = fetch_hour(sym, dt.datetime(day.year, day.month, day.day, hour), session())
        with lock:
            if len(arr):
                pending[day].append(arr)
            counts[day] += 1
            if counts[day] == 24:
                parts = pending.pop(day)
                if parts:
                    m1 = ticks_to_m1(np.vstack(parts))
                    if not m1.empty:
                        path = out_dir / f"{sym}_{day.strftime('%Y%m%d')}.parquet"
                        m1.to_parquet(path)
                        written.append(path)
                        if len(written) % 25 == 0:
                            log(f"{sym}: {len(written)}/{len(days)} días", flush=True)

    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        futs = [ex.submit(task, d, h) for d in pending for h in range(24)]
        for f in cf.as_completed(futs):
            f.result()
    return sorted(written)


def load_m1(sym: str, bars_dir: Path) -> pd.DataFrame:
    files = sorted(Path(bars_dir).glob(f"{sym}_*.parquet"))
    if not files:
        raise FileNotFoundError(f"sin barras M1 para {sym} en {bars_dir}")
    df = pd.concat([pd.read_parquet(f) for f in files]).sort_index()
    return df[~df.index.duplicated(keep="last")]


CANDLE_URL = "https://datafeed.dukascopy.com/datafeed/{sym}/{y}/{m:02d}/{d:02d}/{side}_candles_min_1.bi5"


def fetch_day_candles(sym: str, day: dt.date, side: str, session: requests.Session | None = None, retries: int = 12) -> np.ndarray:
    s = session or requests.Session()
    url = CANDLE_URL.format(sym=sym, y=day.year, m=day.month - 1, d=day.day, side=side)
    backoff = 10.0
    for i in range(retries):
        _throttle()
        try:
            r = s.get(url, headers=HEADERS, timeout=30)
            if r.status_code == 404 or (r.status_code == 200 and len(r.content) == 0):
                return np.empty((0, 6))
            if r.status_code in (429, 503, 403):
                time.sleep(backoff); backoff = min(backoff * 2, 300.0); continue
            r.raise_for_status()
            raw = lzma.decompress(r.content)
            n = len(raw) // 24
            rec = np.frombuffer(raw[: n * 24], dtype=np.dtype(">i4,>i4,>i4,>i4,>i4,>f4"))
            scale = PRICE_SCALE.get(sym, 100000.0)
            base_s = int(dt.datetime(day.year, day.month, day.day, tzinfo=dt.timezone.utc).timestamp())
            return np.column_stack([base_s + rec["f0"].astype(np.int64), rec["f1"] / scale, rec["f2"] / scale, rec["f3"] / scale, rec["f4"] / scale, rec["f5"].astype(np.float64)])
        except (requests.RequestException, lzma.LZMAError):
            if i == retries - 1:
                raise
            time.sleep(backoff); backoff = min(backoff * 2, 300.0)
    raise RuntimeError(f"sin respuesta válida para {url}")


def candles_to_m1(bid: np.ndarray, ask: np.ndarray) -> pd.DataFrame:
    if len(bid) == 0:
        return pd.DataFrame()
    b = pd.DataFrame(bid[:, 1:6], index=pd.to_datetime(bid[:, 0], unit="s", utc=True), columns=["open", "close", "low", "high", "vol"])
    b = b[b["vol"] > 0]
    if len(ask):
        a = pd.DataFrame(ask[:, 1:6], index=pd.to_datetime(ask[:, 0], unit="s", utc=True), columns=["open", "close", "low", "high", "vol"])
        a = a.reindex(b.index).ffill().bfill()
    else:
        a = b.copy()
    sp_open = (a["open"] - b["open"]).clip(lower=0); sp_close = (a["close"] - b["close"]).clip(lower=0)
    out = pd.DataFrame({"open": b["open"], "high": b["high"], "low": b["low"], "close": b["close"], "ask_open": a["open"], "ask_close": a["close"],
                        "spread_mean": (sp_open + sp_close) / 2, "spread_max": np.maximum(sp_open, sp_close), "ticks": b["vol"]})
    return out[~out.index.duplicated()]


def download_range_candles(sym: str, start: dt.date, end: dt.date, out_dir: Path, workers: int = 2, log=print) -> list[Path]:
    import threading
    out_dir = Path(out_dir); out_dir.mkdir(parents=True, exist_ok=True)
    days = [d for d in pd.date_range(start, end, freq="D") if d.weekday() != 5]
    todo = [d for d in days if not (out_dir / f"{sym}_{d.strftime('%Y%m%d')}.parquet").exists()]
    written = [out_dir / f"{sym}_{d.strftime('%Y%m%d')}.parquet" for d in days if d not in todo]
    local = threading.local()

    def session():
        if not hasattr(local, "s"):
            local.s = requests.Session()
        return local.s

    def task(day):
        d = day.date()
        bid = fetch_day_candles(sym, d, "BID", session())
        if len(bid) == 0:
            return None
        ask = fetch_day_candles(sym, d, "ASK", session())
        m1 = candles_to_m1(bid, ask)
        if m1.empty:
            return None
        path = out_dir / f"{sym}_{day.strftime('%Y%m%d')}.parquet"
        m1.to_parquet(path)
        return path

    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        for i, p in enumerate(ex.map(task, todo)):
            if p:
                written.append(p)
            if (i + 1) % 25 == 0:
                log(f"{sym}: {i + 1}/{len(todo)} días (candles)", flush=True)
    return sorted(written)
