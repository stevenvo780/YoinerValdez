#ifndef OHLCMTF_MARKET_MQH
#define OHLCMTF_MARKET_MQH
#include <OHLCMTF/Logger.mqh>

class CMarket
{
private:
   int      m_atr_handle;
   double   m_atr;
   datetime m_atr_bar;
   double   m_spread_buf[];
   int      m_spread_idx;
   bool     m_spread_filled;
public:
   CMarket() : m_atr_handle(INVALID_HANDLE), m_atr(0), m_atr_bar(0), m_spread_idx(0), m_spread_filled(false) {}

   bool Init()
   {
      int n = MathMax(Spread_Sample_Size, 1);
      ArrayResize(m_spread_buf, n);
      ArrayInitialize(m_spread_buf, 0.0);
      m_spread_idx = 0; m_spread_filled = false;
      m_atr_handle = iATR(g_symbol, ATR_Timeframe, ATR_Period);
      if(m_atr_handle == INVALID_HANDLE)
      {
         g_log.Error("no se pudo crear el handle ATR");
         return false;
      }
      return true;
   }
   void Deinit() { if(m_atr_handle != INVALID_HANDLE) IndicatorRelease(m_atr_handle); m_atr_handle = INVALID_HANDLE; }

   double ATR()
   {
      datetime bar = iTime(g_symbol, ATR_Timeframe, 0);
      if(bar != 0 && bar == m_atr_bar && m_atr > 0.0) return m_atr;
      if(m_atr_handle == INVALID_HANDLE) return 0.0;
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(m_atr_handle, 0, 0, 2, buf) < 2) return 0.0;
      m_atr = buf[1];
      m_atr_bar = bar;
      return m_atr;
   }
   double ATRPct()
   {
      double a = ATR();
      double c = iClose(g_symbol, ATR_Timeframe, 1);
      return (a > 0.0 && c > 0.0) ? a / c * 100.0 : 0.0;
   }
   bool VolatilityOK()
   {
      if(!Use_Volatility_Filter) return true;
      double p = ATRPct();
      return (p > 0.0 && p >= ATR_Min_Pct && p <= ATR_Max_Pct);
   }
   bool SweetSpot()
   {
      double band = ATR_Max_Pct - ATR_Min_Pct;
      double p = ATRPct();
      return (band > 0.0 && p >= ATR_Min_Pct + band * 0.20 && p <= ATR_Min_Pct + band * 0.80);
   }

   double CurrentSpread() { return SymbolInfoDouble(g_symbol, SYMBOL_ASK) - SymbolInfoDouble(g_symbol, SYMBOL_BID); }
   void SampleSpread()
   {
      int n = ArraySize(m_spread_buf);
      if(n <= 0) return;
      m_spread_buf[m_spread_idx] = CurrentSpread();
      m_spread_idx = (m_spread_idx + 1) % n;
      if(m_spread_idx == 0) m_spread_filled = true;
   }
   double AverageSpread()
   {
      int n = ArraySize(m_spread_buf);
      int cnt = m_spread_filled ? n : m_spread_idx;
      if(cnt <= 0) return CurrentSpread();
      double s = 0.0;
      for(int i = 0; i < cnt; i++) s += m_spread_buf[i];
      return s / cnt;
   }

   int StructureTrend(ENUM_TIMEFRAMES tf, int lookback)
   {
      if(lookback < 6) return 0;
      if(Bars(g_symbol, tf) < lookback + 5) return 0;
      int seg = MathMax(lookback / 3, 2);
      double h1 = iHigh(g_symbol, tf, iHighest(g_symbol, tf, MODE_HIGH, seg, 1));
      double l1 = iLow (g_symbol, tf, iLowest (g_symbol, tf, MODE_LOW,  seg, 1));
      double h2 = iHigh(g_symbol, tf, iHighest(g_symbol, tf, MODE_HIGH, seg, 1 + seg));
      double l2 = iLow (g_symbol, tf, iLowest (g_symbol, tf, MODE_LOW,  seg, 1 + seg));
      double h3 = iHigh(g_symbol, tf, iHighest(g_symbol, tf, MODE_HIGH, seg, 1 + 2*seg));
      double l3 = iLow (g_symbol, tf, iLowest (g_symbol, tf, MODE_LOW,  seg, 1 + 2*seg));
      if(h1 <= 0.0 || l1 <= 0.0 || h2 <= 0.0 || l2 <= 0.0 || h3 <= 0.0 || l3 <= 0.0) return 0;
      int bull = 0, bear = 0;
      if(h1 > h2 && l1 > l2) bull++;
      if(h2 > h3 && l2 > l3) bull++;
      if(h1 > h3 && l1 > l3) bull++;
      if(h1 < h2 && l1 < l2) bear++;
      if(h2 < h3 && l2 < l3) bear++;
      if(h1 < h3 && l1 < l3) bear++;
      if(bull >= Min_Swing_Confirmations && bull > bear) return  1;
      if(bear >= Min_Swing_Confirmations && bear > bull) return -1;
      return 0;
   }

   double TrailStructureLow(int lookback)
   {
      int idx = iLowest(g_symbol, ATR_Timeframe, MODE_LOW, lookback, 1);
      return (idx >= 0) ? iLow(g_symbol, ATR_Timeframe, idx) : 0.0;
   }
   double TrailStructureHigh(int lookback)
   {
      int idx = iHighest(g_symbol, ATR_Timeframe, MODE_HIGH, lookback, 1);
      return (idx >= 0) ? iHigh(g_symbol, ATR_Timeframe, idx) : 0.0;
   }
};

#endif
