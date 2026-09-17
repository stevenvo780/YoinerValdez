#ifndef OHLCMTF_POSITIONMANAGER_MQH
#define OHLCMTF_POSITIONMANAGER_MQH
#include <OHLCMTF/Market.mqh>
#include <OHLCMTF/Execution.mqh>
#include <OHLCMTF/Recovery.mqh>

class CPositionManager
{
private:
   CMarket     *m_market;
   CExecutor   *m_exec;
   CStateStore *m_state;
   int          m_mods;
public:
   CPositionManager() : m_market(NULL), m_exec(NULL), m_state(NULL), m_mods(0) {}
   void Init(CMarket *market, CExecutor *exec, CStateStore *state) { m_market = market; m_exec = exec; m_state = state; }
   int  Modifications() { return m_mods; }

   double CurrentR(ulong ticket)
   {
      if(!PositionSelectByTicket(ticket)) return 0.0;
      double open = PositionGetDouble(POSITION_PRICE_OPEN), sl = PositionGetDouble(POSITION_SL), cur = PositionGetDouble(POSITION_PRICE_CURRENT);
      int type = (int)PositionGetInteger(POSITION_TYPE);
      double R = m_state.InitialRiskDistance(ticket, open, sl, m_market);
      if(R <= 0.0) return 0.0;
      double pd = (type == POSITION_TYPE_BUY) ? (cur - open) : (open - cur);
      return pd / R;
   }

   void Manage()
   {
      if(!Use_Progressive_Protection) return;
      double freezeLevel = SymbolInfoInteger(g_symbol, SYMBOL_TRADE_FREEZE_LEVEL) * g_point;
      double stopLevel   = SymbolInfoInteger(g_symbol, SYMBOL_TRADE_STOPS_LEVEL)  * g_point;
      double minStep     = PP_Min_Step_Points * g_point;
      double minDist     = MathMax(stopLevel, g_point);

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || PositionGetString(POSITION_SYMBOL) != g_symbol || !IsOurMagic(PositionGetInteger(POSITION_MAGIC))) continue;
         double open = PositionGetDouble(POSITION_PRICE_OPEN), sl = PositionGetDouble(POSITION_SL), tp = PositionGetDouble(POSITION_TP);
         double current = PositionGetDouble(POSITION_PRICE_CURRENT);
         int type = (int)PositionGetInteger(POSITION_TYPE);
         double R = m_state.InitialRiskDistance(ticket, open, sl, m_market);
         if(R <= 0.0) continue;
         double profit_dist = (type == POSITION_TYPE_BUY) ? (current - open) : (open - current);
         if(profit_dist <= 0.0) continue;
         double r_mult = profit_dist / R;
         double cand = 0.0; bool have = false;
         if(r_mult >= PP_Trail_Start_R)
         {
            double atr = m_market.ATR();
            if(type == POSITION_TYPE_BUY)
            {
               double at = current - atr * PP_Trail_ATR_Mult, st = m_market.TrailStructureLow(PP_Trail_Structure_Lookback);
               cand = (st > 0.0) ? MathMax(at, st) : at;
            }
            else
            {
               double at = current + atr * PP_Trail_ATR_Mult, st = m_market.TrailStructureHigh(PP_Trail_Structure_Lookback);
               cand = (st > 0.0) ? MathMin(at, st) : at;
            }
            have = true;
         }
         else if(r_mult >= PP_Stage3_R) { double lock = profit_dist * PP_Lock_Fraction; cand = (type == POSITION_TYPE_BUY) ? open + lock : open - lock; have = true; }
         else if(r_mult >= PP_Stage2_R) { double buf = PP_BE_Buffer_Points * g_point; cand = (type == POSITION_TYPE_BUY) ? open + buf : open - buf; have = true; }
         else if(r_mult >= PP_Stage1_R) { double red = R * PP_Stage1_SL_R; cand = (type == POSITION_TYPE_BUY) ? open - red : open + red; have = true; }
         if(!have) continue;

         bool improves = (sl == 0.0) || (type == POSITION_TYPE_BUY && cand > sl) || (type == POSITION_TYPE_SELL && cand < sl);
         if(!improves) continue;
         if(sl != 0.0 && MathAbs(cand - sl) < minStep) continue;
         if(type == POSITION_TYPE_BUY)
         {
            double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
            if(freezeLevel > 0.0 && sl != 0.0 && (bid - sl) < freezeLevel) continue;
            if(bid - cand < minDist) cand = bid - minDist;
            if(cand <= sl) continue;
         }
         else
         {
            double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
            if(freezeLevel > 0.0 && sl != 0.0 && (sl - ask) < freezeLevel) continue;
            if(cand - ask < minDist) cand = ask + minDist;
            if(sl != 0.0 && cand >= sl) continue;
         }
         if(m_exec.ModifySL(ticket, cand, tp)) m_mods++;
         else g_log.Warn("PP modify falló rc=" + IntegerToString(m_exec.LastRetcode()));
      }
   }
};

#endif
