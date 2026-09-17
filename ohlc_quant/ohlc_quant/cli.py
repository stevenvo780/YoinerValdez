from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path

import pandas as pd

from ohlc_quant.analysis.metrics import by_hour, by_period, by_weekday, compute_metrics, exclusion_analysis, metrics_table
from ohlc_quant.analysis.montecarlo import mc_suite, summary_stats_mc
from ohlc_quant.analysis.report import deals_to_trades, load_deals
from ohlc_quant.analysis.sensitivity import grid_2d, one_at_a_time, plateau_score
from ohlc_quant.analysis.sizing import capital_table, min_lot_risk_profile
from ohlc_quant.analysis.stress import broker_sweep, deposit_sweep, stress_suite
from ohlc_quant.analysis.walkforward import evaluate_many, oos_split, param_grid, walk_forward, wf_summary, wf_table
from ohlc_quant.data.bars import build_market
from ohlc_quant.data.dukascopy import download_range, load_m1
from ohlc_quant.data.quality import data_quality
from ohlc_quant.data.synthetic import synthetic_m1
from ohlc_quant.engine.backtest import run_backtest
from ohlc_quant.engine.params import BrokerSpec, EAParams, ServerClock
from ohlc_quant.engine.signals import atr_series

ROOT = Path(__file__).resolve().parents[1]
pd.set_option("display.width", 220)
pd.set_option("display.max_columns", 40)


def _out(args, name: str, obj):
    out = Path(args.out); out.mkdir(parents=True, exist_ok=True)
    path = out / name
    if isinstance(obj, pd.DataFrame):
        obj.to_csv(path.with_suffix(".csv"))
    else:
        path.with_suffix(".json").write_text(json.dumps(obj, indent=2, default=str), encoding="utf-8")
    return path


def _params(args) -> EAParams:
    p = {"v141": EAParams(), "v140": EAParams.v140(), "lean": EAParams.lean()}[args.preset]
    for kv in args.set or []:
        k, v = kv.split("=", 1)
        cur = getattr(p, k)
        val = (v.lower() in ("1", "true", "yes")) if isinstance(cur, bool) else type(cur)(v)
        p = p.with_(**{k: val})
    return p


def _broker(args) -> BrokerSpec:
    b = BrokerSpec()
    for kv in args.broker or []:
        k, v = kv.split("=", 1)
        b = b.__class__(**{**b.__dict__, k: type(getattr(b, k))(v)})
    return b


def _market(args):
    if args.synthetic:
        m1 = synthetic_m1(days=args.synthetic, seed=args.seed)
    else:
        m1 = load_m1(args.symbol, args.bars)
    clock = ServerClock(args.utc_offset, args.dst)
    return build_market(m1, clock), m1


def _print_metrics(title, m):
    print(f"\n== {title} ==")
    for k, v in m.as_dict().items():
        print(f"  {k:18s} {v:,.3f}" if isinstance(v, float) else f"  {k:18s} {v}")


def cmd_download(args):
    files = download_range(args.symbol, dt.date.fromisoformat(args.from_date), dt.date.fromisoformat(args.to_date), Path(args.bars), args.workers or 48)
    print(f"{len(files)} días en {args.bars}")


def cmd_data_check(args):
    _, m1 = _market(args)
    q = data_quality(m1)
    print(json.dumps(q, indent=2, ensure_ascii=False))
    _out(args, "data_quality", q)


