#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

# venv
if [ ! -d ".venv" ]; then
  python3 -m venv .venv
fi
source .venv/bin/activate
pip install -r requirements.txt

# .env cần có OPENAI_API_KEY
if ! grep -q "OPENAI_API_KEY" .env 2>/dev/null; then
  echo "Missing OPENAI_API_KEY in .env" >&2
  exit 1
fi

# chạy nền (đổi port nếu bạn muốn)
nohup python -m uvicorn app.main:app --host 127.0.0.1 --port 8001 \
  > "$(pwd)/aiscanbias.log" 2>&1 &
echo $! > aiscanbias.pid
