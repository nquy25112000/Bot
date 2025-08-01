#!/usr/bin/env bash
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

  ScanArray(dailyBiasNegative,         st, n, cnt, sb, pb, ss, ps, lt, lp, lv, isB);
  ScanArray(dailyBiasPositive, st, n, cnt, sb, pb, ss, ps, lt, lp, lv, isB);
  ScanArray(dailyBiasFrozen,   st, n, cnt, sb, pb, ss, ps, lt, lp, lv, isB);

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
extern TicketInfo dailyBiasNegative[];
extern TicketInfo dailyBiasPositive[];
extern TicketInfo dailyBiasFrozen[];

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
