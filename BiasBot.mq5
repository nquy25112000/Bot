// Include
#include "./utils/Include.mqh"

int OnInit()
{
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
  if (dt.hour == 0 && dt.min == 0 && dt.sec == 0 && dt.day != lastLoggedDay) {
    BiasResult br = DetectDailyBias();
    if (br.type == "SELL") {
      totalSell++;
    }
    else if (br.type == "BUY") {
      totalBuy++;
    }
    else
    {
      totalNone++;
    }
    lastLoggedDay = dt.day;
    LogDailyBias(br, 7);
  }
  if (dt.hour == 0 && dt.min == 0 && dt.sec == 0 && !dailyBiasRuning) {
    startBias(DAILY_BIAS);
    dailyBiasStartTime = now;
  }

  // double pnl = AccountInfoDouble(ACCOUNT_EQUITY) - AccountInfoDouble(ACCOUNT_BALANCE);
  // if (pnl < -950.0)
  // {
  //   static TriggerCfg TG = DefaultTriggerCfg();
  //   static HybridCfg  CFG = DefaultHybridCfg();

  //   string states[] = { STATE_OPEN }; // hoặc {"*"} nếu muốn gom tất cả comment
  //   Hedging_Hybrid_Dynamic(states, ArraySize(states), TG, CFG);
  // }

  if (dailyBiasRuning) {
    scanDCANegative(DAILY_BIAS);
  }

}

void OnTradeTransaction(const MqlTradeTransaction& trans,
  const MqlTradeRequest& request,
  const MqlTradeResult& result)
{
  TicketOnTradeTransaction(trans, request, result);
}
