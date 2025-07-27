// Include
#include "./utils/Include.mqh"

int OnInit()
{
  if (jump == 1) {
    InitVolumes(m_volumes1);
    targetByIndex1 = 10; targetByIndex2 = 17;
  }
  else {
    InitVolumes(m_volumes2);
    targetByIndex1 = 4; targetByIndex2 = 8;
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
  if (dt.hour == 14 && dt.min == 0 && dt.sec == 0 && !dailyBiasRuning) {
    BiasResult biasResult = DetectDailyBias();
    if (biasResult.type == "SELL")
        orderTypeDailyBias = ORDER_TYPE_SELL;
     else
        orderTypeDailyBias = ORDER_TYPE_BUY;
     PrintFormat("DETECT BIAS %s – Bull=%d | Bear=%d (%.0f%%)",
                 biasResult.type,          // %s  : chuỗi  BUY / SELL / NONE
                 biasResult.bullScore,     // %d  : số nguyên
                 biasResult.bearScore,     // %d  : số nguyên
                 biasResult.percent);      // %.0f: làm tròn phần trăm
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
