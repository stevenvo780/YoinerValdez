//+------------------------------------------------------------------+
//|                                          ExportCalendarCSV.mq5   |
//|  Script auxiliar v14.1: exporta el calendario económico de MT5   |
//|  a Common\Files\news_events.csv para que el filtro por           |
//|  calendario del EA funcione en el Strategy Tester.               |
//|  Ejecutar en un terminal CONECTADO (el calendario no está        |
//|  disponible en el tester). Las horas se escriben en hora del     |
//|  SERVIDOR, igual que las usa el EA.                              |
//+------------------------------------------------------------------+
#property script_show_inputs
#property strict

input datetime Export_From       = D'2024.01.01';
input datetime Export_To         = D'2026.12.31';
input string   Export_Currencies = "USD";                 // separadas por coma
input ENUM_CALENDAR_EVENT_IMPORTANCE Export_Min_Importance = CALENDAR_IMPORTANCE_HIGH;
input string   Export_File       = "news_events.csv";     // en Common\Files

void OnStart()
{
   string parts[];
   int nc = StringSplit(Export_Currencies, ',', parts);
   int fh = FileOpen(Export_File, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(fh == INVALID_HANDLE)
   {
      Print("No se pudo crear ", Export_File, " (", GetLastError(), ")");
      return;
   }
   FileWriteString(fh, "# hora_servidor;divisa;importancia;nombre\n");
   int total = 0;
   for(int c = 0; c < nc; c++)
   {
      string cur = parts[c];
      StringTrimLeft(cur); StringTrimRight(cur); StringToUpper(cur);
      if(cur == "") continue;
      MqlCalendarValue vals[];
      ResetLastError();
      int rc = (int)CalendarValueHistory(vals, Export_From, Export_To, NULL, cur);
      int cerr = GetLastError();
      if(rc < 0 || (rc == 0 && cerr != 0))
      {
         Print("CalendarValueHistory falló para ", cur, " (", GetLastError(), ")");
         continue;
      }
      for(int i = 0; i < ArraySize(vals); i++)
      {
         MqlCalendarEvent ev;
         if(!CalendarEventById(vals[i].event_id, ev)) continue;
         if((int)ev.importance < (int)Export_Min_Importance) continue;
         string imp = (ev.importance == CALENDAR_IMPORTANCE_HIGH) ? "HIGH" :
                      (ev.importance == CALENDAR_IMPORTANCE_MODERATE) ? "MODERATE" : "LOW";
         string name = ev.name;
         StringReplace(name, ";", ",");
         FileWriteString(fh, TimeToString(vals[i].time, TIME_DATE|TIME_MINUTES) + ";" + cur + ";" + imp + ";" + name + "\n");
         total++;
      }
   }
   FileClose(fh);
   Print("Exportados ", total, " eventos a Common\\Files\\", Export_File);
}
