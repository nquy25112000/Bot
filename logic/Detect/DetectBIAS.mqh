//+------------------------------------------------------------------+
//| DetectBIAS.mqh – Daily bias detection (XAUUSD) – Pattern-first   |
//+------------------------------------------------------------------+
#ifndef __DAILY_BIAS_CONDITIONS_MQH__
#define __DAILY_BIAS_CONDITIONS_MQH__
#property strict

#include "./CoreLogicBIAS.mqh"
#include "./CandlePattern.mqh"


//--- INDICATOR HANDLES (được CoreLogicBIAS.* sử dụng)
int rsi_handle  = INVALID_HANDLE;
int macd_handle = INVALID_HANDLE;
int ma50_handle = INVALID_HANDLE;
int atr_handle  = INVALID_HANDLE;
int adx_handle  = INVALID_HANDLE;

//--- Kết quả bias
struct BiasResult
{
   // Kết quả bias cuối cùng
   string  type;            // "BUY" | "SELL" | "NONE"
   double  percent;         // điểm hướng thắng (sau pattern bonus)
   double  bullScore;       // tổng điểm Bull
   double  bearScore;       // tổng điểm Bear

   // Snapshot CandlePattern của nến D1 đã đóng (shift=EVAL_SHIFT)
   int     patternId;       // enum CandlePattern
   string  patternName;     // ví dụ "Bullish Engulfing"
   double  patternScore;    // 0..100
   int     patternCandles;  // 1 / 2 / 3 / 5
   int     patternShift;    // thường = EVAL_SHIFT (1)
   datetime patternTime;    // open time nến D1 tại shift
   string  patternStrength; // "STRONG" | "MODERATE" | "NEUTRAL" | "WEAK"
};

//================= CONFIG – THRESHOLDS & MAPPING ====================
#define BASE_MIN_BUY   50.0
#define BASE_MIN_SELL  50.0
#define BASE_OPP_MAX   35.0

double MapLinear(double x, double x1, double x2, double y1, double y2)
{
   if(x <= x1) return y1;
   if(x >= x2) return y2;
   return y1 + (y2 - y1) * ((x - x1) / (x2 - x1));
}

//=== Phân nhóm mẫu nến theo độ mạnh (THAM CHIẾU, không dùng *) =====
bool IsStrongBull(const PatternScore &ps)
{
   if(ps.bias!="BUY") return false;
   return (ps.id==PATTERN_ENGULFING_BULL
        || ps.id==PATTERN_PIN_BULL
        || ps.id==PATTERN_3_WHITE_SOLDIERS
        || ps.id==PATTERN_RISING_3_METHODS
        || ps.candlesUsed>=3);
}
bool IsStrongBear(const PatternScore &ps)
{
   if(ps.bias!="SELL") return false;
   return (ps.id==PATTERN_ENGULFING_BEAR
        || ps.id==PATTERN_PIN_BEAR
        || ps.id==PATTERN_3_BLACK_CROWS
        || ps.id==PATTERN_FALLING_3_METHODS
        || ps.candlesUsed>=3);
}
bool IsModerateBull(const PatternScore &ps)
{
   if(ps.bias!="BUY") return false;
   return (ps.id==PATTERN_LONG_BULL
        || ps.id==PATTERN_OUTSIDE_BAR_BULL
        || ps.id==PATTERN_HARAMI_BULL);
}
bool IsModerateBear(const PatternScore &ps)
{
   if(ps.bias!="SELL") return false;
   return (ps.id==PATTERN_LONG_BEAR
        || ps.id==PATTERN_OUTSIDE_BAR_BEAR
        || ps.id==PATTERN_HARAMI_BEAR);
}

string PatternStrengthLabel(const PatternScore &ps)
{
   if(IsStrongBull(ps) || IsStrongBear(ps))     return "STRONG";
   if(IsModerateBull(ps) || IsModerateBear(ps)) return "MODERATE";
   if(ps.bias=="NONE")                           return "NEUTRAL";
   return "WEAK";
}

//=== Bonus điểm theo pattern (tham chiếu) ===========================
double PatternBonusBull(const PatternScore &ps)
{
   if(ps.bias!="BUY") return 0.0;
   if(IsStrongBull(ps))    return MathMax(0.0, MathMin(16.0, MapLinear(ps.score, 60, 90, 10, 16)));
   if(IsModerateBull(ps))  return MathMax(0.0, MathMin(12.0, MapLinear(ps.score, 55, 85,  6, 12)));
   return 0.0;
}
double PatternBonusBear(const PatternScore &ps)
{
   if(ps.bias!="SELL") return 0.0;
   if(IsStrongBear(ps))    return MathMax(0.0, MathMin(16.0, MapLinear(ps.score, 60, 90, 10, 16)));
   if(IsModerateBear(ps))  return MathMax(0.0, MathMin(12.0, MapLinear(ps.score, 55, 85,  6, 12)));
   return 0.0;
}

