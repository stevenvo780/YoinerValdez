#ifndef OHLCMTF_NEWS_MQH
#define OHLCMTF_NEWS_MQH
#include <OHLCMTF/Logger.mqh>

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

#endif
