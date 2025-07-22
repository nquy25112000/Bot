//+------------------------------------------------------------------+
//| DailyBiasConditions.mqh – Bias BUY / SELL / NONE for XAUUSD       |
//| Gồm 20 điều kiện (10 Bull / 10 Bear)                              |
//+------------------------------------------------------------------+
#ifndef __DAILY_BIAS_CONDITIONS_MQH__
#define __DAILY_BIAS_CONDITIONS_MQH__
#property strict
#define EVAL_SHIFT 1   // luôn lấy nến đã đóng (index 1)

//------------------------------------------------------------------
// Enum kết quả bias (tường minh)
//------------------------------------------------------------------
enum BiasType
  {
   BIAS_NONE = 0,   // Không rõ
   BIAS_BUY  = 1,   // Ưu tiên MUA
   BIAS_SELL = -1   // Ưu tiên BÁN
  };

//------------------------------------------------------------------
// Struct kết quả chi tiết
//------------------------------------------------------------------
struct BiasResult
  {
   bool      isActiveBias; // true nếu đủ điều kiện (≥6/10 & 4 bắt buộc)
   BiasType  type;         // BUY / SELL / NONE
   double    percent;      // % điều kiện True của phe thắng
   int       bullCount;    // số điều kiện BUY đúng
   int       bearCount;    // số điều kiện SELL đúng
  };

//------------------------------------------------------------------
// Prototype 10 cặp điều kiện Bull / Bear
//------------------------------------------------------------------
bool BodyBull();              bool BodyBear();
bool WickBull();              bool WickBear();
bool VolumeBull();            bool VolumeBear();
bool RSIBull();               bool RSIBear();
bool MACDBull();              bool MACDBear();
bool MA50Bull();              bool MA50Bear();
bool PivotBreakoutBull();     bool PivotBreakoutBear();
bool PullbackFibBull();       bool PullbackFibBear();
bool TrendExpansionBull();    bool TrendExpansionBear();
bool NotExhaustionBull();     bool NotExhaustionBear();

//------------------------------------------------------------------
// Hàm đánh giá bias
//------------------------------------------------------------------
BiasResult DetectDailyBias()
{
   bool bull[10], bear[10];
   int idx = 0;
   bull[idx] = BodyBull();              bear[idx++] = BodyBear();
   bull[idx] = WickBull();              bear[idx++] = WickBear();
   bull[idx] = VolumeBull();            bear[idx++] = VolumeBear();
   bull[idx] = RSIBull();               bear[idx++] = RSIBear();
   bull[idx] = MACDBull();              bear[idx++] = MACDBear();
   bull[idx] = MA50Bull();              bear[idx++] = MA50Bear();
   bull[idx] = PivotBreakoutBull();     bear[idx++] = PivotBreakoutBear();
   bull[idx] = PullbackFibBull();       bear[idx++] = PullbackFibBear();
   bull[idx] = TrendExpansionBull();    bear[idx++] = TrendExpansionBear();
   bull[idx] = NotExhaustionBull();     bear[idx++] = NotExhaustionBear();

   int bullTrue=0, bearTrue=0;
   for(int i=0;i<10;i++){ if(bull[i]) bullTrue++; if(bear[i]) bearTrue++; }

   // 4 điều kiện đầu tiên bắt buộc True cho mỗi phe
   bool mandatoryBull = bull[0] && bull[1] && bull[2] && bull[3];
   bool mandatoryBear = bear[0] && bear[1] && bear[2] && bear[3];

   BiasResult r;
   r.bullCount = bullTrue;
   r.bearCount = bearTrue;
   r.isActiveBias = false;
   r.type = BIAS_NONE;
   r.percent = 0.0;

   // Kiểm tra BUY
   if(mandatoryBull && bullTrue >= 6 && bullTrue > bearTrue)
     {
      r.isActiveBias = true;
      r.type = BIAS_BUY;
      r.percent = bullTrue * 10.0; // 6 -> 60%
      return r;
     }

   // Kiểm tra SELL
   if(mandatoryBear && bearTrue >= 6 && bearTrue > bullTrue)
     {
      r.isActiveBias = true;
      r.type = BIAS_SELL;
      r.percent = bearTrue * 10.0;
      return r;
     }

   // Nếu không phe nào đạt đủ
   return r;
}

//------------------------------------------------------------------
// ========== CÁC HÀM ĐIỀU KIỆN (giữ nguyên logic gốc) ==============
//------------------------------------------------------------------

