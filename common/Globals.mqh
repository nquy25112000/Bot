#ifndef __GLOBALS_MQH__
#define __GLOBALS_MQH__

#include <Trade\Trade.mqh>
CTrade trade;               // Đối tượng giao dịch chung

// Struct lưu ticket phải định nghĩa trước khi dùng m_tickets[]
struct TicketInfo
{
   ulong  ticketId;
   double volume;
   string state;
   double price;
   double activePrice;
};

// Mảng dynamic, sẽ được InitVolumes() resize
double       m_volumes[];
TicketInfo   m_tickets[];
int          ticketCount;

// Các tham số chiến lược
int    jump;
int    targetByIndex1, targetByIndex2;
bool   dailyBiasRunning;
double dailyBiasSL, dailyBiasTP;
ENUM_ORDER_TYPE orderTypeDailyBias;

// Các trạng thái ticket
#define STATE_OPEN         "OPEN"
#define STATE_WAITING_STOP "WAITING_STOP"
#define STATE_ACTIVE_STOP  "ACTIVE_STOP"
#define STATE_CLOSE        "CLOSE"
#define STATE_SKIP         "SKIP"

#endif // __GLOBALS_MQH__
