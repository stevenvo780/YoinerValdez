from __future__ import annotations

import numpy as np
from numba import njit

from ohlc_quant.engine.params import BrokerSpec, EAParams

P_ATR_SL, P_ATR_TP, P_MIN_RISK, P_MAX_RISK, P_CAP, P_MIN_STR, P_MIN_SL_PTS, P_MAX_SPREAD, P_SPREAD_BUF, \
P_HS_THR, P_HS_ATR_MIN, P_HS_RISK_RED, P_HS_SL_EXTRA, P_COOLDOWN, P_MAX_TRADES_DAY, P_USE_PP, P_S1_R, P_S1_SL_R, \
P_S2_R, P_BE_BUF, P_S3_R, P_LOCK, P_TRAIL_R, P_TRAIL_ATR, P_MIN_STEP, P_USE_DAILY, P_MAX_DAILY, P_USE_STREAK, \
P_MAX_STREAK, P_PAUSE_MIN, P_USE_DD, P_MAX_DD, P_SIZING_V141, P_ALLOW_MINLOT, P_SIZE_EQ, P_DD_EQ_PEAK, P_DD_FLATTEN, \
P_DD_PAUSE_H, P_DAILY_FLATTEN, P_WKND_CLOSE, P_WKND_HOUR, P_STREAK_MIN_R, P_AVG_SPREAD_MODE, P_PESSIMISTIC = range(44)

B_POINT, B_TICK_SIZE, B_TICK_VALUE, B_VOL_MIN, B_VOL_MAX, B_VOL_STEP, B_STOPS, B_FREEZE, B_COMM, B_LEVERAGE, \
B_CONTRACT, B_SLIP_FILL, B_SPREAD_MULT, B_SPREAD_ADD = range(14)

EXIT_SL, EXIT_TP, EXIT_DD, EXIT_DAILY, EXIT_WEEKEND, EXIT_END = 1, 2, 3, 4, 5, 6
TR_COLS = ["open_t", "close_t", "type", "vol", "open_price", "close_price", "sl0", "tp0", "pnl", "commission",
           "set", "strength", "exit_reason", "risk_pct_real", "balance_before", "r_multiple", "atr", "spread_pts", "signal_t"]
ST_SKIP_MINLOT, ST_SKIP_SPREAD, ST_SKIP_PAUSE, ST_SKIP_DAILY, ST_SKIP_DD, ST_SKIP_COOLDOWN, ST_SKIP_MAXDAY, ST_SKIP_BUSY, \
ST_DD_LATCHES, ST_PP_MODS, ST_SKIP_HS, ST_SKIP_MARGIN, ST_SIGNALS = range(13)


def pack_params(p: EAParams, pessimistic: bool = True) -> np.ndarray:
    a = np.zeros(44)
    a[P_ATR_SL] = p.atr_sl_mult; a[P_ATR_TP] = p.atr_tp_mult; a[P_MIN_RISK] = p.min_risk_pct; a[P_MAX_RISK] = p.max_risk_pct
    a[P_CAP] = p.hard_risk_cap_pct; a[P_MIN_STR] = min(p.min_signal_strength, 6); a[P_MIN_SL_PTS] = p.min_sl_points
    a[P_MAX_SPREAD] = p.max_spread_points; a[P_SPREAD_BUF] = p.spread_buffer_mult; a[P_HS_THR] = p.high_spread_threshold
    a[P_HS_ATR_MIN] = p.high_spread_atr_min_mult; a[P_HS_RISK_RED] = p.high_spread_risk_reduction; a[P_HS_SL_EXTRA] = p.high_spread_sl_extra_mult
    a[P_COOLDOWN] = p.cooldown_seconds; a[P_MAX_TRADES_DAY] = p.max_trades_per_day; a[P_USE_PP] = p.use_progressive_protection
    a[P_S1_R] = p.pp_stage1_r; a[P_S1_SL_R] = p.pp_stage1_sl_r; a[P_S2_R] = p.pp_stage2_r; a[P_BE_BUF] = p.pp_be_buffer_points
    a[P_S3_R] = p.pp_stage3_r; a[P_LOCK] = p.pp_lock_fraction; a[P_TRAIL_R] = p.pp_trail_start_r; a[P_TRAIL_ATR] = p.pp_trail_atr_mult
    a[P_MIN_STEP] = p.pp_min_step_points; a[P_USE_DAILY] = p.use_daily_loss_limit; a[P_MAX_DAILY] = p.max_daily_loss_pct
    a[P_USE_STREAK] = p.use_loss_streak_guard; a[P_MAX_STREAK] = p.max_consecutive_losses; a[P_PAUSE_MIN] = p.loss_streak_pause_minutes
    a[P_USE_DD] = p.use_total_drawdown_limit; a[P_MAX_DD] = p.max_total_drawdown_pct; a[P_SIZING_V141] = p.sizing_mode == "v141"
    a[P_ALLOW_MINLOT] = p.allow_minlot_above_cap; a[P_SIZE_EQ] = p.size_on_equity; a[P_DD_EQ_PEAK] = p.dd_use_equity_peak
    a[P_DD_FLATTEN] = p.dd_flatten_positions; a[P_DD_PAUSE_H] = p.dd_pause_hours; a[P_DAILY_FLATTEN] = p.daily_loss_flatten
    a[P_WKND_CLOSE] = p.close_before_weekend; a[P_WKND_HOUR] = p.weekend_close_hour; a[P_STREAK_MIN_R] = p.streak_reset_min_r
    a[P_AVG_SPREAD_MODE] = p.use_avg_spread_for_mode; a[P_PESSIMISTIC] = pessimistic
    return a


