#ifndef __CANDLE_PATTERN_MQH__
#define __CANDLE_PATTERN_MQH__
#property strict

// ======================= CONFIG TUNING ============================
#define TF_DEFAULT     PERIOD_D1
#define ATR_PERIOD     14
#define DOJI_BODY_MAX          0.10
#define MARUBOZU_BODY_MIN      0.90
#define PIN_TAIL_MIN_FACTOR    2.0
#define PIN_CLOSE_ZONE         0.25
#define ENGULF_BODY_TOL        0.0
#define HARAMI_BODY_RATIO_MAX  0.60
#define SMALL_WICK_RATIO_MAX   0.15
#define INSIDE_EPS             0.0
#define OUTSIDE_EPS            0.0

// ======================= DATA STRUCTS =============================
struct CandleData {
  double o,h,l,c,range,body,upper,lower,body_ratio,upper_ratio,lower_ratio,mid;
  bool   bull, bear;
};
struct PatternScore {
  int     id;           // enum CandlePattern
  double  score;        // 0..100
  string  name;         // tên mẫu nến
  string  bias;         // "BUY" | "SELL" | "NONE"
  int     candlesUsed;  // số nến sử dụng (1..5)
};

// ======================= PATTERN ENUM =============================
enum CandlePattern {
  PATTERN_NONE = 0,
  // Single-candle
  PATTERN_DOJI,
  PATTERN_MARUBOZU_BULL,
  PATTERN_MARUBOZU_BEAR,
  PATTERN_SPINNING_TOP,
  PATTERN_PIN_BULL,
  PATTERN_PIN_BEAR,
  PATTERN_LONG_BULL,
  PATTERN_LONG_BEAR,
  // 2-candle
  PATTERN_ENGULFING_BULL,
  PATTERN_ENGULFING_BEAR,
  PATTERN_HARAMI_BULL,
  PATTERN_HARAMI_BEAR,
  PATTERN_INSIDE_BAR,
  PATTERN_OUTSIDE_BAR_BULL,
  PATTERN_OUTSIDE_BAR_BEAR,
  // 3+ candles
  PATTERN_3_WHITE_SOLDIERS,
  PATTERN_3_BLACK_CROWS,
  PATTERN_RISING_3_METHODS,
  PATTERN_FALLING_3_METHODS
};

// ======================= SMALL HELPERS ============================
double _Clamp(double x,double lo,double hi){ return MathMax(lo, MathMin(hi,x)); }

bool _GetCandle(const string sym, ENUM_TIMEFRAMES tf, int shift, CandleData &cd) {
  cd.o = iOpen(sym, tf, shift);
  cd.h = iHigh(sym, tf, shift);
  cd.l = iLow(sym, tf, shift);
  cd.c = iClose(sym, tf, shift);
  if(cd.h == 0 || cd.l == 0) return false;
  cd.range = cd.h - cd.l;
  if(cd.range <= 0) return false;
  cd.body  = MathAbs(cd.c - cd.o);
  cd.upper = cd.h - MathMax(cd.c, cd.o);
  cd.lower = MathMin(cd.c, cd.o) - cd.l;
  cd.body_ratio  = cd.body / cd.range;
  cd.upper_ratio = cd.upper / cd.range;
  cd.lower_ratio = cd.lower / cd.range;
  cd.mid   = (cd.h + cd.l) * 0.5;
  cd.bull  = (cd.c > cd.o);
  cd.bear  = (cd.c < cd.o);
  return true;
}

double _ATR(const string sym, ENUM_TIMEFRAMES tf, int period, int shift_base) {
  int bars = iBars(sym, tf);
  if(bars < shift_base + period + 5) return 0.0;
  int need = period;
  double sumTR = 0.0;
  double prevClose = iClose(sym, tf, shift_base+period);
  if(prevClose == 0) return 0.0;
  for(int i = shift_base+period-1; i >= shift_base; --i) {
    double hi = iHigh(sym, tf, i);
    double lo = iLow(sym, tf, i);
    double tr1 = hi - lo;
    double tr2 = MathAbs(hi - prevClose);
    double tr3 = MathAbs(lo - prevClose);
    double tr  = MathMax(tr1, MathMax(tr2, tr3));
    sumTR += tr;
    prevClose = iClose(sym, tf, i);
  }
  return (need > 0 ? sumTR/need : 0.0);
}

