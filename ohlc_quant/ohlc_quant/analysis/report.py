from __future__ import annotations

import re
from pathlib import Path

import pandas as pd

COLMAP = {
    "time": "time", "hora": "time", "tiempo": "time",
    "deal": "deal", "transaccion": "deal", "transaccin": "deal", "operacion": "deal",
    "symbol": "symbol", "simbolo": "symbol", "smbolo": "symbol",
    "type": "type", "tipo": "type",
    "direction": "direction", "direccion": "direction", "direccin": "direction",
    "volume": "volume", "volumen": "volume",
    "price": "price", "precio": "price",
    "order": "order", "orden": "order",
    "commission": "commission", "comision": "commission", "comisin": "commission",
    "swap": "swap",
    "profit": "profit", "beneficio": "profit", "ganancia": "profit",
    "balance": "balance", "saldo": "balance",
    "comment": "comment", "comentario": "comment",
}


def _norm(s) -> str:
    return re.sub(r"[^a-z]", "", str(s).strip().lower())


def _extract_table(raw: pd.DataFrame) -> pd.DataFrame | None:
    hdr = None
    for i in range(min(len(raw), 5000)):
        mapped = [COLMAP.get(_norm(v)) for v in raw.iloc[i].tolist()]
        if "deal" in mapped and "profit" in mapped and "direction" in mapped:
            hdr = i
            break
    if hdr is None:
        return None
    header = [COLMAP.get(_norm(v)) for v in raw.iloc[hdr].tolist()]
    body = raw.iloc[hdr + 1:].copy()
    body.columns = [h if h else f"col{j}" for j, h in enumerate(header)]
    body = body[[c for c in body.columns if not c.startswith("col")]]
    body = body.dropna(subset=["deal"])
    body = body[pd.to_numeric(body["deal"], errors="coerce").notna()]
    for c in ["volume", "price", "commission", "swap", "profit", "balance"]:
        if c in body.columns:
            body[c] = pd.to_numeric(body[c].astype(str).str.replace(" ", "").str.replace(",", "."), errors="coerce").fillna(0.0)
    body["time"] = pd.to_datetime(body["time"], errors="coerce")
    body["direction"] = body["direction"].astype(str).str.strip().str.lower()
    body["type"] = body["type"].astype(str).str.strip().str.lower()
    if "comment" not in body.columns:
        body["comment"] = ""
    body["comment"] = body["comment"].fillna("").astype(str)
    return body.reset_index(drop=True)


def load_deals(path: str | Path) -> pd.DataFrame:
    path = Path(path)
    if path.suffix.lower() in (".xlsx", ".xls"):
        df = _extract_table(pd.read_excel(path, header=None))
    else:
        df = None
        for t in pd.read_html(path, header=None):
            try:
                cand = _extract_table(t)
            except Exception:
                continue
            if cand is not None and (df is None or len(cand) > len(df)):
                df = cand
    if df is None:
        raise ValueError(f"no se encontró la tabla de transacciones en {path}")
    return df


def set_from_comment(c: str) -> str:
    m = re.match(r"R\d+([FC])", str(c).strip())
    return {"F": "FIJO", "C": "CUSTOM"}[m.group(1)] if m else "?"


def deals_to_trades(deals: pd.DataFrame) -> pd.DataFrame:
    rows = []
    cur = None
    for _, d in deals.iterrows():
        dirn = d["direction"]
        cost = d["commission"] + d["swap"] + d["profit"]
        if dirn.startswith("in"):
            cur = {"open_time": d["time"], "type": d["type"], "vol": d["volume"], "open_price": d["price"], "cost": cost,
                   "comment": d["comment"], "set": set_from_comment(d["comment"]), "balance_before": d["balance"] - cost}
        elif dirn.startswith("out") and cur is not None:
            cur.update(close_time=d["time"], close_price=d["price"], pnl=cur["cost"] + cost, balance_after=d["balance"])
            rows.append(cur)
            cur = None
    df = pd.DataFrame(rows)
    if len(df):
        df["risk_pct_real"] = (-df["pnl"] / df["balance_before"] * 100).where(df["pnl"] < 0)
        df["r_multiple"] = 0.0
    return df
