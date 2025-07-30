//==============================================================
// HedgeHelpers.mqh  –  Bộ hàm tiện ích dùng chung cho Hedging
// Tác giả: vmax x ChatGPT
// Ngày:    2025-07-28
//
// Ghi chú đánh số:
// (1a..1d)  : Symbol/Lot utilities
// (2a..2c)  : Broker/Stops/Spread guards
// (3a..3b)  : Indicators (ATR/ADX)
// (4a..4c)  : Triggers & Scan positions by COMMENT state
// (5a..5d)  : Group profit/lots & quy đổi CENT→tiền & close by prefix
// (6a..6b)  : Wrap đặt pending (Buy/Sell Stop) có prefix
// (7a)      : Phân bổ động Momentum/Tunnel theo ADX/ATR
//
// File này KHÔNG tạo CTrade toàn cục để tránh xung đột.
// Các hàm cần trade sẽ nhận tham số CTrade &trade + magic.
//==============================================================
#property strict
#include <Trade/Trade.mqh>

//---------------- (1) SYMBOL/LOT UTILS -------------------------//
// (1a) Lấy DIGITS/PONT của symbol – gọi ở file chính trước khi chuẩn hoá giá.
int    DigitsSym() { return (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS); }  // used: MakeValidPendingPrices (2b)
double PointSym()  { return SymbolInfoDouble(_Symbol, SYMBOL_POINT); }         // used: (2a)(2b)

// (1b) Min/Step/Max lot – dùng trước khi ClampLot.
double SymbolMinLot(){ double v; SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN, v);  return v; } // used: (1c)
double SymbolLotStep(){ double v; SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP, v); return v; } // used: (1c)
double SymbolMaxLot(){ double v; SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX, v);  return v; } // used: (1c)

// (1c) Chuẩn hoá lot theo step và biên min/max – gọi khi đặt lệnh (6a)(6b).
double ClampLot(double x)
{
  double minLot=SymbolMinLot(), step=SymbolLotStep(), maxLot=SymbolMaxLot();
  x = MathMax(minLot, MathMin(x, maxLot));
  int steps = (int)MathRound(x/step);
  return NormalizeDouble(steps*step, 2);
}

// (1d) Chuẩn hoá số lẻ theo DIGITS – dùng ở mọi chỗ set giá.
double Nd(double price){ return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)); }

//---------------- (2) BROKER GUARDS -----------------------------//
// (2a) Stops level tối thiểu (đơn vị giá) – dùng bởi (2b).
double MinStopsDistancePrice()
{
  long lvPoints=0; SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, lvPoints);
  return (double)lvPoints * PointSym();
}

// (2b) Chuẩn hoá Entry/SL/TP theo loại BUY/SELL + stops level – gọi ở (6a)(6b).
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
  if(sl>0) sl = Nd(sl);
  if(tp!=0.0) tp = Nd(tp);
}

// (2c) Spread guard – gọi đầu Hedging_Hybrid_Dynamic().
bool SpreadOK(double max_usd)
{
  double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
  return (spread <= max_usd);
}

