//==============================================================
// Hedging_Hybrid_Dynamic.mqh  –  Dynamic Tunnel + Momentum (MQL5)
// Tác giả: vmax x ChatGPT
// Ngày:    2025-07-30
//==============================================================
#property strict
#include <Trade/Trade.mqh>
#include "HedgeHelpers.mqh"

#ifndef HEDGE_MAGIC
  #define HEDGE_MAGIC 20250727
#endif

//======================= CẤU HÌNH ==============================//
struct TriggerCfg {
  bool   useBreakNoPullback;  double breakUnder_usd; double noPullback_usd; int noPullbackBars;
  int    minMarginLevelPct;   // emergency bật hedge
  bool   useADX; int adxPeriod; ENUM_TIMEFRAMES adxTF; double adxHigh; double adxLow;
  bool   useATR; int atrPeriod; ENUM_TIMEFRAMES atrTF; double momSL_ATR_mult; double atrSideway_usd;
  double maxSpread_usd;
};

struct HybridCfg {
  // Phân bổ
  double allocMomentum; double allocTunnel; double tunnelSellShare;

  // Tunnel
  double D_TUNNEL_usd; double D_TP_usd;

  // Momentum
  double momOffsets_usd[6]; double momW[6]; double momSL_ATR_mult;

  // TP gộp
  double tpMomCents; double tpTunCents; double tpAllCents; bool tpPerLot;
  double tpMinMoney;        // *** mới: sàn tiền tối thiểu (USD/đv account) cho TP gộp
  double trailingLockPct;   // *** mới: khoá lợi nhuận theo % peak (0.0 = tắt)

  // GUARDS/CAPS
  double maxLotsMultiplierNet;   // *** mới: cap lots tổng = k * netAbsVol (mặc định 1.2)
  double placeMinMarginLevelPct; // *** mới: ML tối thiểu để CHO PHÉP đặt thêm (vd 450%)
  int    maxPending;             // *** mới: số pending tối đa cho prefix "HEDGE_"
  int    pendingTTLsec;          // *** mới: TTL pending (giây)
  bool   sellOnlyOnStrongTrend;  // *** mới: trend mạnh tự động BUY=0 cho Tunnel
};

//------------------ DEFAULT CONFIGS (gợi ý cho 10,000 cent & 1:500) ----//
TriggerCfg DefaultTriggerCfg(){
  TriggerCfg tg;
  tg.useBreakNoPullback=true; tg.breakUnder_usd=1.0; tg.noPullback_usd=0.8; tg.noPullbackBars=4;
  tg.minMarginLevelPct=300;
  tg.useADX=true; tg.adxPeriod=14; tg.adxTF=PERIOD_M15; tg.adxHigh=28; tg.adxLow=18;
  tg.useATR=true; tg.atrPeriod=14; tg.atrTF=PERIOD_M5; tg.momSL_ATR_mult=1.2; tg.atrSideway_usd=0.35;
  tg.maxSpread_usd=0.30;
  return tg;
}
HybridCfg DefaultHybridCfg(){
  HybridCfg cfg;
  cfg.allocMomentum=0.60; cfg.allocTunnel=0.40; cfg.tunnelSellShare=0.75;
  cfg.D_TUNNEL_usd=5.0; cfg.D_TP_usd=2.5;
  double offs[6]={0.30,1.00,1.50,2.50,3.50,5.00};
  double ws[6]={0.0667,0.0667,0.20,0.1333,0.2667,0.2667};
  ArrayCopy(cfg.momOffsets_usd, offs); ArrayCopy(cfg.momW, ws);
  cfg.momSL_ATR_mult=1.2;

  cfg.tpMomCents=450; cfg.tpTunCents=300; cfg.tpAllCents=600; cfg.tpPerLot=true;
  cfg.tpMinMoney=1.50;          // sàn ~ $1.50 (cent account vẫn là đơn vị tiền account)
  cfg.trailingLockPct=0.35;     // khoá 35% lợi nhuận nếu đã vượt target

  cfg.maxLotsMultiplierNet=1.2; // tổng hedge ≤ 1.2 × netAbsVol
  cfg.placeMinMarginLevelPct=450; // chỉ đặt thêm nếu ML dự kiến ≥ 450%
  cfg.maxPending=10;
  cfg.pendingTTLsec=1800;       // 30 phút
  cfg.sellOnlyOnStrongTrend=true;
  return cfg;
}

