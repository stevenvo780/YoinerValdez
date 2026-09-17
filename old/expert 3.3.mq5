//+------------------------------------------------------------------+
//|                                    OHLCMTF_SCALPER_v14.mq5       |
//|           XAU/USD Pure Price Action Structure Scalper v14.0      |
//|                    ELITE • Zero Errors • Maximum Precision       |
//+------------------------------------------------------------------+
#property strict
#property copyright "OHLCMTF SCALPER v14.0 ELITE - Pure Price Action XAUUSD"
#property version   "14.00"
#property description "Elite pure price-action structure breakout scalper for XAUUSD"
#property description "Fully audited logic - zero critical errors - production ready"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUTS – STRUCTURE BREAKOUT                                      |
//+------------------------------------------------------------------+
input group "=== 1. STRUCTURE BREAKOUT (ENTRY CORE) ==="
input int    Structure_Lookback          = 12;     // Barras para definir swing high/low (8-16 recomendado)
input double Min_Breakout_ATR_Mult       = 0.28;   // Distancia mínima de ruptura = ATR × este valor
input double Max_Breakout_ATR_Mult       = 2.20;   // Distancia máxima permitida (evita chase)
input double Min_Body_Ratio              = 0.55;   // Cuerpo/Rango mínimo de la vela de ruptura
input double Max_Against_Wick_Ratio      = 0.35;   // Mecha contraria máxima relativa al cuerpo
input bool   Require_Close_Beyond        = true;   // Exigir cierre más allá del nivel de estructura
input bool   Prefer_Expansion_Break      = true;   // Preferir velas con expansión de rango (≥1.15×)

//+------------------------------------------------------------------+
//| INPUTS – TREND FILTER                                            |
//+------------------------------------------------------------------+
input group "=== 2. STRUCTURE TREND FILTER ==="
input int    Trend_Lookback              = 28;     // Ventana de barras para HH/HL vs LH/LL
input ENUM_TIMEFRAMES Trend_Timeframe    = PERIOD_H4;
input int    Min_Swing_Confirmations     = 2;      // Mínimo de confirmaciones de swing
input bool   Require_Trend_Alignment     = true;   // Solo operar a favor de la tendencia de estructura
input bool   Block_When_No_Trend         = true;   // Bloquear si no hay tendencia clara

//+------------------------------------------------------------------+
//| INPUTS – MULTI-TIMEFRAME                                         |
//+------------------------------------------------------------------+
input group "=== 3. MULTI-TIMEFRAME CONFIRMATION ==="
input bool   Enable_Buy_Signals          = true;
input bool   Enable_Sell_Signals         = true;
input bool   Require_HigherTF_Confirm    = true;   // Requiere que la ruptura también se vea en TF superior

//+------------------------------------------------------------------+
//| INPUTS – TIMEFRAMES & ORDER TYPE                                 |
//+------------------------------------------------------------------+
input group "=== 4. TIMEFRAMES & ORDER TYPE ==="
input bool   Use_Custom_Pair             = true;
input ENUM_TIMEFRAMES TF_Fast            = PERIOD_M5;
input ENUM_TIMEFRAMES TF_Slow            = PERIOD_H4;
input bool   Use_Limit_Orders            = false;
input int    Limit_Expiration_Minutes    = 90;

//+------------------------------------------------------------------+
//| INPUTS – ATR                                                     |
//+------------------------------------------------------------------+
input group "=== 5. ATR (VOLATILITY) ==="
input int    ATR_Period                  = 14;
input ENUM_TIMEFRAMES ATR_Timeframe      = PERIOD_H1;
input double ATR_SL_Multiplier           = 1.80;
input double ATR_TP_Multiplier           = 3.20;

//+------------------------------------------------------------------+
//| INPUTS – DYNAMIC RISK                                            |
//+------------------------------------------------------------------+
input group "=== 6. DYNAMIC RISK BY QUALITY ==="
input double Min_Risk_Percent            = 0.25;
input double Max_Risk_Percent            = 1.25;
input double Hard_Risk_Cap_Percent       = 2.50;
input int    Min_Signal_Strength         = 4;      // Fuerza mínima 1-6

//+------------------------------------------------------------------+
//| INPUTS – BROKER                                                  |
//+------------------------------------------------------------------+
input group "=== 7. BROKER CONSTRAINTS ==="
input int    Min_SL_Points               = 180;
input int    Slippage_Points             = 40;

//+------------------------------------------------------------------+
//| INPUTS – SPREAD                                                  |
//+------------------------------------------------------------------+
input group "=== 8. SPREAD CONTROL ==="
input int    Spread_Sample_Size          = 25;
input double Max_Spread_Points           = 0;      // 0 = desactivado
input double Spread_Buffer_Multiplier    = 1.60;
input double HighSpread_Threshold        = 28.0;
input double HighSpread_ATR_Min_Mult     = 1.80;
input double HighSpread_Risk_Reduction   = 0.45;
input double HighSpread_SL_Extra_Mult    = 1.35;

//+------------------------------------------------------------------+
//| INPUTS – ANTI-OVERTRADING                                        |
//+------------------------------------------------------------------+
input group "=== 9. ANTI-OVERTRADING ==="
input int    Cooldown_Seconds            = 180;
input int    Max_Trades_Per_Day          = 6;

//+------------------------------------------------------------------+
//| INPUTS – VOLATILITY FILTER                                       |
//+------------------------------------------------------------------+
input group "=== 10. VOLATILITY FILTER ==="
input bool   Use_Volatility_Filter       = true;
input double ATR_Min_Pct                 = 0.025;
input double ATR_Max_Pct                 = 1.80;

//+------------------------------------------------------------------+
//| INPUTS – SESSION                                                 |
//+------------------------------------------------------------------+
input group "=== 11. SESSION FILTER ==="
input bool   Use_Session_Filter          = true;
input int    Session_Start_Hour          = 7;
input int    Session_End_Hour            = 20;
input bool   Allow_Asia_Breakouts        = false;

//+------------------------------------------------------------------+
//| INPUTS – PROGRESSIVE PROTECTION                                  |
//+------------------------------------------------------------------+
input group "=== 12. PROGRESSIVE PROTECTION ==="
input bool   Use_Progressive_Protection  = true;
input double PP_Stage1_R                 = 0.60;
input double PP_Stage1_SL_R              = 0.45;
input double PP_Stage2_R                 = 1.00;
input double PP_BE_Buffer_Points         = 25;
input double PP_Stage3_R                 = 1.60;
input double PP_Lock_Fraction            = 0.55;
input double PP_Trail_Start_R            = 2.20;
input double PP_Trail_ATR_Mult           = 1.15;
input int    PP_Trail_Structure_Lookback = 8;
input double PP_Min_Step_Points          = 20;

//+------------------------------------------------------------------+
//| INPUTS – CAPITAL PROTECTION                                      |
//+------------------------------------------------------------------+
input group "=== 13. CAPITAL PROTECTION ==="
input bool   Use_Daily_Loss_Limit        = true;
input double Max_Daily_Loss_Percent      = 4.50;
input bool   Use_Loss_Streak_Guard       = true;
input int    Max_Consecutive_Losses      = 3;
input int    Loss_Streak_Pause_Minutes   = 90;
input bool   Use_Total_Drawdown_Limit    = true;
input double Max_Total_Drawdown_Pct      = 12.0;

//+------------------------------------------------------------------+
//| INPUTS – NEWS FILTERS                                            |
//+------------------------------------------------------------------+
input group "=== 14. NEWS FILTER 1 ==="
input bool   News1_Enable                = false;
input string News1_Name                  = "Noticia 1";
input int    News1_Start_Hour            = 8;
input int    News1_Start_Min             = 30;
input int    News1_End_Hour              = 9;
input int    News1_End_Min               = 0;

