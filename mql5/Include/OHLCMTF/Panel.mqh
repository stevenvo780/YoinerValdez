#ifndef OHLCMTF_PANEL_MQH
#define OHLCMTF_PANEL_MQH
#include <OHLCMTF/Context.mqh>

class CPanel
{
private:
   string m_arrows[];
   color  m_bg, m_fg;

   void Label(string sub, int x, int y, string text)
   {
      string name = PANEL_PREFIX + sub;
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetString (0, name, OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      }
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, Panel_Font_Size);
      ObjectSetString (0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, m_fg);
   }
   void Background(int x, int y, int w, int h)
   {
      string name = PANEL_PREFIX + "BG";
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      }
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, m_bg);
      ObjectSetInteger(0, name, OBJPROP_COLOR, m_fg);
   }
public:
   CPanel() : m_bg(clrBlack), m_fg(clrLime) { ArrayResize(m_arrows, 0); }
   void DeleteAll() { ObjectsDeleteAll(0, PANEL_PREFIX); }
   int  Arrows() { return ArraySize(m_arrows); }

   void DrawArrow(const SSignal &sig)
   {
      string name = "DOT_" + (sig.direction == 1 ? "B" : "S") + SetTag(sig.set_id) + "_" + TimeToString(sig.bar_time, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      if(!ObjectCreate(0, name, OBJ_ARROW, 0, sig.bar_time, sig.price)) return;
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, (sig.set_id == SET_CUSTOM ? 108 : 159));
      ObjectSetInteger(0, name, OBJPROP_COLOR, (sig.direction == 1 ? clrLime : clrRed));
      int n = ArraySize(m_arrows);
      ArrayResize(m_arrows, n + 1);
      m_arrows[n] = name;
      if(Max_Signal_Arrows > 0)
         while(ArraySize(m_arrows) > Max_Signal_Arrows)
         {
            ObjectDelete(0, m_arrows[0]);
            for(int i = 0; i < ArraySize(m_arrows) - 1; i++) m_arrows[i] = m_arrows[i + 1];
            ArrayResize(m_arrows, ArraySize(m_arrows) - 1);
         }
   }

   void Update()
   {
      if(!Panel_Show) { DeleteAll(); return; }
      string news_label = "";
      bool blocked = g_news.IsBlocked(news_label);
      double cur_sp = g_market.CurrentSpread() / g_point, avg_sp = g_market.AverageSpread() / g_point;
      int trend = g_market.StructureTrend(Trend_Timeframe, Trend_Lookback);
      string trend_str = (trend == 1) ? "ALCISTA ↑ (solo BUYs)" : (trend == -1) ? "BAJISTA ↓ (solo SELLs)" : ("SIN TENDENCIA → " + (Block_When_No_Trend ? "BLOQUEADO" : "permitido"));
      double balance = AccountInfoDouble(ACCOUNT_BALANCE), equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double float_dd = (balance > 0.0) ? (balance - equity) / balance * 100.0 : 0.0;
      string pos = "Sin posición abierta";
      if(g_state.cur.ticket != 0 && PositionSelectByTicket(g_state.cur.ticket))
         pos = ((int)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "BUY" : "SELL") + " [" + SetTag(g_state.cur.set_id) + "] | R = " + DoubleToString(g_posmgr.CurrentR(g_state.cur.ticket), 2);
      else if(g_exec.CountPendingOrders() > 0) pos = "Orden pendiente activa";

      string L[];
      ArrayResize(L, 90);
      int n = 0;
      L[n++] = "====== OHLCMTF SCALPER v" + OHLC_VERSION + " ======";
      L[n++] = "";
      L[n++] = g_guard.Latched() ? (">>> BLOQUEADO POR DRAWDOWN " + (DD_Pause_Hours > 0 ? "hasta " + TimeToString(g_guard.LatchedUntil(), TIME_DATE|TIME_MINUTES) : "(reset manual)") + " <<<")
             : (blocked ? (">>> BLOQUEADO POR NOTICIA: " + news_label + " <<<")
             : (g_guard.InPause() ? ">>> EN PAUSA POR RACHA <<<"
             : (g_guard.DailyHit() ? ">>> LÍMITE DIARIO ALCANZADO <<<" : ">>> ESTADO: OPERANDO <<<")));
      L[n++] = "";
      L[n++] = "--- SETS ---";
      L[n++] = "FIJO   H1/" + EnumToString(Trend_Timeframe) + "/D1: " + (Use_Fixed_Set ? "ON " : "OFF") + " | trades " + IntegerToString(g_stats.set_trades[SET_FIXED]) + " | P&L " + DoubleToString(g_stats.set_profit[SET_FIXED], 2);
      L[n++] = "CUSTOM " + EnumToString(TF_Fast) + "/" + EnumToString(TF_Slow) + ": " + (Use_Custom_Pair ? "ON " : "OFF") + " | trades " + IntegerToString(g_stats.set_trades[SET_CUSTOM]) + " | P&L " + DoubleToString(g_stats.set_profit[SET_CUSTOM], 2);
      L[n++] = "";
      L[n++] = "--- TENDENCIA ---";
      L[n++] = "Tendencia: " + trend_str + " (" + EnumToString(Trend_Timeframe) + ", " + IntegerToString(Trend_Lookback) + ")";
      L[n++] = "";
      L[n++] = "--- ENTRADAS ---";
      L[n++] = "Lookback " + IntegerToString(Structure_Lookback) + " | margen ATR " + DoubleToString(Min_Breakout_ATR_Mult, 2) + "-" + DoubleToString(Max_Breakout_ATR_Mult, 2) + " | body >= " + DoubleToString(Min_Body_Ratio, 2);
      L[n++] = "Fuerza mínima " + IntegerToString(Min_Signal_Strength) + "/" + IntegerToString(MAX_SIGNAL_STRENGTH) + " | ATR " + DoubleToString(g_market.ATR(), g_digits) + " (" + DoubleToString(g_market.ATRPct(), 3) + "%)";
      L[n++] = "SL = ATR x " + DoubleToString(ATR_SL_Multiplier, 1) + " | TP = ATR x " + DoubleToString(ATR_TP_Multiplier, 1);
      L[n++] = "";
      L[n++] = "--- RIESGO ---";
      L[n++] = "Rango " + DoubleToString(Min_Risk_Percent, 2) + "-" + DoubleToString(Max_Risk_Percent, 2) + "% (techo " + DoubleToString(Hard_Risk_Cap_Percent, 1) + "%)";
      L[n++] = "Último riesgo REAL: " + DoubleToString(g_risk.LastRiskPct(), 2) + "% ($" + DoubleToString(g_risk.LastRiskMoney(), 2) + ") | omitidas por lote mín: " + IntegerToString(g_risk.SkippedMinLot());
      L[n++] = "Posición: " + pos;
      L[n++] = "";
      L[n++] = "--- PROTECCIÓN PROGRESIVA ---";
      L[n++] = (Use_Progressive_Protection ? "ON" : "OFF") + " | R: reducir " + DoubleToString(PP_Stage1_R, 1) + " | BE " + DoubleToString(PP_Stage2_R, 1) + " | asegurar " + DoubleToString(PP_Stage3_R, 1) + " | trailing " + DoubleToString(PP_Trail_Start_R, 1) + " | mods " + IntegerToString(g_posmgr.Modifications());
      L[n++] = "";
      L[n++] = "--- SPREAD ---";
      L[n++] = "Actual " + DoubleToString(cur_sp, 1) + " pts | prom " + DoubleToString(avg_sp, 1) + " pts | techo " + (Max_Spread_Points > 0.0 ? DoubleToString(Max_Spread_Points, 1) : "off");
      if((Use_Avg_Spread_For_Mode ? avg_sp : cur_sp) > HighSpread_Threshold) L[n++] = ">>> MODO SPREAD ALTO <<<";
      L[n++] = "";
      L[n++] = "--- PROTECCIÓN DE CAPITAL ---";
      L[n++] = "Pérdida diaria: " + (Use_Daily_Loss_Limit ? DoubleToString(g_guard.DailyLossPct(), 2) + "% / " + DoubleToString(Max_Daily_Loss_Percent, 1) + "%" : "off");
      L[n++] = "Racha: " + IntegerToString(g_guard.Streak()) + " / " + IntegerToString(Max_Consecutive_Losses) + (g_guard.InPause() ? " [PAUSADO]" : "");
      L[n++] = "DD vs HWM: " + DoubleToString(g_guard.DDPct(), 2) + "% / " + (Use_Total_Drawdown_Limit ? DoubleToString(Max_Total_Drawdown_Pct, 1) + "%" : "off") + " | HWM " + DoubleToString(g_guard.HWM(), 2) + " | flotante " + DoubleToString(float_dd, 2) + "%";
      L[n++] = "Trades hoy: " + IntegerToString(g_guard.TradesToday()) + " / " + IntegerToString(Max_Trades_Per_Day);
      L[n++] = "";
      L[n++] = "--- NOTICIAS ---";
      L[n++] = g_news.LegacyLine("N1", News1_Enable, News1_Name, News1_Start_Hour, News1_Start_Min, News1_End_Hour, News1_End_Min);
      L[n++] = g_news.LegacyLine("N2", News2_Enable, News2_Name, News2_Start_Hour, News2_Start_Min, News2_End_Hour, News2_End_Min);
      L[n++] = g_news.LegacyLine("N3", News3_Enable, News3_Name, News3_Start_Hour, News3_Start_Min, News3_End_Hour, News3_End_Min);
      L[n++] = g_news.LegacyLine("N4", News4_Enable, News4_Name, News4_Start_Hour, News4_Start_Min, News4_End_Hour, News4_End_Min);
      L[n++] = "Calendario: " + (Use_Calendar_Filter ? IntegerToString(g_news.EventCount()) + " eventos " + Calendar_Currencies + " ±" + IntegerToString(Calendar_Block_Before_Min) + "/" + IntegerToString(Calendar_Block_After_Min) + " min" : "(off)");
      L[n++] = "";
      L[n++] = "--- ESTADÍSTICAS ---";
      L[n++] = "TP completo " + IntegerToString(g_stats.tp_full) + " | ganancia parcial " + IntegerToString(g_stats.gain_partial) + " | SL completo " + IntegerToString(g_stats.sl_full) + " | pérdida parcial " + IntegerToString(g_stats.loss_partial);
      L[n++] = "Flechas: " + IntegerToString(Arrows()) + " / " + (Max_Signal_Arrows > 0 ? IntegerToString(Max_Signal_Arrows) : "sin límite");
      ArrayResize(L, n);

      int line_h = Panel_Font_Size + 6, max_len = 0;
      for(int i = 0; i < n; i++) if(StringLen(L[i]) > max_len) max_len = StringLen(L[i]);
      Background(Panel_X - 10, Panel_Y - 10, max_len * (Panel_Font_Size - 1) + 24, n * line_h + 16);
      int y = Panel_Y;
      for(int i = 0; i < n; i++) { Label("L" + IntegerToString(i), Panel_X, y, L[i]); y += line_h; }
   }
};

#endif
