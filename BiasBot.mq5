// Include
#include "./common/Globals.mqh"
#include "./data/MarketDataService.mqh"
#include "./logic/TicketService.mqh"
#include "./logic/TradeService.mqh"
#include "./logic/SignalService.mqh"

int OnInit()
{
  if (jump == 1) {
    InitVolumes(m_volumes1);
    targetByIndex1 = 12; targetByIndex2 = 19;
  }
  else {
    InitVolumes(m_volumes2);
    targetByIndex1 = 5; targetByIndex2 = 10;
  }
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
  if (dt.hour == 7 && dt.min == 0 && dt.sec == 0 && !dailyBiasRuning) {
    startDailyBias();
    dailyBiasStartTime = now;
    Print("run daily on: ", now);
  }

  if (dailyBiasRuning) {
    scanDailyBias();
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