// ============== SHAPE HELPERS (0..1) ==============================
double _DojiShape(const CandleData &c) {
  return (c.body_ratio <= DOJI_BODY_MAX ? 1.0 - (c.body_ratio/DOJI_BODY_MAX) : 0.0);
}
double _MarubozuShape(const CandleData &c) {
  if(c.body_ratio < MARUBOZU_BODY_MIN) return 0.0;
  double wick_penalty = (c.upper_ratio + c.lower_ratio);
  wick_penalty = _Clamp(1.0 - 3.0*wick_penalty, 0.0, 1.0);
  return _Clamp((c.body_ratio - MARUBOZU_BODY_MIN) / (1.0 - MARUBOZU_BODY_MIN), 0.0, 1.0) * 0.7
       + wick_penalty * 0.3;
}
double _PinBullShape(const CandleData &c) {
  if(c.body == 0.0) return 0.0;
  bool tail_ok = (c.lower >= PIN_TAIL_MIN_FACTOR * c.body);
  bool close_top = ((c.h - c.c) <= PIN_CLOSE_ZONE * c.range);
  bool small_upper = (c.upper_ratio <= 0.25);
  if(!(tail_ok && close_top && small_upper)) return 0.0;
  double tail_factor = _Clamp((c.lower / (PIN_TAIL_MIN_FACTOR * c.body)) - 1.0, 0.0, 1.0);
  return 0.6 + 0.4*tail_factor;
}
double _PinBearShape(const CandleData &c) {
  if(c.body == 0.0) return 0.0;
  bool tail_ok = (c.upper >= PIN_TAIL_MIN_FACTOR * c.body);
  bool close_low = ((c.c - c.l) <= PIN_CLOSE_ZONE * c.range);
  bool small_lower = (c.lower_ratio <= 0.25);
  if(!(tail_ok && close_low && small_lower)) return 0.0;
  double tail_factor = _Clamp((c.upper / (PIN_TAIL_MIN_FACTOR * c.body)) - 1.0, 0.0, 1.0);
  return 0.6 + 0.4*tail_factor;
}
double _InsideShape(const CandleData &c1, const CandleData &c2) {
  if(!(c1.h <= c2.h+INSIDE_EPS && c1.l >= c2.l-INSIDE_EPS)) return 0.0;
  double compress = (c1.range / c2.range);
  return _Clamp(1.0 - compress, 0.0, 1.0);
}
double _OutsideShape(const CandleData &c1, const CandleData &c2) {
  if(!(c1.h >= c2.h-OUTSIDE_EPS && c1.l <= c2.l+OUTSIDE_EPS)) return 0.0;
  double expand = (c1.range / c2.range);
  return _Clamp((expand - 1.0), 0.0, 1.0);
}
double _EngulfBodyBull(const CandleData &c1, const CandleData &c2) {
  if(!(c2.bear && c1.bull)) return 0.0;
  double lo1 = MathMin(c1.o,c1.c), hi1 = MathMax(c1.o,c1.c);
  double lo2 = MathMin(c2.o,c2.c), hi2 = MathMax(c2.o,c2.c);
  if(!(lo1 <= lo2+ENGULF_BODY_TOL && hi1 >= hi2-ENGULF_BODY_TOL)) return 0.0;
  double over = _Clamp((c1.c - hi2)/c2.range, 0.0, 1.0);
  return 0.6 + 0.4*over;
}
double _EngulfBodyBear(const CandleData &c1, const CandleData &c2) {
  if(!(c2.bull && c1.bear)) return 0.0;
  double lo1 = MathMin(c1.o,c1.c), hi1 = MathMax(c1.o,c1.c);
  double lo2 = MathMin(c2.o,c2.c), hi2 = MathMax(c2.o,c2.c);
  if(!(lo1 <= lo2+ENGULF_BODY_TOL && hi1 >= hi2-ENGULF_BODY_TOL)) return 0.0;
  double over = _Clamp((lo2 - c1.c)/c2.range, 0.0, 1.0);
  return 0.6 + 0.4*over;
}
double _HaramiBull(const CandleData &c1, const CandleData &c2) {
  if(!(c1.bull && c2.bear)) return 0.0;
  double lo1=MathMin(c1.o,c1.c), hi1=MathMax(c1.o,c1.c);
  double lo2=MathMin(c2.o,c2.c), hi2=MathMax(c2.o,c2.c);
  if(!(lo1 >= lo2 && hi1 <= hi2)) return 0.0;
  if(!(c1.body <= HARAMI_BODY_RATIO_MAX * c2.body)) return 0.0;
  double tight = 1.0 - (c1.body / (HARAMI_BODY_RATIO_MAX*c2.body));
  return _Clamp(0.6 + 0.4*tight, 0.0, 1.0);
}
double _HaramiBear(const CandleData &c1, const CandleData &c2) {
  if(!(c1.bear && c2.bull)) return 0.0;
  double lo1=MathMin(c1.o,c1.c), hi1=MathMax(c1.o,c1.c);
  double lo2=MathMin(c2.o,c2.c), hi2=MathMax(c2.o,c2.c);
  if(!(lo1 >= lo2 && hi1 <= hi2)) return 0.0;
  if(!(c1.body <= HARAMI_BODY_RATIO_MAX * c2.body)) return 0.0;
  double tight = 1.0 - (c1.body / (HARAMI_BODY_RATIO_MAX*c2.body));
  return _Clamp(0.6 + 0.4*tight, 0.0, 1.0);
}
double _RangeVsATR(const CandleData &c, double atr) {
  if(atr <= 0) return 0.5;
  double r = c.range/atr;
  double s = (r - 0.7) / (1.3 - 0.7);
  return _Clamp(0.3 + 0.6*s, 0.2, 1.0);
}

