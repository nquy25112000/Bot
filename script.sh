#!/usr/bin/env bash
<<<<<<< HEAD
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
=======
# Script: generate_hedge_tunnel_files.sh
# Mục đích: Tạo Helper.mqh và HedgeTunnel_Martingale_EA.mqh từ template

set -e

# Thư mục đầu ra (tùy chỉnh nếu cần)
OUT_DIR="./"
echo "Generating files in ${OUT_DIR}"

# 1) Tạo Helper.mqh
cat > "${OUT_DIR}Helper.mqh" << 'EOF'
//+------------------------------------------------------------------+
//| File: Helper.mqh                                                |
//| Mục đích: Gom các hàm tiện ích chung để include ở EA chính       |
//+------------------------------------------------------------------+
#property strict

//======== Lot & Price Utils ========
double SymbolMinLot()  { double v; SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN, v);  return v; }
double SymbolLotStep() { double v; SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP, v); return v; }
double SymbolMaxLot()  { double v; SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX, v);  return v; }

double ClampLot(double x)
{
  double minL = SymbolMinLot(), step = SymbolLotStep(), maxL = SymbolMaxLot();
  x = MathMax(minL, MathMin(x, maxL));
  int n = (int)MathRound(x/step);
  return NormalizeDouble(n*step, 2);
}

double Nd(double p)
{
  return NormalizeDouble(p, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

double TotalFloatingProfit()
{
  double tot = 0.0;
  for(int i = 0, c = PositionsTotal(); i < c; i++)
  {
    ulong tk = PositionGetTicket(i);
    if(tk == 0 || !PositionSelectByTicket(tk)) continue;
    if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
    tot += PositionGetDouble(POSITION_PROFIT);
  }
  return tot;
}

//======== State Scan & Net ========
bool StateInList(const string &s, string st[], int n)
{
  for(int i = 0; i < n; i++)
    if(s == st[i]) return true;
  return false;
}

void ScanArray(TicketInfo &arr[], string st[], int n,
               int &cnt, double &sb, double &pb, double &ss, double &ps,
               ulong &lt, double &lp, double &lv, bool &isBuy)
{
  for(int i = 0, N = ArraySize(arr); i < N; i++)
  {
    if(!StateInList(arr[i].state, st, n)) continue;
    cnt++;
    double v = arr[i].volume, p = arr[i].price;
    if(v > 0) { sb += v; pb += v*p; }
    else      { ss += -v; ps += -v*p; }
    if(arr[i].ticketId > lt)
    {
      lt = arr[i].ticketId;
      lp = p; lv = v; isBuy = (v >= 0);
    }
  }
}

bool ComputeNetAndLatest(string st[], int n,
                         double &netAvg, double &netVol,
                         double &bVol, double &sVol,
                         double &aBP, double &aSP,
                         bool &hasLatest, string &side,
                         double &price, double &vol)
{
  int cnt = 0;
  double sb = 0, pb = 0, ss = 0, ps = 0;
  ulong lt = 0; double lp = 0, lv = 0; bool isB = false;

  ScanArray(m_tickets,         st, n, cnt, sb, pb, ss, ps, lt, lp, lv, isB);
  ScanArray(m_positiveTickets, st, n, cnt, sb, pb, ss, ps, lt, lp, lv, isB);
  ScanArray(m_frozenTickets,   st, n, cnt, sb, pb, ss, ps, lt, lp, lv, isB);

  if(cnt == 0) return false;

  bVol = sb; sVol = ss;
  aBP  = (sb > 0 ? pb/sb : 0);
  aSP  = (ss > 0 ? ps/ss : 0);

  double net = bVol - sVol;
  if(MathAbs(net) >= 1e-9) { netAvg = (pb - ps)/net; netVol = MathAbs(net); }

  hasLatest = (lt > 0);
  side      = (isB ? "BUY" : "SELL");
  price     = lp;
  vol       = MathAbs(lv);

  return MathAbs(net) >= 1e-9;
}

//======== Broker Stops Guard ========
long   StopsLevelPoints() { long lvl = 0; SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, lvl); return lvl; }
double MinStopsPrice()    { return StopsLevelPoints() * SymbolInfoDouble(_Symbol, SYMBOL_POINT); }

void MakeValidPending(string side, double &e, double &sl, double &tp)
{
  double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT), md = MinStopsPrice();
  double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK), bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

  if(side == "BUY")
  {
    if(e <= ask + md)   e  = ask + md + 2*pt;
    if(tp <= e + md)    tp = e + md + 2*pt;
    if(sl > 0 && sl >= e - md) sl = e - md - 2*pt;
  }
  else
  {
    if(e >= bid - md)   e  = bid - md - 2*pt;
    if(tp >= e - md)    tp = e - md - 2*pt;
    if(sl > 0 && sl <= e + md) sl = e + md + 2*pt;
  }

  e  = Nd(e);
  if(sl > 0) sl = Nd(sl);
  tp = Nd(tp);
}