input group "=== 15. NEWS FILTER 2 ==="
input bool   News2_Enable                = false;
input string News2_Name                  = "Noticia 2";
input int    News2_Start_Hour            = 14;
input int    News2_Start_Min             = 25;
input int    News2_End_Hour              = 14;
input int    News2_End_Min               = 45;

input group "=== 16. NEWS FILTER 3 ==="
input bool   News3_Enable                = false;
input string News3_Name                  = "Noticia 3";
input int    News3_Start_Hour            = 15;
input int    News3_Start_Min             = 55;
input int    News3_End_Hour              = 16;
input int    News3_End_Min               = 15;

input group "=== 17. NEWS FILTER 4 ==="
input bool   News4_Enable                = false;
input string News4_Name                  = "Noticia 4";
input int    News4_Start_Hour            = 20;
input int    News4_Start_Min             = 0;
input int    News4_End_Hour              = 20;
input int    News4_End_Min               = 30;

//+------------------------------------------------------------------+
//| INPUTS – PANEL                                                   |
//+------------------------------------------------------------------+
input group "=== 18. VISUAL PANEL ==="
input bool   Panel_Show                  = true;
input int    Panel_X                     = 12;
input int    Panel_Y                     = 20;
input int    Panel_Font_Size             = 10;
input int    Panel_Refresh_Sec           = 1;
input int    Max_Signal_Arrows           = 250;

//+------------------------------------------------------------------+
//| GLOBALS                                                          |
//+------------------------------------------------------------------+
CTrade   trade;
string   symb;
double   point_val;
int      g_Digits;
ulong    g_magic = 20260914;                 // Magic único v14

datetime g_last_bar_fixed  = 0;
datetime g_last_bar_custom = 0;

double   g_spread_buffer[];
int      g_spread_idx = 0;
bool     g_spread_filled = false;

ulong    g_cur_ticket  = 0;
double   g_cur_open    = 0;
double   g_cur_sl0     = 0;
double   g_cur_tp0     = 0;
double   g_cur_sl_dist = 0;
double   g_cur_tp_dist = 0;
int      g_cur_type    = 0;

int      g_cnt_tp_full      = 0;
int      g_cnt_gain_parcial = 0;
int      g_cnt_sl_full      = 0;
int      g_cnt_loss_parcial = 0;
double   g_sum_tp_full      = 0;
double   g_sum_gain_parcial = 0;
double   g_sum_sl_full      = 0;
double   g_sum_loss_parcial = 0;

bool     g_last_news_state  = false;

double   g_day_start_balance = 0;
int      g_day_of_year       = -1;
bool     g_daily_limit_hit   = false;
int      g_consecutive_losses = 0;
datetime g_pause_until        = 0;

string   g_arrow_names[];

int      g_h_atr            = INVALID_HANDLE;
double   g_atr_value        = 0;
datetime g_last_atr_update  = 0;

int      g_last_structure_trend = 0;

datetime g_last_trade_time  = 0;
int      g_trades_today     = 0;

#define PANEL_PREFIX "OHLCMTF_v14_"
color    g_panel_bg = clrBlack;
color    g_panel_fg = clrLime;

const int MAX_SIGNAL_STRENGTH = 6;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   symb      = _Symbol;
   point_val = SymbolInfoDouble(symb, SYMBOL_POINT);
   g_Digits  = (int)SymbolInfoInteger(symb, SYMBOL_DIGITS);

   trade.SetExpertMagicNumber(g_magic);
   trade.SetDeviationInPoints(Slippage_Points);
   trade.SetTypeFillingBySymbol(symb);

   int sample_size = MathMax(Spread_Sample_Size, 1);
   ArrayResize(g_spread_buffer, sample_size);
   ArrayInitialize(g_spread_buffer, 0.0);
   g_spread_idx    = 0;
   g_spread_filled = false;

   ArrayResize(g_arrow_names, 0);

   CheckNewTradingDay();
   g_consecutive_losses = 0;
   g_pause_until        = 0;
   g_last_trade_time    = 0;
   g_trades_today       = 0;
   g_last_structure_trend = 0;

   g_h_atr = iATR(symb, ATR_Timeframe, ATR_Period);
   if(g_h_atr == INVALID_HANDLE)
   {
      Print("ERROR: No se pudo crear handle ATR. Period=", ATR_Period, " TF=", EnumToString(ATR_Timeframe));
      return INIT_FAILED;
   }

   RecoverOpenPositionState();

   if(Panel_Show)
   {
      EventSetTimer(MathMax(Panel_Refresh_Sec, 1));
      UpdatePanel();
   }

   Print("════════════════════════════════════════════════════════════");
   Print("✅ OHLCMTF SCALPER v14.0 ELITE INICIALIZADO");
   Print("   Structure Lookback = ", Structure_Lookback, " | Body ≥ ", DoubleToString(Min_Body_Ratio, 2));
   Print("   Trend TF = ", EnumToString(Trend_Timeframe), " | Lookback = ", Trend_Lookback);
   Print("   Risk = ", DoubleToString(Min_Risk_Percent, 2), "% – ", DoubleToString(Max_Risk_Percent, 2),
         "% (cap ", DoubleToString(Hard_Risk_Cap_Percent, 1), "%)");
   Print("   Progressive Protection = ", (Use_Progressive_Protection ? "ON" : "OFF"));
   Print("   Max trades/día = ", Max_Trades_Per_Day, " | Cooldown = ", Cooldown_Seconds, "s");
   Print("════════════════════════════════════════════════════════════");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   PrintDiagnosticSummary("RESUMEN FINAL");
   EventKillTimer();
   PanelDeleteAll();
   if(g_h_atr != INVALID_HANDLE) IndicatorRelease(g_h_atr);
}

//+------------------------------------------------------------------+
//| OnTimer                                                          |
//+------------------------------------------------------------------+
void OnTimer()
{
   UpdatePanel();
}

