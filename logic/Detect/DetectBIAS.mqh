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
   PatternScore ps = AssessCandleTiered(_Symbol, PERIOD_D1, EVAL_SHIFT);

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
      false, false, false, false,  // Body, Wick, Volume, RSI
      false, false,            // MACD, MA50
      false, false,            // Pivot, PullbackFib
      false, false             // TrendExpansion, NotExhaustion
   };
   static double condWeight[10] = {
      15, 12, 12, 12, 8, 8, 8, 8, 9, 8
   };
   // Tên điều kiện để debug (giữ đúng thứ tự)
   static string condName[10] = {
      "Body", "Wick", "Volume", "RSI",
      "MACD", "MA50",
      "PivotBreakout", "PullbackFib",
      "TrendExpansion", "NotExhaustion"
   };

   // Self-check trọng số (in 1 lần duy nhất)
   {
      static bool weightChecked=false;
      if(!weightChecked){
         double sumW=0.0; for(int i=0;i<CONDITIONS;i++) sumW+=condWeight[i];
         if(MathAbs(sumW-100.0)>0.001)
            PrintFormat("[DetectDailyBias][WARN] condWeight sum != 100 (sum=%.2f)", sumW);
         weightChecked=true;
      }
   }

   // === Tính điểm + Cache kết quả cho Mandatory Gate ===
   double bull = 0.0, bear = 0.0;
   bool   resBull[10];
   bool   resBear[10];

   for(int i=0; i<CONDITIONS; i++)
   {
      bool bBull = condBull[i]();
      bool bBear = condBear[i]();

      resBull[i] = bBull;
      resBear[i] = bBear;

      if(bBull) bull += condWeight[i];
      if(bBear) bear += condWeight[i];
   }

   // 3) Bonus pattern — có “trend factor” để tránh lệch khi thiếu trend
   // Index 8 = TrendExpansion
   double bonusBull = PatternBonusBull(ps);
   double bonusBear = PatternBonusBear(ps);
   if(!resBull[8]) bonusBull *= 0.6;  // không có TrendExpansion: giảm sức mạnh pattern
   if(!resBear[8]) bonusBear *= 0.6;

   bull += bonusBull;
   bear += bonusBear;

   // 4) Ngưỡng động
   double minBuy, minSell, oppMax;
   AdjustThresholdsByPattern(ps, minBuy, minSell, oppMax);

   // 5) Mandatory Gate (Mục 10): nếu bất kỳ điều kiện tiên quyết fail ⇒ hướng đó bị chặn
   bool   mandatoryBullOK = true;
   bool   mandatoryBearOK = true;
   string failBull = "", failBear = "";

   for(int i=0; i<CONDITIONS; i++)
   {
      if(condMandatory[i] && !resBull[i]){
         mandatoryBullOK = false;
         if(failBull!="") failBull += ", ";
         failBull += condName[i];
      }
      if(condMandatory[i] && !resBear[i]){
         mandatoryBearOK = false;
         if(failBear!="") failBear += ", ";
         failBear += condName[i];
      }
   }

   // 6) Quyết định (thêm margin chênh lệch tối thiểu để tránh sát nút)
   r.bullScore = bull;
   r.bearScore = bear;

   double margin = 4.0; // có thể tinh chỉnh hoặc map theo ADX nếu muốn

   bool buyOK  = mandatoryBullOK && (bull >= minBuy)  && (bull > bear) && ((bull - bear) >= margin) && (bear < oppMax);
   bool sellOK = mandatoryBearOK && (bear >= minSell) && (bear > bull) && ((bear - bull) >= margin) && (bull < oppMax);

   if(!mandatoryBullOK)
      PrintFormat("[DetectDailyBias] BUY blocked by mandatory fails: %s", failBull);
   if(!mandatoryBearOK)
      PrintFormat("[DetectDailyBias] SELL blocked by mandatory fails: %s", failBear);

   if(buyOK && !sellOK){ r.type="BUY";  r.percent=MathMin(100.0, bull); }
   else if(sellOK && !buyOK){ r.type="SELL"; r.percent=MathMin(100.0, bear); }
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
