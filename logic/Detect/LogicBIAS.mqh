#ifndef __BIAS_LOGIC_MQH__
#define __BIAS_LOGIC_MQH__
#property strict
#include <Trade/SymbolInfo.mqh>

#define  EVAL_SHIFT   1      // luôn dùng nến đã đóng (index 1)

//=== Cấu hình chỉ báo (chu kỳ) ===
#ifndef INVALID_HANDLE
   #define INVALID_HANDLE -1
#endif
#define RSI_PERIOD    14
#define MACD_FAST     12
#define MACD_SLOW     26
#define MACD_SIGNAL   9
#define MA_PERIOD     50
#define ATR_PERIOD    14
#define ADX_PERIOD    14

// Cấu trúc lưu các handle indicator cho các khung thời gian
struct BiasIndicatorHandles {
  int rsi;
  int macd;
  int ma50;
  int atr;
  int adx;
};
static BiasIndicatorHandles biasHandles[3] = {
  { INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE },
  { INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE },
  { INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE }
};
static ENUM_TIMEFRAMES biasTimeframes[3] = { PERIOD_H1, PERIOD_H4, PERIOD_D1 };

// Hàm trả về index ứng với khung thời gian (0 -> H1, 1 -> H4, 2 -> D1)
inline int GetBiasIndex(ENUM_TIMEFRAMES tf) {
  switch(tf) {
    case PERIOD_H1: return 0;
    case PERIOD_H4: return 1;
    case PERIOD_D1: return 2;
  }
  return -1;
}

// Khởi tạo các indicator cho một symbol trên các khung thời gian (gọi ở OnInit)
void InitializeBiasIndicators(const string &symbol) {
  for(int i = 0; i < 3; i++) {
    ENUM_TIMEFRAMES tf = biasTimeframes[i];
    if(biasHandles[i].rsi != INVALID_HANDLE) IndicatorRelease(biasHandles[i].rsi);
    biasHandles[i].rsi = iRSI(symbol, tf, RSI_PERIOD, PRICE_CLOSE);
    if(biasHandles[i].macd != INVALID_HANDLE) IndicatorRelease(biasHandles[i].macd);
    biasHandles[i].macd = iMACD(symbol, tf, MACD_FAST, MACD_SLOW, MACD_SIGNAL, PRICE_CLOSE);
    if(biasHandles[i].ma50 != INVALID_HANDLE) IndicatorRelease(biasHandles[i].ma50);
    biasHandles[i].ma50 = iMA(symbol, tf, MA_PERIOD, 0, MODE_SMA, PRICE_CLOSE);
    if(biasHandles[i].atr != INVALID_HANDLE) IndicatorRelease(biasHandles[i].atr);
    biasHandles[i].atr = iATR(symbol, tf, ATR_PERIOD);
    if(biasHandles[i].adx != INVALID_HANDLE) IndicatorRelease(biasHandles[i].adx);
    biasHandles[i].adx = iADX(symbol, tf, ADX_PERIOD);
  }
}

// Giải phóng các indicator (gọi ở OnDeinit để tránh rò rỉ bộ nhớ)
void ReleaseBiasIndicators() {
  for(int i = 0; i < 3; i++) {
    if(biasHandles[i].rsi != INVALID_HANDLE) { IndicatorRelease(biasHandles[i].rsi); biasHandles[i].rsi = INVALID_HANDLE; }
    if(biasHandles[i].macd != INVALID_HANDLE) { IndicatorRelease(biasHandles[i].macd); biasHandles[i].macd = INVALID_HANDLE; }
    if(biasHandles[i].ma50 != INVALID_HANDLE) { IndicatorRelease(biasHandles[i].ma50); biasHandles[i].ma50 = INVALID_HANDLE; }
    if(biasHandles[i].atr != INVALID_HANDLE) { IndicatorRelease(biasHandles[i].atr); biasHandles[i].atr = INVALID_HANDLE; }
    if(biasHandles[i].adx != INVALID_HANDLE) { IndicatorRelease(biasHandles[i].adx); biasHandles[i].adx = INVALID_HANDLE; }
  }
}

