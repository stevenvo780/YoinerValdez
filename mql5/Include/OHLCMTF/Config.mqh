#ifndef OHLCMTF_CONFIG_MQH
#define OHLCMTF_CONFIG_MQH
#include <OHLCMTF/Types.mqh>

input group "=== 1. STRUCTURE BREAKOUT (ENTRY CORE) ==="
input int    Structure_Lookback          = 10;
input double Min_Breakout_ATR_Mult       = 0.28;
input double Max_Breakout_ATR_Mult       = 2.20;
input double Min_Body_Ratio              = 0.55;
input double Max_Against_Wick_Ratio      = 0.35;
input bool   Require_Close_Beyond        = true;
input bool   Prefer_Expansion_Break      = false;

input group "=== 2. STRUCTURE TREND FILTER ==="
input int    Trend_Lookback              = 28;
input ENUM_TIMEFRAMES Trend_Timeframe    = PERIOD_H4;
input int    Min_Swing_Confirmations     = 2;
input bool   Require_Trend_Alignment     = true;
input bool   Block_When_No_Trend         = true;

input group "=== 3. MULTI-TIMEFRAME CONFIRMATION ==="
input bool   Enable_Buy_Signals          = true;
input bool   Enable_Sell_Signals         = true;
input bool   Require_HigherTF_Confirm    = true;

input group "=== 4. TIMEFRAMES & ORDER TYPE ==="
input bool   Use_Fixed_Set               = true;    // Set fijo H1 / Trend_Timeframe / D1
input bool   Use_Custom_Pair             = true;    // Set custom TF_Fast / TF_Slow / TF_Slow
input ENUM_TIMEFRAMES TF_Fast            = PERIOD_M5;
input ENUM_TIMEFRAMES TF_Slow            = PERIOD_H4;
input bool   Use_Limit_Orders            = false;
input int    Limit_Expiration_Minutes    = 90;

input group "=== 5. ATR (VOLATILITY) ==="
input int    ATR_Period                  = 14;
input ENUM_TIMEFRAMES ATR_Timeframe      = PERIOD_H1;
input double ATR_SL_Multiplier           = 1.80;
input double ATR_TP_Multiplier           = 3.0;

input group "=== 6. DYNAMIC RISK BY QUALITY ==="
input double Min_Risk_Percent            = 0.25;
input double Max_Risk_Percent            = 1.25;
input double Hard_Risk_Cap_Percent       = 2.50;
input int    Min_Signal_Strength         = 4;
input bool   Allow_MinLot_Above_Cap      = false;   // true = permitir lote mínimo aunque exceda el techo (NO recomendado)
input bool   Size_On_Equity              = true;    // base de riesgo = min(balance, equity)

input group "=== 7. BROKER CONSTRAINTS ==="
input int    Min_SL_Points               = 180;
input int    Slippage_Points             = 40;

input group "=== 8. SPREAD CONTROL ==="
input int    Spread_Sample_Size          = 25;
input double Max_Spread_Points           = 0;       // 0 = desactivado
input double Spread_Buffer_Multiplier    = 1.60;
input double HighSpread_Threshold        = 28.0;
input double HighSpread_ATR_Min_Mult     = 1.80;
input double HighSpread_Risk_Reduction   = 0.45;
input double HighSpread_SL_Extra_Mult    = 1.35;
input bool   Use_Avg_Spread_For_Mode     = true;    // modo spread alto según promedio muestreado

input group "=== 9. ANTI-OVERTRADING ==="
input int    Cooldown_Seconds            = 180;
input int    Max_Trades_Per_Day          = 6;

input group "=== 10. VOLATILITY FILTER ==="
input bool   Use_Volatility_Filter       = true;
input double ATR_Min_Pct                 = 0.025;
input double ATR_Max_Pct                 = 1.80;

input group "=== 11. SESSION FILTER (hora del servidor) ==="
input bool   Use_Session_Filter          = true;
input int    Session_Start_Hour          = 7;
input int    Session_End_Hour            = 20;
input bool   Allow_Asia_Breakouts        = false;
input int    Friday_Entry_Cutoff_Hour    = 24;      // 24 = sin corte

input group "=== 12. PROGRESSIVE PROTECTION ==="
input bool   Use_Progressive_Protection  = false;
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

input group "=== 13. CAPITAL PROTECTION ==="
input bool   Use_Daily_Loss_Limit        = true;
input double Max_Daily_Loss_Percent      = 4.50;
input bool   Daily_Loss_Flatten          = false;   // cerrar posiciones al alcanzar el límite diario
input bool   Use_Loss_Streak_Guard       = true;
input int    Max_Consecutive_Losses      = 3;
input int    Loss_Streak_Pause_Minutes   = 90;
input double Streak_Reset_Min_R          = 0.25;    // ganancia mínima (en R) que resetea la racha; 0 = cualquiera
input bool   Use_Total_Drawdown_Limit    = true;
input double Max_Total_Drawdown_Pct      = 12.0;    // medido contra el máximo histórico (HWM)
input bool   DD_Use_Equity_Peak          = true;    // HWM sobre equity (true) o balance (false)
input bool   DD_Flatten_Positions        = true;    // cerrar todo al superar el límite
input int    DD_Pause_Hours              = 72;      // 0 = requiere DD_Manual_Reset
input bool   DD_Manual_Reset             = false;   // true + reinicio = levantar bloqueo
input bool   Close_Before_Weekend        = false;
input int    Weekend_Close_Hour          = 21;

