#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
analyze_mt5_report.py — Análisis de robustez sobre el reporte del Strategy Tester de MT5.

Uso:
    python3 analyze_mt5_report.py ReportTester-XXXX.xlsx  [--deposit 300] [--runs 20000] [--seed 7]
    python3 analyze_mt5_report.py ReportTester-XXXX.html  [...]

Entrada: el reporte exportado desde el Strategy Tester (clic derecho en la pestaña
"Backtest" → "Informe" → Excel (.xlsx) o HTML). Se usa la tabla "Transacciones" / "Deals".

Salida:
  1. Reconstrucción de operaciones (par IN/OUT por posición) con P&L neto (profit+swap+comisión).
  2. Atribución por SET (comentario "R###F" = set fijo, "R###C" = set custom) si el reporte lo trae.
  3. P&L por mes y por día de la semana.
  4. Métricas recalculadas EXCLUYENDO el mejor mes y EXCLUYENDO el mejor día de la semana.
  5. Monte Carlo: barajado de la secuencia (sin reposición) y bootstrap (con reposición),
     distribución de drawdown máximo, rachas, probabilidad de ruina (equity ≤ 50% del depósito).
  6. Riesgo real por operación (pérdida / balance previo) para detectar forzado por lote mínimo.
"""
import sys
import argparse
import random
import re
from collections import defaultdict

try:
    import pandas as pd
except ImportError:
    sys.exit("Necesita pandas (pip install pandas openpyxl lxml)")

MONTHS = ["Ene","Feb","Mar","Abr","May","Jun","Jul","Ago","Sep","Oct","Nov","Dic"]
WEEKDAYS = ["Lun","Mar","Mié","Jue","Vie","Sáb","Dom"]

# ----------------------------------------------------------------------------- carga
def load_deals(path):
    """Devuelve DataFrame con columnas normalizadas: time, deal, symbol, type, direction,
    volume, price, order, commission, swap, profit, balance, comment."""
    if path.lower().endswith((".xlsx", ".xls")):
        raw = pd.read_excel(path, header=None)
        df = _extract_table(raw)
    else:
        tables = pd.read_html(path, header=None)
        df = None
        for t in tables:
            try:
                cand = _extract_table(t)
                if cand is not None and len(cand) > 0:
                    df = cand if df is None or len(cand) > len(df) else df
            except Exception:
                continue
        if df is None:
            sys.exit("No se encontró la tabla de transacciones (Deals) en el HTML")
    return df

def _norm(s):
    s = str(s).strip().lower()
    return re.sub(r"[^a-z]", "", s)

COLMAP = {
    "time":"time","hora":"time","tiempo":"time",
    "deal":"deal","transaccion":"deal","transaccin":"deal","operacion":"deal",
    "symbol":"symbol","simbolo":"symbol","smbolo":"symbol",
    "type":"type","tipo":"type",
    "direction":"direction","direccion":"direction","direccin":"direction",
    "volume":"volume","volumen":"volume",
    "price":"price","precio":"price",
    "order":"order","orden":"order",
    "commission":"commission","comision":"commission","comisin":"commission",
    "swap":"swap",
    "profit":"profit","beneficio":"profit","ganancia":"profit",
    "balance":"balance","saldo":"balance",
    "comment":"comment","comentario":"comment",
}

def _extract_table(raw):
    # buscar la fila cabecera que contenga 'deal'/'transacción' y 'profit'/'beneficio'
    hdr_idx = None
    for i in range(min(len(raw), 5000)):
        vals = [_norm(v) for v in raw.iloc[i].tolist()]
        mapped = [COLMAP.get(v) for v in vals]
        if "deal" in mapped and "profit" in mapped and "direction" in mapped:
            hdr_idx = i; break
    if hdr_idx is None:
        return None
    header = [COLMAP.get(_norm(v), None) for v in raw.iloc[hdr_idx].tolist()]
    body = raw.iloc[hdr_idx+1:].copy()
    body.columns = [h if h else f"col{j}" for j, h in enumerate(header)]
    body = body[[c for c in body.columns if not c.startswith("col")]]
    body = body.dropna(subset=["deal"])
    body = body[pd.to_numeric(body["deal"], errors="coerce").notna()]
    for c in ["volume","price","commission","swap","profit","balance"]:
        if c in body.columns:
            body[c] = pd.to_numeric(body[c].astype(str).str.replace(" ", "").str.replace(",", "."), errors="coerce").fillna(0.0)
    body["time"] = pd.to_datetime(body["time"], errors="coerce")
    body["direction"] = body["direction"].astype(str).str.strip().str.lower()
    body["type"] = body["type"].astype(str).str.strip().str.lower()
    if "comment" not in body.columns: body["comment"] = ""
    body["comment"] = body["comment"].fillna("").astype(str)
    return body.reset_index(drop=True)

# ----------------------------------------------------------------------------- trades
def build_trades(deals):
    """Empareja deals 'in' con sus 'out' (netting/hedging: una posición a la vez en este EA)."""
    trades = []
    open_trade = None
    for _, d in deals.iterrows():
        dirn = d["direction"]
        if dirn.startswith("in"):
            open_trade = {"open_time": d["time"], "type": d["type"], "volume": d["volume"],
                          "open_price": d["price"], "cost": d["commission"] + d["swap"] + d["profit"],
                          "comment": d["comment"], "set": _set_from_comment(d["comment"]),
                          "balance_before": None}
            # balance antes de abrir = balance de la fila anterior (columna balance tras el deal)
            open_trade["balance_before"] = d["balance"] - (d["commission"] + d["swap"] + d["profit"])
        elif dirn.startswith("out") and open_trade is not None:
            pnl = open_trade["cost"] + d["commission"] + d["swap"] + d["profit"]
            open_trade.update({"close_time": d["time"], "close_price": d["price"], "pnl": pnl,
                               "balance_after": d["balance"]})
            trades.append(open_trade)
            open_trade = None
    return trades

def _set_from_comment(c):
    m = re.match(r"R\d+([FC])", c.strip())
    if m: return "FIJO" if m.group(1) == "F" else "CUSTOM"
    return "?"

# ----------------------------------------------------------------------------- métricas
def metrics(pnls, deposit):
    n = len(pnls)
    if n == 0: return {"n":0}
    wins = [p for p in pnls if p > 0]; losses = [p for p in pnls if p <= 0]
    gp = sum(wins); gl = -sum(losses)
    eq = deposit; peak = deposit; mdd = 0; mddp = 0
    for p in pnls:
        eq += p; peak = max(peak, eq); dd = peak - eq
        if dd > mdd: mdd, mddp = dd, dd / peak * 100
    streak = best = 0
    for p in pnls:
        streak = streak + 1 if p <= 0 else 0; best = max(best, streak)
    return {"n": n, "net": sum(pnls), "pf": (gp / gl) if gl > 0 else float("inf"),
            "winrate": len(wins) / n * 100, "avg_win": (gp / len(wins)) if wins else 0,
            "avg_loss": (-gl / len(losses)) if losses else 0, "expectancy": sum(pnls) / n,
            "max_dd": mdd, "max_dd_pct": mddp, "max_loss_streak": best,
            "recovery": (sum(pnls) / mdd) if mdd > 0 else float("inf")}

def fmt(m):
    if m.get("n", 0) == 0: return "  (sin operaciones)"
    return (f"  n={m['n']:3d}  neto=${m['net']:9.2f}  PF={m['pf']:5.2f}  WR={m['winrate']:5.1f}%  "
            f"E[$/trade]={m['expectancy']:7.2f}  maxDD=${m['max_dd']:7.2f} ({m['max_dd_pct']:5.1f}%)  "
            f"racha-={m['max_loss_streak']}  RF={m['recovery']:5.2f}")

def montecarlo(trades, deposit, runs, seed, target_risk_pct=None):
    """MC sobre RETORNOS fraccionales (pnl / balance previo), compuestos multiplicativamente.
    target_risk_pct: si se indica, todas las operaciones se reescalan por un factor k tal que la
    pérdida MEDIANA pase a valer target_risk_pct % del equity (simula sizing fraccional corregido:
    ganancias y pérdidas se reducen en la misma proporción)."""
    rnd = random.Random(seed)
    rets = [t["pnl"] / t["balance_before"] for t in trades if t["balance_before"] and t["balance_before"] > 0]
    if not rets: return {}
    losses = sorted(-r for r in rets if r < 0)
    med_loss = losses[len(losses) // 2] if losses else 0.01
    k = 1.0 if target_risk_pct is None else min(1.0, (target_risk_pct / 100.0) / med_loss)
    res = {}
    for mode in ("shuffle", "bootstrap"):
        dds = []; ruins = 0; streaks = []; finals = []
        for _ in range(runs):
            seq = rets[:] if mode == "shuffle" else [rnd.choice(rets) for _ in rets]
            if mode == "shuffle": rnd.shuffle(seq)
            eq = deposit; peak = deposit; mdd = 0; ruin = False; st = bs = 0
            for r in seq:
                eq *= (1.0 + k * r); peak = max(peak, eq)
                mdd = max(mdd, (peak - eq) / peak * 100)
                if eq <= deposit * 0.5: ruin = True
                st = st + 1 if r <= 0 else 0; bs = max(bs, st)
            dds.append(mdd); ruins += ruin; streaks.append(bs); finals.append(eq)
        dds.sort(); streaks.sort(); finals.sort()
        q = lambda a, p: a[min(len(a) - 1, int(p * len(a)))]
        res[mode] = {"dd_p50": q(dds, .5), "dd_p95": q(dds, .95), "dd_p99": q(dds, .99),
                     "p_dd12": sum(d >= 12 for d in dds) / runs * 100, "p_dd30": sum(d >= 30 for d in dds) / runs * 100,
                     "p_ruin": ruins / runs * 100, "streak_p95": q(streaks, .95), "streak_p99": q(streaks, .99),
                     "final_p05": q(finals, .05), "final_p50": q(finals, .5), "p_loss": sum(f < deposit for f in finals) / runs * 100,
                     "k": k, "med_loss_pct": med_loss * 100}
    return res

def print_mc(res, title):
    print(f"\n{title}")
    if not res: print("  (sin datos de balance previo)"); return
    first = next(iter(res.values()))
    print(f"  factor de escala k={first['k']:.3f} (pérdida mediana observada = {first['med_loss_pct']:.2f}% del balance previo)")
    for mode, r in res.items():
        print(f"  [{mode:9s}] maxDD% p50={r['dd_p50']:5.1f} p95={r['dd_p95']:5.1f} p99={r['dd_p99']:5.1f} | "
              f"P(DD>=12%)={r['p_dd12']:4.1f}% P(DD>=30%)={r['p_dd30']:4.1f}% | P(ruina 50%)={r['p_ruin']:4.1f}% | "
              f"racha- p95={r['streak_p95']} p99={r['streak_p99']} | final p05=${r['final_p05']:.0f} p50=${r['final_p50']:.0f} | P(neto<0)={r['p_loss']:.1f}%")

# ----------------------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("report")
    ap.add_argument("--deposit", type=float, default=300.0)
    ap.add_argument("--runs", type=int, default=20000)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--cap", type=float, default=1.0, help="pérdida mediana objetivo (%% equity) para el MC de sizing corregido")
    a = ap.parse_args()

    deals = load_deals(a.report)
    trades = build_trades(deals)
    if not trades: sys.exit("No se reconstruyó ninguna operación: revise el formato del reporte")
    pnls = [t["pnl"] for t in trades]

    print("=" * 100)
    print(f"REPORTE: {a.report}  |  operaciones reconstruidas: {len(trades)}  |  depósito: ${a.deposit:.2f}")
    print("=" * 100)
    print("\n[1] MÉTRICAS GLOBALES"); print(fmt(metrics(pnls, a.deposit)))

    # riesgo real por operación
    risks = []
    for t in trades:
        if t["pnl"] < 0 and t["balance_before"]:
            risks.append(-t["pnl"] / t["balance_before"] * 100)
    if risks:
        risks.sort()
        print(f"\n[2] RIESGO REAL POR OPERACIÓN PERDEDORA (pérdida / balance previo): "
              f"mediana={risks[len(risks)//2]:.2f}%  p90={risks[int(.9*len(risks))]:.2f}%  máx={risks[-1]:.2f}%  "
              f"(configurado 0.25–1.25%, techo 2.5%)")
        vols = sorted(set(round(t["volume"], 2) for t in trades))
        print(f"    volúmenes usados: {vols}  →  si casi todo es el lote mínimo, el sizing está forzado por SYMBOL_VOLUME_MIN")

    # atribución por set
    by_set = defaultdict(list)
    for t in trades: by_set[t["set"]].append(t["pnl"])
    print("\n[3] ATRIBUCIÓN POR SET DE SEÑALES (comentario R###F / R###C; '?' = reporte v14.0 sin etiqueta)")
    for k, v in by_set.items(): print(f"  {k:7s}" + fmt(metrics(v, a.deposit)))

    # por mes y por día
    by_month = defaultdict(list); by_wd = defaultdict(list)
    for t in trades:
        by_month[(t["open_time"].year, t["open_time"].month)].append(t["pnl"])
        by_wd[t["open_time"].weekday()].append(t["pnl"])
    print("\n[4] P&L POR MES (por fecha de apertura)")
    for k in sorted(by_month): print(f"  {k[0]}-{MONTHS[k[1]-1]}: n={len(by_month[k]):3d} neto=${sum(by_month[k]):8.2f}")
    print("\n[5] P&L POR DÍA DE LA SEMANA (apertura)")
    for k in sorted(by_wd): print(f"  {WEEKDAYS[k]}: n={len(by_wd[k]):3d} neto=${sum(by_wd[k]):8.2f}")

    best_m = max(by_month, key=lambda k: sum(by_month[k])); best_d = max(by_wd, key=lambda k: sum(by_wd[k]))
    print("\n[6] EXCLUSIONES (dependencia de outliers)")
    ex_m = [t["pnl"] for t in trades if (t["open_time"].year, t["open_time"].month) != best_m]
    ex_d = [t["pnl"] for t in trades if t["open_time"].weekday() != best_d]
    ex_both = [t["pnl"] for t in trades if (t["open_time"].year, t["open_time"].month) != best_m and t["open_time"].weekday() != best_d]
    top3 = sorted(pnls)[-3:]
    ex_top3 = [p for p in pnls if p not in top3]
    print(f"  sin mejor mes ({best_m[0]}-{MONTHS[best_m[1]-1]}):" + fmt(metrics(ex_m, a.deposit)))
    print(f"  sin mejor día ({WEEKDAYS[best_d]}):        " + fmt(metrics(ex_d, a.deposit)))
    print("  sin ambos:                     " + fmt(metrics(ex_both, a.deposit)))
    print("  sin las 3 mejores operaciones: " + fmt(metrics(ex_top3, a.deposit)))

    print_mc(montecarlo(trades, a.deposit, a.runs, a.seed), f"[7] MONTE CARLO ({a.runs} corridas) – retornos fraccionales tal cual (sizing v14.0)")
    print_mc(montecarlo(trades, a.deposit, a.runs, a.seed, target_risk_pct=a.cap), f"[8] MONTE CARLO – reescalado a pérdida mediana = {a.cap}% del equity (sizing v14.1 fraccional)")

    # duración y hora de cierre
    durs = [(t["close_time"] - t["open_time"]).total_seconds() / 3600 for t in trades]
    durs.sort()
    print(f"\n[9] DURACIÓN (h): mediana={durs[len(durs)//2]:.1f}  p90={durs[int(.9*len(durs))]:.1f}  máx={durs[-1]:.1f}")
    over_wknd = sum(1 for t in trades if (t["close_time"] - t["open_time"]).days >= 2 or
                    (t["open_time"].weekday() == 4 and t["close_time"].weekday() != 4))
    print(f"    operaciones que cruzaron fin de semana: {over_wknd}")

if __name__ == "__main__":
    main()
