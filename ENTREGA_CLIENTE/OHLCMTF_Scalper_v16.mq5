//+------------------------------------------------------------------+
//| OHLCMTF_Scalper_v16.mq5 — ARCHIVO ÚNICO generado                  |
//| a partir de Experts/OHLCMTF + Include/OHLCMTF (no editar a mano;  |
//| regenerar con build_single_file.py). Misma lógica que el modular. |
//| Identificación: OHLCMTF SCALPER v16                               |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                            OHLCMTF_Scalper.mq5   |
//|   XAU/USD Pure Price Action Structure Scalper v16 (modular)      |
//|   Lógica: v15 + defaults medidos sobre el M1 Dukascopy completo  |
//|   Módulos en Include/OHLCMTF/*.mqh                                |
//+------------------------------------------------------------------+
#property strict
#property copyright "OHLCMTF SCALPER v16 - Pure Price Action XAUUSD"
#property version   "16.00"
#property description "Structure breakout scalper XAUUSD v16, guardia de equity dura, sin protección progresiva"

//==================== Context.mqh ====================
//==================== Types.mqh ====================

#define OHLC_VERSION   "16.00"
#define MAGIC_FIXED    20260914
#define MAGIC_CUSTOM   20260915
#define GV_PREFIX      "OHLC16_"
#define PANEL_PREFIX   "OHLCMTF_v16_"

enum ENUM_SIGNAL_SET { SET_FIXED = 0, SET_CUSTOM = 1 };

const int MAX_SIGNAL_STRENGTH = 6;

struct SSignal
{
   int      direction;      // 1 buy, -1 sell
   int      strength;       // 1..6
   int      set_id;         // ENUM_SIGNAL_SET
   int      trend;          // -1/0/1
   double   atr;
   double   price;          // high/low de la vela de ruptura
   datetime bar_time;
   double   margin;
   double   body_ratio;
};

struct SPositionState
{
   ulong    ticket;
   ulong    pos_id;
   double   open;
   double   sl0;
   double   tp0;
   double   sl_dist;
   double   tp_dist;
   int      type;
   int      set_id;
   void Clear() { ticket = 0; pos_id = 0; open = 0; sl0 = 0; tp0 = 0; sl_dist = 0; tp_dist = 0; type = 0; set_id = SET_FIXED; }
};

struct SSizing
{
   double   volume;
   double   risk_money;
   double   risk_pct;
   double   base;
   bool     skipped;
   string   reason;
};

string g_symbol;
double g_point;
int    g_digits;

void InitSymbolContext()
{
   g_symbol = _Symbol;
   g_point  = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   g_digits = (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS);
}

bool IsOurMagic(long m)        { return (m == (long)MAGIC_FIXED || m == (long)MAGIC_CUSTOM); }
int  SetFromMagic(long m)      { return (m == (long)MAGIC_CUSTOM) ? SET_CUSTOM : SET_FIXED; }
ulong MagicForSet(int set_id)  { return (set_id == SET_CUSTOM) ? (ulong)MAGIC_CUSTOM : (ulong)MAGIC_FIXED; }
string SetTag(int set_id)      { return (set_id == SET_CUSTOM) ? "C" : "F"; }

double NormalizeTradePrice(double value)
{
   double tick = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0) return NormalizeDouble(value, g_digits);
   return NormalizeDouble(MathRound(value / tick) * tick, g_digits);
}

double MoneyPerPriceUnitPerLot()
{
   double tv = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_SIZE);
   return (ts > 0.0) ? tv / ts : 0.0;
}

datetime DayStart(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt);
}


//==================== Config.mqh ====================

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


//==================== Logger.mqh ====================

class CLogger
{
private:
   int m_file;
public:
   CLogger() : m_file(INVALID_HANDLE) {}
   void Init()
   {
      if(!Log_To_File || MQLInfoInteger(MQL_TESTER)) return;
      m_file = FileOpen("OHLCMTF_" + g_symbol + ".log", FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
      if(m_file != INVALID_HANDLE) FileSeek(m_file, 0, SEEK_END);
   }
   void Deinit() { if(m_file != INVALID_HANDLE) FileClose(m_file); m_file = INVALID_HANDLE; }
   void Write(string level, string msg)
   {
      Print(level, " ", msg);
      if(m_file != INVALID_HANDLE)
      {
         FileWriteString(m_file, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + " " + level + " " + msg + "\n");
         FileFlush(m_file);
      }
   }
   void Info(string msg)  { Write("[INFO]", msg); }
   void Warn(string msg)  { Write("[WARN]", msg); }
   void Error(string msg) { Write("[ERR ]", msg); }
   void Debug(string msg) { if(Log_Verbose) Write("[DBG ]", msg); }
   void Sep()             { Print("════════════════════════════════════════════════════════════"); }
};

CLogger g_log;


//==================== Market.mqh ====================

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


//==================== Signals.mqh ====================

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


//==================== Risk.mqh ====================

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


//==================== Guards.mqh ====================

class CCapitalGuard
{
private:
   double   m_hwm;
   bool     m_latched;
   datetime m_latched_until;
   double   m_dd_pct;
   double   m_day_start_balance;
   int      m_day_of_year;
   bool     m_daily_hit;
   int      m_trades_today;
   int      m_streak;
   datetime m_pause_until;
   datetime m_last_trade_time;
   datetime m_weekend_day;
public:
   CCapitalGuard() : m_hwm(0), m_latched(false), m_latched_until(0), m_dd_pct(0), m_day_start_balance(0), m_day_of_year(-1),
                     m_daily_hit(false), m_trades_today(0), m_streak(0), m_pause_until(0), m_last_trade_time(0), m_weekend_day(0) {}