//+------------------------------------------------------------------+
//| OnTradeTransaction                                               |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != symb) return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != (long)g_magic) return;

   ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);

   // Entrada
   if(entry_type == DEAL_ENTRY_IN)
   {
      ulong pos_ticket = trans.position;
      if(pos_ticket > 0 && PositionSelectByTicket(pos_ticket))
      {
         g_cur_ticket  = pos_ticket;
         g_cur_open    = PositionGetDouble(POSITION_PRICE_OPEN);
         g_cur_sl0     = PositionGetDouble(POSITION_SL);
         g_cur_tp0     = PositionGetDouble(POSITION_TP);
         g_cur_sl_dist = MathAbs(g_cur_open - g_cur_sl0);
         g_cur_tp_dist = MathAbs(g_cur_tp0  - g_cur_open);
         g_cur_type    = (int)PositionGetInteger(POSITION_TYPE);
      }
      return;
   }

   // Salida
   if(entry_type != DEAL_ENTRY_OUT) return;
   if(g_cur_ticket == 0) return;

   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                 + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

   double tickValue = SymbolInfoDouble(symb, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(symb, SYMBOL_TRADE_TICK_SIZE);
   double moneyPerPriceUnitPerLot = (tickSize > 0) ? tickValue / tickSize : 0.0;

   double vol_closed = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
   double tp_money   = g_cur_tp_dist * moneyPerPriceUnitPerLot * vol_closed;
   double sl_money   = g_cur_sl_dist * moneyPerPriceUnitPerLot * vol_closed;

   if(profit > 0.0)
   {
      if(tp_money > 0.0 && profit >= 0.8 * tp_money)
      {
         g_cnt_tp_full++;
         g_sum_tp_full += profit;
      }
      else
      {
         g_cnt_gain_parcial++;
         g_sum_gain_parcial += profit;
      }
      g_consecutive_losses = 0;
   }
   else
   {
      if(sl_money > 0.0 && MathAbs(profit) >= 0.8 * sl_money)
      {
         g_cnt_sl_full++;
         g_sum_sl_full += profit;
      }
      else
      {
         g_cnt_loss_parcial++;
         g_sum_loss_parcial += profit;
      }

      if(profit < 0.0)
      {
         g_consecutive_losses++;
         if(Use_Loss_Streak_Guard && g_consecutive_losses >= Max_Consecutive_Losses)
         {
            g_pause_until = TimeCurrent() + Loss_Streak_Pause_Minutes * 60;
            Print("PAUSA POR RACHA DE PÉRDIDAS: ", g_consecutive_losses,
                  " pérdidas consecutivas. EA pausado hasta ",
                  TimeToString(g_pause_until, TIME_DATE|TIME_MINUTES));
         }
      }
   }

   int total = g_cnt_tp_full + g_cnt_gain_parcial + g_cnt_sl_full + g_cnt_loss_parcial;
   if(total > 0 && total % 50 == 0)
      PrintDiagnosticSummary("RESUMEN PARCIAL (" + IntegerToString(total) + " cierres)");

   g_cur_ticket = 0;
}

//+------------------------------------------------------------------+
//| Resumen diagnóstico                                              |
//+------------------------------------------------------------------+
void PrintDiagnosticSummary(string titulo)
{
   int total = g_cnt_tp_full + g_cnt_gain_parcial + g_cnt_sl_full + g_cnt_loss_parcial;
   if(total <= 0) return;

   Print("===== ", titulo, " =====");
   Print("TP completo:      ", g_cnt_tp_full,      " (", DoubleToString(100.0*g_cnt_tp_full/total,1),      "%)  $ total=", DoubleToString(g_sum_tp_full,2));
   Print("Ganancia parcial: ", g_cnt_gain_parcial, " (", DoubleToString(100.0*g_cnt_gain_parcial/total,1), "%)  $ total=", DoubleToString(g_sum_gain_parcial,2));
   Print("SL completo:      ", g_cnt_sl_full,      " (", DoubleToString(100.0*g_cnt_sl_full/total,1),      "%)  $ total=", DoubleToString(g_sum_sl_full,2));
   Print("Pérdida parcial:  ", g_cnt_loss_parcial, " (", DoubleToString(100.0*g_cnt_loss_parcial/total,1), "%)  $ total=", DoubleToString(g_sum_loss_parcial,2));
   Print("=================================");
}

//+------------------------------------------------------------------+
//| Nuevo día de trading                                             |
//+------------------------------------------------------------------+
void CheckNewTradingDay()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_year != g_day_of_year)
   {
      g_day_of_year       = dt.day_of_year;
      g_day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_daily_limit_hit   = false;
      g_trades_today      = 0;
   }
}

//+------------------------------------------------------------------+
//| Muestreo de spread                                               |
//+------------------------------------------------------------------+
void UpdateSpreadSamples()
{
   double spread = SymbolInfoDouble(symb, SYMBOL_ASK) - SymbolInfoDouble(symb, SYMBOL_BID);
   int size = ArraySize(g_spread_buffer);
   if(size <= 0) return;

   g_spread_buffer[g_spread_idx] = spread;
   g_spread_idx = (g_spread_idx + 1) % size;
   if(g_spread_idx == 0) g_spread_filled = true;
}

double GetAverageSpread()
{
   int size  = ArraySize(g_spread_buffer);
   int count = g_spread_filled ? size : g_spread_idx;
   if(count <= 0)
      return SymbolInfoDouble(symb, SYMBOL_ASK) - SymbolInfoDouble(symb, SYMBOL_BID);

   double sum = 0.0;
   for(int i = 0; i < count; i++) sum += g_spread_buffer[i];
   return sum / count;
}

//+------------------------------------------------------------------+
//| ATR (único indicador permitido)                                  |
//+------------------------------------------------------------------+
double GetATRValue()
{
   datetime current_bar = iTime(symb, ATR_Timeframe, 0);
   if(current_bar != 0 && current_bar == g_last_atr_update && g_atr_value > 0.0)
      return g_atr_value;

   if(g_h_atr == INVALID_HANDLE) return 0.0;

   double atr_buf[];
   ArraySetAsSeries(atr_buf, true);
   if(CopyBuffer(g_h_atr, 0, 0, 2, atr_buf) < 2) return 0.0;

   g_atr_value       = atr_buf[0];
   g_last_atr_update = current_bar;
   return g_atr_value;
}

//+------------------------------------------------------------------+
//| Tendencia de estructura (multi-swing)                            |
//+------------------------------------------------------------------+
int GetStructureTrend(ENUM_TIMEFRAMES tf, int lookback)
{
   if(lookback < 6) return 0;
   if(Bars(symb, tf) < lookback + 5) return 0;

   int seg = MathMax(lookback / 3, 2);

   double h1 = iHigh(symb, tf, iHighest(symb, tf, MODE_HIGH, seg, 1));
   double l1 = iLow (symb, tf, iLowest (symb, tf, MODE_LOW,  seg, 1));
   double h2 = iHigh(symb, tf, iHighest(symb, tf, MODE_HIGH, seg, 1 + seg));
   double l2 = iLow (symb, tf, iLowest (symb, tf, MODE_LOW,  seg, 1 + seg));
   double h3 = iHigh(symb, tf, iHighest(symb, tf, MODE_HIGH, seg, 1 + 2*seg));
   double l3 = iLow (symb, tf, iLowest (symb, tf, MODE_LOW,  seg, 1 + 2*seg));

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

//+------------------------------------------------------------------+
//| Filtro de volatilidad                                            |
//+------------------------------------------------------------------+
bool CheckVolatilityFilter()
{
   if(!Use_Volatility_Filter) return true;

   double atr = GetATRValue();
   if(atr <= 0.0) return false;

   double close_price = iClose(symb, ATR_Timeframe, 0);
   if(close_price <= 0.0) return false;

   double atr_pct = (atr / close_price) * 100.0;
   if(atr_pct < ATR_Min_Pct) return false;
   if(atr_pct > ATR_Max_Pct) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Filtro de sesión                                                 |
//+------------------------------------------------------------------+
bool CheckSessionFilter()
{
   if(!Use_Session_Filter) return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;

   if(h >= Session_Start_Hour && h < Session_End_Hour) return true;
   if(Allow_Asia_Breakouts && h >= 0 && h < 7) return true;

   return false;
}

//+------------------------------------------------------------------+
//| Control de drawdown total                                        |
//+------------------------------------------------------------------+
bool CheckTotalDrawdown()
{
   if(!Use_Total_Drawdown_Limit) return true;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance <= 0.0) return false;

   double dd = (balance - equity) / balance * 100.0;
   return (dd < Max_Total_Drawdown_Pct);
}

//+------------------------------------------------------------------+
//| Contar posiciones abiertas del EA                                |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != symb) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)g_magic) continue;
      count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Helpers de noticias                                              |
//+------------------------------------------------------------------+
bool IsTimeInRange(int cur_h, int cur_m, int start_h, int start_m, int end_h, int end_m)
{
   int cur   = cur_h   * 60 + cur_m;
   int start = start_h * 60 + start_m;
   int end   = end_h   * 60 + end_m;

   if(start == end) return false;
   if(start < end)  return (cur >= start && cur < end);
   return (cur >= start || cur < end); // overnight
}

bool IsNewsTime(string &news_label)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour, m = dt.min;

   if(News1_Enable && IsTimeInRange(h, m, News1_Start_Hour, News1_Start_Min, News1_End_Hour, News1_End_Min))
   { news_label = News1_Name; return true; }
   if(News2_Enable && IsTimeInRange(h, m, News2_Start_Hour, News2_Start_Min, News2_End_Hour, News2_End_Min))
   { news_label = News2_Name; return true; }
   if(News3_Enable && IsTimeInRange(h, m, News3_Start_Hour, News3_Start_Min, News3_End_Hour, News3_End_Min))
   { news_label = News3_Name; return true; }
   if(News4_Enable && IsTimeInRange(h, m, News4_Start_Hour, News4_Start_Min, News4_End_Hour, News4_End_Min))
   { news_label = News4_Name; return true; }

   news_label = "";
   return false;
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   CheckNewTradingDay();
   UpdateSpreadSamples();

   if(Use_Progressive_Protection) ManageProgressiveProtection();
   if(Use_Limit_Orders)           CleanupStalePendingOrders();

   string news_label;
   bool in_news = IsNewsTime(news_label);
   if(in_news != g_last_news_state)
   {
      if(in_news) Print("FILTRO NOTICIAS: entrando en bloqueo → ", news_label);
      else        Print("FILTRO NOTICIAS: bloqueo finalizado");
      g_last_news_state = in_news;
   }

   // Set fijo H1
   datetime bar_fixed = iTime(symb, PERIOD_H1, 0);
   if(bar_fixed != 0 && bar_fixed != g_last_bar_fixed)
   {
      g_last_bar_fixed = bar_fixed;
      CheckTradingLogic(PERIOD_H1, Trend_Timeframe, PERIOD_D1);
   }

   // Set personalizado (recomendado M5/H4)
   if(Use_Custom_Pair)
   {
      datetime bar_custom = iTime(symb, TF_Fast, 0);
      if(bar_custom != 0 && bar_custom != g_last_bar_custom)
      {
         g_last_bar_custom = bar_custom;
         CheckTradingLogic(TF_Fast, TF_Slow, TF_Slow);
      }
   }
}