//==================== CONDITION FUNCTIONS ====================

// 1. Body ───────────────────────────────────────────────────
bool BodyCond(const string &symbol, ENUM_TIMEFRAMES tf, bool bullish) {
  double o = iOpen(symbol, tf, EVAL_SHIFT);
  double c = iClose(symbol, tf, EVAL_SHIFT);
  double h = iHigh(symbol, tf, EVAL_SHIFT);
  double l = iLow(symbol, tf, EVAL_SHIFT);
  double range = h - l; if(range <= 0) return false;
  double body = MathAbs(c - o);
  return (bullish ? (c > o) : (c < o)) && (body / range >= 0.45);
}
inline bool BodyBull(const string &symbol, ENUM_TIMEFRAMES tf){ return BodyCond(symbol, tf, true); }
inline bool BodyBear(const string &symbol, ENUM_TIMEFRAMES tf){ return BodyCond(symbol, tf, false); }

// 2. Wick ───────────────────────────────────────────────────
bool WickBull(const string &symbol, ENUM_TIMEFRAMES tf) {
  double o = iOpen(symbol, tf, EVAL_SHIFT);
  double c = iClose(symbol, tf, EVAL_SHIFT);
  double h = iHigh(symbol, tf, EVAL_SHIFT);
  double l = iLow(symbol, tf, EVAL_SHIFT);
  if(h <= l) return false;
  double upper = h - MathMax(c, o);
  return (c > o) && (upper / (h - l) <= 0.4);
}
bool WickBear(const string &symbol, ENUM_TIMEFRAMES tf) {
  double o = iOpen(symbol, tf, EVAL_SHIFT);
  double c = iClose(symbol, tf, EVAL_SHIFT);
  double h = iHigh(symbol, tf, EVAL_SHIFT);
  double l = iLow(symbol, tf, EVAL_SHIFT);
  if(h <= l) return false;
  double lower = MathMin(c, o) - l;
  return (c < o) && (lower / (h - l) <= 0.45);
}

// 3. Volume ─────────────────────────────────────────────────
bool VolumeBull(const string &symbol, ENUM_TIMEFRAMES tf) {
  long v1 = iVolume(symbol, tf, EVAL_SHIFT);
  if(v1 <= 0) return false;
  long sum = 0; int cnt = 0;
  for(int s = EVAL_SHIFT + 1; s <= EVAL_SHIFT + 5; s++) {
    long v = iVolume(symbol, tf, s);
    if(v > 0) { sum += v; cnt++; }
  }
  long avg = (cnt > 0 ? sum / cnt : v1);
  return v1 > 1.1 * avg;
}
bool VolumeBear(const string &symbol, ENUM_TIMEFRAMES tf) {
  long v1 = iVolume(symbol, tf, EVAL_SHIFT);
  if(v1 <= 0) return false;
  double o = iOpen(symbol, tf, EVAL_SHIFT);
  double c = iClose(symbol, tf, EVAL_SHIFT);
  if(c >= o) return false;
  long sum = 0; int cnt = 0;
  for(int s = EVAL_SHIFT + 1; s <= EVAL_SHIFT + 5; s++) {
    long v = iVolume(symbol, tf, s);
    if(v > 0) { sum += v; cnt++; }
  }
  long avg = (cnt > 0 ? sum / cnt : v1);
  return v1 > 1.1 * avg;
}

// 4. RSI ────────────────────────────────────────────────────
bool RSIBull(const string &symbol, ENUM_TIMEFRAMES tf) {
  int idx = GetBiasIndex(tf);
  if(idx < 0) return false;
  double buf[1];
  if(CopyBuffer(biasHandles[idx].rsi, 0, EVAL_SHIFT, 1, buf) != 1) return false;
  return buf[0] > 52.0;
}
bool RSIBear(const string &symbol, ENUM_TIMEFRAMES tf) {
  int idx = GetBiasIndex(tf);
  if(idx < 0) return false;
  double buf[1];
  if(CopyBuffer(biasHandles[idx].rsi, 0, EVAL_SHIFT, 1, buf) != 1) return false;
  return buf[0] < 48.0;
}

