//+------------------------------------------------------------------+
//|                                            OHLCMTF_Scalper.mq5   |
//|   XAU/USD Pure Price Action Structure Scalper v16 (modular)      |
//|   Lógica: v15 + defaults medidos sobre el M1 Dukascopy completo  |
//|   Módulos en Include/OHLCMTF/*.mqh                                |
//+------------------------------------------------------------------+
#property strict
#property copyright "OHLCMTF SCALPER v16 - Pure Price Action XAUUSD"
#property version   "16.00"
#property description "Structure breakout scalper XAUUSD v16, guardia de equity dura, sin protección progresiva"

#include <OHLCMTF/Context.mqh>
#include <OHLCMTF/Panel.mqh>

CPanel   g_panel;
datetime g_last_bar_fixed  = 0;
datetime g_last_bar_custom = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   InitSymbolContext();
   if(!ValidateInputs()) return INIT_PARAMETERS_INCORRECT;
   g_log.Init();
   if(!g_market.Init()) return INIT_FAILED;
   g_exec.Init();
   g_signals.Init(GetPointer(g_market));
   g_posmgr.Init(GetPointer(g_market), GetPointer(g_exec), GetPointer(g_state));

   g_last_bar_fixed  = iTime(g_symbol, PERIOD_H1, 0);
   g_last_bar_custom = iTime(g_symbol, TF_Fast, 0);

   g_guard.CheckNewDay();
   g_state.Load(g_guard);
   g_state.RecoverOpenPosition(GetPointer(g_market));
   g_state.RecoverDailyFromHistory(g_guard);
   if(Use_Calendar_Filter) g_news.Load(true);

   if(Panel_Show) { EventSetTimer(MathMax(Panel_Refresh_Sec, 1)); g_panel.Update(); }

   g_log.Sep();
   g_log.Info("OHLCMTF SCALPER v" + OHLC_VERSION + " inicializado en " + g_symbol);
   g_log.Info(StringFormat("Sets: FIJO=%s (H1/%s/D1, magic %d) | CUSTOM=%s (%s/%s, magic %d)", Use_Fixed_Set ? "ON" : "OFF", EnumToString(Trend_Timeframe), MAGIC_FIXED,
                         Use_Custom_Pair ? "ON" : "OFF", EnumToString(TF_Fast), EnumToString(TF_Slow), MAGIC_CUSTOM));
   g_log.Info(StringFormat("Riesgo %.2f-%.2f%% (cap %.1f%%) base=%s | lote mínimo sobre cap: %s", Min_Risk_Percent, Max_Risk_Percent, Hard_Risk_Cap_Percent,
                         Size_On_Equity ? "min(balance,equity)" : "balance", Allow_MinLot_Above_Cap ? "PERMITIDO" : "OMITIR"));
   g_log.Info(StringFormat("Guardia DD: %s | flatten=%s | pausa=%dh | HWM=%.2f%s", Use_Total_Drawdown_Limit ? DoubleToString(Max_Total_Drawdown_Pct, 1) + "% vs HWM" : "OFF",
                         DD_Flatten_Positions ? "SÍ" : "NO", DD_Pause_Hours, g_guard.HWM(), g_guard.Latched() ? " | *** BLOQUEADO ***" : ""));
   g_risk.PrintMinLotDiagnostic(GetPointer(g_market));
   g_log.Sep();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_stats.PrintSummary("RESUMEN FINAL", g_risk.SkippedMinLot(), g_guard.HWM(), g_guard.DDPct(), g_guard.Latched());
   g_state.Save(g_guard);
   EventKillTimer();
   g_panel.DeleteAll();
   g_market.Deinit();
   g_log.Deinit();
}

//+------------------------------------------------------------------+
void OnTimer() { g_panel.Update(); }

