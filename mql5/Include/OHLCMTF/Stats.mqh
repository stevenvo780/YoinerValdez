#ifndef OHLCMTF_STATS_MQH
#define OHLCMTF_STATS_MQH
#include <OHLCMTF/Logger.mqh>

class CTradeStats
{
public:
   int    tp_full, gain_partial, sl_full, loss_partial;
   double sum_tp_full, sum_gain_partial, sum_sl_full, sum_loss_partial;
   int    set_trades[2], set_wins[2];
   double set_profit[2];

   CTradeStats() : tp_full(0), gain_partial(0), sl_full(0), loss_partial(0), sum_tp_full(0), sum_gain_partial(0), sum_sl_full(0), sum_loss_partial(0)
   {
      ArrayInitialize(set_trades, 0); ArrayInitialize(set_wins, 0); ArrayInitialize(set_profit, 0.0);
   }
   int Total() { return tp_full + gain_partial + sl_full + loss_partial; }

   void OnEntry(int set_id) { set_trades[set_id]++; }

   void OnExit(double profit, double sl_money, double tp_money, int set_id)
   {
      set_profit[set_id] += profit;
      if(profit > 0.0)
      {
         set_wins[set_id]++;
         if(tp_money > 0.0 && profit >= 0.8 * tp_money) { tp_full++; sum_tp_full += profit; }
         else { gain_partial++; sum_gain_partial += profit; }
      }
      else
      {
         if(sl_money > 0.0 && MathAbs(profit) >= 0.8 * sl_money) { sl_full++; sum_sl_full += profit; }
         else { loss_partial++; sum_loss_partial += profit; }
      }
   }

   void PrintSummary(string title, int skipped_minlot, double hwm, double dd_pct, bool latched)
   {
      int total = Total();
      if(total <= 0) return;
      Print("===== ", title, " =====");
      Print("TP completo:      ", tp_full,      " (", DoubleToString(100.0*tp_full/total,1),      "%)  $=", DoubleToString(sum_tp_full,2));
      Print("Ganancia parcial: ", gain_partial, " (", DoubleToString(100.0*gain_partial/total,1), "%)  $=", DoubleToString(sum_gain_partial,2));
      Print("SL completo:      ", sl_full,      " (", DoubleToString(100.0*sl_full/total,1),      "%)  $=", DoubleToString(sum_sl_full,2));
      Print("Pérdida parcial:  ", loss_partial, " (", DoubleToString(100.0*loss_partial/total,1), "%)  $=", DoubleToString(sum_loss_partial,2));
      for(int s = 0; s < 2; s++)
         if(set_trades[s] > 0)
            Print("SET ", SetTag(s), ": trades=", set_trades[s], " ganadoras=", set_wins[s], " (", DoubleToString(100.0*set_wins[s]/set_trades[s],1), "%) P&L=", DoubleToString(set_profit[s],2));
      Print("Señales omitidas por lote mínimo > cap: ", skipped_minlot);
      Print("HWM: ", DoubleToString(hwm,2), " | DD vs HWM: ", DoubleToString(dd_pct,2), "%", (latched ? " | BLOQUEADO" : ""));
      Print("=================================");
   }
};

#endif
