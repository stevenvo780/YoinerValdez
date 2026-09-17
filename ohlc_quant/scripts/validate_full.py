from __future__ import annotations

import json
import sys
import time
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from ohlc_quant.analysis.metrics import by_period, by_weekday, compute_metrics, exclusion_analysis, metrics_table
from ohlc_quant.analysis.montecarlo import mc_suite
from ohlc_quant.analysis.sensitivity import grid_2d, one_at_a_time, plateau_score
from ohlc_quant.analysis.sizing import capital_table, min_lot_risk_profile
from ohlc_quant.analysis.stress import broker_sweep, deposit_sweep, stress_suite
from ohlc_quant.analysis.walkforward import evaluate_many, oos_split, param_grid, walk_forward, wf_summary, wf_table
from ohlc_quant.data.bars import build_market
from ohlc_quant.data.dukascopy import load_m1
from ohlc_quant.engine.backtest import run_backtest
from ohlc_quant.engine.params import BrokerSpec, EAParams, ServerClock
from ohlc_quant.engine.signals import atr_series

OUT = ROOT / "reports" / "full"
OUT.mkdir(parents=True, exist_ok=True)
DEPOSIT_SMALL = 300.0
DEPOSIT_OK = 3000.0
GRID = {"structure_lookback": [8, 10, 12, 14, 16], "atr_sl_mult": [1.4, 1.6, 1.8, 2.0, 2.2]}
lines: list[str] = []


def w(s: str = ""):
    print(s, flush=True)
    lines.append(s)


def table(df: pd.DataFrame, floatfmt="{:.2f}"):
    w("```")
    w(df.to_string(float_format=lambda x: floatfmt.format(x)))
    w("```")


