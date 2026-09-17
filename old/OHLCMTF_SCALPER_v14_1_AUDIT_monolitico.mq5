//+------------------------------------------------------------------+
//|                              OHLCMTF_SCALPER_v14_1_AUDIT.mq5     |
//|           XAU/USD Pure Price Action Structure Scalper v14.1      |
//|      Build de AUDITORÍA sobre v14.0 ELITE (2026-09-17)           |
//+------------------------------------------------------------------+
//  CAMBIOS RESPECTO A v14.0 (buscar la etiqueta [AUDIT-nn] en el código):
//  [AUDIT-01] Sizing: base de riesgo = min(balance, equity); si el lote
//             mínimo del bróker implica un riesgo > Hard_Risk_Cap_Percent
//             la señal se OMITE (salvo Allow_MinLot_Above_Cap=true). Se
//             registra en el log el riesgo REAL en % y en dinero.
//  [AUDIT-02] Guardia de equity "dura": drawdown medido contra el máximo
//             histórico de equity (high-water mark, persistido en variables
//             globales del terminal). Al superar Max_Total_Drawdown_Pct se
//             CIERRAN posiciones y pendientes (flatten) y se bloquea el EA
//             (latch) hasta reset manual o hasta DD_Pause_Hours.
//  [AUDIT-03] Cada set de señales usa su propio magic (fijo 20260914,
//             personalizado 20260915) y etiqueta el comentario con F/C.
//             Estadísticas por set en panel y log. Use_Fixed_Set permite
//             apagar el set fijo para atribuir resultados.
//  [AUDIT-04] ATR y ATR% se leen de la vela CERRADA (índice 1), nunca de
//             la vela en formación.
//  [AUDIT-05] Recuperación tras reinicio: R inicial desde el deal de
//             entrada en el historial (DEAL_SL), contadores diarios, racha
//             y pausa desde historial + variables globales. Las velas ya
//             cerradas antes del arranque NO se re-evalúan.
//  [AUDIT-06] Órdenes pendientes cuentan como exposición (no se abre una
//             segunda). OrderOpen corregido (stoplimit=0, SL/TP relativos
//             al precio límite).
//  [AUDIT-07] Comprobación explícita del retcode tras enviar la orden.
//  [AUDIT-08] La racha de pérdidas solo se resetea con una ganancia
//             significativa (>= Streak_Reset_Min_R × riesgo inicial).
//  [AUDIT-09] Modo "spread alto" decidido con el spread PROMEDIO muestreado
//             (evita el pico artificial del primer tick de la vela).
//  [AUDIT-10] Filtro de noticias por CALENDARIO ECONÓMICO (MQL5 Calendar en
//             vivo; CSV en Common\Files para el Strategy Tester).
//  [AUDIT-11] Validación de rangos de todos los inputs en OnInit.
//  [AUDIT-12] Cierre opcional antes del fin de semana y corte de entradas
//             los viernes; límite diario opcionalmente cierra posiciones.
//  [AUDIT-13] OnTradeTransaction robusto: no depende de g_cur_ticket para
//             contabilizar salidas; maneja DEAL_ENTRY_OUT_BY.
//  NOTA: ningún input existente cambia de nombre ni de valor por defecto.
//        Los inputs nuevos están en los grupos 19 y 20. Con los valores por
//        defecto nuevos, el comportamiento cambia SOLO en: sizing (AUDIT-01),
//        guardia de equity (AUDIT-02), ATR de vela cerrada (AUDIT-04) y
//        racha (AUDIT-08). Todo ello está justificado en el informe.
//+------------------------------------------------------------------+
#property strict
#property copyright "OHLCMTF SCALPER v14.1 AUDIT - Pure Price Action XAUUSD"
#property version   "14.10"
#property description "Structure breakout scalper XAUUSD - build de auditoría con guardia de equity dura"

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
input double Max_Spread_Points           = 0;      // 0 = desactivado (en real: usar 45-60 para XAUUSD)
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
input int    Session_Start_Hour          = 7;      // Hora del SERVIDOR del bróker (no GMT)
input int    Session_End_Hour            = 20;     // Hora del SERVIDOR del bróker (no GMT)
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
input double Max_Total_Drawdown_Pct      = 12.0;   // [AUDIT-02] ahora medido vs máximo histórico de equity

//+------------------------------------------------------------------+
//| INPUTS – NEWS FILTERS (ventanas fijas, legado)                   |
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
//| INPUTS – AUDIT v14.1: SIZING, EQUITY GUARD, SETS, RESTART        |
//+------------------------------------------------------------------+
input group "=== 19. AUDIT v14.1 – SIZING / EQUITY GUARD / SETS ==="
input bool   Use_Fixed_Set               = true;   // [AUDIT-03] Set fijo H1 / Trend_Timeframe / D1 (apagar para atribuir)
input bool   Allow_MinLot_Above_Cap      = false;  // [AUDIT-01] true = permitir lote mínimo aunque exceda Hard_Risk_Cap (NO recomendado)
input bool   Size_On_Equity              = true;   // [AUDIT-01] Base de riesgo = min(balance, equity)
input bool   DD_Use_Equity_Peak          = true;   // [AUDIT-02] HWM sobre equity (true) o sobre balance (false)
input bool   DD_Flatten_Positions        = true;   // [AUDIT-02] Cerrar todo al superar Max_Total_Drawdown_Pct
input int    DD_Pause_Hours              = 72;     // [AUDIT-02] Horas de bloqueo tras DD; 0 = requiere DD_Manual_Reset
input bool   DD_Manual_Reset             = false;  // [AUDIT-02] Poner true y reiniciar el EA para levantar el bloqueo por DD
input bool   Daily_Loss_Flatten          = false;  // [AUDIT-12] Cerrar posiciones al alcanzar Max_Daily_Loss_Percent
input bool   Close_Before_Weekend        = false;  // [AUDIT-12] Cerrar posiciones el viernes a Weekend_Close_Hour (servidor)
input int    Weekend_Close_Hour          = 21;     // [AUDIT-12] Hora servidor del cierre de viernes
input int    Friday_Entry_Cutoff_Hour    = 24;     // [AUDIT-12] Sin entradas nuevas los viernes desde esta hora (24 = sin corte)
input double Streak_Reset_Min_R          = 0.25;   // [AUDIT-08] Ganancia mínima (en R) para resetear la racha; 0 = cualquier ganancia
input bool   Use_Avg_Spread_For_Mode     = true;   // [AUDIT-09] Modo spread alto según spread promedio (true) o instantáneo (false)

input group "=== 20. AUDIT v14.1 – CALENDAR NEWS FILTER ==="
input bool   Use_Calendar_Filter         = false;  // [AUDIT-10] Filtro por calendario económico (vivo) / CSV (tester)
input string Calendar_Currencies         = "USD";  // Divisas separadas por coma (p.ej. "USD,EUR")
input ENUM_CALENDAR_EVENT_IMPORTANCE Calendar_Min_Importance = CALENDAR_IMPORTANCE_HIGH;
input int    Calendar_Block_Before_Min   = 30;     // Minutos de bloqueo antes del evento
input int    Calendar_Block_After_Min    = 30;     // Minutos de bloqueo después del evento
input bool   Calendar_Close_Positions    = false;  // Cerrar posición abierta al entrar en ventana de evento
input string Calendar_CSV_File           = "news_events.csv"; // Common\Files – formato: YYYY.MM.DD HH:MM;CUR;HIGH|MODERATE|LOW;Nombre (hora servidor)
input int    Calendar_Refresh_Min        = 30;     // Minutos entre recargas del calendario en vivo

//+------------------------------------------------------------------+
//| GLOBALS                                                          |
//+------------------------------------------------------------------+
#define MAGIC_FIXED   20260914   // [AUDIT-03] set fijo   (H1 / Trend_Timeframe / D1)
#define MAGIC_CUSTOM  20260915   // [AUDIT-03] set custom (TF_Fast / TF_Slow / TF_Slow)
#define SET_FIXED     0
#define SET_CUSTOM    1
#define PANEL_PREFIX  "OHLCMTF_v14_"
#define GV_PREFIX     "OHLC14_"

CTrade   trade;
string   symb;
double   point_val;
int      g_Digits;

datetime g_last_bar_fixed  = 0;
datetime g_last_bar_custom = 0;

double   g_spread_buffer[];
int      g_spread_idx = 0;
bool     g_spread_filled = false;

ulong    g_cur_ticket  = 0;
ulong    g_cur_pos_id  = 0;      // identificador estable de posición (DEAL_POSITION_ID)
double   g_cur_open    = 0;
double   g_cur_sl0     = 0;
double   g_cur_tp0     = 0;
double   g_cur_sl_dist = 0;
double   g_cur_tp_dist = 0;
int      g_cur_type    = 0;
int      g_cur_set     = SET_FIXED;

int      g_cnt_tp_full      = 0;
int      g_cnt_gain_parcial = 0;
int      g_cnt_sl_full      = 0;
int      g_cnt_loss_parcial = 0;
double   g_sum_tp_full      = 0;
double   g_sum_gain_parcial = 0;
double   g_sum_sl_full      = 0;
double   g_sum_loss_parcial = 0;

// [AUDIT-03] estadísticas por set
int      g_set_trades[2];
int      g_set_wins[2];
double   g_set_profit[2];

bool     g_last_news_state  = false;

double   g_day_start_balance = 0;
int      g_day_of_year       = -1;
bool     g_daily_limit_hit   = false;
int      g_consecutive_losses = 0;
datetime g_pause_until        = 0;

// [AUDIT-02] guardia de equity
double   g_hwm              = 0;
bool     g_dd_latched       = false;
datetime g_dd_latched_until = 0;
double   g_dd_last_pct      = 0;
datetime g_weekend_closed_day = 0;

// [AUDIT-01] último riesgo real
double   g_last_real_risk_pct = 0;
double   g_last_real_risk_money = 0;
int      g_skipped_minlot   = 0;

