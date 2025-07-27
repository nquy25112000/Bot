#property strict
#include <Trade/Trade.mqh>
#include "Helper.mqh"


// Core martingale
void Hedging_for_state(const string &st[], int n, int maxr, double tpft,
                       double D_TP, double D_TUNNEL, double mult)
{
 // Tính net & latest
  double netAvg, netVol, bVol, sVol, aBP, aSP;
  bool haveLatest; string side; double lp, lv;
  bool haveNet = ComputeNetAndLatest(st,n, netAvg,netVol,bVol,sVol,aBP,aSP,
                                     haveLatest, side, lp, lv);
  if(!haveLatest) return;

  // Xác định tunnel & baseVol
  double Upper,Lower,baseVol;
  if(haveNet) { Upper=Nd(netAvg+D_TUNNEL); Lower=Nd(netAvg-D_TUNNEL); baseVol=netVol; }
  else        { if(side=="SELL"){Lower=Nd(lp);Upper=Nd(Lower+2*D_TUNNEL);} else {Upper=Nd(lp);Lower=Nd(Upper-2*D_TUNNEL);} baseVol=lv; }

  // Entry/SL/TP
  double be=Upper, bs=Lower, bt=Nd(Upper+D_TP);
  double se=Lower, ss=Upper, stp=Nd(Lower-D_TP);

  // Vòng
  for(int r=1;r<=maxr;r++){
    if(TotalFloatingProfit()>=tpft) break;
    double vol=ClampLot(baseVol*MathPow(mult,r-1));
    LogPlan(r,"BUY",vol,be,bs,bt); PlaceStop("BUY",vol,be,bs,bt,r);
    LogPlan(r,"SELL",vol,se,ss,stp); PlaceStop("SELL",vol,se,ss,stp,r);
  }
}