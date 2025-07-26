#!/usr/bin/env bash
set -euo pipefail

# --- chỉnh path gốc nếu cần ---
ROOT="$(pwd)"
TARGET="${ROOT}/logic/Detect"

if [ ! -d "${TARGET}" ]; then
  echo "❌ Không tìm thấy thư mục ${TARGET}. Hãy chạy script từ root project (thư mục chứa logic/Detect)."
  exit 1
fi

echo "➡️  Tạo file vào: ${TARGET}"

# ============ AI_Client.mqh ============
cat > "${TARGET}/AI_Client.mqh" <<'MQH'
//+------------------------------------------------------------------+
//| AI_Client.mqh – Build payload, call AI_Support, parse BiasResult |
//+------------------------------------------------------------------+
#ifndef __AI_CLIENT_MQH__
#define __AI_CLIENT_MQH__
#property strict
#include "CandlePattern.mqh"   // dùng AssessCandleD1()

struct BiasResult
{
   string  type;            // "BUY" | "SELL" | "NONE"
   double  percent;         // 0..100
   double  bullScore;
   double  bearScore;

   int     patternId;
   string  patternName;
   double  patternScore;    // 0..100
   int     patternCandles;  // 1|2|3|5
   int     patternShift;    // thường = 1
   datetime patternTime;    // epoch seconds (open time của nến D1)
   string  patternStrength; // "STRONG" | "MODERATE" | "NEUTRAL" | "WEAK"
};

string __JsonEscape(const string s){
   string r = s;
   StringReplace(r, "\\", "\\\\");
   StringReplace(r, "\"", "\\\"");
   return "\""+r+"\"";
}
string __TimeToISODate(datetime t){
   MqlDateTime d; TimeToStruct(t, d);
   return StringFormat("%04d-%02d-%02d", d.year, d.mon, d.day);
}
int __ClampInt(int x,int lo,int hi){ if(x<lo) return lo; if(x>hi) return hi; return x; }
double __ClampDouble(double x,double lo,double hi){ if(x<lo) return lo; if(x>hi) return hi; return x; }

//--- JSON helpers (đơn giản, vì server ép JSON sạch) ----------------
bool __JsonGetString(const string &json,const string &field,string &out){
   string key="\""+field+"\"";
   int p=StringFind(json,key); if(p<0) return false;
   p=StringFind(json,":",p); if(p<0) return false;
   int q=StringFind(json,"\"",p+1); if(q<0) return false;
   int r=StringFind(json,"\"",q+1); if(r<0) return false;
   out = json.SubString(q+1, r-q-1);
   return true;
}
bool __JsonGetNumber(const string &json,const string &field,double &out){
   string key="\""+field+"\"";
   int p=StringFind(json,key); if(p<0) return false;
   p=StringFind(json,":",p); if(p<0) return false;
   int q=p+1; // skip spaces
   while(q<StringLen(json) && (StringGetCharacter(json,q)==32 || StringGetCharacter(json,q)==9)) q++;
   int r=q;
   while(r<StringLen(json)){
      ushort ch=StringGetCharacter(json,r);
      if(ch==',' || ch=='}' || ch==']') break;
      r++;
   }
   string num = StringTrim(json.SubString(q,r-q));
   out = (double)StringToDouble(num);
   return true;
}
bool __JsonGetInt(const string &json,const string &field,int &out){
   double d; if(!__JsonGetNumber(json,field,d)) return false;
   out=(int)d; return true;
}

//--- In bias --------------------------------------------------------
void PrintBiasResult(const BiasResult &r)
{
   MqlDateTime d; TimeToStruct(r.patternTime, d);
   PrintFormat("[AI Bias] %04d-%02d-%02d | Bias=%s pct=%.1f | Bull=%.1f Bear=%.1f | Pattern=%s[id=%d,score=%.0f,used=%d,%s] shift=%d",
               d.year,d.mon,d.day,
               r.type, r.percent, r.bullScore, r.bearScore,
               r.patternName, r.patternId, r.patternScore, r.patternCandles, r.patternStrength, r.patternShift);
}