def pack_broker(b: BrokerSpec) -> np.ndarray:
    a = np.zeros(14)
    a[B_POINT] = b.point; a[B_TICK_SIZE] = b.tick_size; a[B_TICK_VALUE] = b.tick_value; a[B_VOL_MIN] = b.volume_min
    a[B_VOL_MAX] = b.volume_max; a[B_VOL_STEP] = b.volume_step; a[B_STOPS] = b.stops_level_points; a[B_FREEZE] = b.freeze_level_points
    a[B_COMM] = b.commission_per_lot; a[B_LEVERAGE] = b.leverage; a[B_CONTRACT] = b.contract_size; a[B_SLIP_FILL] = b.slippage_points_fill
    a[B_SPREAD_MULT] = b.spread_multiplier; a[B_SPREAD_ADD] = b.spread_add_points
    return a


@njit(cache=True)
def _floor_step(x, step):
    return np.floor(x / step + 1e-9) * step


@njit(cache=True)
def _check_exit(p_type, p_sl, p_tp, o_k, h_k, l_k, ask_k, bar_spread, slip, pess, gap_only):
    reason = 0; px = 0.0
    if p_type == 1:
        if gap_only:
            if o_k <= p_sl: return EXIT_SL, o_k - slip
            if o_k >= p_tp: return EXIT_TP, o_k
            return 0, 0.0
        hit_sl = l_k <= p_sl; hit_tp = h_k >= p_tp
        if hit_sl and hit_tp:
            reason = EXIT_SL if (pess or abs(o_k - p_sl) < abs(o_k - p_tp)) else EXIT_TP
        elif hit_sl: reason = EXIT_SL
        elif hit_tp: reason = EXIT_TP
        if reason == EXIT_SL: px = min(p_sl, o_k) - slip
        elif reason == EXIT_TP: px = max(p_tp, o_k)
    else:
        if gap_only:
            if ask_k >= p_sl: return EXIT_SL, ask_k + slip
            if ask_k <= p_tp: return EXIT_TP, ask_k
            return 0, 0.0
        ah = h_k + bar_spread; al = l_k + bar_spread
        hit_sl = ah >= p_sl; hit_tp = al <= p_tp
        if hit_sl and hit_tp:
            reason = EXIT_SL if (pess or abs(ask_k - p_sl) < abs(ask_k - p_tp)) else EXIT_TP
        elif hit_sl: reason = EXIT_SL
        elif hit_tp: reason = EXIT_TP
        if reason == EXIT_SL: px = max(p_sl, ask_k) + slip
        elif reason == EXIT_TP: px = min(p_tp, ask_k)
    return reason, px