def cmd_backtest(args):
    md, _ = _market(args)
    p = _params(args); b = _broker(args)
    r = run_backtest(md, p, b, args.deposit, start=args.start, end=args.end)
    m = compute_metrics(r.trades, args.deposit, r.equity.values)
    _print_metrics(f"backtest {args.preset} depósito ${args.deposit}", m)
    print("\nestadísticas motor:", r.stats)
    if len(r.trades):
        print("\npor set:\n", r.trades.groupby("set")["pnl"].agg(["count", "sum", "mean"]))
        print("\nsalidas:\n", r.trades.groupby("exit")["pnl"].agg(["count", "sum"]))
        print("\npor mes:\n", by_period(r.trades).to_string())
        print("\npor día:\n", by_weekday(r.trades).to_string())
        print("\nexclusiones:\n", metrics_table(exclusion_analysis(r.trades, args.deposit)).to_string())
        print("\nriesgo real:", min_lot_risk_profile(r.trades, args.deposit))
        _out(args, f"trades_{args.preset}", r.trades)
        r.equity.resample("1h").last().to_csv(Path(args.out) / f"equity_{args.preset}.csv")
    _out(args, f"metrics_{args.preset}", m.as_dict())


def cmd_compare(args):
    md, _ = _market(args)
    b = _broker(args)
    rows = {}
    for name, p in (("v140", EAParams.v140()), ("v141", EAParams()), ("lean", EAParams.lean())):
        r = run_backtest(md, p, b, args.deposit, start=args.start, end=args.end)
        rows[name] = compute_metrics(r.trades, args.deposit, r.equity.values)
        print(name, r.stats)
    tab = metrics_table(rows)
    print(tab.to_string())
    _out(args, "compare", tab)


def cmd_attribution(args):
    md, _ = _market(args)
    p = _params(args); b = _broker(args)
    rows = {}
    for name, q in (("ambos", p), ("solo_fijo", p.with_(use_custom_pair=False)), ("solo_custom", p.with_(use_fixed_set=False))):
        r = run_backtest(md, q, b, args.deposit, start=args.start, end=args.end)
        rows[name] = compute_metrics(r.trades, args.deposit, r.equity.values)
    tab = metrics_table(rows)
    print(tab.to_string())
    _out(args, "attribution", tab)


def cmd_capital(args):
    md, _ = _market(args)
    p = _params(args); b = _broker(args)
    _, atr = atr_series(md, p)
    tab = capital_table(atr, p, b)
    print(tab.to_string())
    print("\nbarrido de depósito:")
    ds = deposit_sweep(md, p, b, start=args.start, end=args.end)
    print(ds.to_string())
    _out(args, "capital", tab); _out(args, "deposit_sweep", ds)


def cmd_mc(args):
    md, _ = _market(args)
    p = _params(args); b = _broker(args)
    r = run_backtest(md, p, b, args.deposit, start=args.start, end=args.end)
    if len(r.trades) < 5:
        print("menos de 5 operaciones; sin Monte Carlo"); return
    tab = mc_suite(r.trades, args.deposit, args.runs, args.seed, args.target_loss)
    print(tab.to_string())
    _out(args, "montecarlo", tab)


def cmd_report(args):
    trades = deals_to_trades(load_deals(args.file))
    print(f"operaciones reconstruidas: {len(trades)}")
    _print_metrics("global", compute_metrics(trades, args.deposit))
    print("\npor set:\n", trades.groupby("set")["pnl"].agg(["count", "sum", "mean"]))
    print("\npor mes:\n", by_period(trades).to_string())
    print("\npor día:\n", by_weekday(trades).to_string())
    print("\npor hora:\n", by_hour(trades).to_string())
    print("\nexclusiones:\n", metrics_table(exclusion_analysis(trades, args.deposit)).to_string())
    print("\nriesgo real:", min_lot_risk_profile(trades, args.deposit))
    if len(trades) >= 5:
        print("\nMonte Carlo:\n", mc_suite(trades, args.deposit, args.runs, args.seed, args.target_loss).to_string())
    _out(args, "report_trades", trades)


def cmd_mc_summary(args):
    r = summary_stats_mc(args.wins, args.losses, args.avg_win, args.avg_loss, args.max_win, args.max_loss, args.deposit, args.runs, args.seed)
    print(json.dumps(r.as_dict(), indent=2))