string PatternName(int id) {
  switch(id) {
    case PATTERN_DOJI:                return "Doji";
    case PATTERN_MARUBOZU_BULL:       return "Marubozu Bull";
    case PATTERN_MARUBOZU_BEAR:       return "Marubozu Bear";
    case PATTERN_SPINNING_TOP:        return "Spinning Top";
    case PATTERN_PIN_BULL:            return "Pin Bar Bull (Hammer)";
    case PATTERN_PIN_BEAR:            return "Pin Bar Bear (Shooting Star)";
    case PATTERN_LONG_BULL:           return "Long Candle Bull";
    case PATTERN_LONG_BEAR:           return "Long Candle Bear";
    case PATTERN_ENGULFING_BULL:      return "Bullish Engulfing";
    case PATTERN_ENGULFING_BEAR:      return "Bearish Engulfing";
    case PATTERN_HARAMI_BULL:         return "Bullish Harami";
    case PATTERN_HARAMI_BEAR:         return "Bearish Harami";
    case PATTERN_INSIDE_BAR:          return "Inside Bar";
    case PATTERN_OUTSIDE_BAR_BULL:    return "Outside Bar Bull";
    case PATTERN_OUTSIDE_BAR_BEAR:    return "Outside Bar Bear";
    case PATTERN_3_WHITE_SOLDIERS:    return "Three White Soldiers";
    case PATTERN_3_BLACK_CROWS:       return "Three Black Crows";
    case PATTERN_RISING_3_METHODS:    return "Rising Three Methods";
    case PATTERN_FALLING_3_METHODS:   return "Falling Three Methods";
    default: return "None";
  }
}

