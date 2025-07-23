//+------------------------------------------------------------------+
//| DailyBiasConditions.mqh – Daily bias detection (XAUUSD)          |
//| 10 pairs of Bull/Bear condition functions                        |
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


struct BiasResult
  {
   bool              isActiveBias;
   string            type;
   double            percent;
   int               bullCount;
   int               bearCount;
  };

//--- CONDITION FUNCTION POINTER ----------------------------------
typedef bool (*CondFunc)();

struct CondEntry
  {
   CondFunc          fnBull;
   CondFunc          fnBear;
   bool              mandatory;
  };

//--- DetectDailyBias using table-driven approach ------------------
BiasResult DetectDailyBias()
  {
   static CondEntry conds[10] =
     {
        { BodyBull,           BodyBear,           false },
        { WickBull,           WickBear,           false },
        { VolumeBull,         VolumeBear,         false },
        { RSIBull,            RSIBear,            false },
        { MACDBull,           MACDBear,           false },
        { MA50Bull,           MA50Bear,           false },
        { PivotBreakoutBull,  PivotBreakoutBear,  false },
        { PullbackFibBull,    PullbackFibBear,    false },
        { TrendExpansionBull, TrendExpansionBear, false },
        { NotExhaustionBull,  NotExhaustionBear,  false }
     };

   BiasResult r;
   r.bullCount = 0;
   r.bearCount = 0;
   bool mandBull = true, mandBear = true;

   for(int i = 0; i < CONDITIONS; i++)
     {
      if(conds[i].fnBull())
         r.bullCount++;
      else if(conds[i].mandatory)
         mandBull = false;

      if(conds[i].fnBear())
         r.bearCount++;
      else if(conds[i].mandatory)
         mandBear = false;
     }

   if(mandBull && r.bullCount >= 4 && r.bullCount > r.bearCount)
     {
      r.isActiveBias = true;
      r.type         = "BUY";
      r.percent      = r.bullCount * 10.0;
     }
   else if(mandBear && r.bearCount >= 4 && r.bearCount > r.bullCount)
     {
      r.isActiveBias = true;
      r.type         = "SELL";
      r.percent      = r.bearCount * 10.0;
     }
   else
     {
      r.isActiveBias = false;
      r.type         = "NONE";
      r.percent      = 0.0;
     }

   return r;
  }

#endif // __DAILY_BIAS_CONDITIONS_MQH__