   double   HWM()             { return m_hwm; }
   void     SetHWM(double v)  { m_hwm = v; }
   bool     Latched()         { return m_latched; }
   datetime LatchedUntil()    { return m_latched_until; }
   void     SetLatch(bool on, datetime until) { m_latched = on; m_latched_until = until; }
   double   DDPct()           { return m_dd_pct; }
   int      Streak()          { return m_streak; }
   void     SetStreak(int s)  { m_streak = s; }
   datetime PauseUntil()      { return m_pause_until; }
   void     SetPauseUntil(datetime t) { m_pause_until = t; }
   bool     InPause()         { return TimeCurrent() < m_pause_until; }
   bool     DailyHit()        { return m_daily_hit; }
   int      TradesToday()     { return m_trades_today; }
   void     SetTradesToday(int n) { m_trades_today = n; }
   double   DayStartBalance() { return m_day_start_balance; }
   void     SetDayStartBalance(double b) { m_day_start_balance = b; }

   double DailyLossPct()
   {
      if(m_day_start_balance <= 0.0) return 0.0;
      return (m_day_start_balance - AccountInfoDouble(ACCOUNT_EQUITY)) / m_day_start_balance * 100.0;
   }

   void CheckNewDay()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_year != m_day_of_year)
      {
         m_day_of_year = dt.day_of_year;
         m_day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
         m_daily_hit = false;
         m_trades_today = 0;
      }
   }

   // Devuelve true si hay que cerrar todo ahora
   bool EquityTick()
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY), balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double basis = DD_Use_Equity_Peak ? equity : balance;
      if(basis > m_hwm) m_hwm = basis;
      if(m_hwm <= 0.0) return false;
      m_dd_pct = (m_hwm - equity) / m_hwm * 100.0;
      if(!Use_Total_Drawdown_Limit) return false;
      if(m_latched)
      {
         if(DD_Pause_Hours > 0 && TimeCurrent() >= m_latched_until)
         {
            m_latched = false; m_latched_until = 0; m_hwm = basis;
            g_log.Info(StringFormat("DD: pausa terminada; HWM re-basado a %.2f", m_hwm));
         }
         return false;
      }
      if(m_dd_pct >= Max_Total_Drawdown_Pct)
      {
         m_latched = true;
         m_latched_until = (DD_Pause_Hours > 0) ? TimeCurrent() + DD_Pause_Hours * 3600 : 0;
         g_log.Error(StringFormat("GUARDIA DE EQUITY: DD %.2f%% >= %.1f%% (HWM=%.2f equity=%.2f). %s", m_dd_pct, Max_Total_Drawdown_Pct, m_hwm, equity,
                   (DD_Pause_Hours > 0 ? "Bloqueado hasta " + TimeToString(m_latched_until, TIME_DATE|TIME_MINUTES) : "Bloqueado hasta reset manual.")));
         return DD_Flatten_Positions;
      }
      return false;
   }

   bool DailyTick()
   {
      if(!Use_Daily_Loss_Limit || m_day_start_balance <= 0.0) return false;
      double loss = DailyLossPct();
      if(loss >= Max_Daily_Loss_Percent && !m_daily_hit)
      {
         m_daily_hit = true;
         g_log.Warn(StringFormat("LÍMITE DIARIO ALCANZADO (%.2f%%)%s", loss, Daily_Loss_Flatten ? " → cerrando posiciones" : " → sin nuevas entradas hoy"));
         return Daily_Loss_Flatten;
      }
      return false;
   }

   bool InWeekendWindow()
   {
      if(!Close_Before_Weekend) return false;
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      return (dt.day_of_week == 5 && dt.hour >= Weekend_Close_Hour);
   }
   bool WeekendTick(bool has_exposure)
   {
      if(!InWeekendWindow()) return false;
      datetime today = DayStart(TimeCurrent());
      if(m_weekend_day != today) { m_weekend_day = today; g_log.Info("Ventana de cierre de fin de semana activa"); }
      return has_exposure;   // se reintenta en cada tick mientras quede exposición
   }
   bool NeedsFlattenRetry(bool has_exposure)
   {
      return (m_latched && DD_Flatten_Positions && has_exposure) || (m_daily_hit && Daily_Loss_Flatten && has_exposure);
   }

   bool CanEnter(string &reason)
   {
      if(m_latched) { reason = "bloqueado por drawdown"; return false; }
      if(Use_Loss_Streak_Guard)
      {
         if(InPause()) { reason = "pausa por racha"; return false; }
         if(m_streak >= Max_Consecutive_Losses) m_streak = 0;
      }
      if(Use_Daily_Loss_Limit && m_day_start_balance > 0.0)
      {
         if(m_daily_hit || DailyLossPct() >= Max_Daily_Loss_Percent)
         {
            if(!m_daily_hit) { m_daily_hit = true; g_log.Warn(StringFormat("LÍMITE DIARIO ALCANZADO (%.2f%%)", DailyLossPct())); }
            reason = "límite diario"; return false;
         }
      }
      if(InWeekendWindow()) { reason = "ventana de cierre de fin de semana"; return false; }
      if(TimeCurrent() - m_last_trade_time < Cooldown_Seconds) { reason = "cooldown"; return false; }
      if(m_trades_today >= Max_Trades_Per_Day) { reason = "máximo de trades/día"; return false; }
      reason = "";
      return true;
   }

   void OnTradeSent() { m_last_trade_time = TimeCurrent(); m_trades_today++; }

   void OnTradeClosed(double pnl, double sl_money)
   {
      if(pnl > 0.0)
      {
         bool meaningful = (sl_money <= 0.0) || (Streak_Reset_Min_R <= 0.0) || (pnl >= Streak_Reset_Min_R * sl_money);
         if(meaningful) m_streak = 0;
      }
      else if(pnl < 0.0)
      {
         m_streak++;
         if(Use_Loss_Streak_Guard && m_streak >= Max_Consecutive_Losses)
         {
            m_pause_until = TimeCurrent() + Loss_Streak_Pause_Minutes * 60;
            g_log.Warn(StringFormat("PAUSA POR RACHA: %d pérdidas consecutivas; hasta %s", m_streak, TimeToString(m_pause_until, TIME_DATE|TIME_MINUTES)));
         }
      }
   }
};