def cmd_wfa(args):
    md, _ = _market(args)
    p = _params(args); b = _broker(args)
    grid = json.loads(args.grid)
    w = walk_forward(md, p, grid, b, args.deposit, args.is_months, args.oos_months, args.step_months, args.anchored, args.objective, args.workers)
    tab = wf_table(w)
    print(tab.to_string())
    s = wf_summary(w)
    print(json.dumps(s, indent=2, default=str))
    _out(args, "wfa", tab); _out(args, "wfa_summary", s)


def cmd_oos(args):
    md, _ = _market(args)
    p = _params(args); b = _broker(args)
    grid = json.loads(args.grid)
    (is0, is1), (o0, o1) = oos_split(md, args.oos_fraction)
    res = evaluate_many(md, param_grid(p, grid), b, args.deposit, is0, is1, args.workers)
    rows = [{**{k: getattr(q, k) for k in grid}, **m.as_dict()} for q, m in res]
    tab = pd.DataFrame(rows).sort_values("expectancy", ascending=False)
    print("in-sample:", is0, "→", is1); print(tab.head(15).to_string())
    best = res[int(tab.index[0])][0]
    (_, om), = evaluate_many(md, [best], b, args.deposit, o0, o1, 1)
    _print_metrics(f"out-of-sample {o0} → {o1} con mejores params IS", om)
    _out(args, "oos_grid", tab); _out(args, "oos_metrics", om.as_dict())


def cmd_sensitivity(args):
    md, _ = _market(args)
    p = _params(args); b = _broker(args)
    tab = one_at_a_time(md, p, b, args.deposit, start=args.start, end=args.end, workers=args.workers)
    print(tab.to_string())
    _out(args, "sensitivity", tab)
    if args.pair:
        x, y = args.pair.split(",")
        xv = json.loads(args.xvals); yv = json.loads(args.yvals)
        g = grid_2d(md, p, b, args.deposit, x, xv, y, yv, start=args.start, end=args.end, workers=args.workers)
        print(f"\nmalla {x} × {y} (expectancy), plateau={plateau_score(g):.2f}\n", g.round(2).to_string())
        _out(args, f"grid_{x}_{y}", g)


def cmd_stress(args):
    md, m1 = _market(args)
    p = _params(args); b = _broker(args)
    tab = stress_suite(md, p, b, args.deposit, args.start, args.end, m1_utc=m1)
    print(tab.to_string())
    _out(args, "stress", tab)
    print("\nbrókers:\n", broker_sweep(md, p, args.deposit, args.start, args.end).to_string())


def _synthetic_path(job):
    seed, days, vol, p, b, deposit, utc_offset, dst = job
    m1 = synthetic_m1(days=days, seed=seed, vol_annual=vol)
    md = build_market(m1, ServerClock(utc_offset, dst))
    r = run_backtest(md, p, b, deposit)
    m = compute_metrics(r.trades, deposit, r.equity.values)
    return {"seed": seed, **m.as_dict(), "skip_minlot": r.stats["skip_minlot"], "signals": r.signals}


