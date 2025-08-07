#!/usr/bin/env bash
# =========================================================
# Tạo micro-service AIScanBIAS *ngay trong repo Bot*
# Vị trí: logic/Detect/AIScanBIAS
# =========================================================
set -e

# --- 1. Xác định thư mục đích ---
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"          # nơi đặt script
TARGET_DIR="$REPO_ROOT/logic/Detect/AIScanBIAS"

if [ -d "$TARGET_DIR" ]; then
  echo "⚠️  $TARGET_DIR đã tồn tại, không ghi đè."
  exit 1
fi
mkdir -p "$TARGET_DIR/app" "$TARGET_DIR/data"

# --- 2. Tìm Python ---
PYTHON_BIN=""
for v in 3.11 3.10 3.9 3; do
  if command -v python$v >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python$v)"
    break
  fi
done
[ -z "$PYTHON_BIN" ] && { echo "❌ Chưa cài Python3."; exit 1; }
echo "✔️  Sử dụng: $PYTHON_BIN"

# --- 3. Virtual-env ---
cd "$TARGET_DIR"
$PYTHON_BIN -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip

# --- 4. Dependencies ---
cat > requirements.txt <<'REQ'
fastapi
uvicorn[standard]
apscheduler
openai
python-dotenv
pytz ; python_version < "3.9"
REQ
pip install -r requirements.txt

# --- 5. Skeleton code ---
cat > app/__init__.py    <<'PY'
# AIScanBIAS package
PY
cat > app/config.py      <<'PY'
from pathlib import Path
import os, dotenv
BASE_DIR = Path(__file__).resolve().parent.parent
dotenv.load_dotenv(BASE_DIR / ".env")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
TIMEZONE = "Asia/Ho_Chi_Minh"
PY
cat > app/openai_client.py <<'PY'
from openai import OpenAI
from .config import OPENAI_API_KEY
def ask_bias(tf: str, data: dict) -> str:
    client = OpenAI(api_key=OPENAI_API_KEY)
    prompt = (
        f"Dữ liệu {tf}: {data}\n"
        "Trả về JSON đúng struct BiasResult (BUY/SELL/NONE, percent, bullScore…)"
    )
    r = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role":"system","content":"Chuyên gia price-action."},
                  {"role":"user","content":prompt}]
    )
    return r.choices[0].message.content
PY
cat > app/storage.py     <<'PY'
from pathlib import Path, PurePath
import json
DATA_DIR = PurePath(__file__).resolve().parent.parent / "data"
DATA_DIR.mkdir(exist_ok=True)
def save(tf:str, text:str): (DATA_DIR/f"bias_{tf}.json").write_text(text,'utf-8')
def load(tf:str):
    p = DATA_DIR/f"bias_{tf}.json"
    return json.loads(p.read_text('utf-8')) if p.exists() else None
PY
cat > app/service.py     <<'PY'
from .openai_client import ask_bias
from .storage import save
def _chart(tf:str)->dict: return {"demo":True}  # TODO: lấy OHLCV thật
def scan():                               # D1 → H4 → H1
    for tf in ("D1","H4","H1"):
        save(tf, ask_bias(tf, _chart(tf)))
PY
cat > app/scheduler.py   <<'PY'
import pytz, datetime as dt
from apscheduler.schedulers.background import BackgroundScheduler
from .service import scan
from .config import TIMEZONE
tz = pytz.timezone(TIMEZONE)
sched = BackgroundScheduler(timezone=TIMEZONE)
def _before_14h(): return dt.datetime.now(tz).time() < dt.time(14,0)
def _job():        _before_14h() and scan()
def start():       sched.add_job(_job,'cron',hour=7,minute=0); sched.start()
PY
cat > app/main.py        <<'PY'
from fastapi import FastAPI, HTTPException
from .scheduler import start
from .storage import load
app = FastAPI(title="AIScanBIAS")
@app.on_event("startup")  # auto scheduler
def _st(): start()
@app.get("/bias/{tf}")
def get(tf:str):
    data=load(tf.upper());
    if data: return data
    raise HTTPException(404,"Not found")
PY

# --- 6. Mẫu .env ---
echo "OPENAI_API_KEY=" > .env.example

echo -e "\n✅ Đã tạo AIScanBIAS tại: $TARGET_DIR
Bật service:\n  cd logic/Detect/AIScanBIAS\n  source .venv/bin/activate\n  cp .env.example .env  # điền API-key\n  uvicorn app.main:app --reload --port 8000\n"