//==================== Execution.mqh ====================
#include <Trade\Trade.mqh>

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


//==================== Recovery.mqh ====================

class CStateStore
{
private:
   string Key(string k) { return GV_PREFIX + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + g_symbol + "_" + k; }
   string RKey(ulong id) { return Key("R_" + IntegerToString((long)id)); }
   bool m_had_streak;
public:
   SPositionState cur;
   double         cur_realized;
   double         cur_closed_vol;

   CStateStore() : m_had_streak(false), cur_realized(0.0), cur_closed_vol(0.0) { cur.Clear(); }

   void Load(CCapitalGuard &g)
   {
      if(MQLInfoInteger(MQL_TESTER)) GlobalVariablesDeleteAll(GV_PREFIX);
      m_had_streak = GlobalVariableCheck(Key("STREAK"));
      if(GlobalVariableCheck(Key("HWM")))     g.SetHWM(GlobalVariableGet(Key("HWM")));
      bool latched = GlobalVariableCheck(Key("DDLATCH")) && GlobalVariableGet(Key("DDLATCH")) > 0.5;
      datetime until = GlobalVariableCheck(Key("DDUNTIL")) ? (datetime)GlobalVariableGet(Key("DDUNTIL")) : 0;
      if(latched && DD_Manual_Reset)
      {
         g_log.Info("DD: reset manual; HWM re-basado a equity actual");
         latched = false; until = 0; g.SetHWM(AccountInfoDouble(ACCOUNT_EQUITY));
      }
      g.SetLatch(latched, until);
      if(GlobalVariableCheck(Key("STREAK")))  g.SetStreak((int)GlobalVariableGet(Key("STREAK")));
      if(GlobalVariableCheck(Key("PAUSE")))   g.SetPauseUntil((datetime)GlobalVariableGet(Key("PAUSE")));
      if(g.HWM() <= 0.0) g.SetHWM(DD_Use_Equity_Peak ? AccountInfoDouble(ACCOUNT_EQUITY) : AccountInfoDouble(ACCOUNT_BALANCE));
      Save(g);
   }
   void Save(CCapitalGuard &g)
   {
      GlobalVariableSet(Key("HWM"), g.HWM());
      GlobalVariableSet(Key("DDLATCH"), g.Latched() ? 1.0 : 0.0);
      GlobalVariableSet(Key("DDUNTIL"), (double)g.LatchedUntil());
      GlobalVariableSet(Key("STREAK"), (double)g.Streak());
      GlobalVariableSet(Key("PAUSE"), (double)g.PauseUntil());
   }
   bool HasStreakSaved() { return m_had_streak; }

   void RememberEntry(ulong ticket, ulong pos_id, double sl_dist)
   {
      if(sl_dist <= 0.0) return;
      GlobalVariableSet(RKey(ticket), sl_dist);
      if(pos_id != ticket) GlobalVariableSet(RKey(pos_id), sl_dist);
   }
   void ForgetPosition(ulong pos_id, ulong ticket)
   {
      if(GlobalVariableCheck(RKey(pos_id))) GlobalVariableDel(RKey(pos_id));
      if(ticket != pos_id && GlobalVariableCheck(RKey(ticket))) GlobalVariableDel(RKey(ticket));
   }