input group "=== 14. NEWS: CALENDAR FILTER ==="
input bool   Use_Calendar_Filter         = false;
input string Calendar_Currencies         = "USD";
input ENUM_CALENDAR_EVENT_IMPORTANCE Calendar_Min_Importance = CALENDAR_IMPORTANCE_HIGH;
input int    Calendar_Block_Before_Min   = 30;
input int    Calendar_Block_After_Min    = 30;
input bool   Calendar_Close_Positions    = false;
input string Calendar_CSV_File           = "news_events.csv";   // Common\Files, hora servidor: YYYY.MM.DD HH:MM;CUR;HIGH;Nombre
input int    Calendar_Refresh_Min        = 30;

input group "=== 15. NEWS: FIXED WINDOWS (legacy) ==="
input bool   News1_Enable = false; input string News1_Name = "Noticia 1"; input int News1_Start_Hour = 8;  input int News1_Start_Min = 30; input int News1_End_Hour = 9;  input int News1_End_Min = 0;
input bool   News2_Enable = false; input string News2_Name = "Noticia 2"; input int News2_Start_Hour = 14; input int News2_Start_Min = 25; input int News2_End_Hour = 14; input int News2_End_Min = 45;
input bool   News3_Enable = false; input string News3_Name = "Noticia 3"; input int News3_Start_Hour = 15; input int News3_Start_Min = 55; input int News3_End_Hour = 16; input int News3_End_Min = 15;
input bool   News4_Enable = false; input string News4_Name = "Noticia 4"; input int News4_Start_Hour = 20; input int News4_Start_Min = 0;  input int News4_End_Hour = 20; input int News4_End_Min = 30;

input group "=== 16. VISUAL PANEL & LOG ==="
input bool   Panel_Show                  = true;
input int    Panel_X                     = 12;
input int    Panel_Y                     = 20;
input int    Panel_Font_Size             = 10;
input int    Panel_Refresh_Sec           = 1;
input int    Max_Signal_Arrows           = 250;
input bool   Log_To_File                 = false;   // duplicar el log en Files\OHLCMTF_<símbolo>.log
input bool   Log_Verbose                 = false;   // registrar también señales descartadas