void LogPlan(int r, string s, double v, double e, double sl, double tp)
{
  PrintFormat("[HEDGE_MART][R%d] %s_STOP vol=%.2f entry=%.2f sl=%.2f tp=%.2f", r, s, v, e, sl, tp);
}

bool PlaceStop(string side, double vol, double e, double sl, double tp, int r)
{
  vol = ClampLot(vol);
  MakeValidPending(side, e, sl, tp);
  trade.SetExpertMagicNumber(HEDGE_MAGIC);
  trade.SetDeviationInPoints(10);

  string c = StringFormat("%s|%s|R%d", HEDGE_COMMENT_PREFIX, side, r);
  bool ok = (side == "BUY"
             ? trade.BuyStop(vol, e, _Symbol, sl, tp, ORDER_TIME_GTC)
             : trade.SellStop(vol, e, _Symbol, sl, tp, ORDER_TIME_GTC));
  if(!ok) PrintFormat("[HEDGE_MART][ERR] %s_STOP Err=%d", side, GetLastError());
  return ok;
}
EOF

# 2) Tạo HedgeTunnel_Martingale_EA.mqh
cat > "${OUT_DIR}HedgeTunnel_Martingale_EA.mqh" << 'EOF'
//+------------------------------------------------------------------+
//| File: HedgeTunnel_Martingale_EA.mqh                             |
//| Mục đích: EA chính include Helper.mqh và gọi martingale core     |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
#include "Helper.mqh"

extern string   HEDGE_COMMENT_PREFIX = "HEDGE";
extern int      HEDGE_MAGIC          = 20250727;
extern TicketInfo m_tickets[];
extern TicketInfo m_positiveTickets[];
extern TicketInfo m_frozenTickets[];

void Hedging_for_state_martingale(string st[], int n, int maxr, double tpft,
                                  double D_TP, double D_TUNNEL, double mult)
{
  // 1) Tính net & latest
  double netAvg=0, netVol=0, bVol=0, sVol=0, abp=0, asp=0;
  bool hasLatest=false; string side=""; double lp=0, lv=0;
  bool haveNet = ComputeNetAndLatest(st,n,
                                     netAvg, netVol,
                                     bVol, sVol,
                                     abp, asp,
                                     hasLatest, side, lp, lv);
  if(!hasLatest) return;

  // 2) Xác định Tunnel & baseVol
  double Upper, Lower, baseVol;
  if(haveNet)
  {
    Upper   = Nd(netAvg + D_TUNNEL);
    Lower   = Nd(netAvg - D_TUNNEL);
    baseVol = netVol;
  }
  else
  {
    if(side == "SELL")
    {
      Lower = Nd(lp);
      Upper = Nd(Lower + 2*D_TUNNEL);
    }
    else
    {
      Upper = Nd(lp);
      Lower = Nd(Upper - 2*D_TUNNEL);
    }
    baseVol = (lv > 0 ? lv : SymbolMinLot());
  }

  // 3) Entry/SL/TP cố định
  double be = Upper,  bs = Lower, bt = Nd(Upper + D_TP);
  double se = Lower,  ss = Upper, stp= Nd(Lower - D_TP);

  // 4) Vòng Martingale
  for(int r=1; r<=maxr; r++)
  {
    if(TotalFloatingProfit() >= tpft) break;
    double vol = ClampLot(baseVol * MathPow(mult, r-1));

    LogPlan(r, "BUY",  vol, be,  bs,  bt);
    PlaceStop("BUY",  vol, be,  bs,  bt,  r);
    LogPlan(r, "SELL", vol, se,  ss,  stp);
    PlaceStop("SELL", vol, se,  ss,  stp,  r);
  }
}

void OnTick()
{
  string states[] = {"OPEN","POS","FROZEN"};
  int    nStates  = ArraySize(states);
  int    ratio[]  = {2,5,2}; // D_TP=2, D_TUNNEL=5, multiplier=2
  Hedging_for_state_martingale(states, nStates, 4, 100.0,
                               ratio[0], ratio[1], ratio[2]);
}
EOF

echo "Helper.mqh and HedgeTunnel_Martingale_EA.mqh have been created."
>>>>>>> origin/hybrid-hedging-dynamic