string   g_arrow_names[];

int      g_h_atr            = INVALID_HANDLE;
double   g_atr_value        = 0;
datetime g_last_atr_update  = 0;

int      g_last_structure_trend = 0;

datetime g_last_trade_time  = 0;
int      g_trades_today     = 0;

// [AUDIT-10] calendario
struct NewsEvent
{
   datetime time;
   string   currency;
   int      importance;
   string   name;
};
NewsEvent g_news[];
datetime  g_news_loaded_at = 0;
bool      g_calendar_available = true;

color    g_panel_bg = clrBlack;
color    g_panel_fg = clrLime;

const int MAX_SIGNAL_STRENGTH = 6;

//+------------------------------------------------------------------+
//| Helpers genéricos                                                |
//+------------------------------------------------------------------+
bool IsOurMagic(long m)
{
   return (m == (long)MAGIC_FIXED || m == (long)MAGIC_CUSTOM);
}

int SetFromMagic(long m)
{
   return (m == (long)MAGIC_CUSTOM) ? SET_CUSTOM : SET_FIXED;
}

string SetName(int set_id)
{
   if(set_id == SET_CUSTOM)
      return "CUSTOM(" + EnumToString(TF_Fast) + "/" + EnumToString(TF_Slow) + ")";
   return "FIJO(H1/" + EnumToString(Trend_Timeframe) + "/D1)";
}

string GV(string key)
{
   return GV_PREFIX + IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + symb + "_" + key;
}

double NormalizeTradePrice(double value)   // precio alineado a SYMBOL_TRADE_TICK_SIZE
{
   double tick_size = SymbolInfoDouble(symb, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0) return NormalizeDouble(value, g_Digits);
   return NormalizeDouble(MathRound(value / tick_size) * tick_size, g_Digits);
}

bool SendOK()
{
   uint rc = trade.ResultRetcode();
   return (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED || rc == TRADE_RETCODE_DONE_PARTIAL);
}

//+------------------------------------------------------------------+
//| [AUDIT-11] Validación de inputs                                  |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
   bool ok = true;
   if(Structure_Lookback < 3)                     { Print("INPUT: Structure_Lookback debe ser >= 3"); ok = false; }
   if(Min_Breakout_ATR_Mult < 0.0)                { Print("INPUT: Min_Breakout_ATR_Mult debe ser >= 0"); ok = false; }
   if(Max_Breakout_ATR_Mult <= Min_Breakout_ATR_Mult) { Print("INPUT: Max_Breakout_ATR_Mult debe ser > Min_Breakout_ATR_Mult"); ok = false; }
   if(Min_Body_Ratio < 0.0 || Min_Body_Ratio > 1.0) { Print("INPUT: Min_Body_Ratio debe estar en [0,1]"); ok = false; }
   if(Max_Against_Wick_Ratio < 0.0)               { Print("INPUT: Max_Against_Wick_Ratio debe ser >= 0"); ok = false; }
   if(Trend_Lookback < 6)                         { Print("INPUT: Trend_Lookback debe ser >= 6 (3 segmentos de >= 2 barras)"); ok = false; }
   if(Min_Swing_Confirmations < 1 || Min_Swing_Confirmations > 3) { Print("INPUT: Min_Swing_Confirmations debe estar en [1,3]"); ok = false; }
   if(Use_Custom_Pair && PeriodSeconds(TF_Fast) >= PeriodSeconds(TF_Slow))      { Print("INPUT: TF_Fast debe ser menor que TF_Slow"); ok = false; }
   if(!Use_Custom_Pair && !Use_Fixed_Set)         { Print("INPUT: ambos sets desactivados; el EA no generaría señales"); ok = false; }
   if(Limit_Expiration_Minutes < 1)               { Print("INPUT: Limit_Expiration_Minutes debe ser >= 1"); ok = false; }
   if(ATR_Period < 2)                             { Print("INPUT: ATR_Period debe ser >= 2"); ok = false; }
   if(ATR_SL_Multiplier <= 0.0 || ATR_TP_Multiplier <= 0.0) { Print("INPUT: multiplicadores ATR deben ser > 0"); ok = false; }
   if(Min_Risk_Percent <= 0.0)                    { Print("INPUT: Min_Risk_Percent debe ser > 0"); ok = false; }
   if(Max_Risk_Percent < Min_Risk_Percent)        { Print("INPUT: Max_Risk_Percent debe ser >= Min_Risk_Percent"); ok = false; }
   if(Hard_Risk_Cap_Percent < Max_Risk_Percent)   { Print("INPUT: Hard_Risk_Cap_Percent debe ser >= Max_Risk_Percent"); ok = false; }
   if(Hard_Risk_Cap_Percent > 10.0)               { Print("INPUT: Hard_Risk_Cap_Percent > 10% es imprudente; abortando"); ok = false; }
   if(Min_Signal_Strength < 1 || Min_Signal_Strength > MAX_SIGNAL_STRENGTH) { Print("INPUT: Min_Signal_Strength debe estar en [1,6]"); ok = false; }
   if(Min_SL_Points < 0 || Slippage_Points < 0)   { Print("INPUT: Min_SL_Points y Slippage_Points deben ser >= 0"); ok = false; }
   if(Spread_Sample_Size < 1)                     { Print("INPUT: Spread_Sample_Size debe ser >= 1"); ok = false; }
   if(Spread_Buffer_Multiplier < 0.0)             { Print("INPUT: Spread_Buffer_Multiplier debe ser >= 0"); ok = false; }
   if(HighSpread_Risk_Reduction <= 0.0 || HighSpread_Risk_Reduction > 1.0) { Print("INPUT: HighSpread_Risk_Reduction debe estar en (0,1]"); ok = false; }
   if(HighSpread_SL_Extra_Mult < 1.0)             { Print("INPUT: HighSpread_SL_Extra_Mult debe ser >= 1"); ok = false; }
   if(Cooldown_Seconds < 0)                       { Print("INPUT: Cooldown_Seconds debe ser >= 0"); ok = false; }
   if(Max_Trades_Per_Day < 1)                     { Print("INPUT: Max_Trades_Per_Day debe ser >= 1"); ok = false; }
   if(Use_Volatility_Filter && ATR_Max_Pct <= ATR_Min_Pct) { Print("INPUT: ATR_Max_Pct debe ser > ATR_Min_Pct"); ok = false; }
   if(Session_Start_Hour < 0 || Session_Start_Hour > 23 || Session_End_Hour < 1 || Session_End_Hour > 24) { Print("INPUT: horas de sesión fuera de rango"); ok = false; }
   if(Use_Session_Filter && Session_Start_Hour >= Session_End_Hour) { Print("INPUT: Session_Start_Hour debe ser < Session_End_Hour"); ok = false; }
   if(Use_Progressive_Protection)
   {
      if(PP_Stage1_R <= 0.0 || PP_Stage1_R >= PP_Stage2_R || PP_Stage2_R >= PP_Stage3_R || PP_Stage3_R >= PP_Trail_Start_R)
      { Print("INPUT: etapas PP deben ser crecientes: 0 < Stage1 < Stage2 < Stage3 < Trail_Start"); ok = false; }
      if(PP_Stage1_SL_R <= 0.0 || PP_Stage1_SL_R >= 1.0) { Print("INPUT: PP_Stage1_SL_R debe estar en (0,1)"); ok = false; }
      if(PP_Lock_Fraction <= 0.0 || PP_Lock_Fraction >= 1.0) { Print("INPUT: PP_Lock_Fraction debe estar en (0,1)"); ok = false; }
      if(PP_Trail_ATR_Mult <= 0.0 || PP_Trail_Structure_Lookback < 1) { Print("INPUT: parámetros de trailing inválidos"); ok = false; }
      if(PP_BE_Buffer_Points < 0.0 || PP_Min_Step_Points < 0.0) { Print("INPUT: buffers PP deben ser >= 0"); ok = false; }
   }
   if(Max_Daily_Loss_Percent <= 0.0 || Max_Daily_Loss_Percent > 50.0) { Print("INPUT: Max_Daily_Loss_Percent fuera de (0,50]"); ok = false; }
   if(Max_Consecutive_Losses < 1 || Loss_Streak_Pause_Minutes < 0) { Print("INPUT: parámetros de racha inválidos"); ok = false; }
   if(Max_Total_Drawdown_Pct <= 0.0 || Max_Total_Drawdown_Pct > 90.0) { Print("INPUT: Max_Total_Drawdown_Pct fuera de (0,90]"); ok = false; }
   if(DD_Pause_Hours < 0)                         { Print("INPUT: DD_Pause_Hours debe ser >= 0"); ok = false; }
   if(Weekend_Close_Hour < 0 || Weekend_Close_Hour > 23) { Print("INPUT: Weekend_Close_Hour fuera de [0,23]"); ok = false; }
   if(Friday_Entry_Cutoff_Hour < 0 || Friday_Entry_Cutoff_Hour > 24) { Print("INPUT: Friday_Entry_Cutoff_Hour fuera de [0,24]"); ok = false; }
   if(Streak_Reset_Min_R < 0.0)                   { Print("INPUT: Streak_Reset_Min_R debe ser >= 0"); ok = false; }
   if(Calendar_Block_Before_Min < 0 || Calendar_Block_After_Min < 0 || Calendar_Refresh_Min < 1) { Print("INPUT: parámetros de calendario inválidos"); ok = false; }
   int news_h[8], news_m[8];
   news_h[0] = News1_Start_Hour; news_h[1] = News1_End_Hour; news_h[2] = News2_Start_Hour; news_h[3] = News2_End_Hour;
   news_h[4] = News3_Start_Hour; news_h[5] = News3_End_Hour; news_h[6] = News4_Start_Hour; news_h[7] = News4_End_Hour;
   news_m[0] = News1_Start_Min;  news_m[1] = News1_End_Min;  news_m[2] = News2_Start_Min;  news_m[3] = News2_End_Min;
   news_m[4] = News3_Start_Min;  news_m[5] = News3_End_Min;  news_m[6] = News4_Start_Min;  news_m[7] = News4_End_Min;
   for(int i = 0; i < 8; i++)
      if(news_h[i] < 0 || news_h[i] > 23 || news_m[i] < 0 || news_m[i] > 59) { Print("INPUT: ventana de noticias ", (i/2)+1, " fuera de rango"); ok = false; }
   if(Panel_Font_Size < 6 || Panel_Refresh_Sec < 1 || Max_Signal_Arrows < 0) { Print("INPUT: parámetros de panel inválidos"); ok = false; }

   // Advertencias (no bloquean)
   if(ATR_Timeframe != PERIOD_H1)
      Print("AVISO: ATR_Timeframe != H1. SL/TP y margen de ruptura de AMBOS sets se calculan con este ATR.");
   if(Use_Custom_Pair && PeriodSeconds(ATR_Timeframe) > PeriodSeconds(TF_Fast))
      Print("AVISO: el set custom entra en ", EnumToString(TF_Fast), " pero usa SL/TP de ATR(", EnumToString(ATR_Timeframe), "). Es intencional en v14 pero revisar.");
   return ok;
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   symb      = _Symbol;
   point_val = SymbolInfoDouble(symb, SYMBOL_POINT);
   g_Digits  = (int)SymbolInfoInteger(symb, SYMBOL_DIGITS);

   if(!ValidateInputs()) return INIT_PARAMETERS_INCORRECT;   // [AUDIT-11]

   trade.SetExpertMagicNumber(MAGIC_FIXED);
   trade.SetDeviationInPoints(Slippage_Points);
   trade.SetTypeFillingBySymbol(symb);

   int sample_size = MathMax(Spread_Sample_Size, 1);
   ArrayResize(g_spread_buffer, sample_size);
   ArrayInitialize(g_spread_buffer, 0.0);
   g_spread_idx    = 0;
   g_spread_filled = false;

   ArrayResize(g_arrow_names, 0);
   ArrayInitialize(g_set_trades, 0);
   ArrayInitialize(g_set_wins, 0);
   ArrayInitialize(g_set_profit, 0.0);

   g_h_atr = iATR(symb, ATR_Timeframe, ATR_Period);
   if(g_h_atr == INVALID_HANDLE)
   {
      Print("ERROR: No se pudo crear handle ATR. Period=", ATR_Period, " TF=", EnumToString(ATR_Timeframe));
      return INIT_FAILED;
   }

   // [AUDIT-05] No re-evaluar la última vela cerrada antes del arranque
   g_last_bar_fixed  = iTime(symb, PERIOD_H1, 0);
   g_last_bar_custom = iTime(symb, TF_Fast, 0);

   CheckNewTradingDay();
   g_last_structure_trend = 0;
   g_last_trade_time      = 0;

   if(MQLInfoInteger(MQL_TESTER))
      GlobalVariablesDeleteAll(GV_PREFIX);   // cada pasada del tester arranca limpia (la recuperación es para cuenta real)

   LoadPersistentState();            // [AUDIT-02][AUDIT-05] HWM, latch, racha, pausa
   RecoverOpenPositionState();       // [AUDIT-05]
   RecoverDailyStateFromHistory();   // [AUDIT-05]

   if(Use_Calendar_Filter) LoadCalendarEvents(true);   // [AUDIT-10]

   if(Panel_Show)
   {
      EventSetTimer(MathMax(Panel_Refresh_Sec, 1));
      UpdatePanel();
   }

   Print("════════════════════════════════════════════════════════════");
   Print("✅ OHLCMTF SCALPER v14.1 AUDIT INICIALIZADO");
   Print("   Sets: FIJO=", (Use_Fixed_Set ? "ON" : "OFF"), " (H1/", EnumToString(Trend_Timeframe), "/D1, magic ", MAGIC_FIXED, ")",
         " | CUSTOM=", (Use_Custom_Pair ? "ON" : "OFF"), " (", EnumToString(TF_Fast), "/", EnumToString(TF_Slow), ", magic ", MAGIC_CUSTOM, ")");
   Print("   Structure Lookback = ", Structure_Lookback, " | Body ≥ ", DoubleToString(Min_Body_Ratio, 2));
   Print("   Risk = ", DoubleToString(Min_Risk_Percent, 2), "% – ", DoubleToString(Max_Risk_Percent, 2),
         "% (cap ", DoubleToString(Hard_Risk_Cap_Percent, 1), "%) | base=", (Size_On_Equity ? "min(balance,equity)" : "balance"),
         " | lote mínimo sobre cap: ", (Allow_MinLot_Above_Cap ? "PERMITIDO" : "OMITIR SEÑAL"));
   Print("   Guardia DD: ", (Use_Total_Drawdown_Limit ? DoubleToString(Max_Total_Drawdown_Pct,1)+"% vs HWM" : "OFF"),
         " | flatten=", (DD_Flatten_Positions ? "SÍ" : "NO"), " | pausa=", DD_Pause_Hours, "h | HWM actual=", DoubleToString(g_hwm, 2),
         (g_dd_latched ? " | *** BLOQUEADO POR DD ***" : ""));
   PrintMinLotDiagnostic();           // [AUDIT-01]
   Print("════════════════════════════════════════════════════════════");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| [AUDIT-01] Diagnóstico de lote mínimo vs capital                 |
