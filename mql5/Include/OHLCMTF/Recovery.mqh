#ifndef OHLCMTF_RECOVERY_MQH
#define OHLCMTF_RECOVERY_MQH
#include <OHLCMTF/Guards.mqh>
#include <OHLCMTF/Market.mqh>

class CStateStore
{
private:
   string Key(string k) { return GV_PREFIX + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + g_symbol + "_" + k; }
   string RKey(ulong id) { return Key("R_" + IntegerToString((long)id)); }
   bool m_had_streak;
public:
   SPositionState cur;
   double         cur_realized;
   double         cur_closed_vol;

   CStateStore() : m_had_streak(false), cur_realized(0.0), cur_closed_vol(0.0) { cur.Clear(); }

   void Load(CCapitalGuard &g)
   {
      if(MQLInfoInteger(MQL_TESTER)) GlobalVariablesDeleteAll(GV_PREFIX);
      m_had_streak = GlobalVariableCheck(Key("STREAK"));
      if(GlobalVariableCheck(Key("HWM")))     g.SetHWM(GlobalVariableGet(Key("HWM")));
      bool latched = GlobalVariableCheck(Key("DDLATCH")) && GlobalVariableGet(Key("DDLATCH")) > 0.5;
      datetime until = GlobalVariableCheck(Key("DDUNTIL")) ? (datetime)GlobalVariableGet(Key("DDUNTIL")) : 0;
      if(latched && DD_Manual_Reset)
      {
         g_log.Info("DD: reset manual; HWM re-basado a equity actual");
         latched = false; until = 0; g.SetHWM(AccountInfoDouble(ACCOUNT_EQUITY));
      }
      g.SetLatch(latched, until);
      if(GlobalVariableCheck(Key("STREAK")))  g.SetStreak((int)GlobalVariableGet(Key("STREAK")));
      if(GlobalVariableCheck(Key("PAUSE")))   g.SetPauseUntil((datetime)GlobalVariableGet(Key("PAUSE")));
      if(g.HWM() <= 0.0) g.SetHWM(DD_Use_Equity_Peak ? AccountInfoDouble(ACCOUNT_EQUITY) : AccountInfoDouble(ACCOUNT_BALANCE));
      Save(g);
   }
   void Save(CCapitalGuard &g)
   {
      GlobalVariableSet(Key("HWM"), g.HWM());
      GlobalVariableSet(Key("DDLATCH"), g.Latched() ? 1.0 : 0.0);
      GlobalVariableSet(Key("DDUNTIL"), (double)g.LatchedUntil());
      GlobalVariableSet(Key("STREAK"), (double)g.Streak());
      GlobalVariableSet(Key("PAUSE"), (double)g.PauseUntil());
   }
   bool HasStreakSaved() { return m_had_streak; }

   void RememberEntry(ulong ticket, ulong pos_id, double sl_dist)
   {
      if(sl_dist <= 0.0) return;
      GlobalVariableSet(RKey(ticket), sl_dist);
      if(pos_id != ticket) GlobalVariableSet(RKey(pos_id), sl_dist);
   }
   void ForgetPosition(ulong pos_id, ulong ticket)
   {
      if(GlobalVariableCheck(RKey(pos_id))) GlobalVariableDel(RKey(pos_id));
      if(ticket != pos_id && GlobalVariableCheck(RKey(ticket))) GlobalVariableDel(RKey(ticket));
   }