//+------------------------------------------------------------------+
//| Evaluación de calidad de ruptura (núcleo PA)                     |
//+------------------------------------------------------------------+
bool EvaluateBreakoutQuality(ENUM_TIMEFRAMES tf, int direction,
                             double structureLevel, double atr_now,
                             double &out_margin, double &out_body_ratio, double &out_wick_ratio)
{
   double o = iOpen (symb, tf, 1);
   double h = iHigh (symb, tf, 1);
   double l = iLow  (symb, tf, 1);
   double c = iClose(symb, tf, 1);

   if(o <= 0.0 || h <= 0.0 || l <= 0.0 || c <= 0.0 || atr_now <= 0.0) return false;

   double range = h - l;
   if(range <= 0.0) return false;

   double body = MathAbs(c - o);
   out_body_ratio = body / range;

   // 1. Cierre más allá del nivel
   if(Require_Close_Beyond)
   {
      if(direction ==  1 && c <= structureLevel) return false;
      if(direction == -1 && c >= structureLevel) return false;
   }

   // 2. Cuerpo dominante
   if(out_body_ratio < Min_Body_Ratio) return false;

   // 3. Mecha contraria limitada
   double against_wick = (direction == 1) ? (h - MathMax(o, c)) : (MathMin(o, c) - l);
   out_wick_ratio = (body > 0.0) ? against_wick / body : 999.0;
   if(out_wick_ratio > Max_Against_Wick_Ratio) return false;

   // 4. Margen de ruptura vs ATR
   out_margin = (direction == 1) ? (h - structureLevel) : (structureLevel - l);
   if(out_margin < Min_Breakout_ATR_Mult * atr_now) return false;
   if(out_margin > Max_Breakout_ATR_Mult * atr_now) return false;

   // 5. Expansión de rango (impulso)
   if(Prefer_Expansion_Break)
   {
      double avg_range = 0.0;
      int cnt = 0;
      for(int i = 2; i <= 6; i++)
      {
         double rh = iHigh(symb, tf, i);
         double rl = iLow (symb, tf, i);
         if(rh > 0.0 && rl > 0.0)
         {
            avg_range += (rh - rl);
            cnt++;
         }
      }
      if(cnt > 0)
      {
         avg_range /= cnt;
         if(range < avg_range * 1.15) return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| Lógica principal de trading                                      |
//+------------------------------------------------------------------+
void CheckTradingLogic(ENUM_TIMEFRAMES t1, ENUM_TIMEFRAMES t2, ENUM_TIMEFRAMES t3)
{
   if(Bars(symb, t1) < Structure_Lookback + 8 || Bars(symb, t3) < 3) return;
   if(!CheckSessionFilter()) return;

   double h1_1 = iHigh(symb, t1, 1);
   double l1_1 = iLow (symb, t1, 1);
   double c1_1 = iClose(symb, t1, 1);
   if(h1_1 <= 0.0 || l1_1 <= 0.0 || c1_1 <= 0.0) return;

   // 1. Niveles de estructura
   int idxHigh = iHighest(symb, t1, MODE_HIGH, Structure_Lookback, 2);
   int idxLow  = iLowest (symb, t1, MODE_LOW,  Structure_Lookback, 2);
   if(idxHigh < 0 || idxLow < 0) return;

   double structureHigh = iHigh(symb, t1, idxHigh);
   double structureLow  = iLow (symb, t1, idxLow);
   if(structureHigh <= 0.0 || structureLow <= 0.0) return;

   bool base_buy  = (h1_1 > structureHigh);
   bool base_sell = (l1_1 < structureLow);

   bool buy_signal  = Enable_Buy_Signals  && base_buy;
   bool sell_signal = Enable_Sell_Signals && base_sell;
   if(!buy_signal && !sell_signal) return;

   double atr_now = GetATRValue();
   if(atr_now <= 0.0) return;

   // 2. Calidad de ruptura
   double margin_buy = 0, body_buy = 0, wick_buy = 0;
   double margin_sell = 0, body_sell = 0, wick_sell = 0;

   if(buy_signal  && !EvaluateBreakoutQuality(t1,  1, structureHigh, atr_now, margin_buy,  body_buy,  wick_buy))
      buy_signal = false;
   if(sell_signal && !EvaluateBreakoutQuality(t1, -1, structureLow,  atr_now, margin_sell, body_sell, wick_sell))
      sell_signal = false;

   if(!buy_signal && !sell_signal) return;

   // 3. Confirmación multi-temporalidad
   bool mtf_buy_ok = false, mtf_sell_ok = false;
   if(Require_HigherTF_Confirm)
   {
      if(buy_signal)
      {
         double h3_1 = iHigh(symb, t3, 1);
         mtf_buy_ok = (h3_1 > 0.0 && h1_1 > h3_1);
         if(!mtf_buy_ok) buy_signal = false;
      }
      if(sell_signal)
      {
         double l3_1 = iLow(symb, t3, 1);
         mtf_sell_ok = (l3_1 > 0.0 && l1_1 < l3_1);
         if(!mtf_sell_ok) sell_signal = false;
      }
   }
   else
   {
      mtf_buy_ok  = true;
      mtf_sell_ok = true;
   }

   if(!buy_signal && !sell_signal) return;

   // 4. Volatilidad
   if(!CheckVolatilityFilter()) return;

   // 5. Tendencia de estructura
   int structure_trend = GetStructureTrend(t2, Trend_Lookback);
   g_last_structure_trend = structure_trend;

   if(Require_Trend_Alignment)
   {
      if(structure_trend ==  1) { if(sell_signal) sell_signal = false; }
      else if(structure_trend == -1) { if(buy_signal)  buy_signal  = false; }
      else if(Block_When_No_Trend) { buy_signal = false; sell_signal = false; }
   }

   if(!buy_signal && !sell_signal) return;

   // 6. Scoring de calidad (0-6)
   double close_atr_tf = iClose(symb, ATR_Timeframe, 0);
   double atr_pct = (close_atr_tf > 0.0) ? (atr_now / close_atr_tf) * 100.0 : 0.0;
   double band = ATR_Max_Pct - ATR_Min_Pct;
   bool sweet_spot = (band > 0.0) &&
                     (atr_pct >= ATR_Min_Pct + band * 0.20) &&
                     (atr_pct <= ATR_Min_Pct + band * 0.80);

   int min_str = MathMin(Min_Signal_Strength, MAX_SIGNAL_STRENGTH);

   if(buy_signal)
   {
      int s = 1; // base
      if(structure_trend == 1)                                  s++;
      if(Require_HigherTF_Confirm && mtf_buy_ok)                s++;
      if(margin_buy >= Min_Breakout_ATR_Mult * 1.8 * atr_now)   s++;
      if(body_buy >= Min_Body_Ratio + 0.10)                     s++;
      if(sweet_spot)                                            s++;

      if(s >= min_str) ProcessSignal(1, iTime(symb, t1, 1), h1_1, s);
   }

   if(sell_signal)
   {
      int s = 1;
      if(structure_trend == -1)                                 s++;
      if(Require_HigherTF_Confirm && mtf_sell_ok)               s++;
      if(margin_sell >= Min_Breakout_ATR_Mult * 1.8 * atr_now)  s++;
      if(body_sell >= Min_Body_Ratio + 0.10)                    s++;
      if(sweet_spot)                                            s++;

      if(s >= min_str) ProcessSignal(2, iTime(symb, t1, 1), l1_1, s);
   }
}

//+------------------------------------------------------------------+
//| Procesar señal                                                   |
//+------------------------------------------------------------------+
void ProcessSignal(int type, datetime t, double price, int strength)
{
   ExecuteTrade(type, price, strength);
   DrawSignalArrow(type, t, price);
}

//+------------------------------------------------------------------+
//| Dibujar flecha                                                   |
//+------------------------------------------------------------------+
void DrawSignalArrow(int type, datetime t, double price)
{
   string name = "DOT_" + (type==1 ? "B" : "S") + "_" +
                 TimeToString(t, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "_" + IntegerToString(type);

   if(!ObjectCreate(0, name, OBJ_ARROW, 0, t, price)) return;

   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159);
   ObjectSetInteger(0, name, OBJPROP_COLOR, (type==1 ? clrLime : clrRed));

   int n = ArraySize(g_arrow_names);
   ArrayResize(g_arrow_names, n + 1);
   g_arrow_names[n] = name;

   if(Max_Signal_Arrows > 0)
   {
      while(ArraySize(g_arrow_names) > Max_Signal_Arrows)
      {
         ObjectDelete(0, g_arrow_names[0]);
         for(int i = 0; i < ArraySize(g_arrow_names) - 1; i++)
            g_arrow_names[i] = g_arrow_names[i+1];
         ArrayResize(g_arrow_names, ArraySize(g_arrow_names) - 1);
      }
   }
}

//+------------------------------------------------------------------+
//| ¿Hay posición abierta?                                           |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   return CountOpenPositions() > 0;
}

//+------------------------------------------------------------------+
//| Cálculo de volumen dinámico                                      |
//+------------------------------------------------------------------+
double CalcDynamicVolume(double sl_dist_price, double risk_pct)
{
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double tickValue = SymbolInfoDouble(symb, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(symb, SYMBOL_TRADE_TICK_SIZE);

   if(tickSize <= 0.0 || tickValue <= 0.0 || sl_dist_price <= 0.0) return -1.0;

   double moneyPerPriceUnitPerLot = tickValue / tickSize;
   double moneyRiskPerLot = sl_dist_price * moneyPerPriceUnitPerLot;
   if(moneyRiskPerLot <= 0.0) return -1.0;

   double riskAmount = balance * (risk_pct / 100.0);
   double rawVol = riskAmount / moneyRiskPerLot;

   double minVol  = SymbolInfoDouble(symb, SYMBOL_VOLUME_MIN);
   double maxVol  = SymbolInfoDouble(symb, SYMBOL_VOLUME_MAX);
   double stepVol = SymbolInfoDouble(symb, SYMBOL_VOLUME_STEP);
   if(stepVol <= 0.0) stepVol = minVol;

   double vol = MathFloor(rawVol / stepVol) * stepVol;
   if(vol < minVol) vol = minVol;
   if(vol > maxVol) vol = maxVol;

   double marginRequired = 0.0;
   double price = SymbolInfoDouble(symb, SYMBOL_ASK);
   if(!OrderCalcMargin(ORDER_TYPE_BUY, symb, vol, price, marginRequired) || marginRequired <= 0.0)
      return -1.0;

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(marginRequired > freeMargin * 0.80)
   {
      double adjusted = vol * (freeMargin * 0.80) / marginRequired;
      adjusted = MathFloor(adjusted / stepVol) * stepVol;
      if(adjusted < minVol) return -1.0;
      vol = adjusted;
   }

   return vol;
}

//+------------------------------------------------------------------+
//| Comentario de riesgo                                             |
//+------------------------------------------------------------------+
string BuildRiskComment(double sl_dist_price)
{
   long pts = (long)MathRound(sl_dist_price / point_val);
   if(pts < 1) pts = 1;
   if(pts > 999999) pts = 999999;
   return "R" + IntegerToString((int)pts);
}

//+------------------------------------------------------------------+
//| Recuperar distancia de riesgo inicial                            |
//+------------------------------------------------------------------+
double GetInitialRiskDistance(ulong ticket, double open_price, double current_sl)
{
   if(ticket == g_cur_ticket && g_cur_sl_dist > 0.0) return g_cur_sl_dist;

   string cmt = "";
   if(PositionSelectByTicket(ticket)) cmt = PositionGetString(POSITION_COMMENT);
   if(StringLen(cmt) > 1 && StringGetCharacter(cmt, 0) == 'R')
   {
      double pts = StringToDouble(StringSubstr(cmt, 1));
      if(pts > 0.0) return pts * point_val;
   }

   if(current_sl > 0.0 && open_price > 0.0)
   {
      double d = MathAbs(open_price - current_sl);
      if(d > 0.0) return d;
   }

   double atr = GetATRValue();
   if(atr > 0.0) return atr * ATR_SL_Multiplier;

   return 0.0;
}

//+------------------------------------------------------------------+
//| Recuperar estado de posición abierta                             |
//+------------------------------------------------------------------+
void RecoverOpenPositionState()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != symb) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)g_magic) continue;

      g_cur_ticket  = ticket;
      g_cur_open    = PositionGetDouble(POSITION_PRICE_OPEN);
      g_cur_sl0     = PositionGetDouble(POSITION_SL);
      g_cur_tp0     = PositionGetDouble(POSITION_TP);
      g_cur_type    = (int)PositionGetInteger(POSITION_TYPE);
      g_cur_sl_dist = GetInitialRiskDistance(ticket, g_cur_open, g_cur_sl0);
      g_cur_tp_dist = (g_cur_tp0 > 0.0) ? MathAbs(g_cur_tp0 - g_cur_open) : 0.0;
      break;
   }
}

