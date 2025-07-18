#ifndef __GLOBALS_MQH__
#define __GLOBALS_MQH__

#include <Trade\Trade.mqh>
extern CTrade trade;  // Đối tượng giao dịch

// Thông tin ticket (position)
struct TicketInfo {
  ulong    ticketId;
  double   volume;
  string   state;
  double   price;
  double   activePrice;
};

// Định nghĩa trạng thái ticket
#define STATE_OPEN         "OPEN"
#define STATE_WAITING_STOP "WAITING_STOP"
#define STATE_ACTIVE_STOP  "ACTIVE_STOP"
#define STATE_CLOSE        "CLOSE"
#define STATE_SKIP         "SKIP"

// Cấu hình chung
extern int    jump;
extern double m_volumes[];
extern int    targetByIndex1;
extern int    targetByIndex2;

// Trạng thái chiến lược daily
extern bool   dailyBiasRunning;
extern double dailyBiasSL;
extern double dailyBiasTP;
extern ENUM_ORDER_TYPE orderTypeDailyBias;

// Lưu trữ ticket
extern TicketInfo m_tickets[];
extern int        ticketCount;

#endif // __GLOBALS_MQH__
