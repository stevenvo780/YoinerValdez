"""La v16 entregada y el preset Python tienen que ser el mismo robot."""
from __future__ import annotations

import argparse
import re
from pathlib import Path

from ohlc_quant.cli import _params
from ohlc_quant.engine.params import EAParams

ROOT = Path(__file__).resolve().parents[2]
CLIENT_V16 = ROOT / "ENTREGA_CLIENTE" / "OHLCMTF_Scalper_v16.mq5"
CLIENT_V15 = ROOT / "ENTREGA_CLIENTE" / "OHLCMTF_Scalper_v15.mq5"
HEADER = ROOT / "mql5" / "Include" / "OHLCMTF" / "Config.mqh"

INPUT_TO_FIELD = {
    "Structure_Lookback": "structure_lookback",
    "Min_Breakout_ATR_Mult": "min_breakout_atr_mult",
    "Max_Breakout_ATR_Mult": "max_breakout_atr_mult",
    "Min_Body_Ratio": "min_body_ratio",
    "Max_Against_Wick_Ratio": "max_against_wick_ratio",
    "Require_Close_Beyond": "require_close_beyond",
    "Prefer_Expansion_Break": "prefer_expansion_break",
    "Trend_Lookback": "trend_lookback",
    "Trend_Timeframe": "trend_timeframe",
    "Min_Swing_Confirmations": "min_swing_confirmations",
    "Require_Trend_Alignment": "require_trend_alignment",
    "Block_When_No_Trend": "block_when_no_trend",
    "Enable_Buy_Signals": "enable_buy",
    "Enable_Sell_Signals": "enable_sell",
    "Require_HigherTF_Confirm": "require_higher_tf_confirm",
    "Use_Fixed_Set": "use_fixed_set",
    "Use_Custom_Pair": "use_custom_pair",
    "TF_Fast": "tf_fast",
    "TF_Slow": "tf_slow",
    "ATR_Period": "atr_period",
    "ATR_Timeframe": "atr_timeframe",
    "ATR_SL_Multiplier": "atr_sl_mult",
    "ATR_TP_Multiplier": "atr_tp_mult",
    "Min_Risk_Percent": "min_risk_pct",
    "Max_Risk_Percent": "max_risk_pct",
    "Hard_Risk_Cap_Percent": "hard_risk_cap_pct",
    "Min_Signal_Strength": "min_signal_strength",
    "Allow_MinLot_Above_Cap": "allow_minlot_above_cap",
    "Size_On_Equity": "size_on_equity",
    "Min_SL_Points": "min_sl_points",
    "Slippage_Points": "slippage_points",
    "Spread_Sample_Size": "spread_sample_size",
    "Max_Spread_Points": "max_spread_points",
    "Spread_Buffer_Multiplier": "spread_buffer_mult",
    "HighSpread_Threshold": "high_spread_threshold",
    "HighSpread_ATR_Min_Mult": "high_spread_atr_min_mult",
    "HighSpread_Risk_Reduction": "high_spread_risk_reduction",
    "HighSpread_SL_Extra_Mult": "high_spread_sl_extra_mult",
    "Use_Avg_Spread_For_Mode": "use_avg_spread_for_mode",
    "Cooldown_Seconds": "cooldown_seconds",
    "Max_Trades_Per_Day": "max_trades_per_day",
    "Use_Volatility_Filter": "use_volatility_filter",
    "ATR_Min_Pct": "atr_min_pct",
    "ATR_Max_Pct": "atr_max_pct",
    "Use_Session_Filter": "use_session_filter",
    "Session_Start_Hour": "session_start_hour",
    "Session_End_Hour": "session_end_hour",
    "Allow_Asia_Breakouts": "allow_asia_breakouts",
    "Friday_Entry_Cutoff_Hour": "friday_entry_cutoff_hour",
    "Use_Progressive_Protection": "use_progressive_protection",
    "PP_Stage1_R": "pp_stage1_r",
    "PP_Stage1_SL_R": "pp_stage1_sl_r",
    "PP_Stage2_R": "pp_stage2_r",
    "PP_BE_Buffer_Points": "pp_be_buffer_points",
    "PP_Stage3_R": "pp_stage3_r",
    "PP_Lock_Fraction": "pp_lock_fraction",
    "PP_Trail_Start_R": "pp_trail_start_r",
    "PP_Trail_ATR_Mult": "pp_trail_atr_mult",
    "PP_Trail_Structure_Lookback": "pp_trail_structure_lookback",
    "PP_Min_Step_Points": "pp_min_step_points",
    "Use_Daily_Loss_Limit": "use_daily_loss_limit",
    "Max_Daily_Loss_Percent": "max_daily_loss_pct",
    "Daily_Loss_Flatten": "daily_loss_flatten",
    "Use_Loss_Streak_Guard": "use_loss_streak_guard",
    "Max_Consecutive_Losses": "max_consecutive_losses",
    "Loss_Streak_Pause_Minutes": "loss_streak_pause_minutes",
    "Streak_Reset_Min_R": "streak_reset_min_r",
    "Use_Total_Drawdown_Limit": "use_total_drawdown_limit",
    "Max_Total_Drawdown_Pct": "max_total_drawdown_pct",
    "DD_Use_Equity_Peak": "dd_use_equity_peak",
    "DD_Flatten_Positions": "dd_flatten_positions",
    "DD_Pause_Hours": "dd_pause_hours",
    "Close_Before_Weekend": "close_before_weekend",
    "Weekend_Close_Hour": "weekend_close_hour",
}