   double RiskDistanceFromHistory(ulong pos_id, double &tp_dist)
   {
      tp_dist = 0.0;
      if(pos_id == 0) return 0.0;
      if(GlobalVariableCheck(RKey(pos_id)))
      {
         double r = GlobalVariableGet(RKey(pos_id));
         if(r > 0.0) return r;
      }
      if(!HistorySelectByPosition(pos_id)) return 0.0;
      int n = HistoryDealsTotal();
      for(int i = 0; i < n; i++)
      {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0 || (ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
         double price = HistoryDealGetDouble(d, DEAL_PRICE), sl = HistoryDealGetDouble(d, DEAL_SL), tp = HistoryDealGetDouble(d, DEAL_TP);
         if(tp > 0.0 && price > 0.0) tp_dist = MathAbs(tp - price);
         if(sl > 0.0 && price > 0.0) return MathAbs(price - sl);
         string cmt = HistoryDealGetString(d, DEAL_COMMENT);
         if(StringLen(cmt) > 1 && StringGetCharacter(cmt, 0) == 'R')
         {
            double pts = StringToDouble(StringSubstr(cmt, 1));
            if(pts > 0.0) return pts * g_point;
         }
      }
      return 0.0;
   }

   double InitialRiskDistance(ulong ticket, double open_price, double current_sl, CMarket *market)
   {
      if(ticket == cur.ticket && cur.sl_dist > 0.0) return cur.sl_dist;
      double tp_tmp = 0.0;
      double r = RiskDistanceFromHistory(ticket, tp_tmp);
      if(r > 0.0) return r;
      string cmt = "";
      if(PositionSelectByTicket(ticket)) cmt = PositionGetString(POSITION_COMMENT);
      if(StringLen(cmt) > 1 && StringGetCharacter(cmt, 0) == 'R')
      {
         double pts = StringToDouble(StringSubstr(cmt, 1));
         if(pts > 0.0) return pts * g_point;
      }
      if(current_sl > 0.0 && open_price > 0.0 && MathAbs(open_price - current_sl) > 0.0) return MathAbs(open_price - current_sl);
      double atr = market.ATR();
      return (atr > 0.0) ? atr * ATR_SL_Multiplier : 0.0;
   }

   void RecoverOpenPosition(CMarket *market)
   {
      int found = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong t = PositionGetTicket(i);
         if(t == 0 || PositionGetString(POSITION_SYMBOL) != g_symbol) continue;
         long magic = PositionGetInteger(POSITION_MAGIC);
         if(!IsOurMagic(magic)) continue;
         found++;
         if(found > 1) { g_log.Warn("RECUPERACIÓN: más de una posición del EA abierta (#" + IntegerToString((long)t) + ")"); continue; }
         cur.ticket = t;
         cur.pos_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
         cur.set_id = SetFromMagic(magic);
         cur.open   = PositionGetDouble(POSITION_PRICE_OPEN);
         cur.sl0    = PositionGetDouble(POSITION_SL);
         cur.tp0    = PositionGetDouble(POSITION_TP);
         cur.type   = (int)PositionGetInteger(POSITION_TYPE);
         double tp_hist = 0.0;
         cur.sl_dist = RiskDistanceFromHistory(cur.pos_id, tp_hist);
         if(cur.sl_dist <= 0.0 && cur.pos_id != t) cur.sl_dist = RiskDistanceFromHistory(t, tp_hist);
         if(cur.sl_dist <= 0.0) cur.sl_dist = InitialRiskDistance(t, cur.open, cur.sl0, market);
         cur.tp_dist = (tp_hist > 0.0) ? tp_hist : ((cur.tp0 > 0.0) ? MathAbs(cur.tp0 - cur.open) : 0.0);
         g_log.Info(StringFormat("RECUPERACIÓN: posición #%I64u set %s R=%d pts", t, SetTag(cur.set_id), (int)(cur.sl_dist / g_point)));
      }
   }

   void RecoverDailyFromHistory(CCapitalGuard &g)
   {
      datetime day_start = DayStart(TimeCurrent());
      if(!HistorySelect(day_start - 86400 * 30, TimeCurrent() + 3600)) return;
      int trades_today = 0; double realized = 0.0;
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0 || HistoryDealGetString(d, DEAL_SYMBOL) != g_symbol || !IsOurMagic(HistoryDealGetInteger(d, DEAL_MAGIC))) continue;
         if((datetime)HistoryDealGetInteger(d, DEAL_TIME) < day_start) continue;
         ENUM_DEAL_ENTRY e = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY);
         if(e == DEAL_ENTRY_IN || e == DEAL_ENTRY_INOUT) trades_today++;
         realized += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
      }
      g.SetTradesToday(MathMax(g.TradesToday(), trades_today));
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      if(bal - realized > 0.0) g.SetDayStartBalance(bal - realized);
      if(!HasStreakSaved())
      {
         int streak = 0;
         for(int i = total - 1; i >= 0; i--)
         {
            ulong d = HistoryDealGetTicket(i);
            if(d == 0 || HistoryDealGetString(d, DEAL_SYMBOL) != g_symbol || !IsOurMagic(HistoryDealGetInteger(d, DEAL_MAGIC))) continue;
            ENUM_DEAL_ENTRY e = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY);
            if(e != DEAL_ENTRY_OUT && e != DEAL_ENTRY_OUT_BY && e != DEAL_ENTRY_INOUT) continue;
            double p = HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
            if(p < 0.0) streak++; else break;
         }
         g.SetStreak(streak);
      }
      g_log.Info(StringFormat("Recuperación: trades hoy=%d | P&L hoy=%.2f | balance inicio día=%.2f | racha=%d", g.TradesToday(), realized, g.DayStartBalance(), g.Streak()));
   }
};


//==================== News.mqh ====================

struct SNewsEvent
{
   datetime time;
   string   currency;
   int      importance;
   string   name;
};

class CNewsFilter
{
private:
   SNewsEvent m_events[];
   datetime   m_loaded_at;
   bool       m_live_available;
   bool       m_last_state;