// ======================= 3/5-CANDLE DETECTORS =====================
bool _ThreeWhiteSoldiers(const string sym, ENUM_TIMEFRAMES tf, int shift_base, double &shapeScore) {
  CandleData c3,c2,c1;
  if(!_GetCandle(sym,tf,shift_base+2,c3) || !_GetCandle(sym,tf,shift_base+1,c2) || !_GetCandle(sym,tf,shift_base,c1)) return false;
  bool ok = c3.bull && c2.bull && c1.bull
         && (c3.upper_ratio <= SMALL_WICK_RATIO_MAX && c3.lower_ratio <= SMALL_WICK_RATIO_MAX)
         && (c2.upper_ratio <= SMALL_WICK_RATIO_MAX && c2.lower_ratio <= SMALL_WICK_RATIO_MAX)
         && (c1.upper_ratio <= SMALL_WICK_RATIO_MAX && c1.lower_ratio <= SMALL_WICK_RATIO_MAX)
         && (c2.o >= MathMin(c3.o,c3.c) && c2.o <= MathMax(c3.o,c3.c))
         && (c1.o >= MathMin(c2.o,c2.c) && c1.o <= MathMax(c2.o,c2.c))
         && (c2.c > c3.c) && (c1.c > c2.c);
  if(!ok) return false;
  shapeScore = 0.8 + 0.2*_Clamp((c1.body_ratio+c2.body_ratio+c3.body_ratio)/3.0,0.0,1.0);
  return true;
}
bool _ThreeBlackCrows(const string sym, ENUM_TIMEFRAMES tf, int shift_base, double &shapeScore) {
  CandleData c3,c2,c1;
  if(!_GetCandle(sym,tf,shift_base+2,c3) || !_GetCandle(sym,tf,shift_base+1,c2) || !_GetCandle(sym,tf,shift_base,c1)) return false;
  bool ok = c3.bear && c2.bear && c1.bear
         && (c3.upper_ratio <= SMALL_WICK_RATIO_MAX && c3.lower_ratio <= SMALL_WICK_RATIO_MAX)
         && (c2.upper_ratio <= SMALL_WICK_RATIO_MAX && c2.lower_ratio <= SMALL_WICK_RATIO_MAX)
         && (c1.upper_ratio <= SMALL_WICK_RATIO_MAX && c1.lower_ratio <= SMALL_WICK_RATIO_MAX)
         && (c2.o >= MathMin(c3.o,c3.c) && c2.o <= MathMax(c3.o,c3.c))
         && (c1.o >= MathMin(c2.o,c2.c) && c1.o <= MathMax(c2.o,c2.c))
         && (c2.c < c3.c) && (c1.c < c2.c);
  if(!ok) return false;
  shapeScore = 0.8 + 0.2*_Clamp((c1.body_ratio+c2.body_ratio+c3.body_ratio)/3.0,0.0,1.0);
  return true;
}
bool _RisingThreeMethods(const string sym, ENUM_TIMEFRAMES tf, int shift_base, double &shapeScore) {
  CandleData c5,c4,c3,c2,c1;
  if(!_GetCandle(sym,tf,shift_base+4,c5) || !_GetCandle(sym,tf,shift_base+3,c4) ||
     !_GetCandle(sym,tf,shift_base+2,c3) || !_GetCandle(sym,tf,shift_base+1,c2) ||
     !_GetCandle(sym,tf,shift_base,c1)) return false;
  bool small_inside = (c4.h <= c5.h && c4.l >= c5.l) &&
                      (c3.h <= c5.h && c3.l >= c5.l) &&
                      (c2.h <= c5.h && c2.l >= c5.l);
  int bears = (int)c4.bear + (int)c3.bear + (int)c2.bear;
  bool ok = c5.bull && c1.bull && small_inside && (bears >= 2) && (c1.c > c5.h);
  if(!ok) return false;
  shapeScore = 0.7 + 0.3*_Clamp((c1.body_ratio+c5.body_ratio)/2.0,0.0,1.0);
  return true;
}
bool _FallingThreeMethods(const string sym, ENUM_TIMEFRAMES tf, int shift_base, double &shapeScore) {
  CandleData c5,c4,c3,c2,c1;
  if(!_GetCandle(sym,tf,shift_base+4,c5) || !_GetCandle(sym,tf,shift_base+3,c4) ||
     !_GetCandle(sym,tf,shift_base+2,c3) || !_GetCandle(sym,tf,shift_base+1,c2) ||
     !_GetCandle(sym,tf,shift_base,c1)) return false;
  bool small_inside = (c4.h <= c5.h && c4.l >= c5.l) &&
                      (c3.h <= c5.h && c3.l >= c5.l) &&
                      (c2.h <= c5.h && c2.l >= c5.l);
  int bulls = (int)c4.bull + (int)c3.bull + (int)c2.bull;
  bool ok = c5.bear && c1.bear && small_inside && (bulls >= 2) && (c1.c < c5.l);
  if(!ok) return false;
  shapeScore = 0.7 + 0.3*_Clamp((c1.body_ratio+c5.body_ratio)/2.0,0.0,1.0);
  return true;
}

