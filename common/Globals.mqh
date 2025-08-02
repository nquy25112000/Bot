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

// ---------- ENUM / STRUCT ---------------------------------------
enum BiasTF { BIAS_TF_H1 = 0, BIAS_TF_H4 = 1, BIAS_TF_D1 = 2 };

struct BiasConfig {
   string symbol;
   BiasTF timeframe;
};


enum CondIdx {
   IDX_BODY = 0, IDX_WICK, IDX_VOLUME, IDX_RSI, IDX_MACD,
   IDX_MA50, IDX_PIVOT, IDX_PULLBACK, IDX_TREND_EXP, IDX_NOT_EXH,
   COND_TOTAL                               // = 10
};

struct BiasResult
{
   string symbol;
   BiasTF timeframe;
   string type;          // "BUY" | "SELL" | "NONE"
   double percent;
   double bullScore;
   double bearScore;
   int    patternId;
   string patternName;
   double patternScore;
   int    patternCandles;
   int    patternShift;
   datetime patternTime;
   string patternStrength;
};

// thời gian start daily bias. dùng để xác định thời gian bắt đầu của 1 lần chạy daily để tính toán lợi nhuận từ thời điểm start đến hiện tại
datetime dailyBiasStartTime;
// biến negativeTicketIndex dùng để xác định nó đã đi được đến entry nào của mảng DCA Âm
int negativeTicketIndex = 0;
// target lợi nhuận mỗi ngày
double targetProfitDailyBias = 900;

// dailyBiasNegativeVolume danh sách volume được list sẵn ra cho mỗi lệnh DCA âm
// mảng 10 phần tử để test
// static const double dailyBiasNegativeVolume[10] = { 0.05,0.07,0.09,0.11,0.13,0.16,0.16,0.13,0.09,0.07 };
double dailyBiasNegativeVolume[19] = {0.03,0.04,0.05,0.06,0.07,0.08,0.09,0.1,0.1,0.09,0.08,0.07,0.06,0.05,0.05,0.05,0.04,0.03,0.03 };
double h4BiasNegativeVolume[19]    = {0.02,0.03,0.04,0.05,0.06,0.06,0.07,0.08,0.08,0.07,0.06,0.06,0.05,0.04,0.04,0.04,0.03,0.02,0.02};
double h1BiasNegativeVolume[19]    = {0.02,0.02,0.03,0.03,0.04,0.04,0.05,0.05,0.05,0.05,0.04,0.04,0.03,0.03,0.03,0.03,0.02,0.02,0.02};


// negTicketList là danh sách ticket tương ứng với dailyBiasNegativeVolume
TicketInfo negTicketList[];
// posTicketList là danh sách các ticket  dùng cho DCA dương để xác định điểm đó đã được gán lệnh để giá quét qua lại nhiều lần không vào thêm lệnh mới
TicketInfo posTicketList[];
// frozTicketList là danh sách các lệnh đóng băng cho lệnh DCA dương
TicketInfo frozTicketList[];

TicketInfo h4BiasNegative[];
TicketInfo h4BiasPositive[];
TicketInfo h4BiasFrozen[];

TicketInfo h1BiasNegative[];
TicketInfo h1BiasPositive[];
TicketInfo h1BiasFrozen[];

ulong dailyBiasTicketIds[];
ulong h4BiasTicketIds[];
ulong h1BiasTicketIds[];


// targetByIndex để xác định nó đang ở vị trí bao nhiêu trong dailyBiasNegativeVolume, nếu vị trí đặt stop = targetByIndex1 thì target lợi nhuận khác, = targetByIndex2 thì khác
int    targetByIndex1, targetByIndex2;

int totalSell = 0;
int totalBuy = 0;
int totalNone = 0;
int lastLoggedDay = -1;

// orderTypeBias biến khởi tạo đẻ xác định hôm nay đánh bài nào
ENUM_ORDER_TYPE orderTypeBias;
ENUM_ORDER_TYPE orderTypeH4Bias;
ENUM_ORDER_TYPE orderTypeH1Bias;

// dailyBiasRuning xác định nó có trạng thái nào. 0 là không chạy, 1 là đang chạy. để dùng cho logic start dailybias và scan daily bias
bool dailyBiasRuning = false;
// priceFirstEntryDailyBias xác định giá của lệnh đầu tiên trong ngày để so sánh nếu giá thuận xu hướng thì chạy logic DCA Dương còn ngược thì quét list DCA âm đã khởi tạo trước đó
double priceFirstEntryDailyBias;
// DCA Dương mỗi vol mặc định 0.1
double dcaPositiveVol = 0.1;

bool h4BiasRuning = false;
double priceFirstEntryh4Bias;
double dcaPositiveVolH4 = 0.1;

bool h1BiasRuning = false;
double priceFirstEntryh1Bias;
double dcaPositiveVolH1 = 0.1;

string HEDGE_COMMENT_PREFIX = "HEDGE";
int    HEDGE_MAGIC = 20250727;

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


// Bias Type
#define DAILY_BIAS     "D1"
#define H4_BIAS        "H4"
#define H1_BIAS        "H1"

// Array Type
#define POSITIVE_ARRAY        "POSITIVE"
#define NEGATIVE_ARRAY        "NEGATIVE"
#define FROZEN_ARRAY          "FROZEN"

#endif // __GLOBALS_MQH__