@njit(cache=True)
def run_sim(t, o, h, l, c, ask_open, spread_mean,
            ev_t, ev_dir, ev_str, ev_set, ev_atr,
            atr_idx0, atr_closed, trail_low, trail_high,
            P, B, deposit):
    n = len(t)
    n_ev = len(ev_t)
    point = B[B_POINT]; mppu = B[B_TICK_VALUE] / B[B_TICK_SIZE]
    vol_min = B[B_VOL_MIN]; vol_max = B[B_VOL_MAX]; step = B[B_VOL_STEP] if B[B_VOL_STEP] > 0 else B[B_VOL_MIN]
    stops = B[B_STOPS] * point; freeze = B[B_FREEZE] * point
    comm = B[B_COMM]; leverage = B[B_LEVERAGE]; contract = B[B_CONTRACT]; slip = B[B_SLIP_FILL] * point
    sp_mult = B[B_SPREAD_MULT]; sp_add = B[B_SPREAD_ADD] * point
    v141 = P[P_SIZING_V141] > 0.5; pess = P[P_PESSIMISTIC] > 0.5

    max_tr = n_ev + 8
    trades = np.zeros((max_tr, 19))
    ntr = 0
    balance_curve = np.empty(n); equity_curve = np.empty(n)
    stats = np.zeros(16, dtype=np.int64)

    balance = deposit; equity = deposit
    hwm = deposit
    latched = False; latched_until = 0.0
    cur_day = -1; day_start = deposit; daily_hit = False; trades_today = 0
    streak = 0; pause_until = -1.0; last_trade_t = -1e18
    weekend_day = -1

    has_pos = False
    p_type = 0; p_vol = 0.0; p_open = 0.0; p_sl = 0.0; p_tp = 0.0; p_R = 0.0
    p_open_t = 0.0; p_set = 0; p_str = 0; p_sl0 = 0.0; p_risk = 0.0; p_bal_before = 0.0; p_atr = 0.0; p_spread = 0.0; p_sig_t = 0.0
    ev_ptr = 0

    for k in range(n):
        T = t[k]
        day = T // 86400
        hour = (T % 86400) // 3600
        dow = (day + 3) % 7
        if day != cur_day:
            cur_day = day; day_start = balance; daily_hit = False; trades_today = 0
        bid = o[k]
        spread_now = (ask_open[k] - o[k]) * sp_mult + sp_add
        if spread_now < 0: spread_now = 0.0
        ask = bid + spread_now
        avg_spread = (spread_mean[k - 1] if k > 0 else spread_now) * sp_mult + sp_add
        bar_spread = spread_mean[k] * sp_mult + sp_add

        floating = 0.0
        if has_pos:
            floating = (bid - p_open) * p_vol * mppu if p_type == 1 else (p_open - ask) * p_vol * mppu
        equity = balance + floating

        basis = equity if P[P_DD_EQ_PEAK] > 0.5 else balance
        if basis > hwm: hwm = basis
        dd_pct = (hwm - equity) / hwm * 100.0 if hwm > 0 else 0.0
        close_now = 0
        if v141 and P[P_USE_DD] > 0.5:
            if latched:
                if P[P_DD_PAUSE_H] > 0 and T >= latched_until:
                    latched = False; hwm = basis
            elif dd_pct >= P[P_MAX_DD]:
                latched = True; stats[ST_DD_LATCHES] += 1
                latched_until = T + P[P_DD_PAUSE_H] * 3600.0 if P[P_DD_PAUSE_H] > 0 else 1e18
                if P[P_DD_FLATTEN] > 0.5 and has_pos: close_now = EXIT_DD
        if P[P_USE_DAILY] > 0.5 and day_start > 0:
            loss_pct = (day_start - equity) / day_start * 100.0
            if loss_pct >= P[P_MAX_DAILY] and not daily_hit:
                daily_hit = True
                if P[P_DAILY_FLATTEN] > 0.5 and has_pos and close_now == 0: close_now = EXIT_DAILY
        if P[P_WKND_CLOSE] > 0.5 and dow == 4 and hour >= P[P_WKND_HOUR] and weekend_day != day:
            weekend_day = day
            if has_pos and close_now == 0: close_now = EXIT_WEEKEND

        if has_pos and close_now != 0:
            px = bid if p_type == 1 else ask
            gross = (px - p_open) * p_vol * mppu if p_type == 1 else (p_open - px) * p_vol * mppu
            cst = comm * p_vol
            pnl = gross - cst
            balance += pnl
            trades[ntr, 0] = p_open_t; trades[ntr, 1] = T; trades[ntr, 2] = p_type; trades[ntr, 3] = p_vol
            trades[ntr, 4] = p_open; trades[ntr, 5] = px; trades[ntr, 6] = p_sl0; trades[ntr, 7] = p_tp; trades[ntr, 8] = pnl
            trades[ntr, 9] = cst; trades[ntr, 10] = p_set; trades[ntr, 11] = p_str; trades[ntr, 12] = close_now
            trades[ntr, 13] = p_risk; trades[ntr, 14] = p_bal_before; trades[ntr, 15] = pnl / (p_R * p_vol * mppu) if p_R > 0 else 0.0
            trades[ntr, 16] = p_atr; trades[ntr, 17] = p_spread; trades[ntr, 18] = p_sig_t
            ntr += 1
            sl_money = p_R * p_vol * mppu
            if pnl > 0:
                if sl_money <= 0 or P[P_STREAK_MIN_R] <= 0 or pnl >= P[P_STREAK_MIN_R] * sl_money: streak = 0
            elif pnl < 0:
                streak += 1
                if P[P_USE_STREAK] > 0.5 and streak >= P[P_MAX_STREAK]: pause_until = T + P[P_PAUSE_MIN] * 60.0
            has_pos = False
            equity = balance

        if has_pos and P[P_USE_PP] > 0.5:
            price = bid if p_type == 1 else ask
            profit_dist = (price - p_open) if p_type == 1 else (p_open - price)
            if profit_dist > 0 and p_R > 0:
                r_mult = profit_dist / p_R
                cand = 0.0; have = False
                if r_mult >= P[P_TRAIL_R]:
                    ai = atr_idx0[k]
                    a = atr_closed[ai] if ai >= 0 else 0.0
                    if p_type == 1:
                        at = price - a * P[P_TRAIL_ATR]
                        stl = trail_low[ai] if ai >= 0 else np.nan
                        cand = max(at, stl) if not np.isnan(stl) else at
                    else:
                        at = price + a * P[P_TRAIL_ATR]
                        sth = trail_high[ai] if ai >= 0 else np.nan
                        cand = min(at, sth) if not np.isnan(sth) else at
                    have = True
                elif r_mult >= P[P_S3_R]:
                    lock = profit_dist * P[P_LOCK]
                    cand = p_open + lock if p_type == 1 else p_open - lock; have = True
                elif r_mult >= P[P_S2_R]:
                    buf = P[P_BE_BUF] * point
                    cand = p_open + buf if p_type == 1 else p_open - buf; have = True
                elif r_mult >= P[P_S1_R]:
                    red = p_R * P[P_S1_SL_R]
                    cand = p_open - red if p_type == 1 else p_open + red; have = True
                if have:
                    improves = (p_sl == 0.0) or (p_type == 1 and cand > p_sl) or (p_type == 2 and cand < p_sl)
                    if improves and not (p_sl != 0.0 and abs(cand - p_sl) < P[P_MIN_STEP] * point):
                        min_dist = max(stops, point)
                        ok = True
                        if p_type == 1:
                            if freeze > 0 and p_sl != 0.0 and (bid - p_sl) < freeze: ok = False
                            if ok:
                                if bid - cand < min_dist: cand = bid - min_dist
                                if cand <= p_sl: ok = False
                        else:
                            if freeze > 0 and p_sl != 0.0 and (p_sl - ask) < freeze: ok = False
                            if ok:
                                if cand - ask < min_dist: cand = ask + min_dist
                                if p_sl != 0.0 and cand >= p_sl: ok = False
                        if ok:
                            p_sl = cand; stats[ST_PP_MODS] += 1

        for pass_id in range(2):
            if pass_id == 1:
                while ev_ptr < n_ev and ev_t[ev_ptr] == T:
                    stats[ST_SIGNALS] += 1
                    d = ev_dir[ev_ptr]; s = ev_str[ev_ptr]; sid = ev_set[ev_ptr]; atr = ev_atr[ev_ptr]
                    ev_ptr += 1
                    if has_pos:
                        stats[ST_SKIP_BUSY] += 1; continue
                    if v141 and latched:
                        stats[ST_SKIP_DD] += 1; continue
                    if P[P_USE_STREAK] > 0.5:
                        if T < pause_until:
                            stats[ST_SKIP_PAUSE] += 1; continue
                        if streak >= P[P_MAX_STREAK]: streak = 0
                    if P[P_USE_DAILY] > 0.5 and day_start > 0:
                        loss_pct = (day_start - equity) / day_start * 100.0
                        if daily_hit or loss_pct >= P[P_MAX_DAILY]:
                            daily_hit = True; stats[ST_SKIP_DAILY] += 1; continue
                    if (not v141) and P[P_USE_DD] > 0.5:
                        fdd = (balance - equity) / balance * 100.0 if balance > 0 else 100.0
                        if fdd >= P[P_MAX_DD]:
                            stats[ST_SKIP_DD] += 1; continue
                    if T - last_trade_t < P[P_COOLDOWN]:
                        stats[ST_SKIP_COOLDOWN] += 1; continue
                    if trades_today >= P[P_MAX_TRADES_DAY]:
                        stats[ST_SKIP_MAXDAY] += 1; continue
                    cur_spread_pts = spread_now / point
                    mode_spread = avg_spread if P[P_AVG_SPREAD_MODE] > 0.5 else spread_now
                    is_hs = (mode_spread / point) > P[P_HS_THR]
                    if P[P_MAX_SPREAD] > 0 and cur_spread_pts > P[P_MAX_SPREAD]:
                        stats[ST_SKIP_SPREAD] += 1; continue
                    if atr <= 0: continue
                    entry = ask if d == 1 else bid
                    stop_level = stops if stops > 0 else 10.0 * point
                    sl_mult = P[P_ATR_SL]; tp_mult = P[P_ATR_TP]
                    min_str = P[P_MIN_STR]
                    ratio = (s - min_str) / (6.0 - min_str) if 6.0 > min_str else 0.0
                    ratio = min(1.0, max(0.0, ratio))
                    risk = P[P_MIN_RISK] + (P[P_MAX_RISK] - P[P_MIN_RISK]) * ratio
                    tp_mult *= (1.0 + 0.35 * ratio)
                    if is_hs:
                        avs = atr / mode_spread if mode_spread > 0 else 0.0
                        if avs < P[P_HS_ATR_MIN]:
                            stats[ST_SKIP_HS] += 1; continue
                        sl_mult *= P[P_HS_SL_EXTRA]; risk *= P[P_HS_RISK_RED]
                    risk = min(risk, P[P_MAX_RISK]); risk = min(risk, P[P_CAP])
                    if risk <= 0: continue
                    sl_dist = atr * sl_mult; tp_dist = atr * tp_mult
                    fl = avg_spread * P[P_SPREAD_BUF]
                    if fl > 0:
                        if sl_dist < fl: sl_dist = fl
                        if tp_dist < fl: tp_dist = fl
                    min_sl = max(stop_level, P[P_MIN_SL_PTS] * point)
                    if sl_dist < min_sl: sl_dist = min_sl

                    base = min(balance, equity) if (v141 and P[P_SIZE_EQ] > 0.5) else balance
                    mrpl = sl_dist * mppu
                    risk_amt = base * (min(risk, P[P_CAP]) / 100.0)
                    cap_amt = base * (P[P_CAP] / 100.0)
                    vol = _floor_step(risk_amt / mrpl, step)
                    skip = False
                    if vol < vol_min:
                        if v141:
                            if vol_min * mrpl > cap_amt and P[P_ALLOW_MINLOT] < 0.5:
                                stats[ST_SKIP_MINLOT] += 1; skip = True
                        vol = vol_min
                    if skip: continue
                    if v141:
                        cap_vol = _floor_step(cap_amt / mrpl, step)
                        if cap_vol >= vol_min and vol > cap_vol: vol = cap_vol
                    if vol > vol_max: vol = vol_max
                    margin = vol * contract * ask / leverage
                    free = equity
                    if margin > free * 0.8:
                        adj = _floor_step(vol * (free * 0.8) / margin, step)
                        if adj < vol_min:
                            stats[ST_SKIP_MARGIN] += 1; continue
                        vol = adj
                    real_money = vol * mrpl
                    if v141 and real_money > cap_amt + 1e-8 and P[P_ALLOW_MINLOT] < 0.5:
                        stats[ST_SKIP_MINLOT] += 1; continue

                    fill = entry + slip if d == 1 else entry - slip
                    has_pos = True
                    p_type = 1 if d == 1 else 2; p_vol = vol; p_open = fill
                    p_sl = fill - sl_dist if d == 1 else fill + sl_dist
                    p_tp = fill + tp_dist if d == 1 else fill - tp_dist
                    p_sl0 = p_sl; p_R = sl_dist; p_open_t = T; p_set = sid; p_str = s
                    p_risk = real_money / base * 100.0; p_bal_before = balance; p_atr = atr; p_spread = cur_spread_pts; p_sig_t = T
                    last_trade_t = T; trades_today += 1

            if has_pos:
                reason, px = _check_exit(p_type, p_sl, p_tp, o[k], h[k], l[k], ask, bar_spread, slip, pess, pass_id == 0)
                if reason != 0:
                    gross = (px - p_open) * p_vol * mppu if p_type == 1 else (p_open - px) * p_vol * mppu
                    cst = comm * p_vol
                    pnl = gross - cst
                    balance += pnl
                    trades[ntr, 0] = p_open_t; trades[ntr, 1] = T; trades[ntr, 2] = p_type; trades[ntr, 3] = p_vol
                    trades[ntr, 4] = p_open; trades[ntr, 5] = px; trades[ntr, 6] = p_sl0; trades[ntr, 7] = p_tp; trades[ntr, 8] = pnl
                    trades[ntr, 9] = cst; trades[ntr, 10] = p_set; trades[ntr, 11] = p_str; trades[ntr, 12] = reason
                    trades[ntr, 13] = p_risk; trades[ntr, 14] = p_bal_before; trades[ntr, 15] = pnl / (p_R * p_vol * mppu) if p_R > 0 else 0.0
                    trades[ntr, 16] = p_atr; trades[ntr, 17] = p_spread; trades[ntr, 18] = p_sig_t
                    ntr += 1
                    sl_money = p_R * p_vol * mppu
                    if pnl > 0:
                        if sl_money <= 0 or P[P_STREAK_MIN_R] <= 0 or pnl >= P[P_STREAK_MIN_R] * sl_money: streak = 0
                    elif pnl < 0:
                        streak += 1
                        if P[P_USE_STREAK] > 0.5 and streak >= P[P_MAX_STREAK]: pause_until = T + P[P_PAUSE_MIN] * 60.0
                    has_pos = False
                    equity = balance

        if has_pos:
            floating = (c[k] - p_open) * p_vol * mppu if p_type == 1 else (p_open - (c[k] + bar_spread)) * p_vol * mppu
            equity = balance + floating
        else:
            equity = balance
        balance_curve[k] = balance; equity_curve[k] = equity

    if has_pos:
        T = t[n - 1]
        px = c[n - 1] if p_type == 1 else c[n - 1] + spread_mean[n - 1]
        gross = (px - p_open) * p_vol * mppu if p_type == 1 else (p_open - px) * p_vol * mppu
        cst = comm * p_vol; pnl = gross - cst; balance += pnl
        trades[ntr, 0] = p_open_t; trades[ntr, 1] = T; trades[ntr, 2] = p_type; trades[ntr, 3] = p_vol
        trades[ntr, 4] = p_open; trades[ntr, 5] = px; trades[ntr, 6] = p_sl0; trades[ntr, 7] = p_tp; trades[ntr, 8] = pnl
        trades[ntr, 9] = cst; trades[ntr, 10] = p_set; trades[ntr, 11] = p_str; trades[ntr, 12] = EXIT_END
        trades[ntr, 13] = p_risk; trades[ntr, 14] = p_bal_before; trades[ntr, 15] = pnl / (p_R * p_vol * mppu) if p_R > 0 else 0.0
        trades[ntr, 16] = p_atr; trades[ntr, 17] = p_spread; trades[ntr, 18] = p_sig_t
        ntr += 1
        balance_curve[n - 1] = balance; equity_curve[n - 1] = balance
    return trades[:ntr], balance_curve, equity_curve, stats
