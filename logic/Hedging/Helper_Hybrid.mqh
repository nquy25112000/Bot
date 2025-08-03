//==============================================================
// Helper_Hybrid.mqh – Bộ hàm tiện ích dùng chung cho Hedging (MQL5)
//==============================================================
#property strict
#ifndef __HELPER_HYBRID_MQH__
#define __HELPER_HYBRID_MQH__

#include <Trade/Trade.mqh>

//---------------- (1) SYMBOL/LOT UTILS -------------------------//
// (1a) DIGITS/POINT
int    DigitsSym() { return (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS); }
double PointSym()  { return SymbolInfoDouble(_Symbol, SYMBOL_POINT); }

// (1b) Min/Step/Max lot
double SymbolMinLot(){ double v; SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN,  v); return v; }
double SymbolLotStep(){ double v; SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP, v); return v; }
double SymbolMaxLot(){ double v; SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX,  v); return v; }

// (1c) Clamp lot theo step + biên min/max (tự tính chữ số theo step)
double ClampLot(double x)
{
  double minLot=SymbolMinLot(), step=SymbolLotStep(), maxLot=SymbolMaxLot();
  x = MathMax(minLot, MathMin(x, maxLot));
  int steps = (int)MathRound(x/step);
  double v = steps * step;
  int lotDigits=0; double s=step;
  while(lotDigits<8 && MathAbs(s - MathRound(s))>1e-12){ s*=10.0; lotDigits++; }
  return NormalizeDouble(v, lotDigits);
}

// (1d) Normalize theo digits
double Nd(double price){ return NormalizeDouble(price, DigitsSym()); }

//---------------- (2) BROKER GUARDS -----------------------------//
// (2a) Stops level tối thiểu (đơn vị GIÁ)
double MinStopsDistancePrice()
{
  long lvPoints=0; SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, lvPoints);
  return (double)lvPoints * PointSym();
}

// (2b) Hợp lệ hoá Entry/SL/TP cho pending theo side
void MakeValidPendingPrices(const string side, double &entry, double &sl, double &tp)
{
  double pt      = PointSym();
  double minDist = MinStopsDistancePrice();
  double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);

  if(side=="BUY")
  {
    if(entry <= ask + minDist) entry = ask + minDist + 2*pt;
    if(tp    <= entry + minDist) tp = entry + minDist + 2*pt;
    if(sl>0 && sl >= entry - minDist) sl = entry - minDist - 2*pt;
  }
  else // SELL
  {
    if(entry >= bid - minDist) entry = bid - minDist - 2*pt;
    if(tp    >= entry - minDist) tp = entry - minDist - 2*pt;
    if(sl>0 && sl <= entry + minDist) sl = entry + minDist + 2*pt;
  }
  entry = Nd(entry);
  if(sl>0)    sl = Nd(sl);
  if(tp!=0.0) tp = Nd(tp);
}

// (2c) Spread guard
bool SpreadOK(double max_usd)
{
  double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
  return (spread <= max_usd);
}

//---------------- (3) INDICATORS -------------------------------//
// (3a) ATR an toàn (shift=1)
double SafeATR(ENUM_TIMEFRAMES tf, int period)
{
  static int h = INVALID_HANDLE;
  static int lastPeriod = -1;
  static ENUM_TIMEFRAMES lastTF = (ENUM_TIMEFRAMES)-1;

  if(h==INVALID_HANDLE || period!=lastPeriod || tf!=lastTF){
    if(h!=INVALID_HANDLE) IndicatorRelease(h);
    h = iATR(_Symbol, tf, period);
    lastPeriod = period; lastTF = tf;
  }
  if(h==INVALID_HANDLE) return 0.0;

  double buf[]; int copied = CopyBuffer(h, 0, 1, 1, buf);
  if(copied!=1) return 0.0;
  return buf[0];
}

// (3b) ADX an toàn (buffer 0 = ADX)
double SafeADX(ENUM_TIMEFRAMES tf, int period)
{
  static int h = INVALID_HANDLE;
  static int lastPeriod = -1;
  static ENUM_TIMEFRAMES lastTF = (ENUM_TIMEFRAMES)-1;

  if(h==INVALID_HANDLE || period!=lastPeriod || tf!=lastTF){
    if(h!=INVALID_HANDLE) IndicatorRelease(h);
    h = iADX(_Symbol, tf, period);
    lastPeriod = period; lastTF = tf;
  }
  if(h==INVALID_HANDLE) return 0.0;

  double buf[]; int copied = CopyBuffer(h, 0, 1, 1, buf);
  if(copied!=1) return 0.0;
  return buf[0];
}

