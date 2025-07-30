//==============================================================
// Hedging_Hybrid_Dynamic.mqh  –  Dynamic Tunnel + Momentum (MQL5)
// Tác giả: vmax x ChatGPT
// Ngày:    2025-07-28
//
// Gọi helper theo đánh số:
//  (1a..1d)(2a..2c)(3a..3b)(4a..4c)(5a..5d)(6a..6b)(7a)
//==============================================================
#property strict
#include <Trade/Trade.mqh>
#include "HedgeHelpers.mqh"

// Cho phép EA override nếu muốn
#ifndef HEDGE_MAGIC
  #define HEDGE_MAGIC 20250727
#endif

//======================= CẤU HÌNH ==============================//
struct TriggerCfg {
  bool   useBreakNoPullback;
  double breakUnder_usd;
  double noPullback_usd;
  int    noPullbackBars;

  int    minMarginLevelPct;

  bool   useADX;
  int    adxPeriod;
  ENUM_TIMEFRAMES adxTF;
  double adxHigh;
  double adxLow;

  bool   useATR;
  int    atrPeriod;
  ENUM_TIMEFRAMES atrTF;
  double momSL_ATR_mult;
  double atrSideway_usd;

  double maxSpread_usd;
};

struct HybridCfg {
  double allocMomentum;
  double allocTunnel;
  double tunnelSellShare;

  double D_TUNNEL_usd;
  double D_TP_usd;

  double momOffsets_usd[6];
  double momW[6];
  double momSL_ATR_mult;

  double tpMomCents;
  double tpTunCents;
  double tpAllCents;
  bool   tpPerLot;
};

//------------------ DEFAULT CONFIGS -----------------------------//
TriggerCfg DefaultTriggerCfg()
{
  TriggerCfg tg;
  tg.useBreakNoPullback = true;
  tg.breakUnder_usd     = 1.0;
  tg.noPullback_usd     = 0.8;
  tg.noPullbackBars     = 4;
  tg.minMarginLevelPct  = 300;

  tg.useADX   = true;  tg.adxPeriod=14; tg.adxTF=PERIOD_M15; tg.adxHigh=28; tg.adxLow=18;
  tg.useATR   = true;  tg.atrPeriod=14; tg.atrTF=PERIOD_M5;  tg.momSL_ATR_mult=1.2; tg.atrSideway_usd=0.35;

  tg.maxSpread_usd = 0.30;
  return tg;
}

HybridCfg DefaultHybridCfg()
{
  HybridCfg cfg;
  cfg.allocMomentum   = 0.60;
  cfg.allocTunnel     = 0.40;
  cfg.tunnelSellShare = 0.75;

  cfg.D_TUNNEL_usd = 5.0;
  cfg.D_TP_usd     = 2.5;

  double offs[6] = {0.30, 1.00, 1.50, 2.50, 3.50, 5.00};
  double ws[6]   = {0.0667,0.0667,0.20,0.1333,0.2667,0.2667};
  ArrayCopy(cfg.momOffsets_usd, offs);
  ArrayCopy(cfg.momW, ws);

  cfg.momSL_ATR_mult = 1.2;

  cfg.tpMomCents = 450;
  cfg.tpTunCents = 300;
  cfg.tpAllCents = 600;
  cfg.tpPerLot   = true;
  return cfg;
}

