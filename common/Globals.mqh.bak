#ifndef __GLOBALS_MQH__
#define __GLOBALS_MQH__

#include <Trade\Trade.mqh>
CTrade trade;

double       m_volumes[];
TicketInfo   m_tickets[];
int          ticketCount;

int    jump;
int    targetByIndex1, targetByIndex2;
bool   dailyBiasRunning;
double dailyBiasSL, dailyBiasTP;
ENUM_ORDER_TYPE orderTypeDailyBias;

struct TicketInfo
{
   ulong  ticketId;
   double volume;
   string state;
   double price;
   double activePrice;
};

#define STATE_OPEN         "OPEN"
#define STATE_WAITING_STOP "WAITING_STOP"
#define STATE_ACTIVE_STOP  "ACTIVE_STOP"
#define STATE_CLOSE        "CLOSE"
#define STATE_SKIP         "SKIP"

#endif // __GLOBALS_MQH__
