#ifndef OHLCMTF_EXECUTION_MQH
#define OHLCMTF_EXECUTION_MQH
#include <Trade\Trade.mqh>
#include <OHLCMTF/Logger.mqh>

class CExecutor
{
private:
   CTrade m_trade;

   bool SendOK()
   {
      uint rc = m_trade.ResultRetcode();
      return (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED || rc == TRADE_RETCODE_DONE_PARTIAL);
   }
   void ExpirationMode(ENUM_ORDER_TYPE_TIME &mode, datetime &expiration)
   {
      long modes = SymbolInfoInteger(g_symbol, SYMBOL_EXPIRATION_MODE);
      mode = ORDER_TIME_GTC; expiration = 0;
      if((modes & SYMBOL_EXPIRATION_SPECIFIED) != 0) { mode = ORDER_TIME_SPECIFIED; expiration = TimeCurrent() + Limit_Expiration_Minutes * 60; }
      else if((modes & SYMBOL_EXPIRATION_SPECIFIED_DAY) != 0) { mode = ORDER_TIME_SPECIFIED_DAY; expiration = TimeCurrent() + Limit_Expiration_Minutes * 60; }
      else if((modes & SYMBOL_EXPIRATION_GTC) != 0)  mode = ORDER_TIME_GTC;
      else if((modes & SYMBOL_EXPIRATION_DAY) != 0)  mode = ORDER_TIME_DAY;
   }
public:
   void Init()
   {
      m_trade.SetExpertMagicNumber(MAGIC_FIXED);
      m_trade.SetDeviationInPoints(Slippage_Points);
      m_trade.SetTypeFillingBySymbol(g_symbol);
   }
   uint   LastRetcode()     { return m_trade.ResultRetcode(); }
   string LastRetcodeDesc() { return m_trade.ResultRetcodeDescription(); }

   int CountOpenPositions()
   {
      int n = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong t = PositionGetTicket(i);
         if(t == 0 || PositionGetString(POSITION_SYMBOL) != g_symbol || !IsOurMagic(PositionGetInteger(POSITION_MAGIC))) continue;
         n++;
      }
      return n;
   }
   int CountPendingOrders()
   {
      int n = 0;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong t = OrderGetTicket(i);
         if(t == 0 || !OrderSelect(t) || OrderGetString(ORDER_SYMBOL) != g_symbol || !IsOurMagic(OrderGetInteger(ORDER_MAGIC))) continue;
         n++;
      }
      return n;
   }
   bool HasExposure() { return (CountOpenPositions() > 0 || CountPendingOrders() > 0); }

   // entry/sl/tp devueltos ya normalizados; sl_dist/tp_dist en precio
   bool Open(const SSignal &sig, double vol, double sl_dist, double tp_dist, string comment, double &entry, double &sl, double &tp)
   {
      double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK), bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
      double stopLevel = SymbolInfoInteger(g_symbol, SYMBOL_TRADE_STOPS_LEVEL) * g_point;
      if(stopLevel <= 0.0) stopLevel = 10.0 * g_point;
      bool buy = (sig.direction == 1);
      m_trade.SetExpertMagicNumber(MagicForSet(sig.set_id));
      entry = buy ? ask : bid;
      bool sent = false;
      if(Use_Limit_Orders)
      {
         double price = NormalizeTradePrice(sig.price);
         bool limit_ok = buy ? (price < ask - stopLevel) : (price > bid + stopLevel);
         if(limit_ok)
         {
            ENUM_ORDER_TYPE_TIME mode; datetime exp;
            ExpirationMode(mode, exp);
            entry = price;
            sl = NormalizeTradePrice(buy ? price - sl_dist : price + sl_dist);
            tp = NormalizeTradePrice(buy ? price + tp_dist : price - tp_dist);
            sent = m_trade.OrderOpen(g_symbol, buy ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT, vol, 0.0, price, sl, tp, mode, exp, comment) && SendOK();
            return sent;
         }
      }
      sl = NormalizeTradePrice(buy ? entry - sl_dist : entry + sl_dist);
      tp = NormalizeTradePrice(buy ? entry + tp_dist : entry - tp_dist);
      sent = m_trade.PositionOpen(g_symbol, buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, vol, entry, sl, tp, comment) && SendOK();
      return sent;
   }

   bool ModifySL(ulong ticket, double sl, double tp)
   {
      return m_trade.PositionModify(ticket, NormalizeTradePrice(sl), tp) && SendOK();
   }

   void FlattenAll(string reason)
   {
      for(int attempt = 0; attempt < 3; attempt++)
      {
         bool remaining = false;
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong t = PositionGetTicket(i);
            if(t == 0 || PositionGetString(POSITION_SYMBOL) != g_symbol || !IsOurMagic(PositionGetInteger(POSITION_MAGIC))) continue;
            m_trade.SetExpertMagicNumber((ulong)PositionGetInteger(POSITION_MAGIC));
            if(!m_trade.PositionClose(t, (ulong)(Slippage_Points * 3)) || !SendOK())
            {
               remaining = true;
               g_log.Error("FLATTEN(" + reason + "): fallo al cerrar #" + IntegerToString((long)t) + " rc=" + IntegerToString(m_trade.ResultRetcode()) + " " + m_trade.ResultRetcodeDescription());
            }
            else g_log.Info("FLATTEN(" + reason + "): cerrada #" + IntegerToString((long)t));
         }
         for(int i = OrdersTotal() - 1; i >= 0; i--)
         {
            ulong t = OrderGetTicket(i);
            if(t == 0 || !OrderSelect(t) || OrderGetString(ORDER_SYMBOL) != g_symbol || !IsOurMagic(OrderGetInteger(ORDER_MAGIC))) continue;
            if(!m_trade.OrderDelete(t) || !SendOK()) remaining = true;
            else g_log.Info("FLATTEN(" + reason + "): pendiente #" + IntegerToString((long)t) + " eliminada");
         }
         if(!remaining) remaining = HasExposure();   // cierres parciales dejan volumen residual
         if(!remaining) break;
         Sleep(300);
      }
      if(HasExposure()) g_log.Error("FLATTEN(" + reason + "): queda exposición tras 3 intentos; se reintentará en el próximo tick");
   }

   void CleanupStalePending()
   {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong t = OrderGetTicket(i);
         if(t == 0 || !OrderSelect(t) || OrderGetString(ORDER_SYMBOL) != g_symbol || !IsOurMagic(OrderGetInteger(ORDER_MAGIC))) continue;
         datetime setup = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
         if(TimeCurrent() - setup > Limit_Expiration_Minutes * 60) m_trade.OrderDelete(t);
      }
   }
};

#endif
