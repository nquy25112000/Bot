#!/usr/bin/env bash
# ------------------------------------------------------------
# script.sh – khởi tạo & cài BiasService trong Bot/logic/Detect
# ------------------------------------------------------------
set -euo pipefail

SERVICE_NAME="BiasService"        # đổi nếu muốn
PY=python3                         # hoặc python

# Thư mục hiện tại (chính là Bot)
BOT_DIR="$(cd "$(dirname "$0")" && pwd)"
DETECT_DIR="$BOT_DIR/logic/Detect"
SERVICE_DIR="$DETECT_DIR/$SERVICE_NAME"

echo "BOT_DIR     : $BOT_DIR"
echo "SERVICE_DIR : $SERVICE_DIR"
echo "------------------------------------------------------------"

# --- Tạo thư mục ---
if [[ -d "$SERVICE_DIR" ]]; then
  echo "❌ '$SERVICE_DIR' đã tồn tại, dừng."
  exit 1
fi
mkdir -p "$SERVICE_DIR"
cd "$SERVICE_DIR"

# --- requirements.txt ---
cat > requirements.txt <<'REQ'
fastapi
uvicorn[standard]
python-dotenv
pydantic
openai>=1.21
REQ

# --- .env.example & .env ---
cat > .env.example <<'ENV'
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-4o-mini
TEMPERATURE=0.0
ENV
cp .env.example .env

# --- models.py ---
cat > models.py <<'PY'
from datetime import datetime
from typing import List, Literal
from pydantic import BaseModel, Field

class Bar(BaseModel):
    t: int
    o: float; h: float; l: float; c: float

class AnalyzeRequest(BaseModel):
    symbol: str
    timeframe: Literal["H1", "H4", "D1"]
    bars: List[Bar] = Field(..., min_items=5, max_items=100)

class BiasResult(BaseModel):
    symbol: str
    timeframe: Literal["H1", "H4", "D1"]
    type: Literal["BUY", "SELL", "NONE"]
    percent: float
    bullScore: float
    bearScore: float
    patternId: int
    patternName: str
    patternScore: float
    patternCandles: int
    patternShift: int
    patternTime: datetime
    patternStrength: str
PY

# --- app.py ---
cat > app.py <<'PY'
import os, json, openai
from fastapi import FastAPI, HTTPException
from dotenv import load_dotenv
from models import AnalyzeRequest, BiasResult

load_dotenv()
openai.api_key = os.getenv("OPENAI_API_KEY")
MODEL          = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
TEMP           = float(os.getenv("TEMPERATURE", 0))

SYSTEM = ("Bạn là chuyên gia phân tích kỹ thuật 15 năm kinh nghiệm. "
          "Nhận dữ liệu nến và trả về JSON đúng schema BiasResult.")

app = FastAPI(title="BiasService")

def ask_ai(prompt:str)->dict:
    rsp=openai.chat.completions.create(
        model=MODEL,temperature=TEMP,
        messages=[{"role":"system","content":SYSTEM},
                  {"role":"user","content":prompt}]
    )
    return json.loads(rsp.choices[0].message.content.strip())

@app.post("/analyze", response_model=BiasResult)
def analyze(req:AnalyzeRequest):
    bars=json.dumps([b.model_dump() for b in req.bars], ensure_ascii=False)
    prompt=(f"Symbol:{req.symbol}\nTimeframe:{req.timeframe}\nBars:{bars}\n"
            "Hãy trả về BiasResult JSON.")
    try:
        return BiasResult(**ask_ai(prompt))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
PY

# --- README.md ngắn ---
echo "# BiasService – FastAPI + OpenAI" > README.md

# --- virtual-env & install ---
echo "🔧 Tạo venv và cài package..."
$PY -m venv .venv
source .venv/bin/activate
pip install -q --upgrade pip
pip install -q -r requirements.txt

echo "✅ Hoàn tất! Service nằm tại: $SERVICE_DIR"
echo "👉 Điền OPENAI_API_KEY trong $SERVICE_DIR/.env rồi chạy:"
echo "   source $SERVICE_DIR/.venv/bin/activate && uvicorn app:app --port 8000"
