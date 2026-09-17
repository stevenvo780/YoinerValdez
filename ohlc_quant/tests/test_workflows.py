
import pandas as pd
import pytest

from ohlc_quant.analysis.sensitivity import grid_2d, one_at_a_time, plateau_score
from ohlc_quant.analysis.stress import deposit_sweep, stress_suite
from ohlc_quant.analysis.walkforward import evaluate_many, oos_split, param_grid, walk_forward, wf_summary, wf_table
from ohlc_quant.cli import main
from ohlc_quant.engine.params import BrokerSpec, EAParams


def test_param_grid_size():
    g = param_grid(EAParams(), {"structure_lookback": [8, 12], "atr_sl_mult": [1.5, 1.8, 2.2]})
    assert len(g) == 6 and len({(p.structure_lookback, p.atr_sl_mult) for p in g}) == 6


def test_evaluate_many_parallel_matches_serial(md_syn):
    ps = param_grid(EAParams.v140(), {"structure_lookback": [8, 12, 16]})
    ser = evaluate_many(md_syn, ps, BrokerSpec(), 300.0, workers=1)
    par = evaluate_many(md_syn, ps, BrokerSpec(), 300.0, workers=3)
    assert [m.net for _, m in ser] == pytest.approx([m.net for _, m in par])


def test_walk_forward_windows(md_syn):
    w = walk_forward(md_syn, EAParams.v140(), {"structure_lookback": [8, 12]}, BrokerSpec(), 300.0, is_months=1, oos_months=1, step_months=1,
                     workers=2, min_is_trades=1)
    assert len(w) >= 1
    tab = wf_table(w)
    assert {"is_start", "oos_end", "efficiency"} <= set(tab.columns)
    s = wf_summary(w)
    assert s["ventanas"] == len(w)


def test_oos_split_fraction(md_syn):
    (a0, a1), (b0, b1) = oos_split(md_syn, 0.3)
    assert pd.Timestamp(a1) == pd.Timestamp(b0)
    assert pd.Timestamp(a0) < pd.Timestamp(a1) < pd.Timestamp(b1)


def test_sensitivity_and_grid(md_syn):
    tab = one_at_a_time(md_syn, EAParams.v140(), BrokerSpec(), 300.0, names=["structure_lookback", "atr_sl_mult"], fracs=(-0.2, 0.2), workers=2)
    assert tab.iloc[0]["param"] == "base" and len(tab) == 5
    g = grid_2d(md_syn, EAParams.v140(), BrokerSpec(), 300.0, "structure_lookback", [8, 12], "atr_sl_mult", [1.5, 2.2], workers=2)
    assert g.shape == (2, 2) and 0 <= plateau_score(g) <= 1


def test_stress_suite_rows(md_syn, m1_syn):
    tab = stress_suite(md_syn, EAParams.v140(), BrokerSpec(), 300.0, m1_utc=m1_syn)
    assert "base" in tab.index and "spread_x2" in tab.index and "reloj_UTC+0" in tab.index
    assert tab.loc["spread_x2", "net"] <= tab.loc["base", "net"] + 1e-9 or tab.loc["spread_x2", "n"] != tab.loc["base", "n"]


def test_deposit_sweep_minlot_skips_decrease(md_syn):
    tab = deposit_sweep(md_syn, EAParams(), BrokerSpec(), deposits=(300, 3000, 30000))
    assert tab["skip_minlot"].iloc[0] >= tab["skip_minlot"].iloc[-1]


def test_cli_backtest_and_compare(tmp_path):
    main(["backtest", "--synthetic", "60", "--seed", "5", "--preset", "v140", "--out", str(tmp_path)])
    assert (tmp_path / "metrics_v140.json").exists()
    main(["compare", "--synthetic", "60", "--seed", "5", "--out", str(tmp_path)])
    assert (tmp_path / "compare.csv").exists()
    main(["mc-summary", "--wins", "42", "--losses", "35", "--avg-win", "65.6", "--avg-loss", "-26.69", "--max-win", "205.1", "--max-loss", "-74.82", "--runs", "500"])