//+------------------------------------------------------------------+
void PrintMinLotDiagnostic()
{
   double minVol    = SymbolInfoDouble(symb, SYMBOL_VOLUME_MIN);
   double tickValue = SymbolInfoDouble(symb, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(symb, SYMBOL_TRADE_TICK_SIZE);
   double atr       = GetATRValue();
   double base      = RiskBase();
   if(tickSize <= 0.0 || tickValue <= 0.0 || base <= 0.0) return;
   double mppu = tickValue / tickSize;
   double sl_typ = (atr > 0.0) ? atr * ATR_SL_Multiplier : Min_SL_Points * point_val;
   double risk_min_lot = minVol * mppu * sl_typ;
   double cap_money = base * Hard_Risk_Cap_Percent / 100.0;
   double capital_needed = risk_min_lot / (Max_Risk_Percent / 100.0);
   Print("   [Lote mínimo] ", DoubleToString(minVol, 2), " lot | SL típico=", DoubleToString(sl_typ, g_Digits),
         " → riesgo con lote mínimo = $", DoubleToString(risk_min_lot, 2), " = ",
         DoubleToString(risk_min_lot / base * 100.0, 2), "% del capital (cap ", DoubleToString(Hard_Risk_Cap_Percent, 1), "% = $", DoubleToString(cap_money, 2), ")");
   Print("   [Lote mínimo] Capital necesario para operar al ", DoubleToString(Max_Risk_Percent, 2), "% con SL típico: $", DoubleToString(capital_needed, 0));
   if(risk_min_lot > cap_money)
      Print("   ⚠ CUENTA INFRACAPITALIZADA: la mayoría de las señales se omitirán (Allow_MinLot_Above_Cap=false).");
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   PrintDiagnosticSummary("RESUMEN FINAL");
   SavePersistentState();
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
//| [AUDIT-02][AUDIT-05] Persistencia (variables globales terminal)  |
//+------------------------------------------------------------------+
void LoadPersistentState()
{
   if(GlobalVariableCheck(GV("HWM")))       g_hwm = GlobalVariableGet(GV("HWM"));
   if(GlobalVariableCheck(GV("DDLATCH")))   g_dd_latched = (GlobalVariableGet(GV("DDLATCH")) > 0.5);
   if(GlobalVariableCheck(GV("DDUNTIL")))   g_dd_latched_until = (datetime)GlobalVariableGet(GV("DDUNTIL"));
   if(GlobalVariableCheck(GV("STREAK")))    g_consecutive_losses = (int)GlobalVariableGet(GV("STREAK"));
   if(GlobalVariableCheck(GV("PAUSE")))     g_pause_until = (datetime)GlobalVariableGet(GV("PAUSE"));

   if(g_dd_latched && DD_Manual_Reset)
   {
      Print("DD: reset manual solicitado. HWM re-basado a equity actual.");
      g_dd_latched = false;
      g_dd_latched_until = 0;
      g_hwm = AccountInfoDouble(ACCOUNT_EQUITY);
   }
   double eq = DD_Use_Equity_Peak ? AccountInfoDouble(ACCOUNT_EQUITY) : AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_hwm <= 0.0) g_hwm = eq;
   SavePersistentState();
}

void SavePersistentState()
{
   GlobalVariableSet(GV("HWM"), g_hwm);
   GlobalVariableSet(GV("DDLATCH"), g_dd_latched ? 1.0 : 0.0);
   GlobalVariableSet(GV("DDUNTIL"), (double)g_dd_latched_until);
   GlobalVariableSet(GV("STREAK"), (double)g_consecutive_losses);
   GlobalVariableSet(GV("PAUSE"), (double)g_pause_until);
}

//+------------------------------------------------------------------+
//| [AUDIT-05] Recuperar contadores del día y racha desde historial  |
//+------------------------------------------------------------------+
void RecoverDailyStateFromHistory()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime day_start = StructToTime(dt);

   if(!HistorySelect(day_start - 86400 * 30, TimeCurrent() + 3600)) return;

   int    trades_today   = 0;
   double realized_today = 0.0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) != symb) continue;
      if(!IsOurMagic(HistoryDealGetInteger(d, DEAL_MAGIC))) continue;
      datetime t = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
      ENUM_DEAL_ENTRY e = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY);
      if(t >= day_start)
      {
         if(e == DEAL_ENTRY_IN) trades_today++;
         if(e == DEAL_ENTRY_OUT || e == DEAL_ENTRY_OUT_BY)
            realized_today += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION);
      }
   }
   g_trades_today = MathMax(g_trades_today, trades_today);
   // Balance de inicio de día ≈ balance actual − P&L realizado hoy
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal - realized_today > 0.0) g_day_start_balance = bal - realized_today;

   // Racha de pérdidas: si no hay valor persistido, reconstruir desde los últimos cierres
   if(!GlobalVariableCheck(GV("STREAK")))
   {
      int streak = 0;
      for(int i = total - 1; i >= 0; i--)
      {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0) continue;
         if(HistoryDealGetString(d, DEAL_SYMBOL) != symb) continue;
         if(!IsOurMagic(HistoryDealGetInteger(d, DEAL_MAGIC))) continue;
         ENUM_DEAL_ENTRY e = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY);
         if(e != DEAL_ENTRY_OUT && e != DEAL_ENTRY_OUT_BY) continue;
         double p = HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION);
         if(p < 0.0) streak++; else break;
      }
      g_consecutive_losses = streak;
   }
   Print("Recuperación: trades hoy=", g_trades_today, " | P&L hoy=", DoubleToString(realized_today, 2),
         " | balance inicio día=", DoubleToString(g_day_start_balance, 2), " | racha=", g_consecutive_losses);
}