   static bool InRange(int cur_h, int cur_m, int sh, int sm, int eh, int em)
   {
      int cur = cur_h * 60 + cur_m, s = sh * 60 + sm, e = eh * 60 + em;
      if(s == e) return false;
      if(s < e)  return (cur >= s && cur < e);
      return (cur >= s || cur < e);
   }
   static int ImportanceFrom(string s)
   {
      StringToUpper(s);
      if(s == "HIGH" || s == "3") return (int)CALENDAR_IMPORTANCE_HIGH;
      if(s == "MODERATE" || s == "MEDIUM" || s == "2") return (int)CALENDAR_IMPORTANCE_MODERATE;
      if(s == "LOW" || s == "1") return (int)CALENDAR_IMPORTANCE_LOW;
      return (int)CALENDAR_IMPORTANCE_NONE;
   }
   bool CurrencyWanted(string cur)
   {
      string list = Calendar_Currencies;
      StringToUpper(list); StringToUpper(cur);
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
   void Add(datetime t, string cur, int imp, string name)
   {
      int k = ArraySize(m_events);
      ArrayResize(m_events, k + 1);
      m_events[k].time = t; m_events[k].currency = cur; m_events[k].importance = imp; m_events[k].name = name;
   }
   void LoadCSV()
   {
      ArrayResize(m_events, 0);
      if(Calendar_CSV_File == "") return;
      ResetLastError();
      int fh = FileOpen(Calendar_CSV_File, FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON);
      if(fh == INVALID_HANDLE) { g_log.Warn("CALENDARIO: no se pudo abrir Common\\Files\\" + Calendar_CSV_File + " (" + IntegerToString(GetLastError()) + "); filtro inactivo"); return; }
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
         int imp = ImportanceFrom(f[2]);
         if(imp < (int)Calendar_Min_Importance) continue;
         Add(t, cur, imp, (ArraySize(f) > 3) ? f[3] : "evento");
         added++;
      }
      FileClose(fh);
      g_log.Info("CALENDARIO (CSV): " + IntegerToString(added) + " eventos desde " + Calendar_CSV_File);
   }
   void LoadLive()
   {
      ArrayResize(m_events, 0);
      string parts[];
      int nc = StringSplit(Calendar_Currencies, ',', parts);
      datetime from = TimeTradeServer() - 2 * 86400, to = TimeTradeServer() + 7 * 86400;
      int added = 0;
      for(int c = 0; c < nc; c++)
      {
         string cur = parts[c];
         StringTrimLeft(cur); StringTrimRight(cur); StringToUpper(cur);
         if(cur == "") continue;
         MqlCalendarValue vals[];
         ResetLastError();
         int rc = (int)CalendarValueHistory(vals, from, to, NULL, cur);
         int err = GetLastError();
         if(!((rc > 0) || (rc == 0 && err == 0)))
         {
            g_log.Warn("CALENDARIO: CalendarValueHistory falló (" + IntegerToString(err) + "); usando CSV");
            m_live_available = false;
            LoadCSV();
            return;
         }
         for(int i = 0; i < ArraySize(vals); i++)
         {
            MqlCalendarEvent ev;
            if(!CalendarEventById(vals[i].event_id, ev)) continue;
            if((int)ev.importance < (int)Calendar_Min_Importance) continue;
            Add(vals[i].time, cur, (int)ev.importance, ev.name);
            added++;
         }
      }
      g_log.Info("CALENDARIO: " + IntegerToString(added) + " eventos (" + Calendar_Currencies + ", >= " + EnumToString(Calendar_Min_Importance) + ")");
   }
public:
   CNewsFilter() : m_loaded_at(0), m_live_available(true), m_last_state(false) {}
   int EventCount() { return ArraySize(m_events); }

   void Load(bool force)
   {
      bool csv_mode = (MQLInfoInteger(MQL_TESTER) || !m_live_available);
      if(!force && m_loaded_at != 0)
      {
         if(csv_mode) return;
         if(TimeCurrent() - m_loaded_at < Calendar_Refresh_Min * 60) return;
      }
      m_loaded_at = TimeCurrent();
      if(csv_mode) LoadCSV(); else LoadLive();
   }

   bool CalendarBlocked(string &label)
   {
      if(!Use_Calendar_Filter) return false;
      Load(false);
      datetime now = TimeCurrent();
      for(int i = 0; i < ArraySize(m_events); i++)
         if(now >= m_events[i].time - Calendar_Block_Before_Min * 60 && now <= m_events[i].time + Calendar_Block_After_Min * 60)
         {
            label = m_events[i].currency + " " + m_events[i].name + " @" + TimeToString(m_events[i].time, TIME_MINUTES);
            return true;
         }
      return false;
   }

   bool IsBlocked(string &label)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int h = dt.hour, m = dt.min;
      if(News1_Enable && InRange(h, m, News1_Start_Hour, News1_Start_Min, News1_End_Hour, News1_End_Min)) { label = News1_Name; return true; }
      if(News2_Enable && InRange(h, m, News2_Start_Hour, News2_Start_Min, News2_End_Hour, News2_End_Min)) { label = News2_Name; return true; }
      if(News3_Enable && InRange(h, m, News3_Start_Hour, News3_Start_Min, News3_End_Hour, News3_End_Min)) { label = News3_Name; return true; }
      if(News4_Enable && InRange(h, m, News4_Start_Hour, News4_Start_Min, News4_End_Hour, News4_End_Min)) { label = News4_Name; return true; }
      if(CalendarBlocked(label)) return true;
      label = "";
      return false;
   }

   // true si el estado cambió; entering = true al entrar en bloqueo
   bool StateChanged(bool &entering, string &label)
   {
      bool now = IsBlocked(label);
      if(now == m_last_state) return false;
      m_last_state = now; entering = now;
      return true;
   }

   string LegacyLine(string tag, bool enabled, string name, int sh, int sm, int eh, int em)
   {
      string range = StringFormat("%02d:%02d-%02d:%02d", sh, sm, eh, em);
      string status = "(off)";
      if(enabled)
      {
         MqlDateTime dt;
         TimeToStruct(TimeCurrent(), dt);
         status = InRange(dt.hour, dt.min, sh, sm, eh, em) ? "BLOQUEADO" : "libre";
      }
      return StringFormat("%s %-12s %s [%s]", tag, name, range, status);
   }
};


