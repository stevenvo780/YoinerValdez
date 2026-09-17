#ifndef OHLCMTF_CONTEXT_MQH
#define OHLCMTF_CONTEXT_MQH
#include <OHLCMTF/Types.mqh>
#include <OHLCMTF/Config.mqh>
#include <OHLCMTF/Logger.mqh>
#include <OHLCMTF/Market.mqh>
#include <OHLCMTF/Signals.mqh>
#include <OHLCMTF/Risk.mqh>
#include <OHLCMTF/Guards.mqh>
#include <OHLCMTF/Execution.mqh>
#include <OHLCMTF/Recovery.mqh>
#include <OHLCMTF/News.mqh>
#include <OHLCMTF/Stats.mqh>
#include <OHLCMTF/PositionManager.mqh>

CMarket          g_market;
CSignalEngine    g_signals;
CRiskManager     g_risk;
CCapitalGuard    g_guard;
CExecutor        g_exec;
CStateStore      g_state;
CNewsFilter      g_news;
CTradeStats      g_stats;
CPositionManager g_posmgr;

#endif
