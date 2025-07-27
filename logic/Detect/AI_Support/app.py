import os, json, time
from typing import Any, Dict, List, Optional
from dotenv import load_dotenv
from pydantic import BaseModel, Field, field_validator
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

# OpenAI SDK v1.x
from openai import OpenAI

load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
HOST = os.getenv("HOST", "127.0.0.1")
PORT = int(os.getenv("PORT", "8000"))

if not OPENAI_API_KEY:
    print("[WARN] OPENAI_API_KEY is empty. Set it in .env or environment variables.")

client = OpenAI(api_key=OPENAI_API_KEY)

# --------- Schemas (input from MT5) ----------
class Bar(BaseModel):
    t: str | int
    o: float
    h: float
    l: float
    c: float

class Macd(BaseModel):
    m: float = 0.0
    s: float = 0.0

class Features(BaseModel):
    rsi: float = 50.0
    macd: Macd = Macd()
    adx: float = 20.0
    atr: float = 1.0
    trendExpansionBull: bool = False
    trendExpansionBear: bool = False

class PatternIn(BaseModel):
    id: int = 0
    name: str = "None"
    score: float = 0.0
    candlesUsed: int = 1

class AnalyzeIn(BaseModel):
    symbol: str
    timeframe: str = "D1"
    bars: List[Bar] = Field(default_factory=list)
    features: Features = Features()
    pattern: PatternIn = PatternIn()
    session: str = "US"
    patternShift: int = 1
    patternTime: int = 0  # epoch seconds

    @field_validator("timeframe")
    @classmethod
    def _tf_ok(cls, v: str) -> str:
        allowed = {"D1","H4","H1","M30"}
        if v not in allowed:
            raise ValueError(f"timeframe must be one of {allowed}")
        return v

# --------- BiasResult (output) ----------
class BiasResult(BaseModel):
    type: str = "NONE"              # BUY | SELL | NONE
    percent: float = 0.0            # 0..100
    bullScore: float = 0.0
    bearScore: float = 0.0
    patternId: int = 0
    patternName: str = "None"
    patternScore: float = 0.0
    patternCandles: int = 1
    patternShift: int = 1
    patternTime: int = 0            # epoch seconds
    patternStrength: str = "NEUTRAL" # STRONG | MODERATE | NEUTRAL | WEAK

# --------- Helpers ----------
def clamp(x: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, x))

def strength_from_score(score: float, bias: str) -> str:
    if bias == "NONE":
        return "NEUTRAL"
    if score >= 75: return "STRONG"
    if score >= 60: return "MODERATE"
    return "WEAK"

def normalize_bias_json(js: Dict[str, Any], fallback: AnalyzeIn) -> BiasResult:
    # Map & defaults
    t = js.get("type", "NONE")
    t = t.upper()
    if t not in ("BUY","SELL","NONE"): t = "NONE"

    percent = clamp(float(js.get("percent", 0.0)), 0.0, 100.0)
    bull = float(js.get("bullScore", 0.0))
    bear = float(js.get("bearScore", 0.0))

    # Pattern block: prefer model output; else fallback from input
    pid  = int(js.get("patternId", fallback.pattern.id))
    pname= str(js.get("patternName", fallback.pattern.name))
    psc  = float(js.get("patternScore", fallback.pattern.score))
    pc   = int(js.get("patternCandles", fallback.pattern.candlesUsed))
    psh  = int(js.get("patternShift", fallback.patternShift))
    ptim = int(js.get("patternTime", fallback.patternTime))
    pstr = str(js.get("patternStrength", strength_from_score(psc, t)))

    # Validate ranges
    pc = max(1, min(pc, 5))
    psh = max(0, psh)

    return BiasResult(
        type=t, percent=percent, bullScore=bull, bearScore=bear,
        patternId=pid, patternName=pname, patternScore=psc,
        patternCandles=pc, patternShift=psh, patternTime=ptim,
        patternStrength=pstr
    )

def build_user_payload(inp: AnalyzeIn) -> Dict[str, Any]:
    # Keep compact to save tokens
    return {
        "symbol": inp.symbol,
        "timeframe": inp.timeframe,
        "session": inp.session,
        "pattern": inp.pattern.model_dump(),
        "patternShift": inp.patternShift,
        "patternTime": inp.patternTime,
        "features": inp.features.model_dump(),
        "bars": [b.model_dump() for b in inp.bars][-60:],  # cap 60 bars
    }

# --------- FastAPI app ----------
app = FastAPI(title="AI_Support for MT5", version="1.0.0")
app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"]
)

@app.get("/health")
def health():
    return {"ok": True, "ts": int(time.time())}

@app.post("/analyze", response_model=BiasResult)
def analyze(inp: AnalyzeIn) -> Any:
    if not OPENAI_API_KEY:
        raise HTTPException(status_code=500, detail="OPENAI_API_KEY missing")

    system = (
        "You analyze XAUUSD bias on a daily timeframe. "
        "Return ONLY a compact JSON that exactly matches this schema: "
        "{type: BUY|SELL|NONE, percent: number(0..100), bullScore: number, bearScore: number, "
        "patternId: int, patternName: string, patternScore: number, patternCandles: int, "
        "patternShift: int, patternTime: int, patternStrength: STRONG|MODERATE|NEUTRAL|WEAK}. "
        "Consider recent bars, pattern score, RSI/MACD/ADX/ATR, trend expansion flags, and session context. "
        "If confidence is low, use type=NONE and percent=0."
    )

    user_payload = build_user_payload(inp)

    # OpenAI call with forced JSON
    try:
        completion = client.chat.completions.create(
            model=MODEL,
            response_format={"type": "json_object"},
            temperature=0,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": json.dumps(user_payload, ensure_ascii=False)},
            ],
        )
        content = completion.choices[0].message.content
        js = json.loads(content)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"OpenAI error: {e}")

    # Normalize + fill defaults
    out = normalize_bias_json(js, inp)
    return out

if __name__ == "__main__":
    uvicorn.run("app:app", host=HOST, port=PORT, reload=False)
