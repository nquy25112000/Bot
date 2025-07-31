#ifndef __DAILY_BIAS_CONDITIONS_FUNCS_MQH__
#define __DAILY_BIAS_CONDITIONS_FUNCS_MQH__
#property strict
#include <Trade\SymbolInfo.mqh>

#define  EVAL_SHIFT   1      // luôn dùng nến đã đóng (index 1)

//==================== CONDITION FUNCTIONS ====================

// 1. Body  ───────────────────────────────────────────────────
bool BodyCond(bool bullish)
{
   double o=iOpen(_Symbol,PERIOD_D1,EVAL_SHIFT);
   double c=iClose(_Symbol,PERIOD_D1,EVAL_SHIFT);
   double h=iHigh(_Symbol,PERIOD_D1,EVAL_SHIFT);
   double l=iLow(_Symbol,PERIOD_D1,EVAL_SHIFT);
   double range=h-l; if(range<=0) return false;
   double body=MathAbs(c-o);
   return (bullish ? (c>o) : (c<o)) && (body/range>=0.45);   // ≤── nới 55% → 45%
}
inline bool BodyBull(){ return BodyCond(true);  }
inline bool BodyBear(){ return BodyCond(false); }

// 2. Wick  ───────────────────────────────────────────────────
bool WickBull()
{
   double o=iOpen(_Symbol,PERIOD_D1,EVAL_SHIFT);
   double c=iClose(_Symbol,PERIOD_D1,EVAL_SHIFT);
   double h=iHigh(_Symbol,PERIOD_D1,EVAL_SHIFT);
   double l=iLow(_Symbol,PERIOD_D1,EVAL_SHIFT);
   if(h<=l) return false;
   double upper = h - MathMax(c,o);
   return (c>o) && (upper/(h-l)<=0.4);                       // ≤── 0.3 → 0.4
}
bool WickBear()
{
   double o=iOpen(_Symbol,PERIOD_D1,EVAL_SHIFT);
   double c=iClose(_Symbol,PERIOD_D1,EVAL_SHIFT);
   double h=iHigh(_Symbol,PERIOD_D1,EVAL_SHIFT);
   double l=iLow(_Symbol,PERIOD_D1,EVAL_SHIFT);
   if(h<=l) return false;
   double lower = MathMin(c,o) - l;
   return (c<o) && (lower/(h-l)<=0.45);                      // ≤── 0.36 → 0.45
}

// 3. Volume  ─────────────────────────────────────────────────
bool VolumeBull()
{
   long v1=iVolume(_Symbol,PERIOD_D1,EVAL_SHIFT); if(v1<=0) return false;
   long sum=0; int cnt=0;
   for(int s=EVAL_SHIFT+1; s<=EVAL_SHIFT+5; s++)
      if(iVolume(_Symbol,PERIOD_D1,s)>0){ sum+=iVolume(_Symbol,PERIOD_D1,s); cnt++; }
   long avg = (cnt>0) ? sum/cnt : v1;
   return v1 > 1.1 * avg;                                     // ≤── 1.2 → 1.1
}
bool VolumeBear()
{
   long v1=iVolume(_Symbol,PERIOD_D1,EVAL_SHIFT); if(v1<=0) return false;
   double o=iOpen(_Symbol,PERIOD_D1,EVAL_SHIFT);
   double c=iClose(_Symbol,PERIOD_D1,EVAL_SHIFT);
   if(c>=o) return false;
   long sum=0; int cnt=0;
   for(int s=EVAL_SHIFT+1; s<=EVAL_SHIFT+5; s++)
      if(iVolume(_Symbol,PERIOD_D1,s)>0){ sum+=iVolume(_Symbol,PERIOD_D1,s); cnt++; }
   long avg = (cnt>0) ? sum/cnt : v1;
   return v1 > 1.1 * avg;                                     // ≤── 1.2 → 1.1
}

// 4. RSI  ────────────────────────────────────────────────────
bool RSIBull()
{
   double buf[];
   if(CopyBuffer(rsi_handle,0,EVAL_SHIFT,1,buf)!=1) return false;
   return buf[0] > 52.0;                                      // >55 → >52
}
bool RSIBear()
{
   double buf[];
   if(CopyBuffer(rsi_handle,0,EVAL_SHIFT,1,buf)!=1) return false;
   return buf[0] < 48.0;                                      // <45 → <48
}

// 5. MACD  ───────────────────────────────────────────────────
bool MACDBull()
{
   double m[],s[];
   if(CopyBuffer(macd_handle,0,EVAL_SHIFT,1,m)!=1 ||
      CopyBuffer(macd_handle,1,EVAL_SHIFT,1,s)!=1) return false;
   return m[0] > s[0];
}
bool MACDBear()
{
   double m[],s[];
   if(CopyBuffer(macd_handle,0,EVAL_SHIFT,1,m)!=1 ||
      CopyBuffer(macd_handle,1,EVAL_SHIFT,1,s)!=1) return false;
   return m[0] < s[0];
}

// 6. MA50  ───────────────────────────────────────────────────
bool MA50Bull()
{
   double buf[];
   if(CopyBuffer(ma50_handle,0,EVAL_SHIFT,1,buf)!=1) return false;
   return iClose(_Symbol,PERIOD_D1,EVAL_SHIFT) > buf[0];
}
bool MA50Bear()
{
   double buf[];
   if(CopyBuffer(ma50_handle,0,EVAL_SHIFT,1,buf)!=1) return false;
   return iClose(_Symbol,PERIOD_D1,EVAL_SHIFT) < buf[0];
}

