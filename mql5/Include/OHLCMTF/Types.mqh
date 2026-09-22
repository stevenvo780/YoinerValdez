#ifndef OHLCMTF_TYPES_MQH
#define OHLCMTF_TYPES_MQH

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

#endif
