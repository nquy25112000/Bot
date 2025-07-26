//+------------------------------------------------------------------+
//| AIBiasScheduler.mq5 – gọi AI_Support lúc 07:00 mỗi ngày         |
//+------------------------------------------------------------------+
#property strict
#property version   "1.0.0"
#property description "Call AI_Support at 07:00 broker time daily, parse BiasResult and print."

#include "AI_Client.mqh"

//================= INPUTS =================
input string AIS_URL          = "http://127.0.0.1:8000/analyze";
input string SymbolToQuery    = _Symbol;  // ví dụ: XAUUSD
input string TimeframeToQuery = "D1";
input int    RunHour          = 7;        // 07:00 broker time
input int    RunMinute        = 0;
input int    TimerIntervalSec = 30;       // check mỗi 30s
input int    LookbackBars     = 30;       // số nến D1 gửi lên

//================= STATE =================
datetime g_lastRunKey = 0; // YYYYMMDD của lần chạy gần nhất (broker time)

bool IsRunWindow(datetime now, int hh, int mm, int windowSec=120)
{
   MqlDateTime d; TimeToStruct(now, d);
   if(d.hour!=hh || d.min!=mm) return false;
   datetime t0 = now - d.sec; // đầu phút
   return (now - t0) <= windowSec;
}

int OnInit()
{
   EventSetTimer(TimerIntervalSec);
   PrintFormat("[AI] Init OK. Will call %s at %02d:%02d daily. Remember to whitelist URL in Tools->Options->Expert Advisors->WebRequest.",
               AIS_URL, RunHour, RunMinute);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason)
{
   EventKillTimer();
}

void OnTimer()
{
   datetime now = TimeCurrent();
   MqlDateTime d; TimeToStruct(now, d);

   if(IsRunWindow(now, RunHour, RunMinute, 120))
   {
      datetime key = (datetime)(d.year*10000 + d.mon*100 + d.day);
      if(key != g_lastRunKey)
      {
         g_lastRunKey = key;

         string payload = BuildPayloadD1(SymbolToQuery, TimeframeToQuery, LookbackBars, "ASIA");
         string out;
         if(CallAISupport(AIS_URL, payload, out))
         {
            BiasResult br;
            if(ParseBiasResult(out, br))
               PrintBiasResult(br);
            else
               Print("[AI] ParseBiasResult failed. Raw: ", out);
         }
      }
   }
}

void OnTick(){ /* not used */ }
