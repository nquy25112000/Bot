// ────────────────────────────────────────────────────────────────
//  ScanBIAS.mqh  –  DetectBias đa khung (H1–H4–D1)
//  Phiên bản không dùng lambda / MathClamp  → tương thích MT4/MT5
// ────────────────────────────────────────────────────────────────
#ifndef __SCAN_BIAS_MQH__
#define __SCAN_BIAS_MQH__
#property strict

#include "LogicBIAS.mqh"
#include "CandlePattern.mqh"

// ---------- HẰNG SỐ CƠ BẢN --------------------------------------
#define BASE_MIN_BUY   50.0
#define BASE_MIN_SELL  50.0
#define BASE_OPP_MAX   35.0

// ---------- HÀM TIỆN ÍCH ---------------------------------------
double Clamp(double x, double lo, double hi)  // thay cho MathClamp
{
   if(x < lo) return lo;
   if(x > hi) return hi;
   return x;
}
double MapLinear(double x,double x1,double x2,double y1,double y2)
{
   if(x <= x1) return y1;
   if(x >= x2) return y2;
   return y1 + (y2 - y1) * ( (x - x1) / (x2 - x1) );
}

// ---------- PHÂN LOẠI MẪU NẾN -----------------------------------
bool IsStrongBull(const PatternScore &ps)
{
   return (ps.bias=="BUY" && (
           ps.id==PATTERN_ENGULFING_BULL || ps.id==PATTERN_PIN_BULL ||
           ps.id==PATTERN_3_WHITE_SOLDIERS || ps.id==PATTERN_RISING_3_METHODS ||
           ps.candlesUsed>=3));
}
bool IsStrongBear(const PatternScore &ps)
{
   return (ps.bias=="SELL" && (
           ps.id==PATTERN_ENGULFING_BEAR || ps.id==PATTERN_PIN_BEAR ||
           ps.id==PATTERN_3_BLACK_CROWS || ps.id==PATTERN_FALLING_3_METHODS ||
           ps.candlesUsed>=3));
}
bool IsModerateBull(const PatternScore &ps)
{
   return (ps.bias=="BUY" && (
           ps.id==PATTERN_LONG_BULL || ps.id==PATTERN_OUTSIDE_BAR_BULL ||
           ps.id==PATTERN_HARAMI_BULL));
}
bool IsModerateBear(const PatternScore &ps)
{
   return (ps.bias=="SELL" && (
           ps.id==PATTERN_LONG_BEAR || ps.id==PATTERN_OUTSIDE_BAR_BEAR ||
           ps.id==PATTERN_HARAMI_BEAR));
}
string PatternStrengthLabel(const PatternScore &ps)
{
   if(IsStrongBull(ps)  || IsStrongBear(ps))   return "STRONG";
   if(IsModerateBull(ps)|| IsModerateBear(ps)) return "MODERATE";
   if(ps.bias=="NONE")                         return "NEUTRAL";
   return "WEAK";
}

// ---------- BONUS THEO MẪU NẾN ----------------------------------
double PatternBonusBull(const PatternScore &ps)
{
   if(ps.bias!="BUY") return 0.0;
   if(IsStrongBull(ps))
      return Clamp(MapLinear(ps.score,60,90,10,16),0.0,16.0);
   if(IsModerateBull(ps))
      return Clamp(MapLinear(ps.score,55,85, 6,12),0.0,12.0);
   return 0.0;
}
double PatternBonusBear(const PatternScore &ps)
{
   if(ps.bias!="SELL") return 0.0;
   if(IsStrongBear(ps))
      return Clamp(MapLinear(ps.score,60,90,10,16),0.0,16.0);
   if(IsModerateBear(ps))
      return Clamp(MapLinear(ps.score,55,85, 6,12),0.0,12.0);
   return 0.0;
}

// ---------- ĐIỀU CHỈNH NGƯỠNG -----------------------------------
void AdjustThresholdsByPattern(const PatternScore &ps,
                               double &minBuy,double &minSell,double &oppMax)
{
   minBuy  = BASE_MIN_BUY;
   minSell = BASE_MIN_SELL;
   oppMax  = BASE_OPP_MAX;

   if(IsStrongBull(ps))        { minBuy-=5;  oppMax-=5; }
   else if(IsModerateBull(ps)) { minBuy-=2; }
   if(IsStrongBear(ps))        { minSell-=5; oppMax-=5; }
   else if(IsModerateBear(ps)) { minSell-=2; }
   if(ps.bias=="NONE")         { minBuy+=5;  minSell+=5; oppMax+=5; }

   minBuy  = Clamp(minBuy ,35.0,70.0);
   minSell = Clamp(minSell,35.0,70.0);
   oppMax  = Clamp(oppMax ,20.0,60.0);
}



static const double g_condWeight[COND_TOTAL] =
   { 15, 12, 12, 12, 8, 8, 8, 8, 9, 8 };

static const string g_condName[COND_TOTAL] =
   { "Body","Wick","Volume","RSI","MACD",
     "MA50","PivotBreakout","PullbackFib","TrendExpansion","NotExhaustion" };

static const bool g_condMandatory[COND_TOTAL] =
   { false,false,false,false,false,false,false,false,false,false };