// 5. MACD ───────────────────────────────────────────────────
bool MACDBull(const string &symbol, ENUM_TIMEFRAMES tf) {
  int idx = GetBiasIndex(tf);
  if(idx < 0) return false;
  double m[1], s[1];
  if(CopyBuffer(biasHandles[idx].macd, 0, EVAL_SHIFT, 1, m) != 1 ||
     CopyBuffer(biasHandles[idx].macd, 1, EVAL_SHIFT, 1, s) != 1) return false;
  return m[0] > s[0];
}
bool MACDBear(const string &symbol, ENUM_TIMEFRAMES tf) {
  int idx = GetBiasIndex(tf);
  if(idx < 0) return false;
  double m[1], s[1];
  if(CopyBuffer(biasHandles[idx].macd, 0, EVAL_SHIFT, 1, m) != 1 ||
     CopyBuffer(biasHandles[idx].macd, 1, EVAL_SHIFT, 1, s) != 1) return false;
  return m[0] < s[0];
}

// 6. MA50 ───────────────────────────────────────────────────
bool MA50Bull(const string &symbol, ENUM_TIMEFRAMES tf) {
  int idx = GetBiasIndex(tf);
  if(idx < 0) return false;
  double buf[1];
  if(CopyBuffer(biasHandles[idx].ma50, 0, EVAL_SHIFT, 1, buf) != 1) return false;
  return iClose(symbol, tf, EVAL_SHIFT) > buf[0];
}
bool MA50Bear(const string &symbol, ENUM_TIMEFRAMES tf) {
  int idx = GetBiasIndex(tf);
  if(idx < 0) return false;
  double buf[1];
  if(CopyBuffer(biasHandles[idx].ma50, 0, EVAL_SHIFT, 1, buf) != 1) return false;
  return iClose(symbol, tf, EVAL_SHIFT) < buf[0];
}

// 7. Pivot Breakout ──────────────────────────────────────────
bool PivotBreakoutBull(const string &symbol, ENUM_TIMEFRAMES tf) {
  double h = iHigh(symbol, tf, EVAL_SHIFT);
  double l = iLow(symbol, tf, EVAL_SHIFT);
  double c = iClose(symbol, tf, EVAL_SHIFT);
  double PP = (h + l + c) / 3.0;
  double R1 = 2 * PP - l;
  return SymbolInfoDouble(symbol, SYMBOL_BID) > R1;
}
bool PivotBreakoutBear(const string &symbol, ENUM_TIMEFRAMES tf) {
  double h = iHigh(symbol, tf, EVAL_SHIFT);
  double l = iLow(symbol, tf, EVAL_SHIFT);
  double c = iClose(symbol, tf, EVAL_SHIFT);
  double PP = (h + l + c) / 3.0;
  double S1 = 2 * PP - h;
  return SymbolInfoDouble(symbol, SYMBOL_BID) < S1;
}

// 8. Pullback Fibonacci ─────────────────────────────────────
bool PullbackFibBull(const string &symbol, ENUM_TIMEFRAMES tf) {
  double o = iOpen(symbol, tf, EVAL_SHIFT);
  double c = iClose(symbol, tf, EVAL_SHIFT);
  double h = iHigh(symbol, tf, EVAL_SHIFT);
  double l = iLow(symbol, tf, EVAL_SHIFT);
  if(c <= o) return false;
  double range = h - l; if(range <= 0) return false;
  double f236 = l + 0.236 * range;
  double f62  = l + 0.618 * range;
  double p = SymbolInfoDouble(symbol, SYMBOL_BID);
  return (p >= f236 && p <= f62);
}
bool PullbackFibBear(const string &symbol, ENUM_TIMEFRAMES tf) {
  double o = iOpen(symbol, tf, EVAL_SHIFT);
  double c = iClose(symbol, tf, EVAL_SHIFT);
  double h = iHigh(symbol, tf, EVAL_SHIFT);
  double l = iLow(symbol, tf, EVAL_SHIFT);
  if(c >= o) return false;
  double range = h - l; if(range <= 0) return false;
  double f236 = h - 0.236 * range;
  double f62  = h - 0.618 * range;
  double p = SymbolInfoDouble(symbol, SYMBOL_BID);
  return (p <= f236 && p >= f62);
}