// ======================= BUILDERS (REUSABLE) ======================
PatternScore _BuildSingle(const CandleData &c1, double atr) {
  PatternScore best; best.id=PATTERN_NONE; best.score=0; best.name="None"; best.bias="NONE"; best.candlesUsed=1;
  double s_doji = _DojiShape(c1);
  if(s_doji>0) {
    double score = 100.0 * (0.6*s_doji + 0.4*_RangeVsATR(c1,atr));
    if(score > best.score) { best.id=PATTERN_DOJI; best.name=PatternName(best.id); best.bias="NONE"; best.score=score; }
  }
  double s_maru = _MarubozuShape(c1);
  if(s_maru>0) {
    double score = 100.0 * (0.7*s_maru + 0.3*_RangeVsATR(c1,atr));
    int id = (c1.bull ? PATTERN_MARUBOZU_BULL : PATTERN_MARUBOZU_BEAR);
    string bias = (c1.bull ? "BUY" : "SELL");
    if(score > best.score) { best.id=id; best.name=PatternName(id); best.bias=bias; best.score=score; }
  }
  double s_pin_b = _PinBullShape(c1);
  if(s_pin_b>0) {
    double score = 100.0 * (0.7*s_pin_b + 0.3*_RangeVsATR(c1,atr));
    if(score > best.score) { best.id=PATTERN_PIN_BULL; best.name=PatternName(best.id); best.bias="BUY"; best.score=score; }
  }
  double s_pin_s = _PinBearShape(c1);
  if(s_pin_s>0) {
    double score = 100.0 * (0.7*s_pin_s + 0.3*_RangeVsATR(c1,atr));
    if(score > best.score) { best.id=PATTERN_PIN_BEAR; best.name=PatternName(best.id); best.bias="SELL"; best.score=score; }
  }
  if(best.id == PATTERN_NONE) {
    if(c1.body_ratio >= 0.60) {
      double score = 100.0 * (0.4 + 0.6*_RangeVsATR(c1,atr));
      int id = (c1.bull ? PATTERN_LONG_BULL : PATTERN_LONG_BEAR);
      string bias = (c1.bull ? "BUY" : "SELL");
      if(score > best.score) { best.id=id; best.name=PatternName(id); best.bias=bias; best.score=score; }
    } else if(c1.body_ratio > DOJI_BODY_MAX) {
      double balance = 1.0 - MathAbs(c1.upper_ratio - c1.lower_ratio);
      double score = 100.0 * (0.5*balance + 0.5*(1.0 - c1.body_ratio));
      if(score > best.score) { best.id=PATTERN_SPINNING_TOP; best.name=PatternName(best.id); best.bias="NONE"; best.score=score; }
    }
  }
  return best;
}

PatternScore _BuildDouble(const CandleData &c1, const CandleData &c2, double atr) {
  PatternScore best; best.id=PATTERN_NONE; best.score=0; best.name="None"; best.bias="NONE"; best.candlesUsed=2;
  double s_inside = _InsideShape(c1,c2);
  if(s_inside>0) {
    double score = 100.0 * (0.6*s_inside + 0.4*_RangeVsATR(c1,atr));
    if(score > best.score) { best.id=PATTERN_INSIDE_BAR; best.name=PatternName(best.id); best.bias="NONE"; best.score=score; }
  }
  double s_out = _OutsideShape(c1,c2);
  if(s_out>0) {
    double score = 100.0 * (0.6*s_out + 0.4*_RangeVsATR(c1,atr));
    int id = (c1.bull ? PATTERN_OUTSIDE_BAR_BULL : PATTERN_OUTSIDE_BAR_BEAR);
    string bias = (c1.bull ? "BUY" : "SELL");
    if(score > best.score) { best.id=id; best.name=PatternName(id); best.bias=bias; best.score=score; }
  }
  double s_eng_b = _EngulfBodyBull(c1,c2);
  if(s_eng_b>0) {
    double score = 100.0 * (0.6*s_eng_b + 0.4*_RangeVsATR(c1,atr));
    if(score > best.score) { best.id=PATTERN_ENGULFING_BULL; best.name=PatternName(best.id); best.bias="BUY"; best.score=score; }
  }
  double s_eng_s = _EngulfBodyBear(c1,c2);
  if(s_eng_s>0) {
    double score = 100.0 * (0.6*s_eng_s + 0.4*_RangeVsATR(c1,atr));
    if(score > best.score) { best.id=PATTERN_ENGULFING_BEAR; best.name=PatternName(best.id); best.bias="SELL"; best.score=score; }
  }
  double s_har_b = _HaramiBull(c1,c2);
  if(s_har_b>0) {
    double score = 100.0 * (0.6*s_har_b + 0.4*_RangeVsATR(c1,atr));
    if(score > best.score) { best.id=PATTERN_HARAMI_BULL; best.name=PatternName(best.id); best.bias="BUY"; best.score=score; }
  }
  double s_har_s = _HaramiBear(c1,c2);
  if(s_har_s>0) {
    double score = 100.0 * (0.6*s_har_s + 0.4*_RangeVsATR(c1,atr));
    if(score > best.score) { best.id=PATTERN_HARAMI_BEAR; best.name=PatternName(best.id); best.bias="SELL"; best.score=score; }
  }
  return best;
}

