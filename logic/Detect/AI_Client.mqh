//+------------------------------------------------------------------+
//| AI_Client.mqh – Call BiasService và trả về BiasResult            |
//+------------------------------------------------------------------+
#ifndef __AI_CLIENT_MQH__
#define __AI_CLIENT_MQH__

#include <Trade\WebRequest.mqh>

//— Inputs -----------------------------------------------------------
extern string BiasService_URL   = "http://127.0.0.1:8000/analyze"; // endpoint
extern int    Bars_To_Send      = 20;      // số nến gần nhất gửi lên
extern int    BiasService_TimeoutMs = 15000;

//— Enum & struct giống định nghĩa trong Bot ------------------------
enum BiasTF { BIAS_TF_H1, BIAS_TF_H4, BIAS_TF_D1 };

struct BiasResult
{
   string   symbol;
   BiasTF   timeframe;
   string   type;          // BUY | SELL | NONE
   double   percent;
   double   bullScore;
   double   bearScore;
   int      patternId;
   string   patternName;
   double   patternScore;
   int      patternCandles;
   int      patternShift;
   datetime patternTime;
   string   patternStrength;
};

//— Build body JSON --------------------------------------------------
string BuildRequestBody(const string symbol, const ENUM_TIMEFRAMES tf, int bars_n)
{
   MqlRates rates[];
   if(CopyRates(symbol, tf, 1, bars_n, rates) <= 0)
   {
      PrintFormat("CopyRates lỗi: %d", GetLastError());
      return "";
   }

   string bars = "[";
   for(int i = 0; i < bars_n; i++)
   {
      if(i) bars += ",";
      bars += StringFormat(
         "{\"t\":%d,\"o\":%.5f,\"h\":%.5f,\"l\":%.5f,\"c\":%.5f}",
         rates[i].time, rates[i].open, rates[i].high, rates[i].low, rates[i].close
      );
   }
   bars += "]";

   string tf_s = (tf == PERIOD_D1 ? "D1" : tf == PERIOD_H4 ? "H4" : "H1");

   return StringFormat(
      "{\"symbol\":\"%s\",\"timeframe\":\"%s\",\"bars\":%s}",
      symbol, tf_s, bars
   );
}

//— Hàm chính --------------------------------------------------------
bool RequestBias(const string symbol, const ENUM_TIMEFRAMES tf, BiasResult &out)
{
   // 1) Build body
   string body = BuildRequestBody(symbol, tf, Bars_To_Send);
   if(StringLen(body) == 0) return false;

   uchar bytes[];
   int len = StringToCharArray(body, bytes, 0, CP_UTF8);

   string headers = "Content-Type: application/json\r\n";

   // 2) WebRequest
   char  resp[];
   ResetLastError();
   int   code = WebRequest(
                  "POST",
                  BiasService_URL,
                  headers,
                  BiasService_TimeoutMs,
                  bytes, len,
                  resp, NULL);

   if(code != 200)
   {
      PrintFormat("BiasService HTTP %d (Err=%d)", code, GetLastError());
      return false;
   }

   // 3) Parse JSON trả về
   string json = CharArrayToString(resp);
   if(!ParseBiasResultFromJson(json, out))
   {
      Print("ParseBiasResultFromJson thất bại");
      return false;
   }

   // 4) Gán lại enum timeframe
   out.timeframe = (tf == PERIOD_D1 ? BIAS_TF_D1 : tf == PERIOD_H4 ? BIAS_TF_H4 : BIAS_TF_H1);
   return true;
}

#endif // __AI_CLIENT_MQH__