//+------------------------------------------------------------------+
void OnTick()
{
   g_guard.CheckNewDay();
   g_market.SampleSpread();

   if(g_guard.EquityTick()) { g_exec.FlattenAll("DRAWDOWN"); g_state.Save(g_guard); }
   if(g_guard.DailyTick())  g_exec.FlattenAll("DAILY_LOSS");
   if(g_guard.WeekendTick(g_exec.HasExposure())) g_exec.FlattenAll("WEEKEND");
   if(g_guard.NeedsFlattenRetry(g_exec.HasExposure())) g_exec.FlattenAll("RETRY");

   g_posmgr.Manage();
   if(Use_Limit_Orders) g_exec.CleanupStalePending();

   bool entering = false; string label = "";
   if(g_news.StateChanged(entering, label))
   {
      if(entering)
      {
         g_log.Info("NOTICIAS: bloqueo → " + label);
         if(Use_Calendar_Filter && Calendar_Close_Positions && g_exec.CountOpenPositions() > 0) g_exec.FlattenAll("NEWS");
      }
      else g_log.Info("NOTICIAS: bloqueo finalizado");
   }

   if(g_guard.Latched()) return;

   if(Use_Fixed_Set)
   {
      datetime bar = iTime(g_symbol, PERIOD_H1, 0);
      if(bar != 0 && bar != g_last_bar_fixed) { g_last_bar_fixed = bar; EvaluateSet(PERIOD_H1, Trend_Timeframe, PERIOD_D1, SET_FIXED); }
   }
   if(Use_Custom_Pair)
   {
      datetime bar = iTime(g_symbol, TF_Fast, 0);
      if(bar != 0 && bar != g_last_bar_custom) { g_last_bar_custom = bar; EvaluateSet(TF_Fast, TF_Slow, TF_Slow, SET_CUSTOM); }
   }
}

//+------------------------------------------------------------------+
void EvaluateSet(ENUM_TIMEFRAMES t1, ENUM_TIMEFRAMES t2, ENUM_TIMEFRAMES t3, int set_id)
{
   SSignal sigs[];
   int n = g_signals.Evaluate(t1, t2, t3, set_id, sigs);
   for(int i = 0; i < n; i++)
   {
      ExecuteSignal(sigs[i]);
      g_panel.DrawArrow(sigs[i]);
   }
}

