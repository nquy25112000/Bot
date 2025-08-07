// Include
#include "./utils/Include.mqh"

int OnInit()
{

  // 1) Khởi chạy micro-service
  StartBiasService();

  // 2) Xác định thời điểm 15:00 hôm nay (giờ máy = UTC+7 của bạn)
  string today = TimeToString(TimeLocal(), TIME_DATE);  // YYYY.MM.DD
  g_stopTime = StringToTime(today + " 15:00");        // 15:00 local

  //if (!EnsureBiasService()) return(INIT_FAILED);
  InitializeBiasIndicators(_Symbol);
  EventSetTimer(1);
  return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason)
{
  StopBiasService();
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

  if (dt.hour == 0 && dt.min == 0 && dt.sec == 0 && !false) {
    startBias(DAILY_BIAS);
    dailyBiasStartTime = now;
  }

  if (TimeLocal() >= g_stopTime)
  {
    Print("Đã tới 15:00 – dừng AIScanBIAS");
    StopBiasService();
    EventKillTimer();   // ngừng timer, tránh gọi lại
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
    scanDCANegative(DAILY_BIAS);
  }

}

void OnTradeTransaction(const MqlTradeTransaction& trans,
  const MqlTradeRequest& request,
  const MqlTradeResult& result)
{
  TicketOnTradeTransaction(trans, request, result);
}
