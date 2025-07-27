//+------------------------------------------------------------------+
//| AI_Client.mqh – Build payload, call AI_Support, parse BiasResult |
//+------------------------------------------------------------------+
#ifndef __AI_CLIENT_MQH__
#define __AI_CLIENT_MQH__
#property strict
#include "CandlePattern.mqh"   // dùng AssessCandleD1()

//---------------- AIBiasResult (tránh trùng với BiasResult) --------
struct AIBiasResult
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
   datetime patternTime;    // epoch seconds
   string  patternStrength; // "STRONG" | "MODERATE" | "NEUTRAL" | "WEAK"
};

// Nếu DetectBIAS.mqh đã được include (có guard này) ⇒ cung cấp hàm map.
#ifdef __DAILY_BIAS_CONDITIONS_MQH__
void CopyToBiasResult(const AIBiasResult &src, BiasResult &dst)
{
   dst.type           = src.type;
   dst.percent        = src.percent;
   dst.bullScore      = src.bullScore;
   dst.bearScore      = src.bearScore;
   dst.patternId      = src.patternId;
   dst.patternName    = src.patternName;
   dst.patternScore   = src.patternScore;
   dst.patternCandles = src.patternCandles;
   dst.patternShift   = src.patternShift;
   dst.patternTime    = src.patternTime;
   dst.patternStrength= src.patternStrength;
}
#endif

//---------------- small helpers (compatible MQL5) ------------------
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

bool __IsSpace(ushort ch){ return (ch==32 || ch==9 || ch==10 || ch==13); }
string __Trim(const string &s){
   int n=StringLen(s);
   int i=0; while(i<n && __IsSpace(StringGetCharacter(s,i))) i++;
   int j=n-1; while(j>=i && __IsSpace(StringGetCharacter(s,j))) j--;
   if(j<i) return "";
   return StringSubstr(s,i,j-i+1);
}
// Tìm cặp dấu " ... " có xét escape
bool __FindQuoted(const string &src, int from, int &q1, int &q2)
{
   q1 = StringFind(src, "\"", from);
   if(q1<0) return false;
   int i=q1+1;
   int len=StringLen(src);
   while(i<len){
      ushort ch=StringGetCharacter(src,i);
      if(ch=='"'){
         // đếm số backslash liền trước
         int back=0; int k=i-1;
         while(k>=q1 && StringGetCharacter(src,k)=='\\'){ back++; k--; }
         if((back%2)==0){ q2=i; return true; }
      }
      i++;
   }
   return false;
}

//---------------- JSON helpers (đơn giản) --------------------------
bool __JsonGetString(const string &json,const string &field,string &out){
   string key="\""+field+"\"";
   int p=StringFind(json,key); if(p<0) return false;
   p=StringFind(json,":",p);   if(p<0) return false;
   int q1,q2;
   if(!__FindQuoted(json,p+1,q1,q2)) return false;
   out = StringSubstr(json,q1+1, q2-q1-1);
   return true;
}
bool __JsonGetNumber(const string &json,const string &field,double &out){
   string key="\""+field+"\"";
   int p=StringFind(json,key); if(p<0) return false;
   p=StringFind(json,":",p);   if(p<0) return false;

   int q=p+1;
   int len=StringLen(json);
   while(q<len && __IsSpace(StringGetCharacter(json,q))) q++;

   int r=q;
   while(r<len){
      ushort ch=StringGetCharacter(json,r);
      if(ch==',' || ch=='}' || ch==']') break;
      r++;
   }
   string num = __Trim(StringSubstr(json,q,r-q));
   out = StringToDouble(num);
   return true;
}
bool __JsonGetInt(const string &json,const string &field,int &out){
   double d; if(!__JsonGetNumber(json,field,d)) return false;
   out=(int)d; return true;
}

//---------------- In bias ------------------------------------------
void PrintAIBiasResult(const AIBiasResult &r)
{
   MqlDateTime d; TimeToStruct(r.patternTime, d);
   PrintFormat("[AI Bias] %04d-%02d-%02d | Bias=%s pct=%.1f | Bull=%.1f Bear=%.1f | Pattern=%s[id=%d,score=%.0f,used=%d,%s] shift=%d",
               d.year,d.mon,d.day,
               r.type, r.percent, r.bullScore, r.bearScore,
               r.patternName, r.patternId, r.patternScore, r.patternCandles, r.patternStrength, r.patternShift);
}

//---------------- Build payload (D1) --------------------------------
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
      bars += StringFormat("{\"t\":\"%s\",\"o\":%.5f,\"h\":%.5f,\"l\":%.5f,\"c\":%.5f}",
                           __TimeToISODate(t), o,h,l,c);
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

//---------------- Call API ------------------------------------------
bool CallAISupport(const string &url, const string &payload, string &outJson, int timeoutMs=15000)
{
   string headers = "Content-Type: application/json\r\n";
   uchar body[];   StringToCharArray(payload, body, 0, WHOLE_ARRAY, CP_UTF8);
   uchar result[]; string resp_headers;

   ResetLastError();
   int code = WebRequest("POST", url, headers, timeoutMs, body, result, resp_headers);
   requestCount++;
   if(code!=200){
      PrintFormat("[AI] WebRequest fail: HTTP=%d, err=%d. Whitelist %s ?", code, GetLastError(), url);
      return false;
   }
   outJson = CharArrayToString(result, 0, -1, CP_UTF8);
   return true;
}

//---------------- Parse JSON -> AIBiasResult ------------------------
bool ParseAIBiasResult(const string &json, AIBiasResult &r)
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