//+------------------------------------------------------------------+
void ExecuteSignal(const SSignal &sig)
{
   if(g_exec.HasExposure()) return;
   string why = "";
   if(g_news.IsBlocked(why)) { g_log.Info("Señal omitida por noticias: " + why); return; }
   if(!g_guard.CanEnter(why)) { g_log.Debug("Señal omitida: " + why); return; }

   double cur_spread = g_market.CurrentSpread(), avg_spread = g_market.AverageSpread();
   double cur_pts = cur_spread / g_point, avg_pts = avg_spread / g_point;
   double mode_spread = Use_Avg_Spread_For_Mode ? avg_spread : cur_spread;
   bool high_spread = (mode_spread / g_point) > HighSpread_Threshold;
   if(Max_Spread_Points > 0.0 && cur_pts > Max_Spread_Points) { g_log.Info(StringFormat("Señal omitida: spread %.1f > %.1f pts", cur_pts, Max_Spread_Points)); return; }

   double atr = sig.atr;
   if(atr <= 0.0) return;
   double tp_factor = 1.0;
   double risk_pct = g_risk.RiskPctForStrength(sig.strength, tp_factor);
   double sl_mult = ATR_SL_Multiplier, tp_mult = ATR_TP_Multiplier * tp_factor;
   if(high_spread)
   {
      double avs = (mode_spread > 0.0) ? atr / mode_spread : 0.0;
      if(avs < HighSpread_ATR_Min_Mult) { g_log.Info(StringFormat("Señal omitida en spread alto: ATR/spread %.2f < %.2f", avs, HighSpread_ATR_Min_Mult)); return; }
      sl_mult *= HighSpread_SL_Extra_Mult; risk_pct *= HighSpread_Risk_Reduction;
      g_log.Info(StringFormat("Spread alto (%.0f pts): SL x%.2f, riesgo x%.2f", mode_spread / g_point, HighSpread_SL_Extra_Mult, HighSpread_Risk_Reduction));
   }
   risk_pct = MathMin(risk_pct, MathMin(Max_Risk_Percent, Hard_Risk_Cap_Percent));
   if(risk_pct <= 0.0) return;

   double sl_dist = atr * sl_mult, tp_dist = atr * tp_mult;
   double floor_ = avg_spread * Spread_Buffer_Multiplier;
   if(floor_ > 0.0) { if(sl_dist < floor_) sl_dist = floor_; if(tp_dist < floor_) tp_dist = floor_; }
   double stopLevel = SymbolInfoInteger(g_symbol, SYMBOL_TRADE_STOPS_LEVEL) * g_point;
   if(stopLevel <= 0.0) stopLevel = 10.0 * g_point;
   sl_dist = MathMax(sl_dist, MathMax(stopLevel, Min_SL_Points * g_point));

   double entry_ref = (sig.direction == 1) ? SymbolInfoDouble(g_symbol, SYMBOL_ASK) : SymbolInfoDouble(g_symbol, SYMBOL_BID);
   SSizing sz;
   if(!g_risk.CalcVolume(sig.direction, entry_ref, sl_dist, risk_pct, sz)) { g_log.Info("Señal omitida: " + sz.reason); return; }

   long pts = (long)MathRound(sl_dist / g_point);
   string comment = "R" + IntegerToString((int)MathMax(1, MathMin(pts, 999999))) + SetTag(sig.set_id);
   double entry = 0, sl = 0, tp = 0;
   if(!g_exec.Open(sig, sz.volume, sl_dist, tp_dist, comment, entry, sl, tp))
   {
      g_log.Error(StringFormat("ERROR al enviar %s %s rc=%d %s", sig.direction == 1 ? "BUY" : "SELL", SetTag(sig.set_id), g_exec.LastRetcode(), g_exec.LastRetcodeDesc()));
      return;
   }
   g_guard.OnTradeSent();
   g_risk.RecordLast(sz.risk_pct, sz.risk_money);
   g_log.Sep();
   g_log.Info(StringFormat("%s EJECUTADA | set %s | magic %I64u", sig.direction == 1 ? "BUY" : "SELL", SetTag(sig.set_id), MagicForSet(sig.set_id)));
   g_log.Info(StringFormat("Entrada %s | SL %s (%d pts) | TP %s (%d pts) | lote %.2f", DoubleToString(entry, g_digits), DoubleToString(sl, g_digits), (int)(sl_dist / g_point),
                         DoubleToString(tp, g_digits), (int)(tp_dist / g_point), sz.volume));
   g_log.Info(StringFormat("ATR %s | riesgo objetivo %.2f%% | RIESGO REAL %.2f%% ($%.2f) [cap %.2f%%] | fuerza %d/%d | spread %.0f pts (prom %.0f) | tendencia %d",
                         DoubleToString(atr, g_digits), risk_pct, sz.risk_pct, sz.risk_money, Hard_Risk_Cap_Percent, sig.strength, MAX_SIGNAL_STRENGTH, cur_pts, avg_pts, sig.trend));
   g_log.Sep();
}

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != g_symbol) return;
   long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(!IsOurMagic(magic)) return;

   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   ulong pos_id = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   int set_id = SetFromMagic(magic);
   bool has_exit  = (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY || entry == DEAL_ENTRY_INOUT);
   bool has_entry = (entry == DEAL_ENTRY_IN  || entry == DEAL_ENTRY_INOUT);
   if(has_exit) AccountExit(trans.deal, pos_id, set_id);
   if(has_entry) AccountEntry(trans, pos_id, set_id);
}

