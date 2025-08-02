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
  double minL=SymbolMinLot(), step=SymbolLotStep(), maxL=SymbolMaxLot();
  x=MathMax(minL, MathMin(x, maxL));
  int n=(int)MathRound(x/step);
  return NormalizeDouble(n*step, 2);
}

double Nd(double p)
{
  return NormalizeDouble(p, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

double TotalFloatingProfit()
{
  double tot=0.0;
  for(int i=0, c=PositionsTotal(); i<c; i++)
  {
    ulong tk=PositionGetTicket(i);
    if(tk==0 || !PositionSelectByTicket(tk)) continue;
    if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
    tot+=PositionGetDouble(POSITION_PROFIT);
  }
  return tot;
}

//======== State Scan & Net ========
bool StateInList(const string &s, const string &st[], int n)
{
  for(int i=0;i<n;i++)
    if(s==st[i]) return true;
  return false;
}

void ScanArray(TicketInfo &arr[], const string &st[], int n,
               int &cnt, double &sb, double &pb, double &ss, double &ps,
               ulong &lt, double &lp, double &lv, bool &isBuy)
{
  for(int i=0, N=ArraySize(arr); i<N; i++)
  {
    if(!StateInList(arr[i].state, st, n)) continue;
    cnt++;
    double v=arr[i].volume, p=arr[i].price;
    if(v>0) { sb+=v; pb+=v*p; }
    else    { ss+=-v; ps+=-v*p; }
    if(arr[i].ticketId>lt)
    {
      lt=arr[i].ticketId; lp=p; lv=v; isBuy=(v>=0);
    }
  }
}

bool ComputeNetAndLatest(const string &st[], int n,
                         double &netAvg, double &netVol,
                         double &bVol, double &sVol,
                         double &aBP, double &aSP,
                         bool &haveLatest, string &latestSide,
                         double &latestPrice, double &latestVol)
{
  int cnt=0; double sb=0,pb=0,ss=0,ps=0;
  ulong lt=0; double lp=0, lv=0; bool isB=false;
  ScanArray(m_tickets,         st, n, cnt, sb, pb, ss, ps, lt, lp, lv, isB);
  ScanArray(m_positiveTickets, st, n, cnt, sb, pb, ss, ps, lt, lp, lv, isB);
  ScanArray(m_frozenTickets,   st, n, cnt, sb, pb, ss, ps, lt, lp, lv, isB);

  if(cnt==0) return false;
  bVol=sb; sVol=ss;
  aBP=(sb>0?pb/sb:0); aSP=(ss>0?ps/ss:0);
  double net=bVol-sVol;
  if(MathAbs(net)>=1e-9) { netAvg=(pb-ps)/net; netVol=MathAbs(net); }
  haveLatest=(lt>0);
  latestSide=(isB?"BUY":"SELL");
  latestPrice=lp; latestVol=MathAbs(lv);
  return(MathAbs(net)>=1e-9);
}

//======== Broker Stops Guard ========
long   StopsLevelPoints() { long l=0; SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL,l); return l; }
double MinStopsPrice()    { return StopsLevelPoints()*SymbolInfoDouble(_Symbol,SYMBOL_POINT); }

void MakeValidPending(const string side, double &e, double &sl, double &tp)
{
  double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT), md=MinStopsPrice();
  double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
  if(side=="BUY")
  {
    if(e<=ask+md)      e = ask+md+2*pt;
    if(tp<=e+md)       tp = e+md+2*pt;
    if(sl>0 && sl>=e-md) sl = e-md-2*pt;
  }
  else
  {
    if(e>=bid-md)      e = bid-md-2*pt;
    if(tp>=e-md)       tp = e-md-2*pt;
    if(sl>0 && sl<=e+md) sl = e+md+2*pt;
  }
  e=Nd(e); if(sl>0) sl=Nd(sl); tp=Nd(tp);
}

//======== Logging & PlaceStop ========
void LogPlan(int r,const string &s,double v,double e,double sl,double tp)
{
  PrintFormat("[%s][R%d] %s_STOP vol=%.2f entry=%.2f sl=%.2f tp=%.2f",
              HEDGE_COMMENT_PREFIX, r, s, v, e, sl, tp);
}

bool PlaceStop(const string side, double vol, double e, double sl, double tp, int r)
{
  vol=ClampLot(vol);
  MakeValidPending(side,e,sl,tp);
  CTrade tr; tr.SetExpertMagicNumber(HEDGE_MAGIC); tr.SetDeviationInPoints(10);
  bool ok = (side=="BUY"
             ? tr.BuyStop(vol,e,_Symbol,sl,tp,ORDER_TIME_GTC)
             : tr.SellStop(vol,e,_Symbol,sl,tp,ORDER_TIME_GTC));
  if(!ok) PrintFormat("[%s][ERR] %s_STOP failed Err=%d",
                      HEDGE_COMMENT_PREFIX, side, GetLastError());
  return ok;
}