//+------------------------------------------------------------------+
//| OnTradeTransaction  [AUDIT-13]                                   |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != symb) return;
   long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(!IsOurMagic(magic)) return;

   ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   ulong pos_id = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   int   set_id = SetFromMagic(magic);

   bool has_exit  = (entry_type == DEAL_ENTRY_OUT || entry_type == DEAL_ENTRY_OUT_BY || entry_type == DEAL_ENTRY_INOUT);
   bool has_entry = (entry_type == DEAL_ENTRY_IN  || entry_type == DEAL_ENTRY_INOUT);
   if(!has_exit && !has_entry) return;

   // Salida primero (una reversión INOUT cierra la posición anterior y abre otra)
   if(has_exit) AccountExitDeal(trans.deal, pos_id, set_id);

   // Entrada
   if(has_entry)
   {
      ulong pos_ticket = trans.position;
      if(pos_ticket == 0)
      {
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong tk = PositionGetTicket(i);
            if(tk != 0 && (ulong)PositionGetInteger(POSITION_IDENTIFIER) == pos_id) { pos_ticket = tk; break; }
         }
      }
      g_cur_ticket  = pos_ticket;
      g_cur_pos_id  = pos_id;
      g_cur_set     = set_id;
      g_cur_open    = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
      g_cur_sl0     = HistoryDealGetDouble(trans.deal, DEAL_SL);
      g_cur_tp0     = HistoryDealGetDouble(trans.deal, DEAL_TP);
      g_cur_type    = (HistoryDealGetInteger(trans.deal, DEAL_TYPE) == DEAL_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      if(pos_ticket > 0 && PositionSelectByTicket(pos_ticket))
      {
         g_cur_open = PositionGetDouble(POSITION_PRICE_OPEN);
         if(PositionGetDouble(POSITION_SL) > 0.0) g_cur_sl0 = PositionGetDouble(POSITION_SL);
         if(PositionGetDouble(POSITION_TP) > 0.0) g_cur_tp0 = PositionGetDouble(POSITION_TP);
         g_cur_type = (int)PositionGetInteger(POSITION_TYPE);
      }
      g_cur_sl_dist = (g_cur_sl0 > 0.0) ? MathAbs(g_cur_open - g_cur_sl0) : 0.0;
      g_cur_tp_dist = (g_cur_tp0 > 0.0) ? MathAbs(g_cur_tp0 - g_cur_open) : 0.0;
      // Persistir R inicial para recuperación tras reinicio
      if(g_cur_sl_dist > 0.0)
      {
         GlobalVariableSet(GV("R_" + IntegerToString((long)pos_ticket)), g_cur_sl_dist);
         if(pos_id != pos_ticket) GlobalVariableSet(GV("R_" + IntegerToString((long)pos_id)), g_cur_sl_dist);
      }
      g_set_trades[set_id]++;
   }
}

//+------------------------------------------------------------------+
//| [AUDIT-13] Contabilidad de un deal de salida                     |
//+------------------------------------------------------------------+
void AccountExitDeal(ulong deal, ulong pos_id, int set_id)
{
   if(!HistoryDealSelect(deal)) return;
   double profit = HistoryDealGetDouble(deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(deal, DEAL_SWAP)
                 + HistoryDealGetDouble(deal, DEAL_COMMISSION);

   double tickValue = SymbolInfoDouble(symb, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(symb, SYMBOL_TRADE_TICK_SIZE);
   double moneyPerPriceUnitPerLot = (tickSize > 0) ? tickValue / tickSize : 0.0;

   // R y TP iniciales: de memoria si coincide el ticket, si no del historial
   double sl_dist = 0.0, tp_dist = 0.0;
   if(g_cur_ticket != 0 && (g_cur_pos_id == pos_id || g_cur_ticket == pos_id) && g_cur_sl_dist > 0.0)
   {
      sl_dist = g_cur_sl_dist;
      tp_dist = g_cur_tp_dist;
   }
   else
   {
      sl_dist = RiskDistanceFromHistory(pos_id, tp_dist);
      HistoryDealSelect(deal);   // HistorySelectByPosition cambió la selección; re-seleccionar el deal
   }

   double vol_closed = HistoryDealGetDouble(deal, DEAL_VOLUME);
   double tp_money   = tp_dist * moneyPerPriceUnitPerLot * vol_closed;
   double sl_money   = sl_dist * moneyPerPriceUnitPerLot * vol_closed;

   g_set_profit[set_id] += profit;
   if(profit > 0.0) g_set_wins[set_id]++;

   if(profit > 0.0)
   {
      if(tp_money > 0.0 && profit >= 0.8 * tp_money) { g_cnt_tp_full++;      g_sum_tp_full      += profit; }
      else                                            { g_cnt_gain_parcial++; g_sum_gain_parcial += profit; }

      // [AUDIT-08] solo una ganancia significativa resetea la racha
      bool meaningful = (sl_money <= 0.0) || (Streak_Reset_Min_R <= 0.0) || (profit >= Streak_Reset_Min_R * sl_money);
      if(meaningful) g_consecutive_losses = 0;
   }
   else
   {
      if(sl_money > 0.0 && MathAbs(profit) >= 0.8 * sl_money) { g_cnt_sl_full++;      g_sum_sl_full      += profit; }
      else                                                    { g_cnt_loss_parcial++; g_sum_loss_parcial += profit; }

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

   Print("CIERRE ", SetName(set_id), " pos#", pos_id, " P&L=", DoubleToString(profit, 2),
         " | R inicial $", DoubleToString(sl_money, 2), " → ", (sl_money > 0.0 ? DoubleToString(profit / sl_money, 2) : "n/a"), " R");

   int total = g_cnt_tp_full + g_cnt_gain_parcial + g_cnt_sl_full + g_cnt_loss_parcial;
   if(total > 0 && total % 50 == 0)
      PrintDiagnosticSummary("RESUMEN PARCIAL (" + IntegerToString(total) + " cierres)");

   // Si la posición ya no existe (cierre total), liberar el tracking
   bool still_open = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk != 0 && ((ulong)PositionGetInteger(POSITION_IDENTIFIER) == pos_id || tk == pos_id)) { still_open = true; break; }
   }
   if(!still_open)
   {
      if(g_cur_pos_id == pos_id || g_cur_ticket == pos_id) { g_cur_ticket = 0; g_cur_pos_id = 0; }
      if(GlobalVariableCheck(GV("R_" + IntegerToString((long)pos_id)))) GlobalVariableDel(GV("R_" + IntegerToString((long)pos_id)));
   }
   SavePersistentState();
}

//+------------------------------------------------------------------+
//| [AUDIT-05] R inicial desde el deal de entrada (historial)        |
//+------------------------------------------------------------------+
double RiskDistanceFromHistory(ulong pos_id, double &tp_dist_out)
{
   tp_dist_out = 0.0;
   if(pos_id == 0) return 0.0;
   if(GlobalVariableCheck(GV("R_" + IntegerToString((long)pos_id))))
   {
      double r = GlobalVariableGet(GV("R_" + IntegerToString((long)pos_id)));
      if(r > 0.0) return r;
   }
   if(!HistorySelectByPosition(pos_id)) return 0.0;
   int n = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
      double price = HistoryDealGetDouble(d, DEAL_PRICE);
      double sl    = HistoryDealGetDouble(d, DEAL_SL);
      double tp    = HistoryDealGetDouble(d, DEAL_TP);
      if(tp > 0.0 && price > 0.0) tp_dist_out = MathAbs(tp - price);
      if(sl > 0.0 && price > 0.0) return MathAbs(price - sl);
      // Fallback: comentario "R<pts>[F|C]"
      string cmt = HistoryDealGetString(d, DEAL_COMMENT);
      if(StringLen(cmt) > 1 && StringGetCharacter(cmt, 0) == 'R')
      {
         double pts = StringToDouble(StringSubstr(cmt, 1));
         if(pts > 0.0) return pts * point_val;
      }
   }
   return 0.0;
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
   // [AUDIT-03] atribución por set
   for(int s = 0; s < 2; s++)
   {
      if(g_set_trades[s] == 0) continue;
      Print("SET ", SetName(s), ": trades=", g_set_trades[s], " | ganadoras=", g_set_wins[s],
            " (", DoubleToString(100.0 * g_set_wins[s] / g_set_trades[s], 1), "%) | P&L=", DoubleToString(g_set_profit[s], 2));
   }
   Print("Señales omitidas por lote mínimo > cap: ", g_skipped_minlot);
   Print("HWM equity: ", DoubleToString(g_hwm, 2), " | DD actual vs HWM: ", DoubleToString(g_dd_last_pct, 2), "%",
         (g_dd_latched ? " | BLOQUEADO" : ""));
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
//| ATR (único indicador permitido) – [AUDIT-04] vela cerrada        |
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

   g_atr_value       = atr_buf[1];      // [AUDIT-04] ATR de la última vela CERRADA
   g_last_atr_update = current_bar;
   return g_atr_value;
}