//+------------------------------------------------------------------+
//| Ejecutar operación                                               |
//+------------------------------------------------------------------+
void ExecuteTrade(int type, double signal_price, int strength)
{
   if(HasOpenPosition()) return;

   string news_label;
   if(IsNewsTime(news_label))
   {
      Print("Señal omitida por filtro de noticias: ", news_label);
      return;
   }

   if(Use_Loss_Streak_Guard)
   {
      if(TimeCurrent() < g_pause_until) return;
      if(g_consecutive_losses >= Max_Consecutive_Losses) g_consecutive_losses = 0;
   }

   if(Use_Daily_Loss_Limit && g_day_start_balance > 0.0)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double loss_pct = (g_day_start_balance - equity) / g_day_start_balance * 100.0;
      if(loss_pct >= Max_Daily_Loss_Percent)
      {
         if(!g_daily_limit_hit)
         {
            Print("LÍMITE DE PÉRDIDA DIARIA ALCANZADO (", DoubleToString(loss_pct, 2), "%)");
            g_daily_limit_hit = true;
         }
         return;
      }
   }

   if(!CheckTotalDrawdown())
   {
      Print("Señal omitida: drawdown total excedido");
      return;
   }

   if(TimeCurrent() - g_last_trade_time < Cooldown_Seconds) return;
   if(g_trades_today >= Max_Trades_Per_Day) return;

   double ask = SymbolInfoDouble(symb, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symb, SYMBOL_BID);
   double cur_spread = ask - bid;
   double cur_spread_pts = (point_val > 0.0) ? cur_spread / point_val : 0.0;
   bool is_high_spread = (cur_spread_pts > HighSpread_Threshold);

   if(Max_Spread_Points > 0.0 && cur_spread_pts > Max_Spread_Points)
   {
      Print("Señal omitida: spread (", DoubleToString(cur_spread_pts, 1),
            " pts) > max (", DoubleToString(Max_Spread_Points, 1), " pts)");
      return;
   }

   double entry = (type == 1) ? ask : bid;
   double stopLevel = SymbolInfoInteger(symb, SYMBOL_TRADE_STOPS_LEVEL) * point_val;
   if(stopLevel <= 0.0) stopLevel = 10.0 * point_val;

   double atr = GetATRValue();
   if(atr <= 0.0)
   {
      Print("ATR no disponible. Señal omitida.");
      return;
   }

   double sl_mult = ATR_SL_Multiplier;
   double tp_mult = ATR_TP_Multiplier;

   // Riesgo escalado por calidad
   double strength_ratio = 0.0;
   int min_str = MathMin(Min_Signal_Strength, MAX_SIGNAL_STRENGTH);
   if(MAX_SIGNAL_STRENGTH > min_str)
      strength_ratio = (double)(strength - min_str) / (double)(MAX_SIGNAL_STRENGTH - min_str);
   strength_ratio = MathMax(0.0, MathMin(1.0, strength_ratio));

   double risk_pct = Min_Risk_Percent + (Max_Risk_Percent - Min_Risk_Percent) * strength_ratio;
   tp_mult *= (1.0 + 0.35 * strength_ratio);

   if(is_high_spread)
   {
      double atr_vs_spread = atr / cur_spread;
      if(atr_vs_spread < HighSpread_ATR_Min_Mult)
      {
         Print("Señal omitida en spread alto: ATR/spread (", DoubleToString(atr_vs_spread, 2),
               ") < min (", DoubleToString(HighSpread_ATR_Min_Mult, 2), ")");
         return;
      }
      sl_mult  *= HighSpread_SL_Extra_Mult;
      risk_pct *= HighSpread_Risk_Reduction;
      Print("Spread alto (", DoubleToString(cur_spread_pts, 0),
            " pts): SL ×", DoubleToString(HighSpread_SL_Extra_Mult, 1),
            ", riesgo ×", DoubleToString(HighSpread_Risk_Reduction, 1));
   }

   risk_pct = MathMin(risk_pct, Max_Risk_Percent);
   risk_pct = MathMin(risk_pct, Hard_Risk_Cap_Percent);
   if(risk_pct <= 0.0) return;

   double sl_dist = atr * sl_mult;
   double tp_dist = atr * tp_mult;

   double avg_spread = GetAverageSpread();
   double spread_floor = avg_spread * Spread_Buffer_Multiplier;
   if(spread_floor > 0.0)
   {
      if(sl_dist < spread_floor) sl_dist = spread_floor;
      if(tp_dist < spread_floor) tp_dist = spread_floor;
   }

   double min_sl_dist = MathMax(stopLevel, Min_SL_Points * point_val);
   if(sl_dist < min_sl_dist) sl_dist = min_sl_dist;

   double vol = CalcDynamicVolume(sl_dist, risk_pct);
   if(vol <= 0.0)
   {
      Print("No se pudo calcular el volumen. Señal omitida.");
      return;
   }

   double sl = NormalizeDouble((type == 1) ? entry - sl_dist : entry + sl_dist, g_Digits);
   double tp = NormalizeDouble((type == 1) ? entry + tp_dist : entry - tp_dist, g_Digits);

   string cmt = BuildRiskComment(sl_dist);
   bool sent = false;

   if(Use_Limit_Orders)
   {
      double price = signal_price;
      if(type == 1)
      {
         if(price < ask - stopLevel)
            sent = trade.OrderOpen(symb, ORDER_TYPE_BUY_LIMIT, vol, price, price, sl, tp,
                                   ORDER_TIME_SPECIFIED, TimeCurrent() + Limit_Expiration_Minutes * 60, cmt);
         else
            sent = trade.PositionOpen(symb, ORDER_TYPE_BUY, vol, ask, sl, tp, cmt);
      }
      else
      {
         if(price > bid + stopLevel)
            sent = trade.OrderOpen(symb, ORDER_TYPE_SELL_LIMIT, vol, price, price, sl, tp,
                                   ORDER_TIME_SPECIFIED, TimeCurrent() + Limit_Expiration_Minutes * 60, cmt);
         else
            sent = trade.PositionOpen(symb, ORDER_TYPE_SELL, vol, bid, sl, tp, cmt);
      }
   }
   else
   {
      if(type == 1) sent = trade.PositionOpen(symb, ORDER_TYPE_BUY,  vol, ask, sl, tp, cmt);
      else          sent = trade.PositionOpen(symb, ORDER_TYPE_SELL, vol, bid, sl, tp, cmt);
   }

   if(sent)
   {
      g_last_trade_time = TimeCurrent();
      g_trades_today++;

      Print("═══════════════════════════════════════════");
      Print("✅ ", (type==1 ? "BUY" : "SELL"), " EJECUTADA (v14.0 ELITE)");
      Print("   Entrada: ", DoubleToString(entry, g_Digits));
      Print("   SL: ", DoubleToString(sl, g_Digits), " (", DoubleToString(sl_dist/point_val, 0), " pts)");
      Print("   TP: ", DoubleToString(tp, g_Digits), " (", DoubleToString(tp_dist/point_val, 0), " pts)");
      Print("   Lote: ", DoubleToString(vol, 2));
      Print("   ATR: ", DoubleToString(atr, g_Digits), " | Riesgo: ", DoubleToString(risk_pct, 2), "%");
      Print("   Fuerza: ", strength, "/", MAX_SIGNAL_STRENGTH,
            " | Spread: ", DoubleToString(cur_spread_pts, 0), " pts");
      string trend_str = (g_last_structure_trend==1) ? "ALCISTA ↑" :
                         (g_last_structure_trend==-1) ? "BAJISTA ↓" : "SIN TENDENCIA →";
      Print("   Estructura: ", trend_str);
      Print("═══════════════════════════════════════════");
   }
   else
   {
      Print("❌ ERROR al enviar orden (", (type==1?"BUY":"SELL"),
            "). Retcode=", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Limpiar órdenes pendientes caducadas                             |
//+------------------------------------------------------------------+
void CleanupStalePendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket <= 0) continue;
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != symb) continue;
      if(OrderGetInteger(ORDER_MAGIC) != (long)g_magic) continue;

      datetime setup = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(TimeCurrent() - setup > Limit_Expiration_Minutes * 60)
         trade.OrderDelete(ticket);
   }
}