_INPUT = re.compile(r"input\s+(?!group\b)[\w:]+\s+(\w+)\s*=\s*([^;]+);")


def _inputs(path: Path) -> dict[str, str]:
    found = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        code = line.split("//", 1)[0]
        for name, raw in _INPUT.findall(code):
            found[name] = raw.strip()
    return found


def _coerce(raw: str, current):
    if isinstance(current, bool):
        return raw.lower() == "true"
    if isinstance(current, int):
        return int(float(raw))
    if isinstance(current, float):
        return float(raw)
    if raw.startswith("PERIOD_"):
        return raw.removeprefix("PERIOD_")
    return raw.strip().strip('"')


def _assert_matches(path: Path, params: EAParams):
    found = _inputs(path)
    missing = [name for name in INPUT_TO_FIELD if name not in found]
    assert not missing, f"{path.name} sin inputs {missing}"
    for name, field in INPUT_TO_FIELD.items():
        current = getattr(params, field)
        got = _coerce(found[name], current)
        if isinstance(current, float):
            assert abs(got - current) < 1e-9, f"{path.name} {name}={got} != {field}={current}"
        else:
            assert got == current, f"{path.name} {name}={got!r} != {field}={current!r}"


def test_v16_source_is_distinct_and_matches_python_defaults():
    assert CLIENT_V16.is_file()
    assert CLIENT_V15.is_file()
    assert CLIENT_V16.resolve() != CLIENT_V15.resolve()
    v16_text = CLIENT_V16.read_text(encoding="utf-8")
    v15_text = CLIENT_V15.read_text(encoding="utf-8")
    assert 'version   "16.00"' in v16_text
    assert "OHLCMTF SCALPER v16" in v16_text
    assert 'version   "15.00"' in v15_text
    params = EAParams.v16()
    _assert_matches(CLIENT_V16, params)
    _assert_matches(HEADER, params)
    assert params.allow_minlot_above_cap is False
    assert params.hard_risk_cap_pct <= 2.5
    assert _coerce(_inputs(CLIENT_V16)["Allow_MinLot_Above_Cap"], False) is False
    assert _coerce(_inputs(CLIENT_V16)["Hard_Risk_Cap_Percent"], 0.0) <= 2.5
    assert params.custom_min_signal_strength == 0
    frozen = EAParams.v15()
    assert EAParams() == frozen
    assert params != frozen
    assert _params(argparse.Namespace(preset="v16", set=None)) == params
    assert _params(argparse.Namespace(preset="v141", set=None)) == frozen
    assert _params(argparse.Namespace(preset="v15", set=None)) == frozen
