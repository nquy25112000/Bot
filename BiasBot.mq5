// Include
#include "./common/Globals.mqh"
#include "./data/MarketDataService.mqh"
#include "./logic/TicketService.mqh"
#include "./logic/TradeService.mqh"
#include "./logic/SignalService.mqh"
#include "./logic/DailyBiasConditions.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(jump == 1)
     {
      InitVolumes(m_volumes1);
      targetByIndex1 = 12;
      targetByIndex2 = 19;
     }
   else
     {
      InitVolumes(m_volumes2);
      targetByIndex1 = 5;
      targetByIndex2 = 10;
     }
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {

  }
int biasDaysCount = 0;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   if(dt.hour == 7 && dt.min == 0 && dt.sec == 0 && dailyBiasRuning == 0)
     {
      startDailyBias();
      BiasResult br = DetectDailyBias();

      if(br.isActiveBias)
        {
         biasDaysCount++;
         PrintFormat("Bias %s – %.0f%% (Bull=%d | Bear=%d)",
                     br.type==BIAS_BUY  ? "BUY"  :
                     br.type==BIAS_SELL ? "SELL" : "NONE",
                     br.percent, br.bullCount, br.bearCount, biasDaysCount);
        }

      else
        {
         PrintFormat("Lưỡng lự bỏ qua – Bull=%d, Bear=%d",
                     br.bullCount, br.bearCount);
        }


      // In timestamp đẹp hơn
      PrintFormat("Run daily on: %s", TimeToString(now, TIME_DATE|TIME_SECONDS));
     }
   if(dailyBiasRuning == 1)
     {
      scanDailyBias();
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
   TicketOnTradeTransaction(trans, request, result);
  }
//+------------------------------------------------------------------+