//+------------------------------------------------------------------+
//| Protección progresiva (Elite)                                    |
//+------------------------------------------------------------------+
void ManageProgressiveProtection()
{
   double freezeLevel = SymbolInfoInteger(symb, SYMBOL_TRADE_FREEZE_LEVEL) * point_val;
   double stopLevel   = SymbolInfoInteger(symb, SYMBOL_TRADE_STOPS_LEVEL)  * point_val;
   double minStep     = PP_Min_Step_Points * point_val;
   double minDist     = MathMax(stopLevel, point_val);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != symb) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)g_magic) continue;

      double open    = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl      = PositionGetDouble(POSITION_SL);
      double tp      = PositionGetDouble(POSITION_TP);
      double current = PositionGetDouble(POSITION_PRICE_CURRENT);
      int    type    = (int)PositionGetInteger(POSITION_TYPE);

      double R = GetInitialRiskDistance(ticket, open, sl);
      if(R <= 0.0) continue;

      double profit_dist = (type == POSITION_TYPE_BUY) ? (current - open) : (open - current);
      if(profit_dist <= 0.0) continue;

      double r_mult = profit_dist / R;
      double candidate_sl = 0.0;
      bool   have = false;

      if(r_mult >= PP_Trail_Start_R)
      {
         // Etapa 4: trailing ATR + estructura
         double atr = GetATRValue();
         double atr_trail = (type == POSITION_TYPE_BUY)
                            ? current - atr * PP_Trail_ATR_Mult
                            : current + atr * PP_Trail_ATR_Mult;

         int lb = PP_Trail_Structure_Lookback;
         double struct_trail = 0.0;
         if(type == POSITION_TYPE_BUY)
         {
            int idx = iLowest(symb, ATR_Timeframe, MODE_LOW, lb, 1);
            if(idx >= 0) struct_trail = iLow(symb, ATR_Timeframe, idx);
            candidate_sl = (struct_trail > 0.0) ? MathMax(atr_trail, struct_trail) : atr_trail;
         }
         else
         {
            int idx = iHighest(symb, ATR_Timeframe, MODE_HIGH, lb, 1);
            if(idx >= 0) struct_trail = iHigh(symb, ATR_Timeframe, idx);
            candidate_sl = (struct_trail > 0.0) ? MathMin(atr_trail, struct_trail) : atr_trail;
         }
         have = true;
      }
      else if(r_mult >= PP_Stage3_R)
      {
         double lock = profit_dist * PP_Lock_Fraction;
         candidate_sl = (type == POSITION_TYPE_BUY) ? open + lock : open - lock;
         have = true;
      }
      else if(r_mult >= PP_Stage2_R)
      {
         double buf = PP_BE_Buffer_Points * point_val;
         candidate_sl = (type == POSITION_TYPE_BUY) ? open + buf : open - buf;
         have = true;
      }
      else if(r_mult >= PP_Stage1_R)
      {
         double reduced = R * PP_Stage1_SL_R;
         candidate_sl = (type == POSITION_TYPE_BUY) ? open - reduced : open + reduced;
         have = true;
      }

      if(!have) continue;

      bool improves = (sl == 0.0) ||
                      (type == POSITION_TYPE_BUY  && candidate_sl > sl) ||
                      (type == POSITION_TYPE_SELL && candidate_sl < sl);
      if(!improves) continue;
      if(sl != 0.0 && MathAbs(candidate_sl - sl) < minStep) continue;

      if(type == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(symb, SYMBOL_BID);
         if(freezeLevel > 0.0 && sl != 0.0 && (bid - sl) < freezeLevel) continue;
         if(bid - candidate_sl < minDist) candidate_sl = bid - minDist;
         if(candidate_sl <= sl) continue;
      }
      else
      {
         double ask = SymbolInfoDouble(symb, SYMBOL_ASK);
         if(freezeLevel > 0.0 && sl != 0.0 && (sl - ask) < freezeLevel) continue;
         if(candidate_sl - ask < minDist) candidate_sl = ask + minDist;
         if(sl != 0.0 && candidate_sl >= sl) continue;
      }

      if(!trade.PositionModify(ticket, NormalizeDouble(candidate_sl, g_Digits), tp))
         Print("⚠ Error ProgressiveProtection modify: ", trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
//| Panel helpers                                                    |
//+------------------------------------------------------------------+
void PanelSetLabel(string sub, int x, int y, string text, color clr)
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
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void PanelSetBackground(int x, int y, int w, int h)
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
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, g_panel_bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, g_panel_fg);
}

