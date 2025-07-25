//+------------------------------------------------------------------+
//| DailyBiasConditions.mqh – Daily bias detection (XAUUSD)          |
//+------------------------------------------------------------------+
#ifndef __DAILY_BIAS_CONDITIONS_MQH__
#define __DAILY_BIAS_CONDITIONS_MQH__
#include "CoreLogicBIAS.mqh"

#property strict

//--- PARAMETERS ----------------------------------------------------
#define  EVAL_SHIFT   1                     // Always use closed candle (index 1)
const int CONDITIONS = 10;                  // Number of Bull/Bear condition pairs

//--- INDICATOR HANDLES --------------------------------------------
int rsi_handle  = INVALID_HANDLE;
int macd_handle = INVALID_HANDLE;
int ma50_handle = INVALID_HANDLE;
int atr_handle  = INVALID_HANDLE;
int adx_handle  = INVALID_HANDLE;

//--- STRUCTURE: Bias result ----------------------------------------
struct BiasResult
  {
   bool              isActiveBias;
   string            type;         // "BUY", "SELL", "NONE"
   double            percent;      // điểm tương ứng hướng bias được chọn
   double            bullScore;    // tổng điểm từ các điều kiện Bull
   double            bearScore;    // tổng điểm từ các điều kiện Bear
  };

//--- FUNCTION POINTER STRUCTURE ------------------------------------
typedef bool (*CondFunc)();

struct CondEntry
  {
   CondFunc          fnBull;
   CondFunc          fnBear;
   bool              mandatory;
   double            weight;
  };

//--- MAIN FUNCTION -------------------------------------------------
BiasResult DetectDailyBias()
  {
   static CondEntry conds[10] =
     {
        { BodyBull,           BodyBear,           true, 15 },
        { WickBull,           WickBear,           true, 12 },
        { VolumeBull,         VolumeBear,         true, 12 },
        { RSIBull,            RSIBear,            true, 12 },
        { MACDBull,           MACDBear,           false, 8  },
        { MA50Bull,           MA50Bear,           false, 8  },
        { PivotBreakoutBull,  PivotBreakoutBear,  false, 8  },
        { PullbackFibBull,    PullbackFibBear,    false, 8  },
        { TrendExpansionBull, TrendExpansionBear, false, 9 },
        { NotExhaustionBull,  NotExhaustionBear,  false, 8 }
     };

   BiasResult r;
   r.bullScore = 0.0;
   r.bearScore = 0.0;
   r.percent = 0.0;
   r.isActiveBias = false;
   r.type = "NONE";

   for(int i = 0; i < CONDITIONS; i++)
     {
      if(conds[i].fnBull())
         r.bullScore += conds[i].weight;

      if(conds[i].fnBear())
         r.bearScore += conds[i].weight;
     }

   if(r.bullScore >= 45.0 && (r.bullScore > r.bearScore && r.bearScore < 30))
     {
      r.isActiveBias = true;
      r.type         = "BUY";
      r.percent      = r.bullScore;
     }
   else
      if(r.bearScore >= 45.0 && (r.bearScore > r.bullScore && r.bullScore < 30))
        {
         r.isActiveBias = true;
         r.type         = "SELL";
         r.percent      = r.bearScore;
        }
      else
        {
         r.bullScore = r.bearScore;
         r.bearScore = r.bearScore;
         r.percent = 0.0;
         r.isActiveBias = false;
         r.type = "NONE";

        }

   return r;
  }

#endif // __DAILY_BIAS_CONDITIONS_MQH__
//+------------------------------------------------------------------+