//=== Điều chỉnh ngưỡng quyết định theo pattern ======================
void AdjustThresholdsByPattern(const PatternScore &ps, double &minBuy, double &minSell, double &oppMax)
{
   minBuy  = BASE_MIN_BUY;
   minSell = BASE_MIN_SELL;
   oppMax  = BASE_OPP_MAX;

   if(IsStrongBull(ps)){ minBuy -= 5.0; oppMax -= 5.0; }
   else if(IsModerateBull(ps)){ minBuy -= 2.0; }

   if(IsStrongBear(ps)){ minSell -= 5.0; oppMax -= 5.0; }
   else if(IsModerateBear(ps)){ minSell -= 2.0; }

   if(ps.bias=="NONE"){ minBuy += 5.0; minSell += 5.0; oppMax += 5.0; }

   // clamp an toàn
   minBuy  = MathMax(35.0, MathMin(70.0, minBuy));
   minSell = MathMax(35.0, MathMin(70.0, minSell));
   oppMax  = MathMax(20.0, MathMin(60.0, oppMax));
}

//====================== MAIN: DetectDailyBias =======================
BiasResult DetectDailyBias()
{
   BiasResult r;
   r.type="NONE"; r.percent=0.0;
   r.bullScore=0.0; r.bearScore=0.0;
   r.patternId=0; r.patternName="None"; r.patternScore=0.0;
   r.patternCandles=1; r.patternShift=EVAL_SHIFT; r.patternTime=0; r.patternStrength="NEUTRAL";

   // 1) Pattern của nến D1 đã đóng
   PatternScore ps = AssessCandle(_Symbol, PERIOD_D1, EVAL_SHIFT);

   r.patternId       = ps.id;
   r.patternName     = ps.name;
   r.patternScore    = ps.score;
   r.patternCandles  = ps.candlesUsed;
   r.patternShift    = EVAL_SHIFT;
   r.patternTime     = iTime(_Symbol, PERIOD_D1, EVAL_SHIFT);
   r.patternStrength = PatternStrengthLabel(ps);

   // 2) Chấm điểm 10 điều kiện core  =================================
// Dùng mảng function pointer thay vì struct chứa function pointer
typedef bool (*CondFunc)(void);
const int CONDITIONS = 10;

static CondFunc condBull[10] = {
   BodyBull,
   WickBull,
   VolumeBull,
   RSIBull,
   MACDBull,
   MA50Bull,
   PivotBreakoutBull,
   PullbackFibBull,
   TrendExpansionBull,
   NotExhaustionBull
};
static CondFunc condBear[10] = {
   BodyBear,
   WickBear,
   VolumeBear,
   RSIBear,
   MACDBear,
   MA50Bear,
   PivotBreakoutBear,
   PullbackFibBear,
   TrendExpansionBear,
   NotExhaustionBear
};
static bool condMandatory[10] = {
   true, true, true, true,  // Body, Wick, Volume, RSI
   false, false,            // MACD, MA50
   false, false,            // Pivot, PullbackFib
   false, false             // TrendExpansion, NotExhaustion
};
static double condWeight[10] = {
   15, 12, 12, 12, 8, 8, 8, 8, 9, 8
};

// Tính điểm
double bull = 0.0, bear = 0.0;
for(int i=0; i<CONDITIONS; i++)
{
   if(condBull[i]()) bull += condWeight[i];
   if(condBear[i]()) bear += condWeight[i];
}

   // 3) Bonus pattern
   bull += PatternBonusBull(ps);
   bear += PatternBonusBear(ps);

   // 4) Ngưỡng động
   double minBuy, minSell, oppMax;
   AdjustThresholdsByPattern(ps, minBuy, minSell, oppMax);

   // 5) Quyết định
   r.bullScore = bull;
   r.bearScore = bear;

   bool buyOK  = (bull >= minBuy)  && (bull > bear) && (bear < oppMax);
   bool sellOK = (bear >= minSell) && (bear > bull) && (bull < oppMax);

   if(buyOK && !sellOK){ r.type="BUY";  r.percent=bull; }
   else if(sellOK && !buyOK){ r.type="SELL"; r.percent=bear; }
   else { r.type="NONE"; r.percent=0.0; }

   return r;
}

//====================== DEBUG HELPERS ===============================
inline void LogDailyBias(const BiasResult &r, int tzOffsetHours=7)
{
   datetime t = r.patternTime;
   if(tzOffsetHours!=0) t += tzOffsetHours*3600;
   MqlDateTime d; TimeToStruct(t,d);

   PrintFormat("[D1 %04d-%02d-%02d] Bias=%s pct=%.1f | Bull=%.1f Bear=%.1f | "
               "Pattern=%s[score=%.0f,used=%d,%s] | BUY: %i | SELL: %i | NONE: %i | increseVol=%.2f",
               d.year,d.mon,d.day,
               r.type,r.percent,
               r.bullScore,r.bearScore,
               r.patternName,r.patternScore,r.patternCandles,r.patternStrength,
               countBUYBIAS, countSELLBIAS, countNONEBIAS,increseVol);
}

#endif // __DAILY_BIAS_CONDITIONS_MQH__
//+------------------------------------------------------------------+