// 1A. BodyBull – tăng mạnh, thân ≥70%
bool BodyBull(){
   double o=iOpen(_Symbol,PERIOD_D1,1), c=iClose(_Symbol,PERIOD_D1,1),
          h=iHigh(_Symbol,PERIOD_D1,1),  l=iLow (_Symbol,PERIOD_D1,1);
   double range=h-l; if(range<=0) return false;
   double body=MathAbs(c-o);
   return (c>o) && (body/range>=0.7);
}

// 1B. BodyBear – giảm mạnh, thân ≥60%
bool BodyBear(){
   double o=iOpen(_Symbol,PERIOD_D1,1), c=iClose(_Symbol,PERIOD_D1,1),
          h=iHigh(_Symbol,PERIOD_D1,1),  l=iLow (_Symbol,PERIOD_D1,1);
   double range=h-l; if(range<=0) return false;
   double body=MathAbs(c-o);
   return (c<o) && (body/range>=0.6);
}

// 2A. WickBull – râu trên ngắn
bool WickBull(){
   double o=iOpen(_Symbol,PERIOD_D1,1), c=iClose(_Symbol,PERIOD_D1,1),
          h=iHigh(_Symbol,PERIOD_D1,1),  l=iLow (_Symbol,PERIOD_D1,1);
   if(h<=l) return false;
   double upper=h-MathMax(c,o), range=h-l;
   return (c>o) && (upper/range<=0.3);
}

// 2B. WickBear – râu dưới ngắn
bool WickBear(){
   double o=iOpen(_Symbol,PERIOD_D1,1), c=iClose(_Symbol,PERIOD_D1,1),
          h=iHigh(_Symbol,PERIOD_D1,1),  l=iLow (_Symbol,PERIOD_D1,1);
   if(h<=l) return false;
   double lower=MathMin(c,o)-l, range=h-l;
   return (c<o) && (lower/range<=0.3);
}

// 3A. VolumeBull – vol >120% avg5
bool VolumeBull(){
   double v1=iVolume(_Symbol,PERIOD_D1,1); if(v1<=0) return false;
   double sum=0; int cnt=0;
   for(int s=2;s<=6;s++){ double v=iVolume(_Symbol,PERIOD_D1,s); if(v>0){sum+=v;cnt++;}}
   double avg=(cnt>0)?sum/cnt:v1;
   return v1>1.2*avg;
}

// 3B. VolumeBear – vol >120% avg5 & nến giảm
bool VolumeBear(){
   double v1=iVolume(_Symbol,PERIOD_D1,1); if(v1<=0) return false;
   double o=iOpen(_Symbol,PERIOD_D1,1), c=iClose(_Symbol,PERIOD_D1,1);
   if(c>=o) return false;
   double sum=0; int cnt=0;
   for(int s=2;s<=6;s++){ double v=iVolume(_Symbol,PERIOD_D1,s); if(v>0){sum+=v;cnt++;}}
   double avg=(cnt>0)?sum/cnt:v1;
   return v1>1.2*avg;
}

// 4A/4B. RSI
bool RSIBull(){ return iRSI(_Symbol,PERIOD_D1,14,PRICE_CLOSE,1) > 55.0; }
bool RSIBear(){ return iRSI(_Symbol,PERIOD_D1,14,PRICE_CLOSE,1) < 45.0; }

// 5A/5B. MACD
bool MACDBull(){
   double m=iMACD(_Symbol,PERIOD_D1,12,26,9,PRICE_CLOSE,MODE_MAIN,1),
          s=iMACD(_Symbol,PERIOD_D1,12,26,9,PRICE_CLOSE,MODE_SIGNAL,1);
   return m>s;
}
bool MACDBear(){
   double m=iMACD(_Symbol,PERIOD_D1,12,26,9,PRICE_CLOSE,MODE_MAIN,1),
          s=iMACD(_Symbol,PERIOD_D1,12,26,9,PRICE_CLOSE,MODE_SIGNAL,1);
   return m<s;
}

// 6A/6B. MA50
bool MA50Bull(){ return iClose(_Symbol,PERIOD_D1,1) > iMA(_Symbol,PERIOD_D1,50,0,MODE_SMA,PRICE_CLOSE,1); }
bool MA50Bear(){ return iClose(_Symbol,PERIOD_D1,1) < iMA(_Symbol,PERIOD_D1,50,0,MODE_SMA,PRICE_CLOSE,1); }

