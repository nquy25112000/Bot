// Include
#include "./utils/Include.mqh"


int OnInit()
{

  // 1) Khởi chạy micro-service
  Print("BiasServiceDir() = ", BiasServiceDir());
  if (!StartBiasService())
  {
    Print("❌ Không start được AIScanBIAS");
    return(INIT_FAILED);
  }
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




bool isRun(datetime from, datetime to, bool params) {
  datetime now = TimeCurrent();
  if (now >= from && now <= to && params) {
    return true;
  }
  else {
    return false;
  }
}


bool checkProfit() {
  double totalProfitFromTime = GetTotalProfitFrom(dailyBiasStartTime);
  return totalProfitFromTime < 500;
}


void OnTimer() {
  datetime now = TimeCurrent();
  datetime from = StringToTime("2025.04.09 00:00:00");
  datetime to = StringToTime("2025.04.09 05:00:00");



  if (isRun(from, to, checkProfit())) {

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

    int hour = scanHour;
    bool runningBias = isRunningBIAS;
    // từ 8h UTC = 15H VN mà chưa có chạy signal hoặc đã kết thúc công việc hôm nay thì return luôn k chạy nữa
    if (dt.hour >= 8 && !isRunningBIAS) {
      scanHour = 0;
      return;
    }

    if (scanHour == 0) {
      dailyBiasStartTime = now;
    }


    if (dt.hour == scanHour && !isRunningBIAS) {
      startBias();
    }


    // lần chạy đầu mà TP thì ép lần chạy thứ 2 chạy lại vào giờ tiếp theo
    if (isTP == true && dt.hour == scanHour && !isRunningBIAS) {
      clearData();
      orderTypeBias = ORDER_TYPE_BUY; // BUY hoặc SELL
      dcaPositiveVol = 0.06;
      datetime now = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(now, dt);
      scanHour = dt.hour + 1;
      isRunningBIAS = true;
      // Khởi tạo DCA âm
      initDCANegative();
      // Khởi tạo lệnh STOP cách lệnh đầu tiên 2 giá thuận xu hướng. priceInitEntry là price đã được set cho lệnh đầu tiên DCA âm tại hàm initDCANegative();
      orderStopFollowTrend(orderTypeBias == ORDER_TYPE_BUY ? priceInitEntry + 1 : priceInitEntry - 1); // hàm này nó cộng sẵn 1 rồi nên chỉ cần truyền priceInitEntry + 1
      initTargetCentList();
      setIndexNegativeActiveHedge();
      isTP = false;
    }

    /*
    if (TimeLocal() >= g_stopTime)
    {
      Print("Đã tới 15:00 – dừng AIScanBIAS");
      StopBiasService();
      EventKillTimer();   // ngừng timer, tránh gọi lại
    }
    */
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
      if (totalProfitFromTime >= maxProfit || dt.hour == 17) {
        // nếu kết thúc chuỗi lệnh mà thời điểm hiện tại dt.hour >= 7 nghĩa là đã 14h VN thì trả scanHour về 0 để qua ngày sau nó chạy lại
        // ngược lại < 7 thì thời gian scan tiếp theo sẽ là 1 tiếng sau
        scanHour = dt.hour >= 7 ? 0 : dt.hour + 1;
        CloseAllOrdersAndPositions();
        isRunningBIAS = false;
      }
    }

  }

}

void OnTradeTransaction(const MqlTradeTransaction& trans,
  const MqlTradeRequest& request,
  const MqlTradeResult& result)
{
  TicketOnTradeTransaction(trans, request, result);
}