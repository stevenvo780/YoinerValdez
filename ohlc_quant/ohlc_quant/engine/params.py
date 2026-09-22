from __future__ import annotations

from dataclasses import dataclass, asdict, replace, fields

TF_SECONDS = {"M1": 60, "M5": 300, "M15": 900, "M30": 1800, "H1": 3600, "H4": 14400, "D1": 86400}


@dataclass(frozen=True)
class EAParams:
    structure_lookback: int = 12
    min_breakout_atr_mult: float = 0.28
    max_breakout_atr_mult: float = 2.20
    min_body_ratio: float = 0.55
    max_against_wick_ratio: float = 0.35
    require_close_beyond: bool = True
    prefer_expansion_break: bool = True

    trend_lookback: int = 28
    trend_timeframe: str = "H4"
    min_swing_confirmations: int = 2
    require_trend_alignment: bool = True
    block_when_no_trend: bool = True

    enable_buy: bool = True
    enable_sell: bool = True
    require_higher_tf_confirm: bool = True

    use_fixed_set: bool = True
    use_custom_pair: bool = True
    tf_fast: str = "M5"
    tf_slow: str = "H4"

    atr_period: int = 14
    atr_timeframe: str = "H1"
    atr_sl_mult: float = 1.80
    atr_tp_mult: float = 3.20

    min_risk_pct: float = 0.25
    max_risk_pct: float = 1.25
    hard_risk_cap_pct: float = 2.50
    min_signal_strength: int = 4
    custom_min_signal_strength: int = 0

    min_sl_points: int = 180
    slippage_points: int = 40

    spread_sample_size: int = 25
    max_spread_points: float = 0.0
    spread_buffer_mult: float = 1.60
    high_spread_threshold: float = 28.0
    high_spread_atr_min_mult: float = 1.80
    high_spread_risk_reduction: float = 0.45
    high_spread_sl_extra_mult: float = 1.35

    cooldown_seconds: int = 180
    max_trades_per_day: int = 6

    use_volatility_filter: bool = True
    atr_min_pct: float = 0.025
    atr_max_pct: float = 1.80

    use_session_filter: bool = True
    session_start_hour: int = 7
    session_end_hour: int = 20
    allow_asia_breakouts: bool = False

    use_progressive_protection: bool = True
    pp_stage1_r: float = 0.60
    pp_stage1_sl_r: float = 0.45
    pp_stage2_r: float = 1.00
    pp_be_buffer_points: float = 25
    pp_stage3_r: float = 1.60
    pp_lock_fraction: float = 0.55
    pp_trail_start_r: float = 2.20
    pp_trail_atr_mult: float = 1.15
    pp_trail_structure_lookback: int = 8
    pp_min_step_points: float = 20

    use_daily_loss_limit: bool = True
    max_daily_loss_pct: float = 4.50
    use_loss_streak_guard: bool = True
    max_consecutive_losses: int = 3
    loss_streak_pause_minutes: int = 90
    use_total_drawdown_limit: bool = True
    max_total_drawdown_pct: float = 12.0

    sizing_mode: str = "v141"
    allow_minlot_above_cap: bool = False
    size_on_equity: bool = True
    dd_use_equity_peak: bool = True
    dd_flatten_positions: bool = True
    dd_pause_hours: int = 72
    daily_loss_flatten: bool = False
    close_before_weekend: bool = False
    weekend_close_hour: int = 21
    friday_entry_cutoff_hour: int = 24
    streak_reset_min_r: float = 0.25
    use_avg_spread_for_mode: bool = True
    atr_closed_bar: bool = True

    def with_(self, **kw) -> "EAParams":
        return replace(self, **kw)

    def as_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def v15(cls) -> "EAParams":
        """Defaults entregados como OHLCMTF Scalper v15. No siguen a EAParams()."""
        return cls(
            structure_lookback=12,
            min_breakout_atr_mult=0.28,
            max_breakout_atr_mult=2.20,
            min_body_ratio=0.55,
            max_against_wick_ratio=0.35,
            require_close_beyond=True,
            prefer_expansion_break=True,
            trend_lookback=28,
            trend_timeframe="H4",
            min_swing_confirmations=2,
            require_trend_alignment=True,
            block_when_no_trend=True,
            enable_buy=True,
            enable_sell=True,
            require_higher_tf_confirm=True,
            use_fixed_set=True,
            use_custom_pair=True,
            tf_fast="M5",
            tf_slow="H4",
            atr_period=14,
            atr_timeframe="H1",
            atr_sl_mult=1.80,
            atr_tp_mult=3.20,
            min_risk_pct=0.25,
            max_risk_pct=1.25,
            hard_risk_cap_pct=2.50,
            min_signal_strength=4,
            custom_min_signal_strength=0,
            min_sl_points=180,
            slippage_points=40,
            spread_sample_size=25,
            max_spread_points=0.0,
            spread_buffer_mult=1.60,
            high_spread_threshold=28.0,
            high_spread_atr_min_mult=1.80,
            high_spread_risk_reduction=0.45,
            high_spread_sl_extra_mult=1.35,
            cooldown_seconds=180,
            max_trades_per_day=6,
            use_volatility_filter=True,
            atr_min_pct=0.025,
            atr_max_pct=1.80,
            use_session_filter=True,
            session_start_hour=7,
            session_end_hour=20,
            allow_asia_breakouts=False,
            use_progressive_protection=True,
            pp_stage1_r=0.60,
            pp_stage1_sl_r=0.45,
            pp_stage2_r=1.00,
            pp_be_buffer_points=25.0,
            pp_stage3_r=1.60,
            pp_lock_fraction=0.55,
            pp_trail_start_r=2.20,
            pp_trail_atr_mult=1.15,
            pp_trail_structure_lookback=8,
            pp_min_step_points=20.0,
            use_daily_loss_limit=True,
            max_daily_loss_pct=4.50,
            use_loss_streak_guard=True,
            max_consecutive_losses=3,
            loss_streak_pause_minutes=90,
            use_total_drawdown_limit=True,
            max_total_drawdown_pct=12.0,
            sizing_mode="v141",
            allow_minlot_above_cap=False,
            size_on_equity=True,
            dd_use_equity_peak=True,
            dd_flatten_positions=True,
            dd_pause_hours=72,
            daily_loss_flatten=False,
            close_before_weekend=False,
            weekend_close_hour=21,
            friday_entry_cutoff_hour=24,
            streak_reset_min_r=0.25,
            use_avg_spread_for_mode=True,
            atr_closed_bar=True,
        )

    @classmethod
    def v140(cls) -> "EAParams":
        return cls.v15().with_(sizing_mode="v140", allow_minlot_above_cap=True, size_on_equity=False,
                               dd_use_equity_peak=False, dd_flatten_positions=False, streak_reset_min_r=0.0,
                               use_avg_spread_for_mode=False, atr_closed_bar=False)

    @classmethod
    def lean(cls) -> "EAParams":
        return cls.v15().with_(min_risk_pct=0.75, max_risk_pct=0.75, use_volatility_filter=False, use_custom_pair=False)

    @classmethod
    def v16(cls) -> "EAParams":
        """Defaults entregados como OHLCMTF Scalper v16."""
        return cls.v15().with_(
            prefer_expansion_break=False,
            use_progressive_protection=False,
            structure_lookback=10,
            atr_tp_mult=3.0,
        )


