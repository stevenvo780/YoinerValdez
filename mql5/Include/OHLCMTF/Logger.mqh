#ifndef OHLCMTF_LOGGER_MQH
#define OHLCMTF_LOGGER_MQH
#include <OHLCMTF/Config.mqh>

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

#endif