//==================== Stats.mqh ====================

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


//==================== PositionManager.mqh ====================

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


CMarket          g_market;
CSignalEngine    g_signals;
CRiskManager     g_risk;
CCapitalGuard    g_guard;
CExecutor        g_exec;
CStateStore      g_state;
CNewsFilter      g_news;
CTradeStats      g_stats;
CPositionManager g_posmgr;


//==================== Panel.mqh ====================

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


CPanel   g_panel;
datetime g_last_bar_fixed  = 0;
datetime g_last_bar_custom = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   InitSymbolContext();
   if(!ValidateInputs()) return INIT_PARAMETERS_INCORRECT;
   g_log.Init();
   if(!g_market.Init()) return INIT_FAILED;
   g_exec.Init();
   g_signals.Init(GetPointer(g_market));
   g_posmgr.Init(GetPointer(g_market), GetPointer(g_exec), GetPointer(g_state));

   g_last_bar_fixed  = iTime(g_symbol, PERIOD_H1, 0);
   g_last_bar_custom = iTime(g_symbol, TF_Fast, 0);

   g_guard.CheckNewDay();
   g_state.Load(g_guard);
   g_state.RecoverOpenPosition(GetPointer(g_market));
   g_state.RecoverDailyFromHistory(g_guard);
   if(Use_Calendar_Filter) g_news.Load(true);

   if(Panel_Show) { EventSetTimer(MathMax(Panel_Refresh_Sec, 1)); g_panel.Update(); }

   g_log.Sep();
   g_log.Info("OHLCMTF SCALPER v" + OHLC_VERSION + " inicializado en " + g_symbol);
   g_log.Info(StringFormat("Sets: FIJO=%s (H1/%s/D1, magic %d) | CUSTOM=%s (%s/%s, magic %d)", Use_Fixed_Set ? "ON" : "OFF", EnumToString(Trend_Timeframe), MAGIC_FIXED,
                         Use_Custom_Pair ? "ON" : "OFF", EnumToString(TF_Fast), EnumToString(TF_Slow), MAGIC_CUSTOM));
   g_log.Info(StringFormat("Riesgo %.2f-%.2f%% (cap %.1f%%) base=%s | lote mínimo sobre cap: %s", Min_Risk_Percent, Max_Risk_Percent, Hard_Risk_Cap_Percent,
                         Size_On_Equity ? "min(balance,equity)" : "balance", Allow_MinLot_Above_Cap ? "PERMITIDO" : "OMITIR"));
   g_log.Info(StringFormat("Guardia DD: %s | flatten=%s | pausa=%dh | HWM=%.2f%s", Use_Total_Drawdown_Limit ? DoubleToString(Max_Total_Drawdown_Pct, 1) + "% vs HWM" : "OFF",
                         DD_Flatten_Positions ? "SÍ" : "NO", DD_Pause_Hours, g_guard.HWM(), g_guard.Latched() ? " | *** BLOQUEADO ***" : ""));
   g_risk.PrintMinLotDiagnostic(GetPointer(g_market));
   g_log.Sep();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_stats.PrintSummary("RESUMEN FINAL", g_risk.SkippedMinLot(), g_guard.HWM(), g_guard.DDPct(), g_guard.Latched());
   g_state.Save(g_guard);
   EventKillTimer();
   g_panel.DeleteAll();
   g_market.Deinit();
   g_log.Deinit();
}

//+------------------------------------------------------------------+
void OnTimer() { g_panel.Update(); }

//+------------------------------------------------------------------+
void OnTick()
{
   g_guard.CheckNewDay();
   g_market.SampleSpread();

   if(g_guard.EquityTick()) { g_exec.FlattenAll("DRAWDOWN"); g_state.Save(g_guard); }
   if(g_guard.DailyTick())  g_exec.FlattenAll("DAILY_LOSS");
   if(g_guard.WeekendTick(g_exec.HasExposure())) g_exec.FlattenAll("WEEKEND");
   if(g_guard.NeedsFlattenRetry(g_exec.HasExposure())) g_exec.FlattenAll("RETRY");

   g_posmgr.Manage();
   if(Use_Limit_Orders) g_exec.CleanupStalePending();

   bool entering = false; string label = "";
   if(g_news.StateChanged(entering, label))
   {
      if(entering)
      {
         g_log.Info("NOTICIAS: bloqueo → " + label);
         if(Use_Calendar_Filter && Calendar_Close_Positions && g_exec.CountOpenPositions() > 0) g_exec.FlattenAll("NEWS");
      }
      else g_log.Info("NOTICIAS: bloqueo finalizado");
   }

   if(g_guard.Latched()) return;

   if(Use_Fixed_Set)
   {
      datetime bar = iTime(g_symbol, PERIOD_H1, 0);
      if(bar != 0 && bar != g_last_bar_fixed) { g_last_bar_fixed = bar; EvaluateSet(PERIOD_H1, Trend_Timeframe, PERIOD_D1, SET_FIXED); }
   }
   if(Use_Custom_Pair)
   {
      datetime bar = iTime(g_symbol, TF_Fast, 0);
      if(bar != 0 && bar != g_last_bar_custom) { g_last_bar_custom = bar; EvaluateSet(TF_Fast, TF_Slow, TF_Slow, SET_CUSTOM); }
   }
}