double GetATRPct()
{
   double atr = GetATRValue();
   double close_price = iClose(symb, ATR_Timeframe, 1);   // [AUDIT-04]
   if(atr <= 0.0 || close_price <= 0.0) return 0.0;
   return (atr / close_price) * 100.0;
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
   double atr_pct = GetATRPct();
   if(atr_pct <= 0.0) return false;
   if(atr_pct < ATR_Min_Pct) return false;
   if(atr_pct > ATR_Max_Pct) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Filtro de sesión (hora del SERVIDOR)                             |
//+------------------------------------------------------------------+
bool CheckSessionFilter()
{
   if(!Use_Session_Filter) return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;

   // [AUDIT-12] corte de entradas los viernes
   if(dt.day_of_week == 5 && Friday_Entry_Cutoff_Hour < 24 && h >= Friday_Entry_Cutoff_Hour) return false;

   if(h >= Session_Start_Hour && h < Session_End_Hour) return true;
   if(Allow_Asia_Breakouts && h >= 0 && h < 7) return true;

   return false;
}

//+------------------------------------------------------------------+
//| [AUDIT-02] Guardia de equity dura (HWM + flatten + latch)        |
//+------------------------------------------------------------------+
double RiskBase()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   return Size_On_Equity ? MathMin(balance, equity) : balance;
}

void EquityGuardTick()
{
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double basis   = DD_Use_Equity_Peak ? equity : balance;

   if(basis > g_hwm)
   {
      g_hwm = basis;
      GlobalVariableSet(GV("HWM"), g_hwm);
   }
   if(g_hwm <= 0.0) return;

   g_dd_last_pct = (g_hwm - equity) / g_hwm * 100.0;
   if(!Use_Total_Drawdown_Limit) return;

   if(g_dd_latched)
   {
      if(DD_Pause_Hours > 0 && TimeCurrent() >= g_dd_latched_until)
      {
         g_dd_latched = false;
         g_dd_latched_until = 0;
         g_hwm = basis;               // re-base: nuevo presupuesto de DD desde aquí
         Print("DD: pausa terminada. HWM re-basado a ", DoubleToString(g_hwm, 2), ". Operativa reanudada.");
         SavePersistentState();
      }
      return;
   }

   if(g_dd_last_pct >= Max_Total_Drawdown_Pct)
   {
      g_dd_latched = true;
      g_dd_latched_until = (DD_Pause_Hours > 0) ? TimeCurrent() + DD_Pause_Hours * 3600 : 0;
      Print("🛑 GUARDIA DE EQUITY: drawdown ", DoubleToString(g_dd_last_pct, 2), "% >= ", DoubleToString(Max_Total_Drawdown_Pct, 1),
            "% (HWM=", DoubleToString(g_hwm, 2), ", equity=", DoubleToString(equity, 2), "). ",
            (DD_Flatten_Positions ? "Cerrando todo. " : ""),
            (DD_Pause_Hours > 0 ? "Bloqueado hasta " + TimeToString(g_dd_latched_until, TIME_DATE|TIME_MINUTES)
                                : "Bloqueado hasta reset manual (DD_Manual_Reset=true + reinicio)."));
      if(DD_Flatten_Positions) FlattenAll("DRAWDOWN");
      SavePersistentState();
   }
}

bool IsTradingLatched()
{
   return g_dd_latched;
}

//+------------------------------------------------------------------+
//| [AUDIT-02][AUDIT-12] Cerrar todas las posiciones y pendientes    |
//+------------------------------------------------------------------+
void FlattenAll(string reason)
{
   for(int attempt = 0; attempt < 3; attempt++)
   {
      bool remaining = false;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != symb) continue;
         if(!IsOurMagic(PositionGetInteger(POSITION_MAGIC))) continue;
         trade.SetExpertMagicNumber((ulong)PositionGetInteger(POSITION_MAGIC));
         if(!trade.PositionClose(ticket, (ulong)(Slippage_Points * 3)) || !SendOK())
         {
            remaining = true;
            Print("⚠ FLATTEN(", reason, "): fallo al cerrar #", ticket, " retcode=", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
         }
         else
            Print("FLATTEN(", reason, "): cerrada posición #", ticket);
      }
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0) continue;
         if(!OrderSelect(ticket)) continue;
         if(OrderGetString(ORDER_SYMBOL) != symb) continue;
         if(!IsOurMagic(OrderGetInteger(ORDER_MAGIC))) continue;
         if(!trade.OrderDelete(ticket) || !SendOK()) remaining = true;
         else Print("FLATTEN(", reason, "): pendiente #", ticket, " eliminada");
      }
      if(!remaining) break;
      Sleep(300);
   }
}

//+------------------------------------------------------------------+
//| [AUDIT-12] Cierre antes del fin de semana                        |
//+------------------------------------------------------------------+
void WeekendCloseTick()
{
   if(!Close_Before_Weekend) return;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week != 5 || dt.hour < Weekend_Close_Hour) return;
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime today = StructToTime(dt);
   if(g_weekend_closed_day == today) return;
   g_weekend_closed_day = today;
   if(CountOpenPositions() > 0 || CountPendingOrders() > 0)
      FlattenAll("WEEKEND");
}

//+------------------------------------------------------------------+
//| [AUDIT-12] Límite diario evaluado en cada tick                   |
//+------------------------------------------------------------------+
void DailyGuardTick()
{
   if(!Use_Daily_Loss_Limit || g_day_start_balance <= 0.0) return;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double loss_pct = (g_day_start_balance - equity) / g_day_start_balance * 100.0;
   if(loss_pct >= Max_Daily_Loss_Percent && !g_daily_limit_hit)
   {
      g_daily_limit_hit = true;
      Print("LÍMITE DE PÉRDIDA DIARIA ALCANZADO (", DoubleToString(loss_pct, 2), "%)",
            (Daily_Loss_Flatten ? " → cerrando posiciones" : " → sin nuevas entradas hoy"));
      if(Daily_Loss_Flatten) FlattenAll("DAILY_LOSS");
   }
}

//+------------------------------------------------------------------+
//| Posiciones / pendientes del EA                                   |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != symb) continue;
      if(!IsOurMagic(PositionGetInteger(POSITION_MAGIC))) continue;
      count++;
   }
   return count;
}

int CountPendingOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != symb) continue;
      if(!IsOurMagic(OrderGetInteger(ORDER_MAGIC))) continue;
      count++;
   }
   return count;
}

bool HasOpenExposure()   // [AUDIT-06]
{
   return (CountOpenPositions() > 0 || CountPendingOrders() > 0);
}

//+------------------------------------------------------------------+
//| Helpers de noticias (ventanas fijas – legado)                    |
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

   // [AUDIT-10] calendario económico
   if(Use_Calendar_Filter && IsCalendarBlocked(news_label)) return true;

   news_label = "";
   return false;
}

//+------------------------------------------------------------------+
//| [AUDIT-10] Calendario económico: vivo (MQL5 Calendar) o CSV      |
//+------------------------------------------------------------------+
int ImportanceFromString(string s)
{
   StringToUpper(s);
   if(s == "HIGH" || s == "3")     return (int)CALENDAR_IMPORTANCE_HIGH;
   if(s == "MODERATE" || s == "MEDIUM" || s == "2") return (int)CALENDAR_IMPORTANCE_MODERATE;
   if(s == "LOW" || s == "1")      return (int)CALENDAR_IMPORTANCE_LOW;
   return (int)CALENDAR_IMPORTANCE_NONE;
}

bool CurrencyWanted(string cur)
{
   string list = Calendar_Currencies;
   StringToUpper(list);
   StringToUpper(cur);
   string parts[];
   int n = StringSplit(list, ',', parts);
   for(int i = 0; i < n; i++)
   {
      string p = parts[i];
      StringTrimLeft(p); StringTrimRight(p);
      if(p == cur) return true;
   }
   return false;
}

void LoadCalendarEvents(bool force)
{
   bool csv_mode = (MQLInfoInteger(MQL_TESTER) || !g_calendar_available);
   if(!force && g_news_loaded_at != 0)
   {
      if(csv_mode) return;   // el CSV se carga una sola vez (cubre todo el período del backtest)
      if(TimeCurrent() - g_news_loaded_at < Calendar_Refresh_Min * 60) return;
   }
   g_news_loaded_at = TimeCurrent();

   if(csv_mode)
   {
      LoadCalendarFromCSV();
      return;
   }

   ArrayResize(g_news, 0);
   string parts[];
   int nc = StringSplit(Calendar_Currencies, ',', parts);
   datetime from = TimeTradeServer() - 2 * 86400;
   datetime to   = TimeTradeServer() + 7 * 86400;
   int added = 0;
   for(int c = 0; c < nc; c++)
   {
      string cur = parts[c];
      StringTrimLeft(cur); StringTrimRight(cur);
      StringToUpper(cur);
      if(cur == "") continue;
      MqlCalendarValue vals[];
      ResetLastError();
      // Compatible con ambas variantes documentadas de la firma (bool / int): rc>0 ok, rc==0 sin error ok, rc<0 o error → fallo
      int rc  = (int)CalendarValueHistory(vals, from, to, NULL, cur);
      int cerr = GetLastError();
      bool ok = (rc > 0) || (rc == 0 && cerr == 0);
      int n = ok ? ArraySize(vals) : 0;
      if(!ok)
      {
         int err = GetLastError();
         Print("CALENDARIO: CalendarValueHistory falló (", err, "). Usando CSV de respaldo.");
         g_calendar_available = false;
         LoadCalendarFromCSV();
         return;
      }
      for(int i = 0; i < n; i++)
      {
         MqlCalendarEvent ev;
         if(!CalendarEventById(vals[i].event_id, ev)) continue;
         if((int)ev.importance < (int)Calendar_Min_Importance) continue;
         int k = ArraySize(g_news);
         ArrayResize(g_news, k + 1);
         g_news[k].time       = vals[i].time;
         g_news[k].currency   = cur;
         g_news[k].importance = (int)ev.importance;
         g_news[k].name       = ev.name;
         added++;
      }
   }
   Print("CALENDARIO: ", added, " eventos cargados (", Calendar_Currencies, ", importancia >= ", EnumToString(Calendar_Min_Importance), ")");
}

