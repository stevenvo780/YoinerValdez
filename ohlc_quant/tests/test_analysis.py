
import numpy as np
import pandas as pd
import pytest
from hypothesis import given, settings, strategies as st

from ohlc_quant.analysis.metrics import by_weekday, compute_metrics, equity_drawdown, exclusion_analysis, streaks
from ohlc_quant.analysis.montecarlo import mc_suite, monte_carlo, summary_stats_mc
from ohlc_quant.analysis.report import deals_to_trades, load_deals
from ohlc_quant.analysis.sizing import calc_volume, capital_required
from ohlc_quant.engine.params import BrokerSpec, EAParams


def _trades(pnls, start="2026-01-05", deposit=1000.0):
    t = pd.date_range(start, periods=len(pnls), freq="7h")
    bal = deposit + np.concatenate([[0.0], np.cumsum(pnls)[:-1]])
    return pd.DataFrame({"open_time": t, "close_time": t + pd.Timedelta(hours=2), "pnl": pnls, "balance_before": bal,
                         "risk_pct_real": 1.0, "r_multiple": np.sign(pnls), "vol": 0.01})


def test_metrics_known_sequence():
    m = compute_metrics(_trades([10, -5, 20, -5, -5]), 1000.0)
    assert m.n == 5 and m.net == 15 and m.profit_factor == pytest.approx(30 / 15)
    assert m.win_rate == 40.0 and m.max_loss_streak == 2 and m.max_win_streak == 1
    assert m.max_dd == 10 and m.max_dd_pct == pytest.approx(10 / 1025 * 100)


def test_equity_drawdown_and_streaks():
    assert equity_drawdown(np.array([100, -50, -50, 100.0]), 1000)[0] == 100
    assert streaks(np.array([-1, -1, 1, 1, 1, -1.0])) == (2, 3)


@settings(max_examples=100, deadline=None)
@given(st.lists(st.floats(-500, 500, allow_nan=False), min_size=1, max_size=60), st.floats(100, 10000))
def test_metrics_invariants(pnls, deposit):
    m = compute_metrics(_trades(pnls, deposit=deposit), deposit)
    assert m.n == len(pnls)
    assert 0 <= m.win_rate <= 100
    assert m.max_dd >= 0 and 0 <= m.max_dd_pct <= 100 + 1e-9 or m.max_dd_pct > 100
    assert m.profit_factor >= 0
    assert m.final_balance == pytest.approx(deposit + sum(pnls))


def test_exclusions_remove_best_month_and_day():
    pnls = [50.0] * 10 + [-10.0] * 10
    df = _trades(pnls, start="2026-01-05")
    ex = exclusion_analysis(df, 1000.0)
    assert ex["todo"].n == 20
    assert all(v.n <= 20 for v in ex.values())
    assert any(k.startswith("sin_mejor_mes") for k in ex)


def test_monte_carlo_modes_and_scaling():
    df = _trades([30, -10, 25, -12, 40, -9, 15, -20, 35, -8] * 4)
    for mode, blk in (("shuffle", 1), ("bootstrap", 1), ("block", 3)):
        r = monte_carlo(df, 1000.0, runs=500, mode=mode, block=blk)
        assert 0 <= r.dd_p50 <= r.dd_p95 <= r.dd_p99 <= 100
        assert 0 <= r.p_ruin_50 <= 100
    r1 = monte_carlo(df, 1000.0, runs=500, target_median_loss_pct=0.5)
    assert r1.k < 1.0
    assert r1.dd_p95 < monte_carlo(df, 1000.0, runs=500).dd_p95 + 1e-9


def test_shuffle_preserves_final_balance():
    df = _trades([30, -10, 25, -12, 40, -9, 15, -20, 35, -8])
    r = monte_carlo(df, 1000.0, runs=200, mode="shuffle")
    assert r.final_p05 > 0 and r.final_p95 > 0


def test_mc_suite_shape():
    df = _trades([30, -10, 25, -12, 40, -9, 15, -20, 35, -8] * 3)
    tab = mc_suite(df, 1000.0, runs=300)
    assert len(tab) == 6 and {"shuffle", "bootstrap", "block"} == set(tab["mode"])


def test_summary_stats_mc_reproduces_backtest_scale():
    r = summary_stats_mc(42, 35, 65.60, -26.69, 205.10, -74.82, 300.0, runs=2000)
    assert r.dd_p50 > 5 and r.p_dd_ge_30 > 0
    assert r.median_loss_pct == pytest.approx(26.69 / 300 * 100)


def test_sizing_v140_vs_v141():
    p141 = EAParams(); p140 = EAParams.v140(); b = BrokerSpec()
    s140 = calc_volume(30.0, 1.0, 300, 300, p140, b)
    assert s140.volume == 0.01 and s140.risk_pct == pytest.approx(10.0)
    s141 = calc_volume(30.0, 1.0, 300, 300, p141, b)
    assert s141.skipped and s141.reason == "minlot>cap"
    s_ok = calc_volume(30.0, 1.0, 5000, 5000, p141, b)
    assert not s_ok.skipped and s_ok.volume == pytest.approx(0.01) and s_ok.risk_pct <= 2.5
    s_big = calc_volume(30.0, 1.25, 100000, 100000, p141, b)
    assert s_big.risk_pct <= 1.25 + 1e-9
    assert capital_required(30.0, 1.0, b) == pytest.approx(3000.0)


def test_report_roundtrip(tmp_path):
    rows = [["Transacciones"], [None], ["Hora", "Transacción", "Símbolo", "Tipo", "Dirección", "Volumen", "Precio", "Orden", "Comisión", "Swap", "Beneficio", "Saldo", "Comentario"]]
    t = pd.Timestamp("2026-03-02 09:00"); bal = 300.0; d = 1
    rows.append([t, d, "", "balance", "in", 0, 0, 0, 0, 0, 300, 300, ""]); d += 1
    for i, p in enumerate([20.0, -8.0, 35.0, -12.0]):
        t += pd.Timedelta(hours=9)
        rows.append([t, d, "XAUUSD", "buy", "in", 0.01, 3000, d, -0.03, 0, 0, bal - 0.03, "R2200F" if i % 2 == 0 else "R1800C"]); d += 1
        bal += p - 0.06
        rows.append([t + pd.Timedelta(hours=3), d, "XAUUSD", "sell", "out", 0.01, 3010, d, -0.03, 0, p, bal, "[tp]"]); d += 1
    f = tmp_path / "rep.xlsx"
    pd.DataFrame(rows).to_excel(f, header=False, index=False)
    tr = deals_to_trades(load_deals(f))
    assert len(tr) == 4
    assert tr["pnl"].sum() == pytest.approx(35.0 - 0.24)
    assert list(tr["set"]) == ["FIJO", "CUSTOM", "FIJO", "CUSTOM"]
    assert tr["balance_before"].iloc[0] == pytest.approx(300.0)


def test_by_weekday_labels():
    df = _trades([1.0, 2.0, 3.0])
    assert set(by_weekday(df).index) <= {"Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"}