PatternScore _BuildTriple(const string sym, ENUM_TIMEFRAMES tf, int shift_base, double atr, const CandleData &c1) {
  PatternScore best; best.id=PATTERN_NONE; best.score=0; best.name="None"; best.bias="NONE"; best.candlesUsed=3;
  double shape;
  if(_ThreeWhiteSoldiers(sym,tf,shift_base,shape)) {
    double score = 100.0 * (0.6*shape + 0.4*_RangeVsATR(c1,atr));
    if(score > best.score) { best.id=PATTERN_3_WHITE_SOLDIERS; best.name=PatternName(best.id); best.bias="BUY"; best.score=score; }
  }
  if(_ThreeBlackCrows(sym,tf,shift_base,shape)) {
    double score = 100.0 * (0.6*shape + 0.4*_RangeVsATR(c1,atr));
    if(score > best.score) { best.id=PATTERN_3_BLACK_CROWS; best.name=PatternName(best.id); best.bias="SELL"; best.score=score; }
  }
  return best;
}

PatternScore _BuildFive(const string sym, ENUM_TIMEFRAMES tf, int shift_base, double atr, const CandleData &c1) {
  PatternScore best; best.id=PATTERN_NONE; best.score=0; best.name="None"; best.bias="NONE"; best.candlesUsed=5;
  double shape;
  if(_RisingThreeMethods(sym,tf,shift_base,shape)) {
    double score = 100.0 * (0.7*shape + 0.3*_RangeVsATR(c1,atr));
    if(score > best.score) { best.id=PATTERN_RISING_3_METHODS; best.name=PatternName(best.id); best.bias="BUY"; best.score=score; }
  }
  if(_FallingThreeMethods(sym,tf,shift_base,shape)) {
    double score = 100.0 * (0.7*shape + 0.3*_RangeVsATR(c1,atr));
    if(score > best.score) { best.id=PATTERN_FALLING_3_METHODS; best.name=PatternName(best.id); best.bias="SELL"; best.score=score; }
  }
  return best;
}

// ======================= MASTER ASSESSOR (CLEAN) ==================
PatternScore AssessCandle(const string sym, ENUM_TIMEFRAMES tf = TF_DEFAULT, int shift = 1) {
  PatternScore none; none.id=PATTERN_NONE; none.score=0; none.name="None"; none.bias="NONE"; none.candlesUsed=1;
  CandleData c1,c2;
  if(!_GetCandle(sym,tf,shift,c1)) return none;
  double atr = _ATR(sym, tf, ATR_PERIOD, shift);
  PatternScore best = _BuildSingle(c1, atr);
  if(_GetCandle(sym,tf,shift+1,c2)) {
    PatternScore p2 = _BuildDouble(c1,c2,atr);
    if(p2.score > best.score) best = p2;
  }
  PatternScore p3 = _BuildTriple(sym, tf, shift, atr, c1);
  if(p3.score > best.score) best = p3;
  PatternScore p5 = _BuildFive(sym, tf, shift, atr, c1);
  if(p5.score > best.score) best = p5;
  return best;
}