void LoadCalendarFromCSV()
{
   ArrayResize(g_news, 0);
   if(Calendar_CSV_File == "") return;
   ResetLastError();
   int fh = FileOpen(Calendar_CSV_File, FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(fh == INVALID_HANDLE)
   {
      Print("CALENDARIO: no se pudo abrir Common\\Files\\", Calendar_CSV_File, " (", GetLastError(), "). Filtro de calendario INACTIVO.");
      return;
   }
   int added = 0;
   while(!FileIsEnding(fh))
   {
      string line = FileReadString(fh);
      StringTrimLeft(line); StringTrimRight(line);
      if(line == "" || StringGetCharacter(line, 0) == '#') continue;
      string f[];
      if(StringSplit(line, ';', f) < 3) continue;
      datetime t = StringToTime(f[0]);
      if(t <= 0) continue;
      string cur = f[1];
      StringTrimLeft(cur); StringTrimRight(cur);
      if(!CurrencyWanted(cur)) continue;
      int imp = ImportanceFromString(f[2]);
      if(imp < (int)Calendar_Min_Importance) continue;
      int k = ArraySize(g_news);
      ArrayResize(g_news, k + 1);
      g_news[k].time       = t;
      g_news[k].currency   = cur;
      g_news[k].importance = imp;
      g_news[k].name       = (ArraySize(f) > 3) ? f[3] : "evento";
      added++;
   }
   FileClose(fh);
   Print("CALENDARIO (CSV): ", added, " eventos cargados desde ", Calendar_CSV_File);
}

bool IsCalendarBlocked(string &label)
{
   LoadCalendarEvents(false);
   datetime now = TimeCurrent();
   int n = ArraySize(g_news);
   for(int i = 0; i < n; i++)
   {
      if(now >= g_news[i].time - Calendar_Block_Before_Min * 60 && now <= g_news[i].time + Calendar_Block_After_Min * 60)
      {
         label = g_news[i].currency + " " + g_news[i].name + " @" + TimeToString(g_news[i].time, TIME_MINUTES);
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   CheckNewTradingDay();
   UpdateSpreadSamples();

   EquityGuardTick();       // [AUDIT-02] antes que nada: puede cerrar todo
   DailyGuardTick();        // [AUDIT-12]
   WeekendCloseTick();      // [AUDIT-12]

   if(Use_Progressive_Protection) ManageProgressiveProtection();
   if(Use_Limit_Orders)           CleanupStalePendingOrders();

   string news_label;
   bool in_news = IsNewsTime(news_label);
   if(in_news != g_last_news_state)
   {
      if(in_news)
      {
         Print("FILTRO NOTICIAS: entrando en bloqueo → ", news_label);
         if(Use_Calendar_Filter && Calendar_Close_Positions && CountOpenPositions() > 0) FlattenAll("NEWS");
      }
      else Print("FILTRO NOTICIAS: bloqueo finalizado");
      g_last_news_state = in_news;
   }

   if(IsTradingLatched()) return;   // [AUDIT-02] bloqueado por DD: no evaluar señales

   // Set fijo H1  [AUDIT-03]
   if(Use_Fixed_Set)
   {
      datetime bar_fixed = iTime(symb, PERIOD_H1, 0);
      if(bar_fixed != 0 && bar_fixed != g_last_bar_fixed)
      {
         g_last_bar_fixed = bar_fixed;
         CheckTradingLogic(PERIOD_H1, Trend_Timeframe, PERIOD_D1, SET_FIXED);
      }
   }

   // Set personalizado (recomendado M5/H4)
   if(Use_Custom_Pair)
   {
      datetime bar_custom = iTime(symb, TF_Fast, 0);
      if(bar_custom != 0 && bar_custom != g_last_bar_custom)
      {
         g_last_bar_custom = bar_custom;
         CheckTradingLogic(TF_Fast, TF_Slow, TF_Slow, SET_CUSTOM);
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
void CheckTradingLogic(ENUM_TIMEFRAMES t1, ENUM_TIMEFRAMES t2, ENUM_TIMEFRAMES t3, int set_id)
{
   if(Bars(symb, t1) < Structure_Lookback + 8 || Bars(symb, t3) < 3) return;
   if(!CheckSessionFilter()) return;

   double h1_1 = iHigh(symb, t1, 1);
   double l1_1 = iLow (symb, t1, 1);
   double c1_1 = iClose(symb, t1, 1);
   if(h1_1 <= 0.0 || l1_1 <= 0.0 || c1_1 <= 0.0) return;

   // 1. Niveles de estructura (barras 2..Lookback+1: sin look-ahead)
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

   // 3. Confirmación multi-temporalidad (vela cerrada del TF superior)
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

   // 6. Scoring de calidad (1-6)
   double atr_pct = GetATRPct();   // [AUDIT-04]
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

      if(s >= min_str) ProcessSignal(1, iTime(symb, t1, 1), h1_1, s, set_id);
   }

   if(sell_signal)
   {
      int s = 1;
      if(structure_trend == -1)                                 s++;
      if(Require_HigherTF_Confirm && mtf_sell_ok)               s++;
      if(margin_sell >= Min_Breakout_ATR_Mult * 1.8 * atr_now)  s++;
      if(body_sell >= Min_Body_Ratio + 0.10)                    s++;
      if(sweet_spot)                                            s++;

      if(s >= min_str) ProcessSignal(2, iTime(symb, t1, 1), l1_1, s, set_id);
   }
}

//+------------------------------------------------------------------+
//| Procesar señal                                                   |
//+------------------------------------------------------------------+
void ProcessSignal(int type, datetime t, double price, int strength, int set_id)
{
   ExecuteTrade(type, price, strength, set_id);
   DrawSignalArrow(type, t, price, set_id);
}

//+------------------------------------------------------------------+
//| Dibujar flecha                                                   |
//+------------------------------------------------------------------+
void DrawSignalArrow(int type, datetime t, double price, int set_id)
{
   string name = "DOT_" + (type==1 ? "B" : "S") + (set_id == SET_CUSTOM ? "C" : "F") + "_" +
                 TimeToString(t, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "_" + IntegerToString(type);

   if(!ObjectCreate(0, name, OBJ_ARROW, 0, t, price)) return;

   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, (set_id == SET_CUSTOM ? 108 : 159));
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
//| [AUDIT-01] Cálculo de volumen dinámico con techo duro real       |
//+------------------------------------------------------------------+
double CalcDynamicVolume(int type, double entry_price, double sl_dist_price, double risk_pct, double &real_risk_pct, double &real_risk_money)
{
   real_risk_pct = 0.0;
   real_risk_money = 0.0;

   double base      = RiskBase();
   double tickValue = SymbolInfoDouble(symb, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(symb, SYMBOL_TRADE_TICK_SIZE);

   if(base <= 0.0 || tickSize <= 0.0 || tickValue <= 0.0 || sl_dist_price <= 0.0) return -1.0;

   // Riesgo por lote: OrderCalcProfit (moneda de cuenta, modo de cálculo del símbolo); fallback a tick value
   double moneyRiskPerLot = 0.0;
   double sl_price = (type == 1) ? entry_price - sl_dist_price : entry_price + sl_dist_price;
   double loss_one_lot = 0.0;
   if(entry_price > 0.0 && sl_price > 0.0 &&
      OrderCalcProfit((type == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, symb, 1.0, entry_price, sl_price, loss_one_lot))
      moneyRiskPerLot = MathAbs(loss_one_lot);
   if(moneyRiskPerLot <= 0.0)
      moneyRiskPerLot = sl_dist_price * (tickValue / tickSize);
   if(moneyRiskPerLot <= 0.0) return -1.0;

   double riskAmount = base * (MathMin(risk_pct, Hard_Risk_Cap_Percent) / 100.0);
   double capAmount  = base * (Hard_Risk_Cap_Percent / 100.0);
   double rawVol = riskAmount / moneyRiskPerLot;

   double minVol  = SymbolInfoDouble(symb, SYMBOL_VOLUME_MIN);
   double maxVol  = SymbolInfoDouble(symb, SYMBOL_VOLUME_MAX);
   double stepVol = SymbolInfoDouble(symb, SYMBOL_VOLUME_STEP);
   if(stepVol <= 0.0) stepVol = minVol;
   if(minVol <= 0.0 || stepVol <= 0.0) return -1.0;

   double vol = MathFloor(rawVol / stepVol + 1e-9) * stepVol;

   if(vol < minVol)
   {
      double minLotRisk = minVol * moneyRiskPerLot;
      if(minLotRisk > capAmount && !Allow_MinLot_Above_Cap)
      {
         g_skipped_minlot++;
         Print("⛔ Señal omitida: lote mínimo ", DoubleToString(minVol, 2), " implica riesgo $", DoubleToString(minLotRisk, 2),
               " = ", DoubleToString(minLotRisk / base * 100.0, 2), "% > Hard_Risk_Cap ", DoubleToString(Hard_Risk_Cap_Percent, 2),
               "% ($", DoubleToString(capAmount, 2), "). Capital insuficiente para este SL (", DoubleToString(sl_dist_price / point_val, 0), " pts).");
         return -1.0;
      }
      if(minLotRisk > capAmount)
         Print("⚠ Lote mínimo por encima del cap PERMITIDO por input: riesgo real ", DoubleToString(minLotRisk / base * 100.0, 2), "%");
      vol = minVol;
   }

   // Techo duro absoluto: nunca superar Hard_Risk_Cap_Percent si el step lo permite
   double capVol = MathFloor(capAmount / moneyRiskPerLot / stepVol + 1e-9) * stepVol;
   if(capVol >= minVol && vol > capVol) vol = capVol;
   if(vol > maxVol) vol = maxVol;

   // Límite de volumen total del símbolo (si el bróker lo impone)
   double volLimit = SymbolInfoDouble(symb, SYMBOL_VOLUME_LIMIT);
   if(volLimit > 0.0 && vol > volLimit) vol = MathFloor(volLimit / stepVol) * stepVol;
   if(vol < minVol) return -1.0;

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

   real_risk_money = vol * moneyRiskPerLot;
   real_risk_pct   = real_risk_money / base * 100.0;
   // Verificación final del techo duro (defensiva: cubre cualquier camino anterior)
   if(real_risk_money > capAmount + 1e-8 && !Allow_MinLot_Above_Cap)
   {
      g_skipped_minlot++;
      Print("⛔ Señal omitida: riesgo real ", DoubleToString(real_risk_pct, 2), "% > Hard_Risk_Cap ", DoubleToString(Hard_Risk_Cap_Percent, 2), "%");
      return -1.0;
   }
   return vol;
}

//+------------------------------------------------------------------+
//| Comentario de riesgo: "R<pts><F|C>"  [AUDIT-03]                  |
//+------------------------------------------------------------------+
string BuildRiskComment(double sl_dist_price, int set_id)
{
   long pts = (long)MathRound(sl_dist_price / point_val);
   if(pts < 1) pts = 1;
   if(pts > 999999) pts = 999999;
   return "R" + IntegerToString((int)pts) + (set_id == SET_CUSTOM ? "C" : "F");
}

//+------------------------------------------------------------------+
//| Recuperar distancia de riesgo inicial                            |
//+------------------------------------------------------------------+
double GetInitialRiskDistance(ulong ticket, double open_price, double current_sl)
{
   if(ticket == g_cur_ticket && g_cur_sl_dist > 0.0) return g_cur_sl_dist;

   // [AUDIT-05] 1) variable global / deal de entrada del historial
   double tp_tmp = 0.0;
   double r_hist = RiskDistanceFromHistory(ticket, tp_tmp);
   if(r_hist > 0.0) return r_hist;

   // 2) comentario de la posición
   string cmt = "";
   if(PositionSelectByTicket(ticket)) cmt = PositionGetString(POSITION_COMMENT);
   if(StringLen(cmt) > 1 && StringGetCharacter(cmt, 0) == 'R')
   {
      double pts = StringToDouble(StringSubstr(cmt, 1));
      if(pts > 0.0) return pts * point_val;
   }

   // 3) SL actual (puede estar ya movido por PP → R subestimado → gestión más conservadora)
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
   int found = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != symb) continue;
      long magic = PositionGetInteger(POSITION_MAGIC);
      if(!IsOurMagic(magic)) continue;

      found++;
      if(found > 1)
      {
         Print("⚠ RECUPERACIÓN: más de una posición del EA abierta (#", ticket, "). Solo se gestiona la primera en memoria; PP gestiona todas.");
         continue;
      }
      g_cur_ticket  = ticket;
      g_cur_pos_id  = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      g_cur_set     = SetFromMagic(magic);
      g_cur_open    = PositionGetDouble(POSITION_PRICE_OPEN);
      g_cur_sl0     = PositionGetDouble(POSITION_SL);
      g_cur_tp0     = PositionGetDouble(POSITION_TP);
      g_cur_type    = (int)PositionGetInteger(POSITION_TYPE);
      double tp_hist = 0.0;
      g_cur_sl_dist = RiskDistanceFromHistory(g_cur_pos_id, tp_hist);
      if(g_cur_sl_dist <= 0.0 && g_cur_pos_id != ticket) g_cur_sl_dist = RiskDistanceFromHistory(ticket, tp_hist);
      if(g_cur_sl_dist <= 0.0) g_cur_sl_dist = GetInitialRiskDistance(ticket, g_cur_open, g_cur_sl0);
      g_cur_tp_dist = (tp_hist > 0.0) ? tp_hist : ((g_cur_tp0 > 0.0) ? MathAbs(g_cur_tp0 - g_cur_open) : 0.0);
      Print("RECUPERACIÓN: posición #", ticket, " ", SetName(g_cur_set), " R=", DoubleToString(g_cur_sl_dist / point_val, 0), " pts",
            " (fuente: ", (tp_hist > 0.0 || g_cur_sl_dist > 0.0 ? "historial/GV" : "fallback"), ")");
   }
}

//+------------------------------------------------------------------+
//| Ejecutar operación                                               |
//+------------------------------------------------------------------+
void ExecuteTrade(int type, double signal_price, int strength, int set_id)
{
   if(HasOpenExposure()) return;                  // [AUDIT-06]
   if(IsTradingLatched()) return;                 // [AUDIT-02]

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
      if(g_daily_limit_hit || loss_pct >= Max_Daily_Loss_Percent)
      {
         if(!g_daily_limit_hit)
         {
            Print("LÍMITE DE PÉRDIDA DIARIA ALCANZADO (", DoubleToString(loss_pct, 2), "%)");
            g_daily_limit_hit = true;
         }
         return;
      }
   }

   if(TimeCurrent() - g_last_trade_time < Cooldown_Seconds) return;
   if(g_trades_today >= Max_Trades_Per_Day) return;

   double ask = SymbolInfoDouble(symb, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symb, SYMBOL_BID);
   double cur_spread = ask - bid;
   double cur_spread_pts = (point_val > 0.0) ? cur_spread / point_val : 0.0;
   double avg_spread = GetAverageSpread();
   double avg_spread_pts = (point_val > 0.0) ? avg_spread / point_val : 0.0;
   // [AUDIT-09] modo spread alto según promedio (más estable que el tick de apertura de vela)
   double mode_spread_pts = Use_Avg_Spread_For_Mode ? avg_spread_pts : cur_spread_pts;
   double mode_spread     = Use_Avg_Spread_For_Mode ? avg_spread : cur_spread;
   bool is_high_spread = (mode_spread_pts > HighSpread_Threshold);

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
      double atr_vs_spread = (mode_spread > 0.0) ? atr / mode_spread : 0.0;
      if(atr_vs_spread < HighSpread_ATR_Min_Mult)
      {
         Print("Señal omitida en spread alto: ATR/spread (", DoubleToString(atr_vs_spread, 2),
               ") < min (", DoubleToString(HighSpread_ATR_Min_Mult, 2), ")");
         return;
      }
      sl_mult  *= HighSpread_SL_Extra_Mult;
      risk_pct *= HighSpread_Risk_Reduction;
      Print("Spread alto (", DoubleToString(mode_spread_pts, 0),
            " pts): SL ×", DoubleToString(HighSpread_SL_Extra_Mult, 1),
            ", riesgo ×", DoubleToString(HighSpread_Risk_Reduction, 1));
   }

   risk_pct = MathMin(risk_pct, Max_Risk_Percent);
   risk_pct = MathMin(risk_pct, Hard_Risk_Cap_Percent);
   if(risk_pct <= 0.0) return;

   double sl_dist = atr * sl_mult;
   double tp_dist = atr * tp_mult;

   double spread_floor = avg_spread * Spread_Buffer_Multiplier;
   if(spread_floor > 0.0)
   {
      if(sl_dist < spread_floor) sl_dist = spread_floor;
      if(tp_dist < spread_floor) tp_dist = spread_floor;
   }

   double min_sl_dist = MathMax(stopLevel, Min_SL_Points * point_val);
   if(sl_dist < min_sl_dist) sl_dist = min_sl_dist;

   double real_risk_pct = 0.0, real_risk_money = 0.0;
   double vol = CalcDynamicVolume(type, entry, sl_dist, risk_pct, real_risk_pct, real_risk_money);
   if(vol <= 0.0)
   {
      Print("No se pudo calcular un volumen dentro del cap de riesgo. Señal omitida.");
      return;
   }

   string cmt = BuildRiskComment(sl_dist, set_id);
   trade.SetExpertMagicNumber(set_id == SET_CUSTOM ? MAGIC_CUSTOM : MAGIC_FIXED);   // [AUDIT-03]
   bool sent = false;
   double sl = 0.0, tp = 0.0;

   // Modo de expiración soportado por el símbolo para órdenes pendientes
   ENUM_ORDER_TYPE_TIME time_mode = ORDER_TIME_GTC;
   datetime expiration = 0;
   if(Use_Limit_Orders)
   {
      long exp_modes = SymbolInfoInteger(symb, SYMBOL_EXPIRATION_MODE);
      if((exp_modes & SYMBOL_EXPIRATION_SPECIFIED) != 0) { time_mode = ORDER_TIME_SPECIFIED; expiration = TimeCurrent() + Limit_Expiration_Minutes * 60; }
      else if((exp_modes & SYMBOL_EXPIRATION_GTC) != 0)  { time_mode = ORDER_TIME_GTC; }
      else if((exp_modes & SYMBOL_EXPIRATION_DAY) != 0)  { time_mode = ORDER_TIME_DAY; }
      // Si no hay SPECIFIED, CleanupStalePendingOrders() sigue caducando las pendientes por tiempo
   }

   if(Use_Limit_Orders)
   {
      double price = NormalizeTradePrice(signal_price);
      if(type == 1)
      {
         if(price < ask - stopLevel)
         {
            // [AUDIT-06] SL/TP relativos al precio límite; stoplimit = 0
            sl = NormalizeTradePrice(price - sl_dist);
            tp = NormalizeTradePrice(price + tp_dist);
            sent = trade.OrderOpen(symb, ORDER_TYPE_BUY_LIMIT, vol, 0.0, price, sl, tp, time_mode, expiration, cmt) && SendOK();
            entry = price;
         }
         else
         {
            sl = NormalizeTradePrice(entry - sl_dist);
            tp = NormalizeTradePrice(entry + tp_dist);
            sent = trade.PositionOpen(symb, ORDER_TYPE_BUY, vol, ask, sl, tp, cmt) && SendOK();
         }
      }
      else
      {
         if(price > bid + stopLevel)
         {
            sl = NormalizeTradePrice(price + sl_dist);
            tp = NormalizeTradePrice(price - tp_dist);
            sent = trade.OrderOpen(symb, ORDER_TYPE_SELL_LIMIT, vol, 0.0, price, sl, tp, time_mode, expiration, cmt) && SendOK();
            entry = price;
         }
         else
         {
            sl = NormalizeTradePrice(entry + sl_dist);
            tp = NormalizeTradePrice(entry - tp_dist);
            sent = trade.PositionOpen(symb, ORDER_TYPE_SELL, vol, bid, sl, tp, cmt) && SendOK();
         }
      }
   }
   else
   {
      sl = NormalizeTradePrice((type == 1) ? entry - sl_dist : entry + sl_dist);
      tp = NormalizeTradePrice((type == 1) ? entry + tp_dist : entry - tp_dist);
      if(type == 1) sent = trade.PositionOpen(symb, ORDER_TYPE_BUY,  vol, ask, sl, tp, cmt) && SendOK();
      else          sent = trade.PositionOpen(symb, ORDER_TYPE_SELL, vol, bid, sl, tp, cmt) && SendOK();
   }

   if(sent)
   {
      g_last_trade_time = TimeCurrent();
      g_trades_today++;
      g_last_real_risk_pct   = real_risk_pct;
      g_last_real_risk_money = real_risk_money;

      Print("═══════════════════════════════════════════");
      Print("✅ ", (type==1 ? "BUY" : "SELL"), " EJECUTADA (v14.1) | SET ", SetName(set_id), " | magic ", (set_id == SET_CUSTOM ? MAGIC_CUSTOM : MAGIC_FIXED));
      Print("   Entrada: ", DoubleToString(entry, g_Digits));
      Print("   SL: ", DoubleToString(sl, g_Digits), " (", DoubleToString(sl_dist/point_val, 0), " pts)");
      Print("   TP: ", DoubleToString(tp, g_Digits), " (", DoubleToString(tp_dist/point_val, 0), " pts)");
      Print("   Lote: ", DoubleToString(vol, 2));
      Print("   ATR: ", DoubleToString(atr, g_Digits), " | Riesgo objetivo: ", DoubleToString(risk_pct, 2),
            "% | RIESGO REAL: ", DoubleToString(real_risk_pct, 2), "% ($", DoubleToString(real_risk_money, 2), ") [cap ",
            DoubleToString(Hard_Risk_Cap_Percent, 2), "%]");
      Print("   Fuerza: ", strength, "/", MAX_SIGNAL_STRENGTH,
            " | Spread: ", DoubleToString(cur_spread_pts, 0), " pts (prom ", DoubleToString(avg_spread_pts, 0), ")");
      string trend_str = (g_last_structure_trend==1) ? "ALCISTA ↑" :
                         (g_last_structure_trend==-1) ? "BAJISTA ↓" : "SIN TENDENCIA →";
      Print("   Estructura: ", trend_str);
      Print("═══════════════════════════════════════════");
   }
   else
   {
      Print("❌ ERROR al enviar orden (", (type==1?"BUY":"SELL"), " ", SetName(set_id),
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
      if(ticket == 0) continue;
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != symb) continue;
      if(!IsOurMagic(OrderGetInteger(ORDER_MAGIC))) continue;

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
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != symb) continue;
      if(!IsOurMagic(PositionGetInteger(POSITION_MAGIC))) continue;

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
         // Etapa 4: trailing ATR + estructura (velas cerradas del ATR_Timeframe)
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

      if(!trade.PositionModify(ticket, NormalizeTradePrice(candidate_sl), tp))
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
   double atr_pct = GetATRPct();

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double float_dd = (balance > 0.0) ? (balance - equity) / balance * 100.0 : 0.0;

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
      pos_status = (type == POSITION_TYPE_BUY ? "BUY" : "SELL") + " " + (g_cur_set == SET_CUSTOM ? "[C]" : "[F]") +
                   " | R = " + DoubleToString(r_mult, 2);
   }
   else if(CountPendingOrders() > 0) pos_status = "Orden pendiente activa";

   string lines[];
   int n = 0;
   ArrayResize(lines, 90);

   lines[n++] = "====== OHLCMTF SCALPER v14.1 AUDIT ======";
   lines[n++] = "";
   lines[n++] = g_dd_latched ? (">>> BLOQUEADO POR DRAWDOWN " + (DD_Pause_Hours > 0 ? "hasta " + TimeToString(g_dd_latched_until, TIME_DATE|TIME_MINUTES) : "(reset manual)") + " <<<")
              : (blocked ? (">>> BLOQUEADO POR NOTICIA: " + news_label + " <<<")
              : (in_pause ? ">>> EN PAUSA POR RACHA DE PÉRDIDAS <<<"
              : (g_daily_limit_hit ? ">>> LÍMITE DE PÉRDIDA DIARIA ALCANZADO <<<"
              : ">>> ESTADO: OPERANDO <<<")));
   lines[n++] = "";

   lines[n++] = "--- SETS DE SEÑALES ---";
   lines[n++] = "FIJO   H1/" + EnumToString(Trend_Timeframe) + "/D1: " + (Use_Fixed_Set ? "ON " : "OFF") +
                " | trades " + IntegerToString(g_set_trades[SET_FIXED]) + " | P&L " + DoubleToString(g_set_profit[SET_FIXED], 2);
   lines[n++] = "CUSTOM " + EnumToString(TF_Fast) + "/" + EnumToString(TF_Slow) + ": " + (Use_Custom_Pair ? "ON " : "OFF") +
                " | trades " + IntegerToString(g_set_trades[SET_CUSTOM]) + " | P&L " + DoubleToString(g_set_profit[SET_CUSTOM], 2);
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

   lines[n++] = "--- ATR / SL-TP (vela cerrada) ---";
   lines[n++] = "ATR: " + DoubleToString(atr_val, g_Digits) + " (" + DoubleToString(atr_pct, 3) + "%)";
   lines[n++] = "SL = ATR × " + DoubleToString(ATR_SL_Multiplier, 1) + " | TP = ATR × " + DoubleToString(ATR_TP_Multiplier, 1);
   lines[n++] = "";

   lines[n++] = "--- RIESGO DINÁMICO ---";
   lines[n++] = "Rango: " + DoubleToString(Min_Risk_Percent, 2) + "% – " + DoubleToString(Max_Risk_Percent, 2) +
                 "% (techo " + DoubleToString(Hard_Risk_Cap_Percent, 1) + "%)";
   lines[n++] = "Último riesgo REAL: " + DoubleToString(g_last_real_risk_pct, 2) + "% ($" + DoubleToString(g_last_real_risk_money, 2) + ")" +
                 " | omitidas por lote mín: " + IntegerToString(g_skipped_minlot);
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
   if((Use_Avg_Spread_For_Mode ? avg_spread_pts : cur_spread_pts) > HighSpread_Threshold)
      lines[n++] = ">>> MODO SPREAD ALTO ACTIVO <<<";
   lines[n++] = "";

   lines[n++] = "--- PROTECCIÓN DE CAPITAL ---";
   lines[n++] = "Pérdida diaria: " + (Use_Daily_Loss_Limit
                  ? DoubleToString(daily_loss_pct, 2) + "% / " + DoubleToString(Max_Daily_Loss_Percent, 1) + "%"
                  : "desactivado");
   lines[n++] = "Racha pérdidas: " + IntegerToString(g_consecutive_losses) + " / " + IntegerToString(Max_Consecutive_Losses) +
                 (in_pause ? "  [PAUSADO]" : "");
   lines[n++] = "DD vs HWM: " + DoubleToString(g_dd_last_pct, 2) + "% / " +
                 (Use_Total_Drawdown_Limit ? DoubleToString(Max_Total_Drawdown_Pct, 1) + "%" : "desactivado") +
                 " | HWM " + DoubleToString(g_hwm, 2) + " | flotante " + DoubleToString(float_dd, 2) + "%";
   lines[n++] = "Trades hoy: " + IntegerToString(g_trades_today) + " / " + IntegerToString(Max_Trades_Per_Day);
   lines[n++] = "";

   lines[n++] = "--- FILTRO DE NOTICIAS ---";
   lines[n++] = FormatNewsLine("N1", News1_Enable, News1_Name, News1_Start_Hour, News1_Start_Min, News1_End_Hour, News1_End_Min);
   lines[n++] = FormatNewsLine("N2", News2_Enable, News2_Name, News2_Start_Hour, News2_Start_Min, News2_End_Hour, News2_End_Min);
   lines[n++] = FormatNewsLine("N3", News3_Enable, News3_Name, News3_Start_Hour, News3_Start_Min, News3_End_Hour, News3_End_Min);
   lines[n++] = FormatNewsLine("N4", News4_Enable, News4_Name, News4_Start_Hour, News4_Start_Min, News4_End_Hour, News4_End_Min);
   lines[n++] = "Calendario: " + (Use_Calendar_Filter ? (IntegerToString(ArraySize(g_news)) + " eventos " + Calendar_Currencies +
                 " ±" + IntegerToString(Calendar_Block_Before_Min) + "/" + IntegerToString(Calendar_Block_After_Min) + " min") : "(off)");
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
