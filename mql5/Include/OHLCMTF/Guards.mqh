#ifndef OHLCMTF_GUARDS_MQH
#define OHLCMTF_GUARDS_MQH
#include <OHLCMTF/Logger.mqh>

class CCapitalGuard
{
private:
   double   m_hwm;
   bool     m_latched;
   datetime m_latched_until;
   double   m_dd_pct;
   double   m_day_start_balance;
   int      m_day_of_year;
   bool     m_daily_hit;
   int      m_trades_today;
   int      m_streak;
   datetime m_pause_until;
   datetime m_last_trade_time;
   datetime m_weekend_day;
public:
   CCapitalGuard() : m_hwm(0), m_latched(false), m_latched_until(0), m_dd_pct(0), m_day_start_balance(0), m_day_of_year(-1),
                     m_daily_hit(false), m_trades_today(0), m_streak(0), m_pause_until(0), m_last_trade_time(0), m_weekend_day(0) {}

   double   HWM()             { return m_hwm; }
   void     SetHWM(double v)  { m_hwm = v; }
   bool     Latched()         { return m_latched; }
   datetime LatchedUntil()    { return m_latched_until; }
   void     SetLatch(bool on, datetime until) { m_latched = on; m_latched_until = until; }
   double   DDPct()           { return m_dd_pct; }
   int      Streak()          { return m_streak; }
   void     SetStreak(int s)  { m_streak = s; }
   datetime PauseUntil()      { return m_pause_until; }
   void     SetPauseUntil(datetime t) { m_pause_until = t; }
   bool     InPause()         { return TimeCurrent() < m_pause_until; }
   bool     DailyHit()        { return m_daily_hit; }
   int      TradesToday()     { return m_trades_today; }
   void     SetTradesToday(int n) { m_trades_today = n; }
   double   DayStartBalance() { return m_day_start_balance; }
   void     SetDayStartBalance(double b) { m_day_start_balance = b; }

   double DailyLossPct()
   {
      if(m_day_start_balance <= 0.0) return 0.0;
      return (m_day_start_balance - AccountInfoDouble(ACCOUNT_EQUITY)) / m_day_start_balance * 100.0;
   }

   void CheckNewDay()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_year != m_day_of_year)
      {
         m_day_of_year = dt.day_of_year;
         m_day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
         m_daily_hit = false;
         m_trades_today = 0;
      }
   }

   // Devuelve true si hay que cerrar todo ahora
   bool EquityTick()
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY), balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double basis = DD_Use_Equity_Peak ? equity : balance;
      if(basis > m_hwm) m_hwm = basis;
      if(m_hwm <= 0.0) return false;
      m_dd_pct = (m_hwm - equity) / m_hwm * 100.0;
      if(!Use_Total_Drawdown_Limit) return false;
      if(m_latched)
      {
         if(DD_Pause_Hours > 0 && TimeCurrent() >= m_latched_until)
         {
            m_latched = false; m_latched_until = 0; m_hwm = basis;
            g_log.Info(StringFormat("DD: pausa terminada; HWM re-basado a %.2f", m_hwm));
         }
         return false;
      }
      if(m_dd_pct >= Max_Total_Drawdown_Pct)
      {
         m_latched = true;
         m_latched_until = (DD_Pause_Hours > 0) ? TimeCurrent() + DD_Pause_Hours * 3600 : 0;
         g_log.Error(StringFormat("GUARDIA DE EQUITY: DD %.2f%% >= %.1f%% (HWM=%.2f equity=%.2f). %s", m_dd_pct, Max_Total_Drawdown_Pct, m_hwm, equity,
                   (DD_Pause_Hours > 0 ? "Bloqueado hasta " + TimeToString(m_latched_until, TIME_DATE|TIME_MINUTES) : "Bloqueado hasta reset manual.")));
         return DD_Flatten_Positions;
      }
      return false;
   }

   bool DailyTick()
   {
      if(!Use_Daily_Loss_Limit || m_day_start_balance <= 0.0) return false;
      double loss = DailyLossPct();
      if(loss >= Max_Daily_Loss_Percent && !m_daily_hit)
      {
         m_daily_hit = true;
         g_log.Warn(StringFormat("LÍMITE DIARIO ALCANZADO (%.2f%%)%s", loss, Daily_Loss_Flatten ? " → cerrando posiciones" : " → sin nuevas entradas hoy"));
         return Daily_Loss_Flatten;
      }
      return false;
   }

   bool InWeekendWindow()
   {
      if(!Close_Before_Weekend) return false;
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      return (dt.day_of_week == 5 && dt.hour >= Weekend_Close_Hour);
   }
   bool WeekendTick(bool has_exposure)
   {
      if(!InWeekendWindow()) return false;
      datetime today = DayStart(TimeCurrent());
      if(m_weekend_day != today) { m_weekend_day = today; g_log.Info("Ventana de cierre de fin de semana activa"); }
      return has_exposure;   // se reintenta en cada tick mientras quede exposición
   }
   bool NeedsFlattenRetry(bool has_exposure)
   {
      return (m_latched && DD_Flatten_Positions && has_exposure) || (m_daily_hit && Daily_Loss_Flatten && has_exposure);
   }

   bool CanEnter(string &reason)
   {
      if(m_latched) { reason = "bloqueado por drawdown"; return false; }
      if(Use_Loss_Streak_Guard)
      {
         if(InPause()) { reason = "pausa por racha"; return false; }
         if(m_streak >= Max_Consecutive_Losses) m_streak = 0;
      }
      if(Use_Daily_Loss_Limit && m_day_start_balance > 0.0)
      {
         if(m_daily_hit || DailyLossPct() >= Max_Daily_Loss_Percent)
         {
            if(!m_daily_hit) { m_daily_hit = true; g_log.Warn(StringFormat("LÍMITE DIARIO ALCANZADO (%.2f%%)", DailyLossPct())); }
            reason = "límite diario"; return false;
         }
      }
      if(InWeekendWindow()) { reason = "ventana de cierre de fin de semana"; return false; }
      if(TimeCurrent() - m_last_trade_time < Cooldown_Seconds) { reason = "cooldown"; return false; }
      if(m_trades_today >= Max_Trades_Per_Day) { reason = "máximo de trades/día"; return false; }
      reason = "";
      return true;
   }

   void OnTradeSent() { m_last_trade_time = TimeCurrent(); m_trades_today++; }

   void OnTradeClosed(double pnl, double sl_money)
   {
      if(pnl > 0.0)
      {
         bool meaningful = (sl_money <= 0.0) || (Streak_Reset_Min_R <= 0.0) || (pnl >= Streak_Reset_Min_R * sl_money);
         if(meaningful) m_streak = 0;
      }
      else if(pnl < 0.0)
      {
         m_streak++;
         if(Use_Loss_Streak_Guard && m_streak >= Max_Consecutive_Losses)
         {
            m_pause_until = TimeCurrent() + Loss_Streak_Pause_Minutes * 60;
            g_log.Warn(StringFormat("PAUSA POR RACHA: %d pérdidas consecutivas; hasta %s", m_streak, TimeToString(m_pause_until, TIME_DATE|TIME_MINUTES)));
         }
      }
   }
};

#endif
