#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT="${PORT:-8001}"
APP="app.main:app"
LOG_FILE="$BASE_DIR/aiscanbias.log"
PID_FILE="$BASE_DIR/aiscanbias.pid"

cd "$BASE_DIR"

# 1) VENV
if [ ! -f ".venv/bin/activate" ]; then
  echo "🐍 Tạo .venv..."
  python3 -m venv .venv
fi
source .venv/bin/activate

# 2) DEPS (bắt buộc có pytz)
pip install --upgrade pip >/dev/null
pip install -r requirements.txt
python - <<'PY'
import importlib, sys, subprocess
try: importlib.import_module("pytz")
except ImportError:
    subprocess.check_call([sys.executable,"-m","pip","install","pytz"])
PY

# 3) .ENV (phải có key)
if ! grep -q '^OPENAI_API_KEY=' ".env" 2>/dev/null; then
  echo "❌ Thiếu OPENAI_API_KEY trong .env"; exit 1
fi

# 4) SEED dữ liệu (để GET /bias/* có data ngay)
python - <<'PY'
from app.service import scan
scan()
PY

# 5) DỌN PORT CŨ + START API NỀN
lsof -ti :$PORT | xargs -r kill
nohup python -m uvicorn "$APP" --host 127.0.0.1 --port "$PORT" --log-level warning \
  > "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"
echo "✅ AIScanBIAS started (PID $(cat "$PID_FILE")) on :$PORT"