// 9. Trend Expansion ─────────────────────────────────────────
bool TrendExpansionBull(const string &symbol, ENUM_TIMEFRAMES tf) {
  int idx = GetBiasIndex(tf);
  if(idx < 0) return false;
  double atr_buf[1];
  if(CopyBuffer(biasHandles[idx].atr, 0, EVAL_SHIFT, 1, atr_buf) != 1) return false;
  double atr = atr_buf[0];
  double adx_buf[1], plus_buf[1], minus_buf[1];
  if(CopyBuffer(biasHandles[idx].adx, 0, EVAL_SHIFT, 1, adx_buf) != 1 ||
     CopyBuffer(biasHandles[idx].adx, 1, EVAL_SHIFT, 1, plus_buf) != 1 ||
     CopyBuffer(biasHandles[idx].adx, 2, EVAL_SHIFT, 1, minus_buf) != 1) return false;
  double h = iHigh(symbol, tf, EVAL_SHIFT);
  double l = iLow(symbol, tf, EVAL_SHIFT);
  double range = h - l;
  if(!(atr > 0 && range >= 1.0 * atr && range < 2.5 * atr)) return false;
  return (adx_buf[0] >= 20.0) && (plus_buf[0] > minus_buf[0]);
}
bool TrendExpansionBear(const string &symbol, ENUM_TIMEFRAMES tf) {
  int idx = GetBiasIndex(tf);
  if(idx < 0) return false;
  double atr_buf[1];
  if(CopyBuffer(biasHandles[idx].atr, 0, EVAL_SHIFT, 1, atr_buf) != 1) return false;
  double atr = atr_buf[0];
  double adx_buf[1], plus_buf[1], minus_buf[1];
  if(CopyBuffer(biasHandles[idx].adx, 0, EVAL_SHIFT, 1, adx_buf) != 1 ||
     CopyBuffer(biasHandles[idx].adx, 1, EVAL_SHIFT, 1, plus_buf) != 1 ||
     CopyBuffer(biasHandles[idx].adx, 2, EVAL_SHIFT, 1, minus_buf) != 1) return false;
  double h = iHigh(symbol, tf, EVAL_SHIFT);
  double l = iLow(symbol, tf, EVAL_SHIFT);
  double range = h - l;
  if(!(atr > 0 && range >= 1.0 * atr && range < 2.5 * atr)) return false;
  return (adx_buf[0] >= 20.0) && (minus_buf[0] > plus_buf[0]);
}

// 10. Not Exhaustion ─────────────────────────────────────────
bool NotExhaustionBull(const string &symbol, ENUM_TIMEFRAMES tf) {
  double o = iOpen(symbol, tf, EVAL_SHIFT);
  double c = iClose(symbol, tf, EVAL_SHIFT);
  double h = iHigh(symbol, tf, EVAL_SHIFT);
  double l = iLow(symbol, tf, EVAL_SHIFT);
  double range = h - l; if(range <= 0) return false;
  double body = MathAbs(c - o);
  double upper = h - MathMax(c, o);
  return !(body / range < 0.3 && upper / range > 0.6);
}
bool NotExhaustionBear(const string &symbol, ENUM_TIMEFRAMES tf) {
  double o = iOpen(symbol, tf, EVAL_SHIFT);
  double c = iClose(symbol, tf, EVAL_SHIFT);
  double h = iHigh(symbol, tf, EVAL_SHIFT);
  double l = iLow(symbol, tf, EVAL_SHIFT);
  double range = h - l; if(range <= 0) return false;
  double body = MathAbs(c - o);
  double lower = MathMin(c, o) - l;
  return !(body / range < 0.3 && lower / range > 0.6);
}

#endif // __BIAS_LOGIC_MQH__
