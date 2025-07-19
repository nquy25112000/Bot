//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#ifndef __GLOBALS_MQH__
#define __GLOBALS_MQH__
#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>
CTrade trade;

struct TicketInfo
  {
   ulong             ticketId;
   double            volume;
   string            state;
   double            price;
   double            activePrice;
  };

double     m_volumes[];
string m_tickets[];

int    jump = 1;
int    targetByIndex1, targetByIndex2;
bool   dailyBiasRunning = false;
ENUM_ORDER_TYPE orderTypeDailyBias;
bool dailyBiasRuning = 0;

#define STATE_OPEN         "OPEN"
#define STATE_WAITING_STOP "WAITING_STOP"
#define STATE_ACTIVE_STOP  "ACTIVE_STOP"
#define STATE_CLOSE        "CLOSE"
#define STATE_SKIP         "SKIP"
#define STATE_WAITING_DCA  "WAITING_DCA"
#define STATE_ACTIVE_DCA   "ACTIVE_DCA"
#define STATE_OPEN_DCA     "OPEN_DCA"
#define STATE_FREZEN_DCA   "FREZEN_DCA"
#endif // __GLOBALS_MQH__
