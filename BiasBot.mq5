// Include
#include "./utils/Include.mqh"

int OnInit()
{
  InitVolumes();
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
  if (dt.hour == 14 && dt.min == 0 && dt.sec == 0 && !dailyBiasRuning) {
    startDailyBias();
    dailyBiasStartTime = now;
  }

  if (dailyBiasRuning) {
    scanDCANegative();
    double totalProfitFromStartDailyBias = GetTotalProfitFrom(dailyBiasStartTime);
    if (totalProfitFromStartDailyBias >= targetProfitDailyBias) {
      CloseAllOrdersAndPositions();
      dailyBiasRuning = false;
    }
  }
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
  const MqlTradeRequest& request,
  const MqlTradeResult& result)
{
  TicketOnTradeTransaction(trans, request, result);
}