// ======================= TIERED CONFIG (GUARDED) ==================
#ifndef PATTERN_TIERED_CFG
#define PATTERN_TIERED_CFG
input bool   PATTERN_TIERED_ENABLE   = true;   // bật quét theo tầng 1→2→3→5
input double TIER1_MIN_SCORE         = 62.0;   // single-candle đủ đẹp thì trả luôn
input double TIER1_STRONG_MIN_SCORE  = 58.0;   // nới cho Pin/Marubozu
input double TIER2_MIN_SCORE         = 60.0;   // 2-candle (Engulf/Outside/Harami)
input double TIER3_MIN_SCORE         = 58.0;   // 3-candle (3 Soldiers/Crows)
input double TIER5_MIN_SCORE         = 58.0;   // 5-candle (3 Methods)
#endif

// ======================= TIERED HELPERS ===========================
bool _IsSingleStrong(const PatternScore &p) {
  if(p.candlesUsed != 1) return false;
  return (p.id == PATTERN_PIN_BULL || p.id == PATTERN_PIN_BEAR
       || p.id == PATTERN_MARUBOZU_BULL || p.id == PATTERN_MARUBOZU_BEAR);
}
bool _AcceptGood(const PatternScore &p, double minScore) {
  return (p.bias != "NONE" && p.score >= minScore);
}

// ======================= ASSESSOR TIERED ==========================
PatternScore AssessCandleTiered(const string sym, ENUM_TIMEFRAMES tf = TF_DEFAULT, int shift = 1) {
  if(!PATTERN_TIERED_ENABLE)
    return AssessCandle(sym, tf, shift);
  PatternScore out; out.id=PATTERN_NONE; out.score=0; out.name="None"; out.bias="NONE"; out.candlesUsed=1;
  CandleData c1,c2;
  if(!_GetCandle(sym,tf,shift,c1)) return out;
  double atr = _ATR(sym, tf, ATR_PERIOD, shift);
  // Tier 1: SINGLE
  PatternScore p1 = _BuildSingle(c1, atr);
  if(_IsSingleStrong(p1) && _AcceptGood(p1, TIER1_STRONG_MIN_SCORE)) return p1;
  if(_AcceptGood(p1, TIER1_MIN_SCORE)) return p1;
  // Tier 2: DOUBLE
  if(!_GetCandle(sym,tf,shift+1,c2)) return (p1.id != PATTERN_NONE ? p1 : out);
  PatternScore p2 = _BuildDouble(c1,c2,atr);
  if(_AcceptGood(p2, TIER2_MIN_SCORE)) return p2;
  // Tier 3: TRIPLE
  PatternScore p3 = _BuildTriple(sym, tf, shift, atr, c1);
  if(_AcceptGood(p3, TIER3_MIN_SCORE)) return p3;
  // Tier 4: FIVE
  PatternScore p5 = _BuildFive(sym, tf, shift, atr, c1);
  if(_AcceptGood(p5, TIER5_MIN_SCORE)) return p5;
  // fallback best
  PatternScore best = p1;
  if(p2.score > best.score) best = p2;
  if(p3.score > best.score) best = p3;
  if(p5.score > best.score) best = p5;
  return best;
}

// ======================= CONVENIENCE ==============================
inline PatternScore AssessCandleD1(int shift = 1) { return AssessCandle(_Symbol, TF_DEFAULT, shift); }
inline PatternScore AssessCandleTieredD1(int shift = 1) { return AssessCandleTiered(_Symbol, TF_DEFAULT, shift); }
inline void PrintPattern(const PatternScore &ps, int shift = 1, int tzOffsetHours = 0) {
  datetime t = iTime(_Symbol, TF_DEFAULT, shift);
  if(tzOffsetHours != 0) t += tzOffsetHours * 3600;
  MqlDateTime d; TimeToStruct(t, d);
  PrintFormat("[D1 %04d-%02d-%02d | shift=%d] Pattern: %s | Bias=%s | Score=%.0f | CandlesUsed=%d",
              d.year, d.mon, d.day, shift, ps.name, ps.bias, ps.score, ps.candlesUsed);
}

#endif // __CANDLE_PATTERN_MQH__
