#include <Trade\Trade.mqh>                      // Kết nối thư viện giao dịch
#include "../common/Globals.mqh"               // Biến toàn cục và struct
#include "../data/MarketDataService.mqh"       // Dịch vụ lấy dữ liệu giá/volume
#include "../logic/SignalService.mqh"          // Dịch vụ sinh tín hiệu
#include "../logic/TradeService.mqh"           // Dịch vụ đặt/đóng lệnh
#include "../logic/TicketService.mqh"          // Dịch vụ quản lý ticket

static const double volumes1[19] = { /* volume profile 1 */ };
static const double volumes2[10] = { /* volume profile 2 */ };

int jump = 1;                  // Khoảng giá (point) để chia entry
int targetByIndex1;            // Mốc entry 1 để tính TP
int targetByIndex2;            // Mốc entry 2 để tính TP
bool dailyBiasRunning = false; // Trạng thái chiến lược daily

int OnInit() {
  // Khởi tạo volumes và timer
  if(jump==1) {
    InitVolumes(volumes1, ArraySize(volumes1), 1);
    targetByIndex1=12; targetByIndex2=19;
  } else {
    InitVolumes(volumes2, ArraySize(volumes2), 1);
    targetByIndex1=5;  targetByIndex2=10;
  }
  EventSetTimer(1);   // OnTimer mỗi 1s
  TicketInit();       // Khởi tạo theo dõi ticket
  return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
  EventKillTimer();   // Hủy timer khi tắt EA
}

void OnTick() {
  UpdateTickets();    // Cập nhật trạng thái ticket (đóng khi TP)
}

void OnTimer() {
  // Thực thi theo giờ: StartDailyBias lúc 07:00, scan liên tục
  static bool initToday=false;
  MqlDateTime tm; TimeToStruct(TimeCurrent(), tm);
  if(tm.hour==7 && tm.min==0 && !initToday) {
    StartDailyBias();
    initToday=true;
  }
  if(dailyBiasRunning) ScanDailyBias();
  if(tm.hour!=7) initToday=false;
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result) {
  // Cập nhật ticket khi TP xảy ra
  TicketOnTradeTransaction(trans, request, result);
}