//================== HÀM CHÍNH – HYBRID DYNAMIC ==================//
void Hedging_Hybrid_Dynamic(string listState[], int nStates,
                            const TriggerCfg &tg, HybridCfg cfg)
{
  // [G0] Vệ sinh pending cũ & guard spread
  CTrade trade;
  if(cfg.pendingTTLsec>0) CancelExpiredPendingsByPrefix(trade, "HEDGE_", cfg.pendingTTLsec);  // (8d)
  if(tg.maxSpread_usd > 0 && !SpreadOK(tg.maxSpread_usd)){ Print("[HEDGE] Spread lớn, hoãn."); return; } // (2c)

  // [S1] Scan cụm vé theo COMMENT (4c)
  double netAvg=0, netAbsVol=0, buyVol=0, sellVol=0, avgBuy=0, avgSell=0;
  bool haveLatest=false; string latestSide=""; double latestPrice=0, latestVolAbs=0;
  bool haveNet = ComputeNetAndLatestByState(listState, nStates,
                                            netAvg, netAbsVol,
                                            buyVol, sellVol,
                                            avgBuy, avgSell,
                                            haveLatest, latestSide,
                                            latestPrice, latestVolAbs);
  if(netAbsVol<=0){ Print("[HEDGE] vol ròng = 0. Abort."); return; }

  // [T1] Triggers
  bool priceGate = (!tg.useBreakNoPullback) ? true
                   : BrokeUnderNoPullback(tg.breakUnder_usd, tg.noPullback_usd, tg.noPullbackBars, tg.atrTF);  // (4a)
  bool accountGate=false;
  if(tg.minMarginLevelPct>0){ int ml=(int)AccountInfoInteger(ACCOUNT_MARGIN_LEVEL); if(ml>0 && ml<=tg.minMarginLevelPct) accountGate=true; }

  double adx = tg.useADX ? SafeADX(tg.adxTF, tg.adxPeriod) : 0.0;   // (3b)
  double atr = tg.useATR ? SafeATR(tg.atrTF, tg.atrPeriod) : 0.0;   // (3a)

  if(!(priceGate || accountGate)){ Print("[HEDGE] Trigger chưa đạt."); return; }

  // [A1] Phân bổ động (7a)
  DecideAllocations(adx, atr, tg.useADX, tg.adxHigh, tg.adxLow, tg.useATR, tg.atrSideway_usd,
                    cfg.allocMomentum, cfg.allocTunnel);

  // SELL‑only cho Tunnel nếu trend mạnh
  if(cfg.sellOnlyOnStrongTrend){
    double bid=SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(adx>=tg.adxHigh || bid < (netAvg - cfg.D_TUNNEL_usd)){
      cfg.tunnelSellShare = 1.0; // BUY=0
    }
  }

  // [CAP1] Tổng cap lots theo netAbsVol
  double capByNet = cfg.maxLotsMultiplierNet * netAbsVol;

  // [CAP2] Cap theo Margin dự kiến (8e)
  double addLotsByMargin = EstimateAdditionalLotsByMargin(cfg.placeMinMarginLevelPct);
  double alreadyHedgeLots = HedgeOpenLots(); // (8f)
  double maxLotsAllowed = MathMax(0.0, capByNet); // base
  // Cho phép tổng hedge ≤ min(capByNet, already + addByMargin)
  maxLotsAllowed = MathMin(maxLotsAllowed, alreadyHedgeLots + addLotsByMargin);

  // [CAP3] Max pending
  int curPending = CountPendingByPrefix("HEDGE_");
  if(curPending >= cfg.maxPending){ Print("[HEDGE] Đã đạt maxPending. Hoãn đặt thêm."); return; }

  // [V1] Volume kế hoạch
  double HM = ClampLot(netAbsVol * cfg.allocMomentum);
  double HT = ClampLot(MathMax(0.0, netAbsVol - HM));

  // Giới hạn kế hoạch theo availableLotsToPlace
  double availableLotsToPlace = MathMax(0.0, maxLotsAllowed - alreadyHedgeLots);
  if((HM+HT) > availableLotsToPlace){
    double scale = (availableLotsToPlace>0 ? availableLotsToPlace / (HM+HT) : 0.0);
    HM = ClampLot(HM * scale);
    HT = ClampLot(HT * scale);
    if(HM+HT <= 0){ Print("[HEDGE] Không còn room lots để đặt."); return; }
  }

  // [TUN] Tunnel core
  double upper, lower, baseVolTunnel;
  if(haveNet){ upper=Nd(netAvg + cfg.D_TUNNEL_usd); lower=Nd(netAvg - cfg.D_TUNNEL_usd); baseVolTunnel=HT; }
  else{
    if(latestSide=="SELL"){ lower=Nd(latestPrice); upper=Nd(lower + 2.0*cfg.D_TUNNEL_usd); }
    else                  { upper=Nd(latestPrice); lower=Nd(upper - 2.0*cfg.D_TUNNEL_usd); }
    baseVolTunnel=(HT>0?HT:latestVolAbs);
  }
  double volT_sell=ClampLot(baseVolTunnel * cfg.tunnelSellShare);
  double volT_buy =ClampLot(MathMax(0.0, baseVolTunnel - volT_sell));

  // Dedupe R-L tránh lặp
  if(volT_sell>0 && !PendingExistsKey("HEDGE_TUN",1,1)){
    double e=lower, sl=upper, tp=Nd(lower - cfg.D_TP_usd);
    if(CountPendingByPrefix("HEDGE_") < cfg.maxPending)
      PlaceSellStopPrefix(trade, HEDGE_MAGIC, volT_sell, e, sl, tp, "HEDGE_TUN", 1, 1);
  }
  if(volT_buy>0 && !PendingExistsKey("HEDGE_TUN",1,1)){ // cùng R-L cho BUY trong Tunnel
    double e=upper, sl=lower, tp=Nd(upper + cfg.D_TP_usd);
    if(CountPendingByPrefix("HEDGE_") < cfg.maxPending)
      PlaceBuyStopPrefix(trade, HEDGE_MAGIC, volT_buy, e, sl, tp, "HEDGE_TUN", 1, 1);
  }

  // [MOM] Momentum SELL ladder
  double lastLow = iLow(_Symbol, tg.atrTF, 1);
  double slDist  = (tg.useATR ? cfg.momSL_ATR_mult * MathMax(atr, 0.01) : 0.60);

  double sumW=0; for(int i=0;i<6;i++) sumW += cfg.momW[i];
  for(int i=0;i<6;i++){
    if(HM<=0) break;
    if(CountPendingByPrefix("HEDGE_") >= cfg.maxPending){ Print("[HEDGE] Đụng trần pending."); break; }

    double share=(sumW>0 ? cfg.momW[i]/sumW : 0.0);
    double vol=ClampLot(HM * share);
    if(vol<=0) continue;

    // Dedupe 1-1: HEDGE_MOM|SELL|R1-Li
    if(PendingExistsKey("HEDGE_MOM",1,i+1)) continue;

    // CAP theo effective delta: không để bias SELL vượt quá capByNet
    double effDelta = EffectiveDeltaLots(); // dương=BUY, âm=SELL (8g)
    double futureDelta = effDelta - vol;    // đặt SELL làm delta âm hơn
    if(MathAbs(futureDelta) > capByNet){ continue; } // bỏ leg nếu vượt

    double entry=Nd(lastLow - cfg.momOffsets_usd[i]);
    double sl=Nd(entry + slDist);

    PlaceSellStopPrefix(trade, HEDGE_MAGIC, vol, entry, sl, 0.0, "HEDGE_MOM", 1, i+1);
  }

  // [TP] TP gộp + trailing lock
  double lotsM = TotalLotsByPrefix("HEDGE_MOM"), lotsT = TotalLotsByPrefix("HEDGE_TUN"), lotsAll = TotalLotsByPrefix("HEDGE_");
  auto TargetMoney = [&](double cents, double lots){ double v = (cfg.tpPerLot? CentsToMoney(cents, lots) : CentsToMoney(cents, 1.0)); return MathMax(v, cfg.tpMinMoney); };

  static double peakMom=0, peakTun=0, peakAll=0;
  double pnlMom=GroupProfitByPrefix("HEDGE_MOM"), pnlTun=GroupProfitByPrefix("HEDGE_TUN"), pnlAll=GroupProfitByPrefix("HEDGE_");

  double targMom=TargetMoney(cfg.tpMomCents, lotsM);
  double targTun=TargetMoney(cfg.tpTunCents, lotsT);
  double targAll=TargetMoney(cfg.tpAllCents, lotsAll);

  // Update peaks
  peakMom = MathMax(peakMom, pnlMom); peakTun=MathMax(peakTun,pnlTun); peakAll=MathMax(peakAll,pnlAll);

  // Close logic: đạt target → đóng ngay; nếu đã vượt target và quay đầu > trailing → đóng bảo toàn
  if(cfg.tpMomCents>0 && targMom>0){
    if(pnlMom >= targMom) CloseAllByPrefix(trade, "HEDGE_MOM");
    else if(cfg.trailingLockPct>0 && peakMom>=targMom && pnlMom <= peakMom*(1.0 - cfg.trailingLockPct))
      CloseAllByPrefix(trade, "HEDGE_MOM");
  }
  if(cfg.tpTunCents>0 && targTun>0){
    if(pnlTun >= targTun) CloseAllByPrefix(trade, "HEDGE_TUN");
    else if(cfg.trailingLockPct>0 && peakTun>=targTun && pnlTun <= peakTun*(1.0 - cfg.trailingLockPct))
      CloseAllByPrefix(trade, "HEDGE_TUN");
  }
  if(cfg.tpAllCents>0 && targAll>0){
    if(pnlAll >= targAll) CloseAllByPrefix(trade, "HEDGE_");
    else if(cfg.trailingLockPct>0 && peakAll>=targAll && pnlAll <= peakAll*(1.0 - cfg.trailingLockPct))
      CloseAllByPrefix(trade, "HEDGE_");
  }
}