//---------------- (4) TRIGGERS & SCAN POSITIONS ----------------//
// (4a) Phá đáy gần nhất & không hồi tối thiểu
bool BrokeUnderNoPullback(double breakUnder_usd, double noPullback_usd, int bars, ENUM_TIMEFRAMES tf)
{
  double lastLow = iLow(_Symbol, tf, 1);
  if(lastLow<=0) return false;
  double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
  if(bid > lastLow - breakUnder_usd) return false;

  for(int i=1;i<=bars;i++){
    double hi = iHigh(_Symbol, tf, i);
    if(hi >= (lastLow - breakUnder_usd + noPullback_usd)) return false;
  }
  return true;
}

// (4b) COMMENT có chứa 1 trong các state (hỗ trợ "*" = lấy tất cả)
bool CommentHasState(const string &cmt, string &listState[], int nStates)
{
  if(nStates==0) return true;
  if(nStates==1 && listState[0]=="*") return true;
  for(int i=0;i<nStates;i++){
    if(listState[i]=="" ) continue;
    if(StringFind(cmt, listState[i]) >= 0) return true;
  }
  return false;
}

// (4c) Tính netAvg/netAbsVol theo state
bool ComputeNetAndLatestByState(string &listState[], int nStates,
                                double &netAvgPrice, double &netVolAbs,
                                double &buyVol, double &sellVol,
                                double &avgBuyPrice, double &avgSellPrice,
                                bool &haveLatest, string &latestSide,
                                double &latestPrice, double &latestVolAbs)
{
  buyVol=sellVol=0.0; avgBuyPrice=avgSellPrice=0.0;
  netAvgPrice=0.0; netVolAbs=0.0; haveLatest=false;
  latestSide=""; latestPrice=0.0; latestVolAbs=0.0;

  double sumBuyPV=0.0, sumSellPV=0.0;
  ulong  latestTicket=0;

  CPositionInfo pos;
  int total = PositionsTotal();
  for(int i=0;i<total;i++)
  {
    if(!pos.SelectByIndex(i))                continue;
    if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;

    string cmt = PositionGetString(POSITION_COMMENT);
    if(!CommentHasState(cmt, listState, nStates))   continue;

    long   type  = (long)PositionGetInteger(POSITION_TYPE);
    double vol   = PositionGetDouble(POSITION_VOLUME);
    double price = PositionGetDouble(POSITION_PRICE_OPEN);
    ulong  tk    = (ulong)PositionGetInteger(POSITION_TICKET);

    if(type==POSITION_TYPE_BUY){
      buyVol += vol; sumBuyPV  += price*vol;
      if(tk>latestTicket){ latestTicket=tk; latestSide="BUY";  latestPrice=price; latestVolAbs=vol; haveLatest=true; }
    } else
    if(type==POSITION_TYPE_SELL){
      sellVol += vol; sumSellPV += price*vol;
      if(tk>latestTicket){ latestTicket=tk; latestSide="SELL"; latestPrice=price; latestVolAbs=vol; haveLatest=true; }
    }
  }

  if(buyVol>0)  avgBuyPrice  = sumBuyPV  / buyVol;
  if(sellVol>0) avgSellPrice = sumSellPV / sellVol;

  double signedSum = sumBuyPV - sumSellPV;
  double netVol    = buyVol - sellVol;

  if(MathAbs(netVol) >= 1e-9){
    netAvgPrice = signedSum / netVol;
    netVolAbs   = MathAbs(netVol);
    return true;
  }else{
    netAvgPrice = latestPrice;
    netVolAbs   = latestVolAbs;
    return false;
  }
}


//---------------- (5) GROUP PNL & CLOSE & CENT→MONEY -----------//
// (5a) Tổng P/L nhóm theo prefix COMMENT
double GroupProfitByPrefix(const string &prefix)
{
  double sum=0.0;
  CPositionInfo pos;
  for(int i=PositionsTotal()-1;i>=0;--i){
    if(!pos.SelectByIndex(i))                     continue;
    if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
    string cmt = PositionGetString(POSITION_COMMENT);
    if(StringFind(cmt, prefix)==0)
      sum += PositionGetDouble(POSITION_PROFIT);
  }
  return sum;
}


// (5b) Tổng lots đang mở theo prefix
double TotalLotsByPrefix(const string &prefix)
{
  double lots=0.0;
  CPositionInfo pos;
  for(int i=PositionsTotal()-1;i>=0;--i){
    if(!pos.SelectByIndex(i))                     continue;
    if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
    string cmt = PositionGetString(POSITION_COMMENT);
    if(StringFind(cmt, prefix)==0)
      lots += MathAbs(PositionGetDouble(POSITION_VOLUME));
  }
  return lots;
}