bool ValidateInputs()
{
   bool ok = true;
   #define FAIL(msg) { Print("INPUT: ", msg); ok = false; }
   if(Structure_Lookback < 3)                          FAIL("Structure_Lookback >= 3")
   if(Min_Breakout_ATR_Mult < 0.0)                     FAIL("Min_Breakout_ATR_Mult >= 0")
   if(Max_Breakout_ATR_Mult <= Min_Breakout_ATR_Mult)  FAIL("Max_Breakout_ATR_Mult > Min_Breakout_ATR_Mult")
   if(Min_Body_Ratio < 0.0 || Min_Body_Ratio > 1.0)    FAIL("Min_Body_Ratio en [0,1]")
   if(Max_Against_Wick_Ratio < 0.0)                    FAIL("Max_Against_Wick_Ratio >= 0")
   if(Trend_Lookback < 6)                              FAIL("Trend_Lookback >= 6")
   if(Min_Swing_Confirmations < 1 || Min_Swing_Confirmations > 3) FAIL("Min_Swing_Confirmations en [1,3]")
   if(!Use_Fixed_Set && !Use_Custom_Pair)              FAIL("ambos sets desactivados")
   if(Use_Custom_Pair && PeriodSeconds(TF_Fast) >= PeriodSeconds(TF_Slow)) FAIL("TF_Fast < TF_Slow")
   if(Limit_Expiration_Minutes < 1)                    FAIL("Limit_Expiration_Minutes >= 1")
   if(ATR_Period < 2)                                  FAIL("ATR_Period >= 2")
   if(ATR_SL_Multiplier <= 0.0 || ATR_TP_Multiplier <= 0.0) FAIL("multiplicadores ATR > 0")
   if(Min_Risk_Percent <= 0.0)                         FAIL("Min_Risk_Percent > 0")
   if(Max_Risk_Percent < Min_Risk_Percent)             FAIL("Max_Risk_Percent >= Min_Risk_Percent")
   if(Hard_Risk_Cap_Percent < Max_Risk_Percent)        FAIL("Hard_Risk_Cap_Percent >= Max_Risk_Percent")
   if(Hard_Risk_Cap_Percent > 10.0)                    FAIL("Hard_Risk_Cap_Percent > 10% es imprudente")
   if(Min_Signal_Strength < 1 || Min_Signal_Strength > MAX_SIGNAL_STRENGTH) FAIL("Min_Signal_Strength en [1,6]")
   if(Min_SL_Points < 0 || Slippage_Points < 0)        FAIL("Min_SL_Points / Slippage_Points >= 0")
   if(Spread_Sample_Size < 1)                          FAIL("Spread_Sample_Size >= 1")
   if(Spread_Buffer_Multiplier < 0.0)                  FAIL("Spread_Buffer_Multiplier >= 0")
   if(HighSpread_Risk_Reduction <= 0.0 || HighSpread_Risk_Reduction > 1.0) FAIL("HighSpread_Risk_Reduction en (0,1]")
   if(HighSpread_SL_Extra_Mult < 1.0)                  FAIL("HighSpread_SL_Extra_Mult >= 1")
   if(Cooldown_Seconds < 0)                            FAIL("Cooldown_Seconds >= 0")
   if(Max_Trades_Per_Day < 1)                          FAIL("Max_Trades_Per_Day >= 1")
   if(Use_Volatility_Filter && ATR_Max_Pct <= ATR_Min_Pct) FAIL("ATR_Max_Pct > ATR_Min_Pct")
   if(Session_Start_Hour < 0 || Session_Start_Hour > 23 || Session_End_Hour < 1 || Session_End_Hour > 24) FAIL("horas de sesión fuera de rango")
   if(Use_Session_Filter && Session_Start_Hour >= Session_End_Hour) FAIL("Session_Start_Hour < Session_End_Hour")
   if(Friday_Entry_Cutoff_Hour < 0 || Friday_Entry_Cutoff_Hour > 24) FAIL("Friday_Entry_Cutoff_Hour en [0,24]")
   if(Use_Progressive_Protection)
   {
      if(PP_Stage1_R <= 0.0 || PP_Stage1_R >= PP_Stage2_R || PP_Stage2_R >= PP_Stage3_R || PP_Stage3_R >= PP_Trail_Start_R) FAIL("etapas PP crecientes: 0 < S1 < S2 < S3 < Trail")
      if(PP_Stage1_SL_R <= 0.0 || PP_Stage1_SL_R >= 1.0) FAIL("PP_Stage1_SL_R en (0,1)")
      if(PP_Lock_Fraction <= 0.0 || PP_Lock_Fraction >= 1.0) FAIL("PP_Lock_Fraction en (0,1)")
      if(PP_Trail_ATR_Mult <= 0.0 || PP_Trail_Structure_Lookback < 1) FAIL("trailing inválido")
      if(PP_BE_Buffer_Points < 0.0 || PP_Min_Step_Points < 0.0) FAIL("buffers PP >= 0")
   }
   if(Max_Daily_Loss_Percent <= 0.0 || Max_Daily_Loss_Percent > 50.0) FAIL("Max_Daily_Loss_Percent en (0,50]")
   if(Max_Consecutive_Losses < 1 || Loss_Streak_Pause_Minutes < 0) FAIL("racha inválida")
   if(Streak_Reset_Min_R < 0.0)                        FAIL("Streak_Reset_Min_R >= 0")
   if(Max_Total_Drawdown_Pct <= 0.0 || Max_Total_Drawdown_Pct > 90.0) FAIL("Max_Total_Drawdown_Pct en (0,90]")
   if(DD_Pause_Hours < 0)                              FAIL("DD_Pause_Hours >= 0")
   if(Weekend_Close_Hour < 0 || Weekend_Close_Hour > 23) FAIL("Weekend_Close_Hour en [0,23]")
   if(Calendar_Block_Before_Min < 0 || Calendar_Block_After_Min < 0 || Calendar_Refresh_Min < 1) FAIL("calendario inválido")
   int nh[8], nm[8];
   nh[0] = News1_Start_Hour; nh[1] = News1_End_Hour; nh[2] = News2_Start_Hour; nh[3] = News2_End_Hour;
   nh[4] = News3_Start_Hour; nh[5] = News3_End_Hour; nh[6] = News4_Start_Hour; nh[7] = News4_End_Hour;
   nm[0] = News1_Start_Min;  nm[1] = News1_End_Min;  nm[2] = News2_Start_Min;  nm[3] = News2_End_Min;
   nm[4] = News3_Start_Min;  nm[5] = News3_End_Min;  nm[6] = News4_Start_Min;  nm[7] = News4_End_Min;
   for(int i = 0; i < 8; i++)
      if(nh[i] < 0 || nh[i] > 23 || nm[i] < 0 || nm[i] > 59) FAIL("ventana de noticias fuera de rango")
   if(Panel_Font_Size < 6 || Panel_Refresh_Sec < 1 || Max_Signal_Arrows < 0) FAIL("panel inválido")
   #undef FAIL
   if(ATR_Timeframe != PERIOD_H1)
      Print("AVISO: ATR_Timeframe != H1; SL/TP y margen de ruptura de ambos sets usan este ATR.");
   if(Use_Custom_Pair && PeriodSeconds(ATR_Timeframe) > PeriodSeconds(TF_Fast))
      Print("AVISO: el set custom entra en ", EnumToString(TF_Fast), " con SL/TP de ATR(", EnumToString(ATR_Timeframe), ").");
   return ok;
}

#endif