//+------------------------------------------------------------------+
void EvaluateSet(ENUM_TIMEFRAMES t1, ENUM_TIMEFRAMES t2, ENUM_TIMEFRAMES t3, int set_id)
{
   SSignal sigs[];
   int n = g_signals.Evaluate(t1, t2, t3, set_id, sigs);
   for(int i = 0; i < n; i++)
   {
      ExecuteSignal(sigs[i]);
      g_panel.DrawArrow(sigs[i]);
   }
}

//+------------------------------------------------------------------+
void ExecuteSignal(const SSignal &sig)
{
   if(g_exec.HasExposure()) return;
   string why = "";
   if(g_news.IsBlocked(why)) { g_log.Info("Señal omitida por noticias: " + why); return; }
   if(!g_guard.CanEnter(why)) { g_log.Debug("Señal omitida: " + why); return; }

   double cur_spread = g_market.CurrentSpread(), avg_spread = g_market.AverageSpread();
   double cur_pts = cur_spread / g_point, avg_pts = avg_spread / g_point;
   double mode_spread = Use_Avg_Spread_For_Mode ? avg_spread : cur_spread;
   bool high_spread = (mode_spread / g_point) > HighSpread_Threshold;
   if(Max_Spread_Points > 0.0 && cur_pts > Max_Spread_Points) { g_log.Info(StringFormat("Señal omitida: spread %.1f > %.1f pts", cur_pts, Max_Spread_Points)); return; }

   double atr = sig.atr;
   if(atr <= 0.0) return;
   double tp_factor = 1.0;
   double risk_pct = g_risk.RiskPctForStrength(sig.strength, tp_factor);
   double sl_mult = ATR_SL_Multiplier, tp_mult = ATR_TP_Multiplier * tp_factor;
   if(high_spread)
   {
      double avs = (mode_spread > 0.0) ? atr / mode_spread : 0.0;
      if(avs < HighSpread_ATR_Min_Mult) { g_log.Info(StringFormat("Señal omitida en spread alto: ATR/spread %.2f < %.2f", avs, HighSpread_ATR_Min_Mult)); return; }
      sl_mult *= HighSpread_SL_Extra_Mult; risk_pct *= HighSpread_Risk_Reduction;
      g_log.Info(StringFormat("Spread alto (%.0f pts): SL x%.2f, riesgo x%.2f", mode_spread / g_point, HighSpread_SL_Extra_Mult, HighSpread_Risk_Reduction));
   }
   risk_pct = MathMin(risk_pct, MathMin(Max_Risk_Percent, Hard_Risk_Cap_Percent));
   if(risk_pct <= 0.0) return;

   double sl_dist = atr * sl_mult, tp_dist = atr * tp_mult;
   double floor_ = avg_spread * Spread_Buffer_Multiplier;
   if(floor_ > 0.0) { if(sl_dist < floor_) sl_dist = floor_; if(tp_dist < floor_) tp_dist = floor_; }
   double stopLevel = SymbolInfoInteger(g_symbol, SYMBOL_TRADE_STOPS_LEVEL) * g_point;
   if(stopLevel <= 0.0) stopLevel = 10.0 * g_point;
   sl_dist = MathMax(sl_dist, MathMax(stopLevel, Min_SL_Points * g_point));

   double entry_ref = (sig.direction == 1) ? SymbolInfoDouble(g_symbol, SYMBOL_ASK) : SymbolInfoDouble(g_symbol, SYMBOL_BID);
   SSizing sz;
   if(!g_risk.CalcVolume(sig.direction, entry_ref, sl_dist, risk_pct, sz)) { g_log.Info("Señal omitida: " + sz.reason); return; }

   long pts = (long)MathRound(sl_dist / g_point);
   string comment = "R" + IntegerToString((int)MathMax(1, MathMin(pts, 999999))) + SetTag(sig.set_id);
   double entry = 0, sl = 0, tp = 0;
   if(!g_exec.Open(sig, sz.volume, sl_dist, tp_dist, comment, entry, sl, tp))
   {
      g_log.Error(StringFormat("ERROR al enviar %s %s rc=%d %s", sig.direction == 1 ? "BUY" : "SELL", SetTag(sig.set_id), g_exec.LastRetcode(), g_exec.LastRetcodeDesc()));
      return;
   }
   g_guard.OnTradeSent();
   g_risk.RecordLast(sz.risk_pct, sz.risk_money);
   g_log.Sep();
   g_log.Info(StringFormat("%s EJECUTADA | set %s | magic %I64u", sig.direction == 1 ? "BUY" : "SELL", SetTag(sig.set_id), MagicForSet(sig.set_id)));
   g_log.Info(StringFormat("Entrada %s | SL %s (%d pts) | TP %s (%d pts) | lote %.2f", DoubleToString(entry, g_digits), DoubleToString(sl, g_digits), (int)(sl_dist / g_point),
                         DoubleToString(tp, g_digits), (int)(tp_dist / g_point), sz.volume));
   g_log.Info(StringFormat("ATR %s | riesgo objetivo %.2f%% | RIESGO REAL %.2f%% ($%.2f) [cap %.2f%%] | fuerza %d/%d | spread %.0f pts (prom %.0f) | tendencia %d",
                         DoubleToString(atr, g_digits), risk_pct, sz.risk_pct, sz.risk_money, Hard_Risk_Cap_Percent, sig.strength, MAX_SIGNAL_STRENGTH, cur_pts, avg_pts, sig.trend));
   g_log.Sep();
}

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != g_symbol) return;
   long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(!IsOurMagic(magic)) return;

   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   ulong pos_id = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   int set_id = SetFromMagic(magic);
   bool has_exit  = (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY || entry == DEAL_ENTRY_INOUT);
   bool has_entry = (entry == DEAL_ENTRY_IN  || entry == DEAL_ENTRY_INOUT);
   if(has_exit) AccountExit(trans.deal, pos_id, set_id);
   if(has_entry) AccountEntry(trans, pos_id, set_id);
}