//---------------- (3) INDICATORS -------------------------------//
// (3a) ATR an toàn (CopyBuffer, shift=1) – gọi khi tính SL Momentum & sideway check.
double SafeATR(ENUM_TIMEFRAMES tf, int period)
{
  static int   h = INVALID_HANDLE;
  static int   lastPeriod = -1;
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

// (3b) ADX an toàn (buffer 0 = đường ADX) – gọi để điều chỉnh phân bổ Momentum/Tunnel.
double SafeADX(ENUM_TIMEFRAMES tf, int period)
{
  static int   h = INVALID_HANDLE;
  static int   lastPeriod = -1;
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
// (4a) Giá phá đáy gần nhất & không hồi tối thiểu – gọi trong phần Trigger của hàm chính.
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

// (4b) COMMENT có chứa 1 trong các state – dùng bởi (4c).
bool CommentHasState(const string &cmt, string listState[], int nStates)
{
  for(int i=0;i<nStates;i++){
    if(listState[i]=="" ) continue;
    if(StringFind(cmt, listState[i]) >= 0) return true;
  }
  return false;
}

// (4c) Tính netAvg/netAbsVol của cụm vị thế theo state – gọi đầu hàm chính.
bool ComputeNetAndLatestByState(string listState[], int nStates,
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

  int total = PositionsTotal();
  for(int i=0;i<total;i++)
  {
    if(!PositionSelectByIndex(i)) continue;
    if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;

    string cmt = PositionGetString(POSITION_COMMENT);
    if(!CommentHasState(cmt, listState, nStates)) continue;

    long   type = (long)PositionGetInteger(POSITION_TYPE);
    double vol  = PositionGetDouble(POSITION_VOLUME);
    double price= PositionGetDouble(POSITION_PRICE_OPEN);
    ulong  tk   = (ulong)PositionGetInteger(POSITION_TICKET);

    if(type==POSITION_TYPE_BUY){
      buyVol += vol; sumBuyPV  += price*vol;
      if(tk>latestTicket){ latestTicket=tk; latestSide="BUY"; latestPrice=price; latestVolAbs=vol; haveLatest=true; }
    } else
    if(type==POSITION_TYPE_SELL){
      sellVol += vol; sumSellPV += price*vol;
      if(tk>latestTicket){ latestTicket=tk; latestSide="SELL"; latestPrice=price; latestVolAbs=vol; haveLatest=true; }
    }
  }

  if(buyVol>0)  avgBuyPrice  = sumBuyPV / buyVol;
  if(sellVol>0) avgSellPrice = sumSellPV / sellVol;

  double signedSum = sumBuyPV - sumSellPV;        // SELL âm
  double netVol    = buyVol - sellVol;

  if(MathAbs(netVol) >= 1e-9){
    netAvgPrice = signedSum / netVol;
    netVolAbs   = MathAbs(netVol);
    return true;  // haveNet
  }else{
    // FLAT: dùng latest làm anchor
    netAvgPrice = latestPrice;
    netVolAbs   = latestVolAbs;
    return false;
  }
}

//---------------- (5) GROUP PNL & CLOSE & CENT→MONEY -------------//
// (5a) Tổng P/L nhóm theo prefix COMMENT – dùng cho TP gộp.
double GroupProfitByPrefix(const string &prefix)
{
  double sum=0.0;
  for(int i=PositionsTotal()-1;i>=0;--i){
    if(!PositionSelectByIndex(i)) continue;
    if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
    string cmt = PositionGetString(POSITION_COMMENT);
    if(StringFind(cmt, prefix)==0)
      sum += PositionGetDouble(POSITION_PROFIT);
  }
  return sum;
}

// (5b) Tổng lots đang mở của nhóm – dùng scale ngưỡng TP gộp khi tpPerLot=true.
double TotalLotsByPrefix(const string &prefix)
{
  double lots=0.0;
  for(int i=PositionsTotal()-1;i>=0;--i){
    if(!PositionSelectByIndex(i)) continue;
    if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
    string cmt = PositionGetString(POSITION_COMMENT);
    if(StringFind(cmt, prefix)==0)
      lots += MathAbs(PositionGetDouble(POSITION_VOLUME));
  }
  return lots;
}

// (5c) Quy đổi "cent" giá → tiền account cho N lot – dùng set ngưỡng TP gộp.
double CentsToMoney(double cents, double lots)
{
  double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
  double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
  double dollars = cents/100.0;
  return dollars * (tv/ts) * lots; // ví dụ XAU: ~$100/lot cho mỗi $1 di chuyển
}

// (5d) Đóng tất cả vị thế có prefix – gọi khi đạt TP gộp.
void CloseAllByPrefix(CTrade &trade, const string &prefix)
{
  for(int i=PositionsTotal()-1;i>=0;--i){
    if(!PositionSelectByIndex(i)) continue;
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
// (6a) SELL_STOP có prefix + magic – gọi trong Momentum & Tunnel SELL.
bool PlaceSellStopPrefix(CTrade &trade, int magic, double vol, double entry, double sl, double tp,
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

// (6b) BUY_STOP có prefix + magic – gọi trong Tunnel BUY (đối xứng).
bool PlaceBuyStopPrefix(CTrade &trade, int magic, double vol, double entry, double sl, double tp,
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
// (7a) Điều chỉnh Momentum/Tunnel theo ADX/ATR – gọi ngay trước khi tính HM/HT.
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