void PanelDeleteAll()
{
   ObjectsDeleteAll(0, PANEL_PREFIX);
}

string FormatNewsLine(string tag, bool enabled, string name, int sh, int sm, int eh, int em)
{
   string range = StringFormat("%02d:%02d-%02d:%02d", sh, sm, eh, em);
   string status;
   if(!enabled) status = "(off)";
   else
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      bool active = IsTimeInRange(dt.hour, dt.min, sh, sm, eh, em);
      status = active ? "BLOQUEADO" : "libre";
   }
   return StringFormat("%s %-12s %s [%s]", tag, name, range, status);
}

//+------------------------------------------------------------------+
//| Actualizar panel visual                                          |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   if(!Panel_Show) { PanelDeleteAll(); return; }

   string news_label;
   bool blocked = IsNewsTime(news_label);

   double cur_spread_pts = (point_val > 0.0)
      ? (SymbolInfoDouble(symb, SYMBOL_ASK) - SymbolInfoDouble(symb, SYMBOL_BID)) / point_val : 0.0;
   double avg_spread_pts = (point_val > 0.0) ? GetAverageSpread() / point_val : 0.0;

   double daily_loss_pct = 0.0;
   if(g_day_start_balance > 0.0)
      daily_loss_pct = (g_day_start_balance - AccountInfoDouble(ACCOUNT_EQUITY)) / g_day_start_balance * 100.0;

   bool in_pause = (TimeCurrent() < g_pause_until);

   int trend = GetStructureTrend(Trend_Timeframe, Trend_Lookback);
   string trend_str;
   if(trend == 1)       trend_str = "ALCISTA ↑  (Solo BUYs)";
   else if(trend == -1) trend_str = "BAJISTA ↓  (Solo SELLs)";
   else                 trend_str = "SIN TENDENCIA → " + (Block_When_No_Trend ? "BLOQUEADO" : "Permitido");

   double atr_val = GetATRValue();
   double atr_pct = 0.0;
   double cp = iClose(symb, ATR_Timeframe, 0);
   if(atr_val > 0.0 && cp > 0.0) atr_pct = (atr_val / cp) * 100.0;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double total_dd = (balance > 0.0) ? (balance - equity) / balance * 100.0 : 0.0;

   string pos_status = "Sin posición abierta";
   if(g_cur_ticket != 0 && PositionSelectByTicket(g_cur_ticket))
   {
      double open    = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl      = PositionGetDouble(POSITION_SL);
      double current = PositionGetDouble(POSITION_PRICE_CURRENT);
      int    type    = (int)PositionGetInteger(POSITION_TYPE);
      double R = GetInitialRiskDistance(g_cur_ticket, open, sl);
      double profit_dist = (type == POSITION_TYPE_BUY) ? (current - open) : (open - current);
      double r_mult = (R > 0.0) ? profit_dist / R : 0.0;
      pos_status = (type == POSITION_TYPE_BUY ? "BUY" : "SELL") + " | R = " + DoubleToString(r_mult, 2);
   }

   string lines[];
   int n = 0;
   ArrayResize(lines, 80);

   lines[n++] = "====== OHLCMTF SCALPER v14.0 ELITE ======";
   lines[n++] = "";
   lines[n++] = blocked ? (">>> BLOQUEADO POR NOTICIA: " + news_label + " <<<")
                        : (in_pause ? ">>> EN PAUSA POR RACHA DE PÉRDIDAS <<<"
                                    : (g_daily_limit_hit ? ">>> LÍMITE DE PÉRDIDA DIARIA ALCANZADO <<<"
                                                         : ">>> ESTADO: OPERANDO <<<"));
   lines[n++] = "";

   lines[n++] = "--- TENDENCIA DE ESTRUCTURA ---";
   lines[n++] = "Tendencia: " + trend_str;
   lines[n++] = "TF: " + EnumToString(Trend_Timeframe) + " | Lookback: " + IntegerToString(Trend_Lookback);
   lines[n++] = "";

   lines[n++] = "--- ENTRADAS (RUPTURA) ---";
   lines[n++] = "Lookback: " + IntegerToString(Structure_Lookback) + " barras";
   lines[n++] = "Margen ATR: " + DoubleToString(Min_Breakout_ATR_Mult, 2) + " – " + DoubleToString(Max_Breakout_ATR_Mult, 2) + "×";
   lines[n++] = "Body ≥ " + DoubleToString(Min_Body_Ratio, 2) + " | Max mecha contraria: " + DoubleToString(Max_Against_Wick_Ratio, 2);
   lines[n++] = "Fuerza mínima: " + IntegerToString(Min_Signal_Strength) + " / " + IntegerToString(MAX_SIGNAL_STRENGTH);
   lines[n++] = "";

   lines[n++] = "--- ATR / SL-TP ---";
   lines[n++] = "ATR: " + DoubleToString(atr_val, g_Digits) + " (" + DoubleToString(atr_pct, 3) + "%)";
   lines[n++] = "SL = ATR × " + DoubleToString(ATR_SL_Multiplier, 1) + " | TP = ATR × " + DoubleToString(ATR_TP_Multiplier, 1);
   lines[n++] = "";

   lines[n++] = "--- RIESGO DINÁMICO ---";
   lines[n++] = "Rango: " + DoubleToString(Min_Risk_Percent, 2) + "% – " + DoubleToString(Max_Risk_Percent, 2) +
                 "% (techo " + DoubleToString(Hard_Risk_Cap_Percent, 1) + "%)";
   lines[n++] = "Posición: " + pos_status;
   lines[n++] = "";

   lines[n++] = "--- PROTECCIÓN PROGRESIVA ---";
   lines[n++] = "Activa: " + (Use_Progressive_Protection ? "SÍ" : "NO");
   lines[n++] = "Etapas R: reducir " + DoubleToString(PP_Stage1_R, 1) +
                 " | BE " + DoubleToString(PP_Stage2_R, 1) +
                 " | asegurar " + DoubleToString(PP_Stage3_R, 1) +
                 " | trailing " + DoubleToString(PP_Trail_Start_R, 1);
   lines[n++] = "";

   lines[n++] = "--- SPREAD ---";
   lines[n++] = "Actual: " + DoubleToString(cur_spread_pts, 1) + " pts | Prom: " + DoubleToString(avg_spread_pts, 1) + " pts";
   lines[n++] = "Techo: " + (Max_Spread_Points > 0.0 ? DoubleToString(Max_Spread_Points, 1) + " pts" : "desactivado");
   if(cur_spread_pts > HighSpread_Threshold)
      lines[n++] = ">>> MODO SPREAD ALTO ACTIVO <<<";
   lines[n++] = "";

   lines[n++] = "--- PROTECCIÓN DE CAPITAL ---";
   lines[n++] = "Pérdida diaria: " + (Use_Daily_Loss_Limit
                  ? DoubleToString(daily_loss_pct, 2) + "% / " + DoubleToString(Max_Daily_Loss_Percent, 1) + "%"
                  : "desactivado");
   lines[n++] = "Racha pérdidas: " + IntegerToString(g_consecutive_losses) + " / " + IntegerToString(Max_Consecutive_Losses) +
                 (in_pause ? "  [PAUSADO]" : "");
   lines[n++] = "Drawdown total: " + DoubleToString(total_dd, 2) + "% / " +
                 (Use_Total_Drawdown_Limit ? DoubleToString(Max_Total_Drawdown_Pct, 1) + "%" : "desactivado");
   lines[n++] = "Trades hoy: " + IntegerToString(g_trades_today) + " / " + IntegerToString(Max_Trades_Per_Day);
   lines[n++] = "";

   lines[n++] = "--- FILTRO DE NOTICIAS ---";
   lines[n++] = FormatNewsLine("N1", News1_Enable, News1_Name, News1_Start_Hour, News1_Start_Min, News1_End_Hour, News1_End_Min);
   lines[n++] = FormatNewsLine("N2", News2_Enable, News2_Name, News2_Start_Hour, News2_Start_Min, News2_End_Hour, News2_End_Min);
   lines[n++] = FormatNewsLine("N3", News3_Enable, News3_Name, News3_Start_Hour, News3_Start_Min, News3_End_Hour, News3_End_Min);
   lines[n++] = FormatNewsLine("N4", News4_Enable, News4_Name, News4_Start_Hour, News4_Start_Min, News4_End_Hour, News4_End_Min);
   lines[n++] = "";

   lines[n++] = "--- ESTADÍSTICAS ---";
   lines[n++] = "TP completo: " + IntegerToString(g_cnt_tp_full) + " | Ganancia parcial: " + IntegerToString(g_cnt_gain_parcial);
   lines[n++] = "SL completo: " + IntegerToString(g_cnt_sl_full) + " | Pérdida parcial: " + IntegerToString(g_cnt_loss_parcial);
   lines[n++] = "Flechas: " + IntegerToString(ArraySize(g_arrow_names)) + " / " +
                 (Max_Signal_Arrows > 0 ? IntegerToString(Max_Signal_Arrows) : "sin límite");

   ArrayResize(lines, n);

   int line_h = Panel_Font_Size + 6;
   int max_len = 0;
   for(int i = 0; i < n; i++)
      if(StringLen(lines[i]) > max_len) max_len = StringLen(lines[i]);

   int panel_w = max_len * (Panel_Font_Size - 1) + 24;
   int panel_h = n * line_h + 16;
   PanelSetBackground(Panel_X - 10, Panel_Y - 10, panel_w, panel_h);

   int y = Panel_Y;
   for(int i = 0; i < n; i++)
   {
      PanelSetLabel("L" + IntegerToString(i), Panel_X, y, lines[i], g_panel_fg);
      y += line_h;
   }
}
//+------------------------------------------------------------------+