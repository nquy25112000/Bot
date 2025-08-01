//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#ifndef __GLOBALS_MQH__
#define __GLOBALS_MQH__

struct TicketInfo
{
  ulong             ticketId;
  double            volume;
  string            state;
  double            price;
  double            activePrice;
  ulong             frozenByTicketId;
};

struct BiasResult
{
   // Kết quả bias cuối cùng
   string  type;            // "BUY" | "SELL" | "NONE"
   double  percent;         // điểm hướng thắng (sau pattern bonus)
   double  bullScore;       // tổng điểm Bull
   double  bearScore;       // tổng điểm Bear

   // Snapshot CandlePattern của nến D1 đã đóng (shift=EVAL_SHIFT)
   int     patternId;       // enum CandlePattern
   string  patternName;     // ví dụ "Bullish Engulfing"
   double  patternScore;    // 0..100
   int     patternCandles;  // 1 / 2 / 3 / 5
   int     patternShift;    // thường = EVAL_SHIFT (1)
   datetime patternTime;    // open time nến D1 tại shift
   string  patternStrength; // "STRONG" | "MODERATE" | "NEUTRAL" | "WEAK"
};


// thời gian start daily bias. dùng để xác định thời gian bắt đầu của 1 lần chạy daily để tính toán lợi nhuận từ thời điểm start đến hiện tại
datetime dailyBiasStartTime;

// biến negativeTicketIndex dùng để xác định nó đã đi được đến entry nào của mảng DCA Âm
int negativeTicketIndex = 0;

// target lợi nhuận mỗi ngày
double targetProfitDailyBias = 900;

// m_volumes danh sách volume được list sẵn ra cho mỗi lệnh DCA âm
double m_volumes[];

// m_tickets là danh sách ticket tương ứng với m_volumes
TicketInfo m_tickets[];

// m_positiveTickets là danh sách các ticket  dùng cho DCA dương để xác định điểm đó đã được gán lệnh để giá quét qua lại nhiều lần không vào thêm lệnh mới
TicketInfo m_positiveTickets[];

//
TicketInfo m_frozenTickets[];

// Bước nhảy giá để đặt các lệnh stop cho mỗi lệnh. ví dụ jum = 1 thì cứ cách mỗi 1 giá thì đặt 1 lệnh stop cho lệnh âm
int    jump = 1;

// targetByIndex để xác định nó đang ở vị trí bao nhiêu trong m_volumes, nếu vị trí đặt stop = targetByIndex1 thì target lợi nhuận khác, = targetByIndex2 thì khác
int    targetByIndex1, targetByIndex2;

// orderTypeDailyBias biến khởi tạo đẻ xác định hôm nay đánh bài nào
ENUM_ORDER_TYPE orderTypeDailyBias;

// dailyBiasRuning xác định nó có trạng thái nào. 0 là không chạy, 1 là đang chạy. để dùng cho logic start dailybias và scan daily bias
bool dailyBiasRuning = false;

// priceFirstEntryDailyBias xác định giá của lệnh đầu tiên trong ngày để so sánh nếu giá thuận xu hướng thì chạy logic DCA Dương còn ngược thì quét list DCA âm đã khởi tạo trước đó
double priceFirstEntryDailyBias;

// DCA Dương mỗi vol mặc định 0.1
double dcaPositiveVol = 0.1;

string HEDGE_COMMENT_PREFIX = "HEDGE";
int    HEDGE_MAGIC          = 20250727;

// dành cho DCA âm
#define STATE_OPEN         "OPEN"
#define STATE_WAITING_STOP "WAITING_STOP"
#define STATE_ACTIVE_STOP  "ACTIVE_STOP"
#define STATE_SKIP         "SKIP"

// Dành cho DCA dương
#define STATE_OPEN_DCA         "OPEN_DCA_HEDGE"
#define STATE_ACTIVE_STOP_DCA  "ACTIVE_STOP_DCA"

// dành cho frozen
#define STATE_OPEN_FROZEN    "OPEN_FROZEN"
#define STATE_ACTIVE_FROZEN    "ACTIVE_FROZEN"

// dành chung
#define STATE_CLOSE        "CLOSE"

#endif // __GLOBALS_MQH__