// ---------- HÀM CHÍNH: DetectBias --------------------------------
BiasResult DetectBias(const BiasConfig &cfg)
{
   BiasResult r;
   r.symbol     = cfg.symbol;
   r.timeframe  = cfg.timeframe;
   r.type       = "NONE";
   r.percent    = 0.0;
   r.bullScore  = 0.0;
   r.bearScore  = 0.0;

   // 1) Chuyển BiasTF sang ENUM_TIMEFRAMES
   ENUM_TIMEFRAMES tf = PERIOD_D1;
   if(cfg.timeframe==BIAS_TF_H1) tf=PERIOD_H1;
   else if(cfg.timeframe==BIAS_TF_H4) tf=PERIOD_H4;

   // 2) Đánh giá mẫu nến
   PatternScore ps = AssessCandleTiered(cfg.symbol,tf,EVAL_SHIFT);
   r.patternId       = ps.id;
   r.patternName     = ps.name;
   r.patternScore    = ps.score;
   r.patternCandles  = ps.candlesUsed;
   r.patternShift    = EVAL_SHIFT;
   r.patternTime     = iTime(cfg.symbol,tf,EVAL_SHIFT);
   r.patternStrength = PatternStrengthLabel(ps);

   // 3) Điểm 10 điều kiện
   bool resBull[COND_TOTAL];
   bool resBear[COND_TOTAL];
   double bull=0.0, bear=0.0;

   // Helper macro để tiết kiệm gõ
#define ADD_COND(idx, condBull, condBear)        \
      { resBull[idx] = (condBull);               \
        resBear[idx] = (condBear);               \
        if(resBull[idx]) bull += g_condWeight[idx];  \
        if(resBear[idx]) bear += g_condWeight[idx]; }

   ADD_COND(IDX_BODY ,  BodyBull (cfg.symbol,tf), BodyBear (cfg.symbol,tf));
   ADD_COND(IDX_WICK ,  WickBull (cfg.symbol,tf), WickBear (cfg.symbol,tf));
   ADD_COND(IDX_VOLUME, VolumeBull(cfg.symbol,tf),VolumeBear(cfg.symbol,tf));
   ADD_COND(IDX_RSI  ,  RSIBull  (cfg.symbol,tf), RSIBear  (cfg.symbol,tf));
   ADD_COND(IDX_MACD ,  MACDBull (cfg.symbol,tf), MACDBear (cfg.symbol,tf));
   ADD_COND(IDX_MA50 ,  MA50Bull (cfg.symbol,tf), MA50Bear (cfg.symbol,tf));
   ADD_COND(IDX_PIVOT,  PivotBreakoutBull(cfg.symbol,tf),
                         PivotBreakoutBear(cfg.symbol,tf));
   ADD_COND(IDX_PULLBACK,PullbackFibBull(cfg.symbol,tf),
                            PullbackFibBear(cfg.symbol,tf));
   ADD_COND(IDX_TREND_EXP,TrendExpansionBull(cfg.symbol,tf),
                            TrendExpansionBear(cfg.symbol,tf));
   ADD_COND(IDX_NOT_EXH ,NotExhaustionBull(cfg.symbol,tf),
                            NotExhaustionBear(cfg.symbol,tf));
#undef ADD_COND

   // 4) Bonus mẫu nến
   double bonusBull = PatternBonusBull(ps);
   double bonusBear = PatternBonusBear(ps);
   if(!resBull[IDX_TREND_EXP]) bonusBull *= 0.6;
   if(!resBear[IDX_TREND_EXP]) bonusBear *= 0.6;
   bull += bonusBull;
   bear += bonusBear;

   // 5) Ngưỡng động
   double minBuy,minSell,oppMax;
   AdjustThresholdsByPattern(ps,minBuy,minSell,oppMax);

   // 6) Mandatory gate
   bool mandatoryBullOK=true, mandatoryBearOK=true;
   for(int i=0;i<COND_TOTAL;i++)
   {
      if(g_condMandatory[i] && !resBull[i]) mandatoryBullOK=false;
      if(g_condMandatory[i] && !resBear[i]) mandatoryBearOK=false;
   }

   // 7) Ra quyết định
   r.bullScore = bull;
   r.bearScore = bear;
   double margin = 4.0;

   bool buyOK  = mandatoryBullOK && bull>=minBuy  && bull>bear &&
                 (bull-bear)>=margin && bear<oppMax;
   bool sellOK = mandatoryBearOK && bear>=minSell && bear>bull &&
                 (bear-bull)>=margin && bull<oppMax;

   if(buyOK && !sellOK)  { r.type="BUY";  r.percent=Clamp(bull,0,100); }
   else if(sellOK && !buyOK){ r.type="SELL"; r.percent=Clamp(bear,0,100);}
   else { r.type="NONE"; r.percent=0.0; }

   return r;
}

// ---------- GHI LOG JSON (tuỳ chọn) ------------------------------
void LogBiasResultJSON(const BiasResult &r)
{
   string tfStr = (r.timeframe==BIAS_TF_H1 ? "H1" :
                   r.timeframe==BIAS_TF_H4 ? "H4" : "D1");

   string json;
   json  = "{\"symbol\":\""+r.symbol+"\","
           "\"timeframe\":\""+tfStr+"\","
           "\"bias\":\""+r.type+"\","
           "\"score\":"+DoubleToString(r.percent,1)+","
           "\"timestamp\":"+(string)r.patternTime+"}";

   Print(json);

   int h = FileOpen("DetectBiasLog.json",
                    FILE_READ|FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_ANSI);
   if(h!=INVALID_HANDLE){
      FileSeek(h,0,SEEK_END);
      FileWrite(h,json);
      FileClose(h);
   }
}

// ---------- ALIAS GIỮ TƯƠNG THÍCH CŨ ---------------------------

#endif // __SCAN_BIAS_MQH__
