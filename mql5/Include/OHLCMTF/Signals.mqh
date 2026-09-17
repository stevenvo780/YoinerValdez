#ifndef OHLCMTF_SIGNALS_MQH
#define OHLCMTF_SIGNALS_MQH
#include <OHLCMTF/Market.mqh>

class CSignalEngine
{
private:
   CMarket *m_market;
   int      m_last_trend;

   bool BreakoutQuality(ENUM_TIMEFRAMES tf, int direction, double level, double atr_now,
                        double &out_margin, double &out_body_ratio, double &out_wick_ratio)
   {
      double o = iOpen(g_symbol, tf, 1), h = iHigh(g_symbol, tf, 1), l = iLow(g_symbol, tf, 1), c = iClose(g_symbol, tf, 1);
      if(o <= 0.0 || h <= 0.0 || l <= 0.0 || c <= 0.0 || atr_now <= 0.0) return false;
      double range = h - l;
      if(range <= 0.0) return false;
      double body = MathAbs(c - o);
      out_body_ratio = body / range;
      if(Require_Close_Beyond)
      {
         if(direction ==  1 && c <= level) return false;
         if(direction == -1 && c >= level) return false;
      }
      if(out_body_ratio < Min_Body_Ratio) return false;
      double against = (direction == 1) ? (h - MathMax(o, c)) : (MathMin(o, c) - l);
      out_wick_ratio = (body > 0.0) ? against / body : 999.0;
      if(out_wick_ratio > Max_Against_Wick_Ratio) return false;
      out_margin = (direction == 1) ? (h - level) : (level - l);
      if(out_margin < Min_Breakout_ATR_Mult * atr_now) return false;
      if(out_margin > Max_Breakout_ATR_Mult * atr_now) return false;
      if(Prefer_Expansion_Break)
      {
         double avg = 0.0; int cnt = 0;
         for(int i = 2; i <= 6; i++)
         {
            double rh = iHigh(g_symbol, tf, i), rl = iLow(g_symbol, tf, i);
            if(rh > 0.0 && rl > 0.0) { avg += (rh - rl); cnt++; }
         }
         if(cnt > 0 && range < (avg / cnt) * 1.15) return false;
      }
      return true;
   }

   int Score(int direction, int trend, bool mtf_ok, double margin, double body_ratio, double atr_now, bool sweet)
   {
      int s = 1;
      if(trend == direction)                                   s++;
      if(Require_HigherTF_Confirm && mtf_ok)                   s++;
      if(margin >= Min_Breakout_ATR_Mult * 1.8 * atr_now)      s++;
      if(body_ratio >= Min_Body_Ratio + 0.10)                  s++;
      if(sweet)                                                s++;
      return s;
   }

public:
   CSignalEngine() : m_market(NULL), m_last_trend(0) {}
   void Init(CMarket *market) { m_market = market; }
   int  LastTrend() { return m_last_trend; }

   bool SessionOpen()
   {
      if(!Use_Session_Filter) return true;
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int h = dt.hour;
      if(dt.day_of_week == 5 && Friday_Entry_Cutoff_Hour < 24 && h >= Friday_Entry_Cutoff_Hour) return false;
      if(h >= Session_Start_Hour && h < Session_End_Hour) return true;
      if(Allow_Asia_Breakouts && h >= 0 && h < 7) return true;
      return false;
   }

   // Devuelve el número de señales (0..2) escritas en out[]
   int Evaluate(ENUM_TIMEFRAMES t1, ENUM_TIMEFRAMES t2, ENUM_TIMEFRAMES t3, int set_id, SSignal &out[])
   {
      ArrayResize(out, 0);
      if(Bars(g_symbol, t1) < Structure_Lookback + 8) return 0;
      if(Require_HigherTF_Confirm && Bars(g_symbol, t3) < 3) return 0;
      if(!SessionOpen()) return 0;

      double h1 = iHigh(g_symbol, t1, 1), l1 = iLow(g_symbol, t1, 1), c1 = iClose(g_symbol, t1, 1);
      if(h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0) return 0;

      int idxH = iHighest(g_symbol, t1, MODE_HIGH, Structure_Lookback, 2);
      int idxL = iLowest (g_symbol, t1, MODE_LOW,  Structure_Lookback, 2);
      if(idxH < 0 || idxL < 0) return 0;
      double sHigh = iHigh(g_symbol, t1, idxH), sLow = iLow(g_symbol, t1, idxL);
      if(sHigh <= 0.0 || sLow <= 0.0) return 0;

      bool buy  = Enable_Buy_Signals  && (h1 > sHigh);
      bool sell = Enable_Sell_Signals && (l1 < sLow);
      if(!buy && !sell) return 0;

      double atr_now = m_market.ATR();
      if(atr_now <= 0.0) return 0;

      double mB = 0, bB = 0, wB = 0, mS = 0, bS = 0, wS = 0;
      if(buy  && !BreakoutQuality(t1,  1, sHigh, atr_now, mB, bB, wB)) buy = false;
      if(sell && !BreakoutQuality(t1, -1, sLow,  atr_now, mS, bS, wS)) sell = false;
      if(!buy && !sell) return 0;

      bool mtfB = true, mtfS = true;
      if(Require_HigherTF_Confirm)
      {
         double h3 = iHigh(g_symbol, t3, 1), l3 = iLow(g_symbol, t3, 1);
         mtfB = (h3 > 0.0 && h1 > h3);
         mtfS = (l3 > 0.0 && l1 < l3);
         if(!mtfB) buy = false;
         if(!mtfS) sell = false;
      }
      if(!buy && !sell) return 0;
      if(!m_market.VolatilityOK()) return 0;

      int trend = m_market.StructureTrend(t2, Trend_Lookback);
      m_last_trend = trend;
      if(Require_Trend_Alignment)
      {
         if(trend == 1)       sell = false;
         else if(trend == -1) buy = false;
         else if(Block_When_No_Trend) { buy = false; sell = false; }
      }
      if(!buy && !sell) return 0;

      bool sweet = m_market.SweetSpot();
      int min_str = MathMin(Min_Signal_Strength, MAX_SIGNAL_STRENGTH);
      datetime bt = iTime(g_symbol, t1, 1);
      int n = 0;
      if(buy)
      {
         int s = Score(1, trend, mtfB, mB, bB, atr_now, sweet);
         if(s >= min_str)
         {
            ArrayResize(out, n + 1);
            out[n].direction = 1; out[n].strength = s; out[n].set_id = set_id; out[n].trend = trend; out[n].atr = atr_now;
            out[n].price = h1; out[n].bar_time = bt; out[n].margin = mB; out[n].body_ratio = bB; n++;
         }
         else g_log.Debug("BUY " + SetTag(set_id) + " descartada: fuerza " + IntegerToString(s) + " < " + IntegerToString(min_str));
      }
      if(sell)
      {
         int s = Score(-1, trend, mtfS, mS, bS, atr_now, sweet);
         if(s >= min_str)
         {
            ArrayResize(out, n + 1);
            out[n].direction = -1; out[n].strength = s; out[n].set_id = set_id; out[n].trend = trend; out[n].atr = atr_now;
            out[n].price = l1; out[n].bar_time = bt; out[n].margin = mS; out[n].body_ratio = bS; n++;
         }
         else g_log.Debug("SELL " + SetTag(set_id) + " descartada: fuerza " + IntegerToString(s) + " < " + IntegerToString(min_str));
      }
      return n;
   }
};

#endif