// (5c) Quy đổi "cent" giá → tiền account cho N lot
double CentsToMoney(double cents, double lots)
{
  double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
  double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
  double dollars = cents/100.0;
  return dollars * (tv/ts) * lots; // ví dụ XAU: ~$100/lot cho mỗi $1 move/lot
}

// (5d) Đóng tất cả vị thế có prefix
void CloseAllByPrefix(const string &prefix)
{
  CPositionInfo pos;
  for(int i=PositionsTotal()-1;i>=0;--i){
    if(!pos.SelectByIndex(i))                     continue;
    if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
    string cmt = PositionGetString(POSITION_COMMENT);
    if(StringFind(cmt, prefix)==0){
      ulong  tk  = (ulong)PositionGetInteger(POSITION_TICKET);
      double vol = PositionGetDouble(POSITION_VOLUME);
      trade.PositionClose(tk, vol);
    }
  }
}

//---------------- (6) WRAP ĐẶT PENDING --------------------------//
// (6a) SELL_STOP có prefix + magic
bool PlaceSellStopPrefix(int magic, double vol, double entry, double sl, double tp,
                         const string &prefix, int roundIdx, int legIdx)
{
  if(vol<=0) return false;
  vol = ClampLot(vol);
  MakeValidPendingPrices("SELL", entry, sl, tp);

  trade.SetExpertMagicNumber(magic);
  trade.SetDeviationInPoints(10);

  string cmt = StringFormat("%s|SELL|R%d-L%d", prefix, roundIdx, legIdx);
  bool ok = trade.SellStop(vol, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, cmt);
  if(!ok) PrintFormat("[HEDGE][ERR] SELL_STOP %.2f @%.2f err=%d", vol, entry, GetLastError());
  return ok;
}

// (6b) BUY_STOP có prefix + magic
bool PlaceBuyStopPrefix(int magic, double vol, double entry, double sl, double tp,
                        const string &prefix, int roundIdx, int legIdx)
{
  if(vol<=0) return false;
  vol = ClampLot(vol);
  MakeValidPendingPrices("BUY", entry, sl, tp);

  trade.SetExpertMagicNumber(magic);
  trade.SetDeviationInPoints(10);

  string cmt = StringFormat("%s|BUY|R%d-L%d", prefix, roundIdx, legIdx);
  bool ok = trade.BuyStop(vol, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, cmt);
  if(!ok) PrintFormat("[HEDGE][ERR] BUY_STOP %.2f @%.2f err=%d", vol, entry, GetLastError());
  return ok;
}

//---------------- (7) PHÂN BỔ ĐỘNG ------------------------------//
void DecideAllocations(const double adx, const double atr_usd,
                       const bool useADX,  const double adxHigh, const double adxLow,
                       const bool useATR,  const double atrSideway_usd,
                       double &allocMomentum, double &allocTunnel)
{
  double m = allocMomentum;
  double t = allocTunnel;

  if(useADX){
    if(adx >= adxHigh){ m = 0.80; t = 0.20; }
    else if(adx <= adxLow){ m = 0.40; t = 0.60; }
  }
  if(useATR){
    if(atr_usd >= atrSideway_usd*1.2) { m = MathMax(m, 0.60); t = 1.0 - m; }  // biến động
    else                               { t = MathMax(t, 0.60); m = 1.0 - t; }  // sideway
  }
  allocMomentum = m;
  allocTunnel   = MathMax(0.0, 1.0 - m);
}

//---------------- (8) GUARDS / CAPS ------------------------------//
// NOTE (MQL5): Duyệt pending bằng OrderGetTicket(i) → OrderSelect(ticket).

// (8a) Đếm pending theo prefix (trên symbol hiện tại)
int CountPendingByPrefix(const string &prefix){
  int cnt=0; int total=OrdersTotal();
  for(int i=0;i<total;i++){
    ulong tk = OrderGetTicket(i);
    if(tk==0 || !OrderSelect(tk)) continue;
    if(OrderGetString(ORDER_SYMBOL)!=_Symbol) continue;
    string cmt=OrderGetString(ORDER_COMMENT);
    if(StringFind(cmt, prefix)==0) cnt++;
  }
  return cnt;
}

// (8b) Tổng lots pending theo prefix
double PendingLotsByPrefix(const string &prefix){
  double sum=0.0; int total=OrdersTotal();
  for(int i=0;i<total;i++){
    ulong tk = OrderGetTicket(i);
    if(tk==0 || !OrderSelect(tk)) continue;
    if(OrderGetString(ORDER_SYMBOL)!=_Symbol) continue;
    string cmt=OrderGetString(ORDER_COMMENT);
    if(StringFind(cmt, prefix)==0) sum += OrderGetDouble(ORDER_VOLUME_CURRENT);
  }
  return sum;
}

