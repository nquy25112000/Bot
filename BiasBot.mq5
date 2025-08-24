// Include
#include "./utils/Include.mqh"

int OnInit()
{
  if(!EnsureBiasService()) return(INIT_FAILED);
  InitializeBiasIndicators(_Symbol);
  EventSetTimer(1);
  return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason)
{

}

void OnTick()
{

}


void OnTimer() {
  datetime now = TimeCurrent();
  MqlDateTime dt;
  TimeToStruct(now, dt);
  // ===== Nhật ký Bias mở phiên mới (00:00) =====
  if (dt.hour == 0 && dt.min == 0 && dt.sec == 0 && dt.day != lastLoggedDay)
  {
    // 1) Tạo cấu hình detect cho khung D1
    BiasConfig cfg;
    cfg.symbol = _Symbol;
    cfg.timeframe = BIAS_TF_D1;        // D1

    // 2) Gọi hàm detect mới
    BiasResult br;
    br = DetectBias(cfg);

    // 3) Thống kê kết quả
    if (br.type == "SELL")
      totalSell++;
    else if (br.type == "BUY")
      totalBuy++;
    else
      totalNone++;

    // 4) Lưu thời điểm đã log & ghi log JSON chuẩn
    lastLoggedDay = dt.day;
    LogBiasResultJSON(br);             // ghi JSON (hàm mới)
    // Hoặc nếu bạn vẫn muốn log text: LogDailyBias(br, 7);
  }

  // set thời gian bắt đầu cho daily bias ngày mới
  if(dt.hour == 0 && dt.min == 0 && dt.sec == 0) {
      dailyBiasStartTime = now;
  }
  
  // từ 8h UTC = 15H VN mà chưa có chạy signal hoặc đã kết thúc công việc hôm nay thì return luôn k chạy nữa
  if(dt.hour >= 8 && !isRunningBIAS){
    scanHour = 0;
    return;
  }

  if (dt.hour == scanHour && !isRunningBIAS) {
    startBias();
  }

  // [D1 7H> NONE > H4(7H) > NONE > H1(7H,8H,9H,10) > H4(11H) > NONE > H1(11H,12H,13H,14H)]  TOI 14H K CO SIGNAL NGHI LUON

  // double pnl = AccountInfoDouble(ACCOUNT_EQUITY) - AccountInfoDouble(ACCOUNT_BALANCE);
  // if (pnl < -950.0)
  // {
  //   static TriggerCfg TG = DefaultTriggerCfg();
  //   static HybridCfg  CFG = DefaultHybridCfg();

  //   string states[] = { STATE_OPEN }; // hoặc {"*"} nếu muốn gom tất cả comment
  //   Hedging_Hybrid_Dynamic(states, ArraySize(states), TG, CFG);
  // }

  if (isRunningBIAS) {
    scanDCANegative();
    double totalProfitFromTime = GetTotalProfitFrom(dailyBiasStartTime);
    // đạt target ngày hoặc là hết time chạy bias thì dừng toàn bộ hoạt động sau 18h UTC = 24h VN
    if(totalProfitFromTime >= maxProfit || dt.hour > 17) {
      scanHour = 0; 
      CloseAllOrdersAndPositions();
      isRunningBIAS = false;
    }
  }
 
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
  const MqlTradeRequest& request,
  const MqlTradeResult& result)
{
  TicketOnTradeTransaction(trans, request, result);
}