def main():
    t0 = time.time()
    global OUT
    if len(sys.argv) > 1 and sys.argv[1] == "--synthetic":
        from ohlc_quant.data.synthetic import synthetic_m1
        m1 = synthetic_m1(days=int(sys.argv[2]), seed=3)
        OUT = ROOT / "reports" / "full_synthetic"
        OUT.mkdir(parents=True, exist_ok=True)
    else:
        m1 = load_m1("XAUUSD", ROOT / "data" / "bars")
    md = build_market(m1, ServerClock(2, "us"))
    span = (m1.index.max() - m1.index.min()).days
    w("# Validación cuantitativa OHLCMTF SCALPER v14 sobre XAUUSD (ticks Dukascopy)")
    w(f"Datos: {m1.index.min()} → {m1.index.max()} UTC · {len(m1):,} velas M1 · {span} días · hora servidor UTC+2/+3 (DST US)")
    from ohlc_quant.data.quality import data_quality
    w("```"); w(json.dumps(data_quality(m1), indent=1, ensure_ascii=False, default=str)); w("```")
    w()

    w("## 1. Backtests base")
    rows = {}
    results = {}
    for name, p, dep in (("v140_$300", EAParams.v140(), DEPOSIT_SMALL), ("v141_$300", EAParams(), DEPOSIT_SMALL),
                         ("v141_$3000", EAParams(), DEPOSIT_OK), ("lean_$3000", EAParams.lean(), DEPOSIT_OK),
                         ("v141_$3000_solo_fijo", EAParams(use_custom_pair=False), DEPOSIT_OK),
                         ("v141_$3000_solo_custom", EAParams(use_fixed_set=False), DEPOSIT_OK)):
        r = run_backtest(md, p, BrokerSpec(), dep)
        results[name] = r
        rows[name] = compute_metrics(r.trades, dep, r.equity.values, span)
        r.trades.to_csv(OUT / f"trades_{name}.csv", index=False)
        w(f"- {name}: señales={r.signals} stats={r.stats}")
    table(metrics_table(rows))
    rows_ref = dict(rows)
    w()

    w("## 2. Riesgo real por operación y capital necesario")
    for name in ("v140_$300", "v141_$3000"):
        w(f"- {name}: {json.dumps(min_lot_risk_profile(results[name].trades, 0), default=str)}")
    _, atr = atr_series(md, EAParams())
    table(capital_table(atr, EAParams(), BrokerSpec()))
    w("Barrido de depósito (v141):")
    table(deposit_sweep(md, EAParams(), BrokerSpec()))
    w()

    ref = results["v141_$3000"]
    w("## 3. Distribución temporal (v141 $3000)")
    w("Por mes:"); table(by_period(ref.trades))
    w("Por día de la semana:"); table(by_weekday(ref.trades))
    w("Exclusiones:"); table(metrics_table(exclusion_analysis(ref.trades, DEPOSIT_OK)))
    w("Por set:"); table(ref.trades.groupby("set")["pnl"].agg(["count", "sum", "mean"]))
    w("Por salida:"); table(ref.trades.groupby("exit")["pnl"].agg(["count", "sum", "mean"]))
    w("Por fuerza de señal:"); table(ref.trades.groupby("strength")["pnl"].agg(["count", "sum", "mean"]))
    w()

    w("## 4. Monte Carlo sobre las operaciones (v141 $3000 y v140 $300)")
    for name, dep in (("v141_$3000", DEPOSIT_OK), ("v140_$300", DEPOSIT_SMALL)):
        tr = results[name].trades
        if len(tr) >= 10:
            w(f"{name}:"); table(mc_suite(tr, dep, runs=20000))
    w()

    w("## 5. Partición temporal 70/30 (malla en IS, una sola evaluación OOS)")
    (is0, is1), (o0, o1) = oos_split(md, 0.3)
    res = evaluate_many(md, param_grid(EAParams.lean(), GRID), BrokerSpec(), DEPOSIT_OK, is0, is1)
    tab = pd.DataFrame([{**{k: getattr(q, k) for k in GRID}, **m.as_dict()} for q, m in res]).sort_values("expectancy", ascending=False)
    w(f"IS {is0} → {is1}; OOS {o0} → {o1}")
    table(tab[["structure_lookback", "atr_sl_mult", "n", "net", "profit_factor", "expectancy", "max_dd_pct"]].head(10))
    best = res[int(tab.index[0])][0]
    (_, om), = evaluate_many(md, [best], BrokerSpec(), DEPOSIT_OK, o0, o1, 1)
    (_, dm), = evaluate_many(md, [EAParams.lean()], BrokerSpec(), DEPOSIT_OK, o0, o1, 1)
    table(metrics_table({"OOS_mejor_IS": om, "OOS_defaults": dm}))
    tab.to_csv(OUT / "oos_grid.csv", index=False)
    w()

    w("## 6. Walk-forward rodante (IS 6m / OOS 2m / paso 2m, preset LEAN $3000)")
    wf = walk_forward(md, EAParams.lean(), GRID, BrokerSpec(), DEPOSIT_OK, 6, 2, 2, False, "expectancy_x_n", None, 15)
    table(wf_table(wf))
    w("```"); w(json.dumps(wf_summary(wf), indent=2, default=str)); w("```")
    wf_table(wf).to_csv(OUT / "wfa.csv", index=False)
    w("Walk-forward anclado:")
    wfa = walk_forward(md, EAParams.lean(), GRID, BrokerSpec(), DEPOSIT_OK, 6, 2, 2, True, "expectancy_x_n", None, 15)
    w("```"); w(json.dumps(wf_summary(wfa), indent=2, default=str)); w("```")
    w()

    w("## 7. Sensibilidad ±10/20 % (LEAN $3000)")
    sens = one_at_a_time(md, EAParams.lean(), BrokerSpec(), DEPOSIT_OK)
    table(sens)
    sens.to_csv(OUT / "sensitivity.csv", index=False)
    g = grid_2d(md, EAParams.lean(), BrokerSpec(), DEPOSIT_OK, "structure_lookback", GRID["structure_lookback"], "atr_sl_mult", GRID["atr_sl_mult"])
    w(f"Malla structure_lookback × atr_sl_mult (expectancy), meseta={plateau_score(g):.2f}")
    table(g)
    g2 = grid_2d(md, EAParams.lean(), BrokerSpec(), DEPOSIT_OK, "min_breakout_atr_mult", [0.15, 0.2, 0.28, 0.35, 0.45], "min_body_ratio", [0.45, 0.5, 0.55, 0.6, 0.65])
    w(f"Malla min_breakout_atr_mult × min_body_ratio (expectancy), meseta={plateau_score(g2):.2f}")
    table(g2)
    w()

    w("## 8. Estrés de ejecución y de configuración (LEAN $3000)")
    st = stress_suite(md, EAParams.lean(), BrokerSpec(), DEPOSIT_OK, m1_utc=m1)
    table(st)
    st.to_csv(OUT / "stress.csv")
    w("Tipos de bróker:"); table(broker_sweep(md, EAParams.lean(), DEPOSIT_OK))
    w()

    w("## 9. Sensibilidad de sesión y del set custom (v141 $3000)")
    rows = {}
    for name, p in (("sesion_7-20", EAParams()), ("sesion_8-18", EAParams(session_start_hour=8, session_end_hour=18)),
                    ("sesion_9-17", EAParams(session_start_hour=9, session_end_hour=17)), ("sesion_13-20", EAParams(session_start_hour=13, session_end_hour=20)),
                    ("sin_sesion", EAParams(use_session_filter=False)), ("custom_M15", EAParams(tf_fast="M15")),
                    ("custom_M30", EAParams(tf_fast="M30")), ("trend_D1", EAParams(trend_timeframe="D1")), ("min_str_5", EAParams(min_signal_strength=5)),
                    ("min_str_3", EAParams(min_signal_strength=3)), ("sin_expansion", EAParams(prefer_expansion_break=False))):
        r = run_backtest(md, p, BrokerSpec(), DEPOSIT_OK)
        rows[name] = compute_metrics(r.trades, DEPOSIT_OK, r.equity.values, span)
    table(metrics_table(rows))
    w()

    w("## 10. Por año (v141 $3000, defaults)")
    yrs = {}
    for y in sorted(set(md.m1.index.year)):
        r = run_backtest(md, EAParams(), BrokerSpec(), DEPOSIT_OK, start=f"{y}-01-01", end=f"{y + 1}-01-01")
        yrs[str(y)] = compute_metrics(r.trades, DEPOSIT_OK, r.equity.values, 365)
    table(metrics_table(yrs))
    w()
    w("## 11. Hipótesis nula: la misma estrategia sobre caminos sintéticos sin estructura (paseo aleatorio con regímenes de volatilidad)")
    for name, key, dep in (("synthetic", "v140_$300", DEPOSIT_SMALL), ("synthetic_v141", "v141_$3000", DEPOSIT_OK)):
        f = ROOT / "reports" / name / "synthetic_mc.csv"
        if not f.exists():
            continue
        syn = pd.read_csv(f)
        real = rows_ref[key]
        yrs = max(span / 365.25, 1e-9)
        exp_real = real.expectancy; pf_real = real.profit_factor
        w(f"- {key} vs {len(syn)} caminos sintéticos de 365 días: expectancy real={exp_real:.2f} (percentil sintético {int((syn['expectancy'] < exp_real).mean() * 100)}), "
          f"PF real={pf_real:.2f} (percentil {int((syn['profit_factor'] < pf_real).mean() * 100)}), "
          f"neto sintético mediana={syn['net'].median():.0f}, P(neto>0)={(syn['net'] > 0).mean() * 100:.0f}%")
    w()
    w(f"Tiempo total: {time.time() - t0:.0f}s")
    (OUT / "VALIDACION.md").write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
