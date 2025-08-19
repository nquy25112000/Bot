#!/usr/bin/env bash
set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=8001
APP="app.main:app"

cd "$BASE_DIR"

# Tạo venv nếu chưa có
if [ ! -f ".venv/bin/activate" ]; then
  echo "🐍 Tạo .venv..."
  python3 -m venv .venv
fi
source .venv/bin/activate

pip install --upgrade pip
pip install -r requirements.txt pytz

# Seed JSON
python - <<'PY'
from app.service import scan
scan()
PY

# Dọn port cũ và chạy API
lsof -ti :$PORT | xargs -r kill
nohup python -m uvicorn "$APP" --host 127.0.0.1 --port $PORT --log-level warning > aiscanbias.log 2>&1 &
echo "✅ AIScanBIAS API started at :$PORT"