// 7A/7B. Pivot breakout
bool PivotBreakoutBull(){
   double h=iHigh(_Symbol,PERIOD_D1,1), l=iLow(_Symbol,PERIOD_D1,1), c=iClose(_Symbol,PERIOD_D1,1);
   double PP=(h+l+c)/3.0, R1=2*PP-l;
   return SymbolInfoDouble(_Symbol,SYMBOL_BID) > R1;
}
bool PivotBreakoutBear(){
   double h=iHigh(_Symbol,PERIOD_D1,1), l=iLow(_Symbol,PERIOD_D1,1), c=iClose(_Symbol,PERIOD_D1,1);
   double PP=(h+l+c)/3.0, S1=2*PP-h;
   return SymbolInfoDouble(_Symbol,SYMBOL_BID) < S1;
}

// 8A/8B. Pullback Fibonacci
bool PullbackFibBull(){
   double o=iOpen(_Symbol,PERIOD_D1,1), c=iClose(_Symbol,PERIOD_D1,1),
          h=iHigh(_Symbol,PERIOD_D1,1), l=iLow(_Symbol,PERIOD_D1,1);
   if(c<=o) return false;
   double range=h-l; if(range<=0) return false;
   double f38=l+0.382*range, f62=l+0.618*range;
   double p=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   return p>=f38 && p<=f62;
}
bool PullbackFibBear(){
   double o=iOpen(_Symbol,PERIOD_D1,1), c=iClose(_Symbol,PERIOD_D1,1),
          h=iHigh(_Symbol,PERIOD_D1,1), l=iLow(_Symbol,PERIOD_D1,1);
   if(c>=o) return false;
   double range=h-l; if(range<=0) return false;
   double f38=h-0.382*range, f62=h-0.618*range;
   double p=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   return p<=f38 && p>=f62;
}

// 9A/9B. Trend Expansion with ATR & ADX
bool TrendExpansionBull(){
   double atr=iATR(_Symbol,PERIOD_D1,14,1), h=iHigh(_Symbol,PERIOD_D1,1), l=iLow(_Symbol,PERIOD_D1,1);
   double range=h-l; if(!(atr>0 && range>1.2*atr && range<2.5*atr)) return false;
   double adx=iADX(_Symbol,PERIOD_D1,14,PRICE_CLOSE,MODE_MAIN,1),
          dpi=iADX(_Symbol,PERIOD_D1,14,PRICE_CLOSE,MODE_PLUSDI,1),
          dmi=iADX(_Symbol,PERIOD_D1,14,PRICE_CLOSE,MODE_MINUSDI,1);
   return (adx>=25.0) && (dpi>dmi);
}
bool TrendExpansionBear(){
   double atr=iATR(_Symbol,PERIOD_D1,14,1), h=iHigh(_Symbol,PERIOD_D1,1), l=iLow(_Symbol,PERIOD_D1,1);
   double range=h-l; if(!(atr>0 && range>1.2*atr && range<2.5*atr)) return false;
   double adx=iADX(_Symbol,PERIOD_D1,14,PRICE_CLOSE,MODE_MAIN,1),
          dpi=iADX(_Symbol,PERIOD_D1,14,PRICE_CLOSE,MODE_PLUSDI,1),
          dmi=iADX(_Symbol,PERIOD_D1,14,PRICE_CLOSE,MODE_MINUSDI,1);
   return (adx>=25.0) && (dmi>dpi);
}

// 10A/10B. NotExhaustion
bool NotExhaustionBull(){
   double o=iOpen(_Symbol,PERIOD_D1,1), c=iClose(_Symbol,PERIOD_D1,1),
          h=iHigh(_Symbol,PERIOD_D1,1), l=iLow(_Symbol,PERIOD_D1,1);
   double range=h-l; if(range<=0) return false;
   double body=MathAbs(c-o), upper=h-MathMax(c,o);
   return !(body/range<0.3 && upper/range>0.6);
}
bool NotExhaustionBear(){
   double o=iOpen(_Symbol,PERIOD_D1,1), c=iClose(_Symbol,PERIOD_D1,1),
          h=iHigh(_Symbol,PERIOD_D1,1), l=iLow(_Symbol,PERIOD_D1,1);
   double range=h-l; if(range<=0) return false;
   double body=MathAbs(c-o), lower=MathMin(c,o)-l;
   return !(body/range<0.3 && lower/range>0.6);
}

#endif // __DAILY_BIAS_CONDITIONS_MQH__