void AccountEntry(const MqlTradeTransaction &trans, ulong pos_id, int set_id)
{
   ulong ticket = trans.position;
   if(ticket == 0)
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong t = PositionGetTicket(i);
         if(t != 0 && (ulong)PositionGetInteger(POSITION_IDENTIFIER) == pos_id) { ticket = t; break; }
      }
   g_state.cur.ticket = ticket; g_state.cur.pos_id = pos_id; g_state.cur.set_id = set_id;
   g_state.cur.open = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   g_state.cur.sl0  = HistoryDealGetDouble(trans.deal, DEAL_SL);
   g_state.cur.tp0  = HistoryDealGetDouble(trans.deal, DEAL_TP);
   g_state.cur.type = (HistoryDealGetInteger(trans.deal, DEAL_TYPE) == DEAL_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   if(ticket > 0 && PositionSelectByTicket(ticket))
   {
      g_state.cur.open = PositionGetDouble(POSITION_PRICE_OPEN);
      if(PositionGetDouble(POSITION_SL) > 0.0) g_state.cur.sl0 = PositionGetDouble(POSITION_SL);
      if(PositionGetDouble(POSITION_TP) > 0.0) g_state.cur.tp0 = PositionGetDouble(POSITION_TP);
      g_state.cur.type = (int)PositionGetInteger(POSITION_TYPE);
   }
   g_state.cur.sl_dist = (g_state.cur.sl0 > 0.0) ? MathAbs(g_state.cur.open - g_state.cur.sl0) : 0.0;
   g_state.cur.tp_dist = (g_state.cur.tp0 > 0.0) ? MathAbs(g_state.cur.tp0 - g_state.cur.open) : 0.0;
   g_state.RememberEntry(ticket, pos_id, g_state.cur.sl_dist);
   g_stats.OnEntry(set_id);
}

void AccountExit(ulong deal, ulong pos_id, int set_id)
{
   if(!HistoryDealSelect(deal)) return;
   double profit = HistoryDealGetDouble(deal, DEAL_PROFIT) + HistoryDealGetDouble(deal, DEAL_SWAP) + HistoryDealGetDouble(deal, DEAL_COMMISSION) + HistoryDealGetDouble(deal, DEAL_FEE);
   double mppu = MoneyPerPriceUnitPerLot();
   double sl_dist = 0.0, tp_dist = 0.0;
   if(g_state.cur.ticket != 0 && (g_state.cur.pos_id == pos_id || g_state.cur.ticket == pos_id) && g_state.cur.sl_dist > 0.0)
   { sl_dist = g_state.cur.sl_dist; tp_dist = g_state.cur.tp_dist; }
   else
   { sl_dist = g_state.RiskDistanceFromHistory(pos_id, tp_dist); HistoryDealSelect(deal); }
   double vol = HistoryDealGetDouble(deal, DEAL_VOLUME);
   double sl_money = sl_dist * mppu * vol, tp_money = tp_dist * mppu * vol;

   g_stats.OnExit(profit, sl_money, tp_money, set_id);
   g_log.Info(StringFormat("CIERRE set %s pos#%I64u P&L=%.2f | R inicial $%.2f → %s R", SetTag(set_id), pos_id, profit, sl_money, sl_money > 0.0 ? DoubleToString(profit / sl_money, 2) : "n/a"));
   if(g_stats.Total() > 0 && g_stats.Total() % 50 == 0)
      g_stats.PrintSummary("RESUMEN PARCIAL (" + IntegerToString(g_stats.Total()) + " cierres)", g_risk.SkippedMinLot(), g_guard.HWM(), g_guard.DDPct(), g_guard.Latched());

   bool still_open = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t != 0 && ((ulong)PositionGetInteger(POSITION_IDENTIFIER) == pos_id || t == pos_id)) { still_open = true; break; }
   }
   // La racha se evalúa por POSICIÓN cerrada (agregando fills parciales), no por deal
   bool mine = (g_state.cur.pos_id == pos_id || g_state.cur.ticket == pos_id);
   if(mine) { g_state.cur_realized += profit; g_state.cur_closed_vol += vol; }
   if(!still_open)
   {
      double pos_pnl = mine ? g_state.cur_realized : profit;
      double pos_vol = mine ? g_state.cur_closed_vol : vol;
      g_guard.OnTradeClosed(pos_pnl, sl_dist * mppu * pos_vol);
      ulong tk = g_state.cur.ticket;
      if(mine) { g_state.cur.Clear(); g_state.cur_realized = 0.0; g_state.cur_closed_vol = 0.0; }
      g_state.ForgetPosition(pos_id, tk);
   }
   g_state.Save(g_guard);
}
//+------------------------------------------------------------------+