//================== HÀM CHÍNH – HYBRID DYNAMIC ==================//
// Đầu vào: listState[] – các chuỗi cần xuất hiện trong POSITION_COMMENT
// => lọc đúng cụm vé cần hedge (4c). Có thể gọi từ OnTick/OnTimer.
void Hedging_Hybrid_Dynamic(string listState[], int nStates,
                            const TriggerCfg &tg, HybridCfg cfg)
{
  // [G1] Guard spread (2c)
  if(tg.maxSpread_usd > 0 && !SpreadOK(tg.maxSpread_usd)){
    Print("[HEDGE] Spread quá lớn, hoãn đặt lệnh.");
    return;
  }

  // [S1] Scan cụm vé theo COMMENT (4c)
  double netAvg=0, netAbsVol=0, buyVol=0, sellVol=0, avgBuy=0, avgSell=0;
  bool haveLatest=false; string latestSide=""; double latestPrice=0, latestVolAbs=0;
  bool haveNet = ComputeNetAndLatestByState(listState, nStates,
                                            netAvg, netAbsVol,
                                            buyVol, sellVol,
                                            avgBuy, avgSell,
                                            haveLatest, latestSide,
                                            latestPrice, latestVolAbs);
  if(netAbsVol<=0){
    Print("[HEDGE] Không có vol ròng từ listState. Abort.");
    return;
  }

  // [T1] Triggers: phá đáy & không hồi (4a), margin, ADX/ATR (3a)(3b)
  bool priceGate = true;
  if(tg.useBreakNoPullback)
    priceGate = BrokeUnderNoPullback(tg.breakUnder_usd, tg.noPullback_usd, tg.noPullbackBars, tg.atrTF);

  bool accountGate = false;
  if(tg.minMarginLevelPct > 0){
    int ml = (int)AccountInfoInteger(ACCOUNT_MARGIN_LEVEL);
    if(ml>0 && ml <= tg.minMarginLevelPct) accountGate = true;
  }

  double adx     = tg.useADX ? SafeADX(tg.adxTF, tg.adxPeriod) : 0.0;
  double atr_usd = tg.useATR ? SafeATR(tg.atrTF, tg.atrPeriod) : 0.0;

  if(!(priceGate || accountGate)){
    Print("[HEDGE] Trigger chưa đạt (price/vol/margin).");
    return;
  }

  // [A1] Phân bổ động Momentum/Tunnel (7a)
  DecideAllocations(adx, atr_usd,
                    tg.useADX, tg.adxHigh, tg.adxLow,
                    tg.useATR, tg.atrSideway_usd,
                    cfg.allocMomentum, cfg.allocTunnel);

  // [V1] Tính volumes (không over-hedge mặc định)
  double Vnet = netAbsVol;
  double HM   = ClampLot(Vnet * cfg.allocMomentum);            // (1c)
  double HT   = ClampLot(MathMax(0.0, Vnet - HM));             // (1c)

  // [TUN] Tunnel core (đối xứng quanh netAvg hoặc anchor latest)
  CTrade trade; // trade dùng xuyên suốt file chính & truyền vào helper (6a)(6b)(5d)
  double upper, lower, baseVolTunnel;
  if(haveNet){
    upper = Nd(netAvg + cfg.D_TUNNEL_usd);                     // (1d)
    lower = Nd(netAvg - cfg.D_TUNNEL_usd);                     // (1d)
    baseVolTunnel = HT;
  } else {
    if(latestSide=="SELL"){ lower=Nd(latestPrice); upper=Nd(lower + 2.0*cfg.D_TUNNEL_usd); }
    else                  { upper=Nd(latestPrice); lower=Nd(upper - 2.0*cfg.D_TUNNEL_usd); }
    baseVolTunnel = (HT>0 ? HT : latestVolAbs);
  }

  double volT_sell = ClampLot(baseVolTunnel * cfg.tunnelSellShare);
  double volT_buy  = ClampLot(MathMax(0.0, baseVolTunnel - volT_sell));

  if(volT_sell > 0){
    double e = lower, sl=upper, tp=Nd(lower - cfg.D_TP_usd);
    PlaceSellStopPrefix(trade, HEDGE_MAGIC, volT_sell, e, sl, tp, "HEDGE_TUN", 1, 1); // (6a)
  }
  if(volT_buy > 0){
    double e = upper, sl=lower, tp=Nd(upper + cfg.D_TP_usd);
    PlaceBuyStopPrefix(trade, HEDGE_MAGIC, volT_buy, e, sl, tp, "HEDGE_TUN", 1, 1);   // (6b)
  }

  // [MOM] Momentum SELL ladder theo đà
  double lastLow      = iLow(_Symbol, tg.atrTF, 1);
  double slDist_usd   = (tg.useATR ? cfg.momSL_ATR_mult * MathMax(atr_usd, 0.01) : 0.60);

  double sumW=0; for(int i=0;i<6;i++) sumW += cfg.momW[i];
  for(int i=0;i<6;i++){
    if(HM<=0) break;
    double share = (sumW>0 ? cfg.momW[i]/sumW : 0.0);
    double vol   = ClampLot(HM * share);
    if(vol <= 0) continue;

    double entry = Nd(lastLow - cfg.momOffsets_usd[i]);
    double sl    = Nd(entry + slDist_usd);
    // TP lẻ = 0 → dùng TP gộp nhóm Momentum
    PlaceSellStopPrefix(trade, HEDGE_MAGIC, vol, entry, sl, 0.0, "HEDGE_MOM", 1, i+1); // (6a)
  }

  // [TP] TP gộp theo CENT quy ra tiền (5a..5d)
  if(cfg.tpMomCents > 0){
    double lotsM   = TotalLotsByPrefix("HEDGE_MOM");                           // (5b)
    double targetM = cfg.tpPerLot ? CentsToMoney(cfg.tpMomCents, lotsM)        // (5c)
                                  : CentsToMoney(cfg.tpMomCents, 1.0);
    if(targetM>0 && GroupProfitByPrefix("HEDGE_MOM") >= targetM)               // (5a)
      CloseAllByPrefix(trade, "HEDGE_MOM");                                     // (5d)
  }
  if(cfg.tpTunCents > 0){
    double lotsT   = TotalLotsByPrefix("HEDGE_TUN");
    double targetT = cfg.tpPerLot ? CentsToMoney(cfg.tpTunCents, lotsT)
                                  : CentsToMoney(cfg.tpTunCents, 1.0);
    if(targetT>0 && GroupProfitByPrefix("HEDGE_TUN") >= targetT)
      CloseAllByPrefix(trade, "HEDGE_TUN");
  }
  if(cfg.tpAllCents > 0){
    double lotsAll   = TotalLotsByPrefix("HEDGE_");
    double targetAll = cfg.tpPerLot ? CentsToMoney(cfg.tpAllCents, lotsAll)
                                    : CentsToMoney(cfg.tpAllCents, 1.0);
    if(targetAll>0 && GroupProfitByPrefix("HEDGE_") >= targetAll)
      CloseAllByPrefix(trade, "HEDGE_");
  }
}