void AccountEntry(const MqlTradeTransaction &trans, ulong pos_id, int set_id)
{
   ulong ticket = trans.position;
   if(ticket == 0)
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong t = PositionGetTicket(i);
         if(t != 0 && (ulong)PositionGetInteger(POSITION_IDENTIFIER) == pos_id) { ticket = t; break; }
      }
   g_state.cur.ticket = ticket; g_state.cur.pos_id = pos_id; g_state.cur.set_id = set_id;
   g_state.cur.open = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   g_state.cur.sl0  = HistoryDealGetDouble(trans.deal, DEAL_SL);
   g_state.cur.tp0  = HistoryDealGetDouble(trans.deal, DEAL_TP);
   g_state.cur.type = (HistoryDealGetInteger(trans.deal, DEAL_TYPE) == DEAL_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   if(ticket > 0 && PositionSelectByTicket(ticket))
   {
      g_state.cur.open = PositionGetDouble(POSITION_PRICE_OPEN);
      if(PositionGetDouble(POSITION_SL) > 0.0) g_state.cur.sl0 = PositionGetDouble(POSITION_SL);
      if(PositionGetDouble(POSITION_TP) > 0.0) g_state.cur.tp0 = PositionGetDouble(POSITION_TP);
      g_state.cur.type = (int)PositionGetInteger(POSITION_TYPE);
   }
   g_state.cur.sl_dist = (g_state.cur.sl0 > 0.0) ? MathAbs(g_state.cur.open - g_state.cur.sl0) : 0.0;
   g_state.cur.tp_dist = (g_state.cur.tp0 > 0.0) ? MathAbs(g_state.cur.tp0 - g_state.cur.open) : 0.0;
   g_state.RememberEntry(ticket, pos_id, g_state.cur.sl_dist);
   g_stats.OnEntry(set_id);
}

void AccountExit(ulong deal, ulong pos_id, int set_id)
{
   if(!HistoryDealSelect(deal)) return;
   double profit = HistoryDealGetDouble(deal, DEAL_PROFIT) + HistoryDealGetDouble(deal, DEAL_SWAP) + HistoryDealGetDouble(deal, DEAL_COMMISSION) + HistoryDealGetDouble(deal, DEAL_FEE);
   double mppu = MoneyPerPriceUnitPerLot();
   double sl_dist = 0.0, tp_dist = 0.0;
   if(g_state.cur.ticket != 0 && (g_state.cur.pos_id == pos_id || g_state.cur.ticket == pos_id) && g_state.cur.sl_dist > 0.0)
   { sl_dist = g_state.cur.sl_dist; tp_dist = g_state.cur.tp_dist; }
   else
   { sl_dist = g_state.RiskDistanceFromHistory(pos_id, tp_dist); HistoryDealSelect(deal); }
   double vol = HistoryDealGetDouble(deal, DEAL_VOLUME);
   double sl_money = sl_dist * mppu * vol, tp_money = tp_dist * mppu * vol;

   g_stats.OnExit(profit, sl_money, tp_money, set_id);
   g_log.Info(StringFormat("CIERRE set %s pos#%I64u P&L=%.2f | R inicial $%.2f → %s R", SetTag(set_id), pos_id, profit, sl_money, sl_money > 0.0 ? DoubleToString(profit / sl_money, 2) : "n/a"));
   if(g_stats.Total() > 0 && g_stats.Total() % 50 == 0)
      g_stats.PrintSummary("RESUMEN PARCIAL (" + IntegerToString(g_stats.Total()) + " cierres)", g_risk.SkippedMinLot(), g_guard.HWM(), g_guard.DDPct(), g_guard.Latched());

   bool still_open = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t != 0 && ((ulong)PositionGetInteger(POSITION_IDENTIFIER) == pos_id || t == pos_id)) { still_open = true; break; }
   }
   // La racha se evalúa por POSICIÓN cerrada (agregando fills parciales), no por deal
   bool mine = (g_state.cur.pos_id == pos_id || g_state.cur.ticket == pos_id);
   if(mine) { g_state.cur_realized += profit; g_state.cur_closed_vol += vol; }
   if(!still_open)
   {
      double pos_pnl = mine ? g_state.cur_realized : profit;
      double pos_vol = mine ? g_state.cur_closed_vol : vol;
      g_guard.OnTradeClosed(pos_pnl, sl_dist * mppu * pos_vol);
      ulong tk = g_state.cur.ticket;
      if(mine) { g_state.cur.Clear(); g_state.cur_realized = 0.0; g_state.cur_closed_vol = 0.0; }
      g_state.ForgetPosition(pos_id, tk);
   }
   g_state.Save(g_guard);
}
//+------------------------------------------------------------------+
