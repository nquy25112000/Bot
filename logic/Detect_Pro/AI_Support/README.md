# AI_Support (MT5 -> FastAPI -> OpenAI -> BiasResult)

## Run
source .venv/bin/activate
python app.py

## Endpoint
POST /analyze
Content-Type: application/json

Payload (ví dụ):
{
  "symbol": "XAUUSD",
  "timeframe": "D1",
  "pattern": {"id": 9, "name": "Bullish Engulfing", "score": 82, "candlesUsed": 2},
  "bars": [{"t":"2025-07-25","o":2370,"h":2384,"l":2360,"c":2378}, ...],  // 20-60 bars
  "features": {
    "rsi": 54.2, "macd": {"m":0.12,"s":0.05}, "adx": 21.7, "atr": 18.3,
    "trendExpansionBull": true, "trendExpansionBear": false
  },
  "session": "US",
  "patternShift": 1,
  "patternTime": 1690675200  // epoch seconds (open time of D1 bar at shift)
}

Response (BiasResult JSON):
{
  "type":"BUY","percent":67.0,"bullScore":62.0,"bearScore":38.0,
  "patternId":9,"patternName":"Bullish Engulfing","patternScore":82.0,
  "patternCandles":2,"patternShift":1,"patternTime":1690675200,"patternStrength":"STRONG"
}

## MT5: Remember to whitelist http://127.0.0.1:8000 in Tools -> Options -> Expert Advisors -> WebRequest.