//--- Build payload (bars D1 + pattern snapshot hiện tại) ------------
string BuildPayloadD1(const string symbol, const string timeframe, int lookback, const string session="ASIA")
{
   int n = __ClampInt(lookback, 5, 120);
   string bars="[";
   for(int i=n; i>=1; --i){
      datetime t=iTime(symbol, PERIOD_D1, i);
      double o=iOpen(symbol,PERIOD_D1,i);
      double h=iHigh(symbol,PERIOD_D1,i);
      double l=iLow(symbol,PERIOD_D1,i);
      double c=iClose(symbol,PERIOD_D1,i);
      if(i!=n) bars += ",";
      bars += StringFormat("{\"t\":\"%s\",\"o\":%.5f,\"h\":%.5f,\"l\":%.5f,\"c\":%.5f}", __TimeToISODate(t), o,h,l,c);
   }
   bars+="]";

   PatternScore ps = AssessCandleD1(1);
   datetime pt = iTime(symbol, PERIOD_D1, 1);

   string payload =
      "{"
        "\"symbol\":" + __JsonEscape(symbol) + ","
        "\"timeframe\":" + __JsonEscape(timeframe) + ","
        "\"session\":" + __JsonEscape(session) + ","
        "\"pattern\":{\"id\":" + IntegerToString(ps.id) + ","
                     "\"name\":" + __JsonEscape(ps.name) + ","
                     "\"score\":" + DoubleToString(ps.score,1) + ","
                     "\"candlesUsed\":" + IntegerToString(ps.candlesUsed) + "},"
        "\"patternShift\":1,"
        "\"patternTime\":" + IntegerToString((int)pt) + ","
        "\"features\":{"
            "\"rsi\":50.0,\"macd\":{\"m\":0.0,\"s\":0.0},\"adx\":20.0,\"atr\":1.0,"
            "\"trendExpansionBull\":false,\"trendExpansionBear\":false"
        "},"
        "\"bars\":" + bars +
      "}";
   return payload;
}

//--- Call API -------------------------------------------------------
bool CallAISupport(const string &url, const string &payload, string &outJson, int timeoutMs=15000)
{
   string headers = "Content-Type: application/json\r\n";
   uchar body[]; StringToCharArray(payload, body, 0, WHOLE_ARRAY, CP_UTF8);
   uchar result[]; string resp_headers;

   ResetLastError();
   int code = WebRequest("POST", url, headers, timeoutMs, body, result, resp_headers);
   if(code!=200){
      PrintFormat("[AI] WebRequest fail: HTTP=%d, err=%d. Whitelist %s ?", code, GetLastError(), url);
      return false;
   }
   outJson = CharArrayToString(result, 0, -1, CP_UTF8);
   return true;
}

//--- Parse JSON -> BiasResult --------------------------------------
bool ParseBiasResult(const string &json, BiasResult &r)
{
   r.type="NONE"; r.percent=0; r.bullScore=0; r.bearScore=0;
   r.patternId=0; r.patternName="None"; r.patternScore=0; r.patternCandles=1; r.patternShift=1; r.patternTime=0; r.patternStrength="NEUTRAL";

   string s; double d; int v;
   if(__JsonGetString(json,"type",s)) r.type=s;
   if(__JsonGetNumber(json,"percent",d)) r.percent=__ClampDouble(d,0,100);
   if(__JsonGetNumber(json,"bullScore",d)) r.bullScore=d;
   if(__JsonGetNumber(json,"bearScore",d)) r.bearScore=d;

   if(__JsonGetInt(json,"patternId",v)) r.patternId=v;
   if(__JsonGetString(json,"patternName",s)) r.patternName=s;
   if(__JsonGetNumber(json,"patternScore",d)) r.patternScore=d;
   if(__JsonGetInt(json,"patternCandles",v)) r.patternCandles=__ClampInt(v,1,5);
   if(__JsonGetInt(json,"patternShift",v)) r.patternShift=v;
   if(__JsonGetInt(json,"patternTime",v)) r.patternTime=(datetime)v;
   if(__JsonGetString(json,"patternStrength",s)) r.patternStrength=s;
   return true;
}
#endif // __AI_CLIENT_MQH__
MQH

# ============ AIBiasScheduler.mq5 ============
cat > "${TARGET}/AIBiasScheduler.mq5" <<'MQ5'
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
MQ5

echo "✅ Đã tạo:"
echo "   - ${TARGET}/AI_Client.mqh"
echo "   - ${TARGET}/AIBiasScheduler.mq5"
echo "👉 Import EA (AIBiasScheduler.mq5) vào MT5, gắn lên chart, set giờ 07:00."