   double RiskDistanceFromHistory(ulong pos_id, double &tp_dist)
   {
      tp_dist = 0.0;
      if(pos_id == 0) return 0.0;
      if(GlobalVariableCheck(RKey(pos_id)))
      {
         double r = GlobalVariableGet(RKey(pos_id));
         if(r > 0.0) return r;
      }
      if(!HistorySelectByPosition(pos_id)) return 0.0;
      int n = HistoryDealsTotal();
      for(int i = 0; i < n; i++)
      {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0 || (ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
         double price = HistoryDealGetDouble(d, DEAL_PRICE), sl = HistoryDealGetDouble(d, DEAL_SL), tp = HistoryDealGetDouble(d, DEAL_TP);
         if(tp > 0.0 && price > 0.0) tp_dist = MathAbs(tp - price);
         if(sl > 0.0 && price > 0.0) return MathAbs(price - sl);
         string cmt = HistoryDealGetString(d, DEAL_COMMENT);
         if(StringLen(cmt) > 1 && StringGetCharacter(cmt, 0) == 'R')
         {
            double pts = StringToDouble(StringSubstr(cmt, 1));
            if(pts > 0.0) return pts * g_point;
         }
      }
      return 0.0;
   }

   double InitialRiskDistance(ulong ticket, double open_price, double current_sl, CMarket *market)
   {
      if(ticket == cur.ticket && cur.sl_dist > 0.0) return cur.sl_dist;
      double tp_tmp = 0.0;
      double r = RiskDistanceFromHistory(ticket, tp_tmp);
      if(r > 0.0) return r;
      string cmt = "";
      if(PositionSelectByTicket(ticket)) cmt = PositionGetString(POSITION_COMMENT);
      if(StringLen(cmt) > 1 && StringGetCharacter(cmt, 0) == 'R')
      {
         double pts = StringToDouble(StringSubstr(cmt, 1));
         if(pts > 0.0) return pts * g_point;
      }
      if(current_sl > 0.0 && open_price > 0.0 && MathAbs(open_price - current_sl) > 0.0) return MathAbs(open_price - current_sl);
      double atr = market.ATR();
      return (atr > 0.0) ? atr * ATR_SL_Multiplier : 0.0;
   }

   void RecoverOpenPosition(CMarket *market)
   {
      int found = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong t = PositionGetTicket(i);
         if(t == 0 || PositionGetString(POSITION_SYMBOL) != g_symbol) continue;
         long magic = PositionGetInteger(POSITION_MAGIC);
         if(!IsOurMagic(magic)) continue;
         found++;
         if(found > 1) { g_log.Warn("RECUPERACIÓN: más de una posición del EA abierta (#" + IntegerToString((long)t) + ")"); continue; }
         cur.ticket = t;
         cur.pos_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
         cur.set_id = SetFromMagic(magic);
         cur.open   = PositionGetDouble(POSITION_PRICE_OPEN);
         cur.sl0    = PositionGetDouble(POSITION_SL);
         cur.tp0    = PositionGetDouble(POSITION_TP);
         cur.type   = (int)PositionGetInteger(POSITION_TYPE);
         double tp_hist = 0.0;
         cur.sl_dist = RiskDistanceFromHistory(cur.pos_id, tp_hist);
         if(cur.sl_dist <= 0.0 && cur.pos_id != t) cur.sl_dist = RiskDistanceFromHistory(t, tp_hist);
         if(cur.sl_dist <= 0.0) cur.sl_dist = InitialRiskDistance(t, cur.open, cur.sl0, market);
         cur.tp_dist = (tp_hist > 0.0) ? tp_hist : ((cur.tp0 > 0.0) ? MathAbs(cur.tp0 - cur.open) : 0.0);
         g_log.Info(StringFormat("RECUPERACIÓN: posición #%I64u set %s R=%d pts", t, SetTag(cur.set_id), (int)(cur.sl_dist / g_point)));
      }
   }

   void RecoverDailyFromHistory(CCapitalGuard &g)
   {
      datetime day_start = DayStart(TimeCurrent());
      if(!HistorySelect(day_start - 86400 * 30, TimeCurrent() + 3600)) return;
      int trades_today = 0; double realized = 0.0;
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0 || HistoryDealGetString(d, DEAL_SYMBOL) != g_symbol || !IsOurMagic(HistoryDealGetInteger(d, DEAL_MAGIC))) continue;
         if((datetime)HistoryDealGetInteger(d, DEAL_TIME) < day_start) continue;
         ENUM_DEAL_ENTRY e = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY);
         if(e == DEAL_ENTRY_IN || e == DEAL_ENTRY_INOUT) trades_today++;
         realized += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
      }
      g.SetTradesToday(MathMax(g.TradesToday(), trades_today));
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      if(bal - realized > 0.0) g.SetDayStartBalance(bal - realized);
      if(!HasStreakSaved())
      {
         int streak = 0;
         for(int i = total - 1; i >= 0; i--)
         {
            ulong d = HistoryDealGetTicket(i);
            if(d == 0 || HistoryDealGetString(d, DEAL_SYMBOL) != g_symbol || !IsOurMagic(HistoryDealGetInteger(d, DEAL_MAGIC))) continue;
            ENUM_DEAL_ENTRY e = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY);
            if(e != DEAL_ENTRY_OUT && e != DEAL_ENTRY_OUT_BY && e != DEAL_ENTRY_INOUT) continue;
            double p = HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
            if(p < 0.0) streak++; else break;
         }
         g.SetStreak(streak);
      }
      g_log.Info(StringFormat("Recuperación: trades hoy=%d | P&L hoy=%.2f | balance inicio día=%.2f | racha=%d", g.TradesToday(), realized, g.DayStartBalance(), g.Streak()));
   }
};

#endif