def cmd_synthetic_mc(args):
    import os
    from concurrent.futures import ProcessPoolExecutor
    p = _params(args); b = _broker(args)
    jobs = [(seed, args.days, args.vol, p, b, args.deposit, args.utc_offset, args.dst) for seed in range(args.paths)]
    workers = args.workers or max(1, min(os.cpu_count() or 1, len(jobs)))
    with ProcessPoolExecutor(max_workers=workers) as ex:
        rows = list(ex.map(_synthetic_path, jobs, chunksize=max(1, len(jobs) // (workers * 4))))
    tab = pd.DataFrame(rows)
    print(tab[["n", "net", "profit_factor", "win_rate", "expectancy", "max_dd_pct", "max_loss_streak", "max_risk_pct"]].describe().round(2).to_string())
    print("\n% caminos con neto>0:", round((tab["net"] > 0).mean() * 100, 1), "| % con DD>=12%:", round((tab["max_dd_pct"] >= 12).mean() * 100, 1),
          "| % con DD>=30%:", round((tab["max_dd_pct"] >= 30).mean() * 100, 1))
    _out(args, "synthetic_mc", tab)


def main(argv=None):
    ap = argparse.ArgumentParser(prog="ohlc_quant", description="Validación cuantitativa OHLCMTF SCALPER v14")
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--symbol", default="XAUUSD"); common.add_argument("--bars", default=str(ROOT / "data" / "bars"))
    common.add_argument("--out", default=str(ROOT / "reports")); common.add_argument("--deposit", type=float, default=300.0)
    common.add_argument("--preset", choices=["v141", "v140", "lean"], default="v141"); common.add_argument("--set", action="append", help="param=valor")
    common.add_argument("--broker", action="append", help="campo=valor de BrokerSpec")
    common.add_argument("--utc-offset", type=int, default=2); common.add_argument("--dst", choices=["us", "eu", "none"], default="us")
    common.add_argument("--start"); common.add_argument("--end"); common.add_argument("--synthetic", type=int, default=0, help="días sintéticos en vez de datos reales")
    common.add_argument("--seed", type=int, default=7); common.add_argument("--runs", type=int, default=20000); common.add_argument("--target-loss", type=float, default=1.0)
    common.add_argument("--workers", type=int, default=None)
    sub = ap.add_subparsers(dest="cmd", required=True)
    P = dict(parents=[common])
    s = sub.add_parser("download", **P); s.add_argument("from_date"); s.add_argument("to_date"); s.set_defaults(fn=cmd_download)
    sub.add_parser("backtest", **P).set_defaults(fn=cmd_backtest)
    sub.add_parser("data-check", **P).set_defaults(fn=cmd_data_check)
    sub.add_parser("compare", **P).set_defaults(fn=cmd_compare)
    sub.add_parser("attribution", **P).set_defaults(fn=cmd_attribution)
    sub.add_parser("capital", **P).set_defaults(fn=cmd_capital)
    sub.add_parser("mc", **P).set_defaults(fn=cmd_mc)
    s = sub.add_parser("report", **P); s.add_argument("file"); s.set_defaults(fn=cmd_report)
    s = sub.add_parser("mc-summary", **P)
    for k, t in (("wins", int), ("losses", int), ("avg-win", float), ("avg-loss", float), ("max-win", float), ("max-loss", float)):
        s.add_argument(f"--{k}", type=t, required=True)
    s.set_defaults(fn=cmd_mc_summary)
    s = sub.add_parser("wfa", **P); s.add_argument("--grid", default='{"structure_lookback":[8,12,16],"atr_sl_mult":[1.5,1.8,2.2]}')
    s.add_argument("--is-months", type=int, default=6); s.add_argument("--oos-months", type=int, default=2); s.add_argument("--step-months", type=int, default=2)
    s.add_argument("--anchored", action="store_true"); s.add_argument("--objective", default="expectancy_x_n"); s.set_defaults(fn=cmd_wfa)
    s = sub.add_parser("oos", **P); s.add_argument("--grid", default='{"structure_lookback":[8,12,16],"atr_sl_mult":[1.5,1.8,2.2]}'); s.add_argument("--oos-fraction", type=float, default=0.3); s.set_defaults(fn=cmd_oos)
    s = sub.add_parser("sensitivity", **P); s.add_argument("--pair"); s.add_argument("--xvals", default="[8,10,12,14,16]"); s.add_argument("--yvals", default="[1.4,1.6,1.8,2.0,2.2]"); s.set_defaults(fn=cmd_sensitivity)
    sub.add_parser("stress", **P).set_defaults(fn=cmd_stress)
    s = sub.add_parser("synthetic-mc", **P); s.add_argument("--paths", type=int, default=64); s.add_argument("--days", type=int, default=365); s.add_argument("--vol", type=float, default=0.16); s.set_defaults(fn=cmd_synthetic_mc)
    args = ap.parse_args(argv)
    args.fn(args)


if __name__ == "__main__":
    main()
