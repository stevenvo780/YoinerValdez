#ifndef OHLCMTF_RISK_MQH
#define OHLCMTF_RISK_MQH
#include <OHLCMTF/Market.mqh>

class CRiskManager
{
private:
   int    m_skipped_minlot;
   double m_last_pct;
   double m_last_money;
public:
   CRiskManager() : m_skipped_minlot(0), m_last_pct(0), m_last_money(0) {}
   int    SkippedMinLot() { return m_skipped_minlot; }
   double LastRiskPct()   { return m_last_pct; }
   double LastRiskMoney() { return m_last_money; }
   void   RecordLast(double pct, double money) { m_last_pct = pct; m_last_money = money; }

   double RiskBase()
   {
      double bal = AccountInfoDouble(ACCOUNT_BALANCE), eq = AccountInfoDouble(ACCOUNT_EQUITY);
      return Size_On_Equity ? MathMin(bal, eq) : bal;
   }

   double RiskPctForStrength(int strength, double &tp_mult_factor)
   {
      int min_str = MathMin(Min_Signal_Strength, MAX_SIGNAL_STRENGTH);
      double ratio = (MAX_SIGNAL_STRENGTH > min_str) ? (double)(strength - min_str) / (double)(MAX_SIGNAL_STRENGTH - min_str) : 0.0;
      ratio = MathMax(0.0, MathMin(1.0, ratio));
      tp_mult_factor = 1.0 + 0.35 * ratio;
      return Min_Risk_Percent + (Max_Risk_Percent - Min_Risk_Percent) * ratio;
   }

   double MoneyRiskPerLot(int type, double entry, double sl_dist)
   {
      double sl_price = (type == 1) ? entry - sl_dist : entry + sl_dist;
      double loss = 0.0;
      if(entry > 0.0 && sl_price > 0.0 &&
         OrderCalcProfit((type == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, g_symbol, 1.0, entry, sl_price, loss) && MathAbs(loss) > 0.0)
         return MathAbs(loss);
      return sl_dist * MoneyPerPriceUnitPerLot();
   }

   bool CalcVolume(int type, double entry, double sl_dist, double risk_pct, SSizing &out)
   {
      out.volume = 0; out.risk_money = 0; out.risk_pct = 0; out.skipped = true; out.reason = "";
      out.base = RiskBase();
      if(out.base <= 0.0 || sl_dist <= 0.0) { out.reason = "base/sl inválidos"; return false; }
      double mrpl = MoneyRiskPerLot(type, entry, sl_dist);
      if(mrpl <= 0.0) { out.reason = "riesgo por lote = 0"; return false; }
      double minVol = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN), maxVol = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MAX);
      double step = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_STEP);
      if(step <= 0.0) step = minVol;
      if(minVol <= 0.0 || step <= 0.0) { out.reason = "símbolo sin volumen mínimo"; return false; }

      double capAmt  = out.base * Hard_Risk_Cap_Percent / 100.0;
      double riskAmt = out.base * MathMin(risk_pct, Hard_Risk_Cap_Percent) / 100.0;
      double vol = MathFloor(riskAmt / mrpl / step + 1e-9) * step;
      if(vol < minVol)
      {
         double minRisk = minVol * mrpl;
         if(minRisk > capAmt && !Allow_MinLot_Above_Cap)
         {
            m_skipped_minlot++;
            out.risk_money = minRisk; out.risk_pct = minRisk / out.base * 100.0;
            out.reason = StringFormat("lote mínimo %.2f = %.2f%% > cap %.2f%% (SL %d pts)", minVol, out.risk_pct, Hard_Risk_Cap_Percent, (int)(sl_dist / g_point));
            return false;
         }
         if(minRisk > capAmt) g_log.Warn(StringFormat("lote mínimo por encima del cap permitido por input: %.2f%%", minRisk / out.base * 100.0));
         vol = minVol;
      }
      double capVol = MathFloor(capAmt / mrpl / step + 1e-9) * step;
      if(capVol >= minVol && vol > capVol) vol = capVol;
      if(vol > maxVol) vol = maxVol;
      double limit = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_LIMIT);
      if(limit > 0.0 && vol > limit) vol = MathFloor(limit / step) * step;
      if(vol < minVol) { out.reason = "volumen < mínimo tras límites"; return false; }

      double margin = 0.0;
      if(!OrderCalcMargin((type == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, g_symbol, vol, entry, margin) || margin <= 0.0)
      { out.reason = "OrderCalcMargin falló"; return false; }
      double free = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(margin > free * 0.80)
      {
         double adj = MathFloor(vol * (free * 0.80) / margin / step) * step;
         if(adj < minVol) { out.reason = "margen libre insuficiente"; return false; }
         vol = adj;
      }
      out.risk_money = vol * mrpl;
      out.risk_pct   = out.risk_money / out.base * 100.0;
      if(out.risk_money > capAmt + 1e-8 && !Allow_MinLot_Above_Cap)
      {
         m_skipped_minlot++;
         out.reason = StringFormat("riesgo real %.2f%% > cap %.2f%%", out.risk_pct, Hard_Risk_Cap_Percent);
         return false;
      }
      out.volume = vol; out.skipped = false; out.reason = "ok";
      return true;
   }

   void PrintMinLotDiagnostic(CMarket *market)
   {
      double minVol = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN);
      double mppu = MoneyPerPriceUnitPerLot();
      double base = RiskBase();
      if(mppu <= 0.0 || base <= 0.0) return;
      double atr = market.ATR();
      double sl = (atr > 0.0) ? atr * ATR_SL_Multiplier : Min_SL_Points * g_point;
      double risk = minVol * mppu * sl;
      double cap = base * Hard_Risk_Cap_Percent / 100.0;
      g_log.Info(StringFormat("[Lote mínimo] %.2f lot | SL típico=%s → riesgo=$%.2f = %.2f%% del capital (cap %.1f%% = $%.2f)",
                            minVol, DoubleToString(sl, g_digits), risk, risk / base * 100.0, Hard_Risk_Cap_Percent, cap));
      g_log.Info(StringFormat("[Lote mínimo] capital necesario para operar al %.2f%%: $%.0f", Max_Risk_Percent, risk / (Max_Risk_Percent / 100.0)));
      if(risk > cap) g_log.Warn("CUENTA INFRACAPITALIZADA: la mayoría de las señales se omitirán (Allow_MinLot_Above_Cap=false).");
   }
};

#endif