// 7. Pivot Breakout ──────────────────────────────────────────
bool PivotBreakoutBull()
{
   double h=iHigh(_Symbol,PERIOD_D1,EVAL_SHIFT),
          l=iLow(_Symbol,PERIOD_D1,EVAL_SHIFT),
          c=iClose(_Symbol,PERIOD_D1,EVAL_SHIFT);
   double PP=(h+l+c)/3.0, R1 = 2*PP - l;
   return SymbolInfoDouble(_Symbol,SYMBOL_BID) > R1;
}
bool PivotBreakoutBear()
{
   double h=iHigh(_Symbol,PERIOD_D1,EVAL_SHIFT),
          l=iLow(_Symbol,PERIOD_D1,EVAL_SHIFT),
          c=iClose(_Symbol,PERIOD_D1,EVAL_SHIFT);
   double PP=(h+l+c)/3.0, S1 = 2*PP - h;
   return SymbolInfoDouble(_Symbol,SYMBOL_BID) < S1;
}

// 8. Pullback Fibonacci ─────────────────────────────────────
bool PullbackFibBull()
{
   double o=iOpen(_Symbol,PERIOD_D1,EVAL_SHIFT), c=iClose(_Symbol,PERIOD_D1,EVAL_SHIFT),
          h=iHigh(_Symbol,PERIOD_D1,EVAL_SHIFT), l=iLow(_Symbol,PERIOD_D1,EVAL_SHIFT);
   if(c<=o) return false;
   double range=h-l; if(range<=0) return false;
   double f236 = l + 0.236*range, f62 = l + 0.618*range;      // ↓ mở rộng từ 23.6%
   double p = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   return (p >= f236 && p <= f62);
}
bool PullbackFibBear()
{
   double o=iOpen(_Symbol,PERIOD_D1,EVAL_SHIFT), c=iClose(_Symbol,PERIOD_D1,EVAL_SHIFT),
          h=iHigh(_Symbol,PERIOD_D1,EVAL_SHIFT), l=iLow(_Symbol,PERIOD_D1,EVAL_SHIFT);
   if(c>=o) return false;
   double range=h-l; if(range<=0) return false;
   double f236 = h - 0.236*range, f62 = h - 0.618*range;
   double p = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   return (p <= f236 && p >= f62);
}

// 9. Trend Expansion ─────────────────────────────────────────
bool TrendExpansionBull()
{
   double atr_buf[];
   if(CopyBuffer(atr_handle,0,EVAL_SHIFT,1,atr_buf)!=1) return false;
   double atr = atr_buf[0];

   double adx_buf[], plus_buf[], minus_buf[];
   if(CopyBuffer(adx_handle,0,EVAL_SHIFT,1,adx_buf)!=1 ||
      CopyBuffer(adx_handle,1,EVAL_SHIFT,1,plus_buf)!=1 ||
      CopyBuffer(adx_handle,2,EVAL_SHIFT,1,minus_buf)!=1) return false;

   double h=iHigh(_Symbol,PERIOD_D1,EVAL_SHIFT), l=iLow(_Symbol,PERIOD_D1,EVAL_SHIFT);
   double range = h - l;
   if(!(atr>0 && range >= 1.0*atr && range < 2.5*atr)) return false;   // ≥ ATR (thay vì >1.2)
   return (adx_buf[0] >= 20.0) && (plus_buf[0] > minus_buf[0]);        // ADX 25 → 20
}
bool TrendExpansionBear()
{
   double atr_buf[];
   if(CopyBuffer(atr_handle,0,EVAL_SHIFT,1,atr_buf)!=1) return false;
   double atr = atr_buf[0];

   double adx_buf[], plus_buf[], minus_buf[];
   if(CopyBuffer(adx_handle,0,EVAL_SHIFT,1,adx_buf)!=1 ||
      CopyBuffer(adx_handle,1,EVAL_SHIFT,1,plus_buf)!=1 ||
      CopyBuffer(adx_handle,2,EVAL_SHIFT,1,minus_buf)!=1) return false;

   double h=iHigh(_Symbol,PERIOD_D1,EVAL_SHIFT), l=iLow(_Symbol,PERIOD_D1,EVAL_SHIFT);
   double range = h - l;
   if(!(atr>0 && range >= 1.0*atr && range < 2.5*atr)) return false;
   return (adx_buf[0] >= 20.0) && (minus_buf[0] > plus_buf[0]);
}

// 10. Not Exhaustion ─────────────────────────────────────────
bool NotExhaustionBull()
{
   double o=iOpen(_Symbol,PERIOD_D1,EVAL_SHIFT), c=iClose(_Symbol,PERIOD_D1,EVAL_SHIFT);
   double h=iHigh(_Symbol,PERIOD_D1,EVAL_SHIFT), l=iLow(_Symbol,PERIOD_D1,EVAL_SHIFT);
   double range = h - l; if(range<=0) return false;
   double body=MathAbs(c-o), upper=h-MathMax(c,o);
   return !(body/range < 0.3 && upper/range > 0.6);
}
bool NotExhaustionBear()
{
   double o=iOpen(_Symbol,PERIOD_D1,EVAL_SHIFT), c=iClose(_Symbol,PERIOD_D1,EVAL_SHIFT);
   double h=iHigh(_Symbol,PERIOD_D1,EVAL_SHIFT), l=iLow(_Symbol,PERIOD_D1,EVAL_SHIFT);
   double range = h - l; if(range<=0) return false;
   double body=MathAbs(c-o), lower=MathMin(c,o)-l;
   return !(body/range < 0.3 && lower/range > 0.6);
}

#endif // __DAILY_BIAS_CONDITIONS_FUNCS_MQH__