PARAM_NAMES = [f.name for f in fields(EAParams)]


@dataclass(frozen=True)
class BrokerSpec:
    point: float = 0.01
    digits: int = 2
    tick_size: float = 0.01
    tick_value: float = 1.0
    volume_min: float = 0.01
    volume_max: float = 100.0
    volume_step: float = 0.01
    stops_level_points: int = 0
    freeze_level_points: int = 0
    commission_per_lot: float = 0.0
    leverage: int = 100
    contract_size: float = 100.0
    slippage_points_fill: float = 0.0
    spread_multiplier: float = 1.0
    spread_add_points: float = 0.0

    def money_per_price_unit_per_lot(self) -> float:
        return self.tick_value / self.tick_size


@dataclass(frozen=True)
class ServerClock:
    base_offset_hours: int = 2
    dst_rule: str = "us"

    def offset_hours(self, utc_ts: float) -> int:
        import datetime as dt
        d = dt.datetime.fromtimestamp(utc_ts, dt.timezone.utc)
        if self.dst_rule == "none":
            return self.base_offset_hours
        if self.dst_rule == "us":
            start = _nth_sunday(d.year, 3, 2)
            end = _nth_sunday(d.year, 11, 1)
            return self.base_offset_hours + (1 if start <= d.date() < end else 0)
        if self.dst_rule == "eu":
            start = _last_sunday(d.year, 3)
            end = _last_sunday(d.year, 10)
            return self.base_offset_hours + (1 if start <= d.date() < end else 0)
        raise ValueError(self.dst_rule)


def _nth_sunday(year: int, month: int, n: int):
    import datetime as dt
    d = dt.date(year, month, 1)
    d += dt.timedelta(days=(6 - d.weekday()) % 7)
    return d + dt.timedelta(weeks=n - 1)


def _last_sunday(year: int, month: int):
    import datetime as dt
    d = dt.date(year, month + 1, 1) - dt.timedelta(days=1) if month < 12 else dt.date(year, 12, 31)
    return d - dt.timedelta(days=(d.weekday() + 1) % 7)
