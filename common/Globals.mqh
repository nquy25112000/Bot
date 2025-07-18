#ifndef __GLOBALS_MQH__
#define __GLOBALS_MQH__
#include <Trade\Trade.mqh>
extern CTrade trade;

struct TicketInfo
{
   ulong  ticketId;
   double volume;
   string state;
   double price;
   double activePrice;
};

extern double     m_volumes[];
extern TicketInfo m_tickets[];
extern int        ticketCount;

extern int    jump;
extern int    targetByIndex1, targetByIndex2;
extern bool   dailyBiasRunning;
extern double dailyBiasSL, dailyBiasTP;
extern ENUM_ORDER_TYPE orderTypeDailyBias;

#define STATE_OPEN         "OPEN"
#define STATE_WAITING_STOP "WAITING_STOP"
#define STATE_ACTIVE_STOP  "ACTIVE_STOP"
#define STATE_CLOSE        "CLOSE"
#define STATE_SKIP         "SKIP"
#endif // __GLOBALS_MQH__