// (8c) Dedupe pending theo key R-L
bool PendingExistsKey(const string &prefix, int roundIdx, int legIdx){
  string head=StringFormat("%s|", prefix);
  string tail=StringFormat("|R%d-L%d", roundIdx, legIdx);
  int total=OrdersTotal();
  for(int i=0;i<total;i++){
    ulong tk = OrderGetTicket(i);
    if(tk==0 || !OrderSelect(tk)) continue;
    if(OrderGetString(ORDER_SYMBOL)!=_Symbol) continue;
    string cmt=OrderGetString(ORDER_COMMENT);
    if(StringFind(cmt, head)==0 && StringFind(cmt, tail)>=0) return true;
  }
  return false;
}

// (8d) Hủy pending quá TTL (giây)
int CancelExpiredPendingsByPrefix(const string &prefix, int ttl_seconds){
  int killed=0; datetime now=TimeCurrent(); int total=OrdersTotal();
  for(int i=total-1;i>=0;--i){
    ulong tk = OrderGetTicket(i);
    if(tk==0 || !OrderSelect(tk)) continue;
    if(OrderGetString(ORDER_SYMBOL)!=_Symbol) continue;
    string cmt=OrderGetString(ORDER_COMMENT);
    if(StringFind(cmt, prefix)!=0) continue;        // chỉ xoá prefix ở đầu
    datetime t0=(datetime)OrderGetInteger(ORDER_TIME_SETUP);
    if(ttl_seconds>0 && (now - t0) >= ttl_seconds){
      if(trade.OrderDelete(tk)) killed++;
    }
  }
  return killed;
}

// (8e) Ước lượng lot có thể thêm để vẫn giữ ML ≥ target
double EstimateAdditionalLotsByMargin(double targetMinMarginLevelPct){
  double eq=AccountInfoDouble(ACCOUNT_EQUITY);
  double curMargin=AccountInfoDouble(ACCOUNT_MARGIN);
  double allowMargin = (targetMinMarginLevelPct>0 ? (eq * 100.0 / targetMinMarginLevelPct) : DBL_MAX);
  double addMargin   = MathMax(0.0, allowMargin - curMargin);
  // margin/lot (ước lượng theo BUY 1.0 lot @Bid)
  double bid=SymbolInfoDouble(_Symbol, SYMBOL_BID), marginPerLot=0.0;
  if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, 1.0, bid, marginPerLot)) return 0.0;
  if(marginPerLot<=0.0) return 0.0;
  return addMargin / marginPerLot;
}

// (8f) Tổng lots mở theo prefix tổng "HEDGE_" (positions + pending)
double HedgeOpenLots(){ return TotalLotsByPrefix("HEDGE_") + PendingLotsByPrefix("HEDGE_"); }

// (8g) Delta hiệu dụng (BUY - SELL) gồm cả pending
#include <Trade/PositionInfo.mqh>   // đảm bảo có dòng này ở đầu file

// (8g) Delta hiệu dụng (BUY - SELL) gồm cả pending
double EffectiveDeltaLots(){
  double buy=0, sell=0;

  // positions
  CPositionInfo pos;
  for(int i=PositionsTotal()-1; i>=0; --i){
    if(!pos.SelectByIndex(i))                    continue;
    if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
    long   t = (long)PositionGetInteger(POSITION_TYPE);
    double v = PositionGetDouble(POSITION_VOLUME);
    if(t==POSITION_TYPE_BUY)  buy  += v;
    else if(t==POSITION_TYPE_SELL) sell += v;
  }

  // pending orders (giữ nguyên logic cũ)
  int total = OrdersTotal();
  for(int i=0;i<total;i++){
    ulong tk = OrderGetTicket(i);
    if(tk==0 || !OrderSelect(tk))                 continue;
    if(OrderGetString(ORDER_SYMBOL)!=_Symbol)     continue;
    ENUM_ORDER_TYPE ty=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
    double v = OrderGetDouble(ORDER_VOLUME_CURRENT);
    if(ty==ORDER_TYPE_BUY_LIMIT || ty==ORDER_TYPE_BUY_STOP || ty==ORDER_TYPE_BUY_STOP_LIMIT) buy+=v;
    else if(ty==ORDER_TYPE_SELL_LIMIT || ty==ORDER_TYPE_SELL_STOP || ty==ORDER_TYPE_SELL_STOP_LIMIT) sell+=v;
  }
  return buy - sell; // dương = bias BUY; âm = bias SELL
}


#endif // __HELPER_HYBRID_MQH__
