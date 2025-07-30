#ifndef __INCLUDE_MQH__
#define __INCLUDE_MQH__

// library
#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>
CTrade trade;

// common
#include "../common/Globals.mqh"

// data
#include "../data/MarketDataService.mqh"

// logic
#include "../logic/DetectBIAS.mqh"
#include "../logic/CoreLogicBIAS.mqh"
#include "../logic/SignalService.mqh"
#include "../logic/TicketService.mqh"
#include "../logic/TradeService.mqh"// Hedging (đường dẫn từ Bot/utils -> Bot/logic)

#include "..\\logic\\Hedging\\Helper_Hybrid.mqh"
#include "..\\logic\\Hedging\\Hedging_Hybrid_Dynamic.mqh"

// logic/DCA_Negative
#include "../logic/DCA_Negative/DCA_Handle.mqh"
#include "../logic/DCA_Negative/DCA_Update.mqh"

// logic/DCA_Positive
#include "../logic/DCA_Positive/DCA_Handle.mqh"
#include "../logic/DCA_Positive/DCA_Update.mqh"
#include "../logic/DCA_Positive/DCA_Util.mqh"

// logic/Frozen
#include "../logic/Frozen/Frozen_Handle.mqh"

// utils
#include "./GetTotalProfitFrom.mqh"
#include "./updateTicketInfo.mqh"
#include "./CalcTP.mqh"


#endif // __INCLUDE_MQH__
