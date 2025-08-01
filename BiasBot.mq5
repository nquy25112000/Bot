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
  if (dt.hour == 0 && dt.min == 0 && dt.sec == 0 && !dailyBiasRuning) {
    startBias(DAILY_BIAS);
    dailyBiasStartTime = now;
  }

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
