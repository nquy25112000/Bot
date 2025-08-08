#!/usr/bin/env bash
set -euo pipefail

# ====== CONFIG ======
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT="${PORT:-8001}"                      # cho phép override: PORT=8010 ./aiscanbias.sh start
UVICORN_BIN="python -m uvicorn"          # đổi sang 'uvicorn' nếu bạn muốn
APP_IMPORT="app.main:app"
PID_FILE="$BASE_DIR/aiscanbias.pid"
LOG_FILE="$BASE_DIR/aiscanbias.log"
ENV_FILE="$BASE_DIR/.env"
VENV_ACT="$BASE_DIR/.venv/bin/activate"

cd "$BASE_DIR"

# ====== UTIL ======
say()   { echo -e "👉 $*"; }
good()  { echo -e "✅ $*"; }
warn()  { echo -e "⚠️  $*"; }
bad()   { echo -e "❌ $*" >&2; }
exists(){ command -v "$1" >/dev/null 2>&1; }

kill_port() { lsof -ti :"$PORT" | xargs -r kill || true; }

ensure_venv() {
  if [[ ! -f "$VENV_ACT" ]]; then
    say "Tạo venv tại .venv ..."
    python3 -m venv .venv
  fi
  # shellcheck disable=SC1090
  source "$VENV_ACT"
}

ensure_env() {
  if [[ ! -f "$ENV_FILE" ]] || ! grep -q '^OPENAI_API_KEY=' "$ENV_FILE"; then
    warn "Chưa thấy OPENAI_API_KEY trong .env"
    read -r -p "Nhập OPENAI_API_KEY: " KEY
    echo "OPENAI_API_KEY=$KEY" > "$ENV_FILE"
    good "Đã tạo .env"
  fi
}

install_deps() {
  say "Cài/đồng bộ dependencies..."
  pip install --upgrade pip >/dev/null
  pip install -r requirements.txt
  # bảo hiểm cho trường hợp requirements dùng điều kiện python_version → thiếu pytz
  python - <<'PY'
import importlib, sys, subprocess
try: importlib.import_module("pytz")
except ImportError:
    subprocess.check_call([sys.executable,"-m","pip","install","pytz"])
PY
  good "Dependencies OK"
}

seed_data() {
  say "Seed dữ liệu bias (D1/H4/H1)..."
  python - <<'PY'
from app.service import scan
scan()
PY
  ls -l "$BASE_DIR/data"/bias_*.json || true
  good "Seed xong"
}

start_fg() {
  ensure_venv
  ensure_env
  install_deps
  seed_data
  say "Dọn port $PORT nếu đang bận..."
  kill_port
  say "Start API (foreground) tại http://127.0.0.1:$PORT ..."
  exec $UVICORN_BIN "$APP_IMPORT" --host 127.0.0.1 --port "$PORT" --log-level info
}

start_bg() {
  ensure_venv
  ensure_env
  install_deps
  seed_data
  say "Dọn port $PORT nếu đang bận..."
  kill_port
  say "Start API (background) → log: $LOG_FILE"
  nohup $UVICORN_BIN "$APP_IMPORT" --host 127.0.0.1 --port "$PORT" --log-level warning \
    > "$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"
  good "PID: $(cat "$PID_FILE")"
}

stop() {
  local killed=0
  if [[ -f "$PID_FILE" ]]; then
    say "Kill PID từ $PID_FILE ..."
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
    killed=1
  fi
  say "Kill theo port $PORT ..."
  kill_port && killed=1 || true
  if [[ "$killed" -eq 1 ]]; then good "Đã dừng AIScanBIAS"; else warn "Không thấy process để dừng"; fi
}

status() {
  if [[ -f "$PID_FILE" ]] && ps -p "$(cat "$PID_FILE")" >/dev/null 2>&1; then
    good "Đang chạy (PID $(cat "$PID_FILE")) trên port $PORT"
  elif lsof -ti :"$PORT" >/dev/null 2>&1; then
    good "Một process khác đang giữ port $PORT: $(lsof -ti :"$PORT")"
  else
    warn "Chưa chạy"
  fi
}

logs() {
  [[ -f "$LOG_FILE" ]] || { warn "Chưa có $LOG_FILE"; return 0; }
  tail -n 100 -f "$LOG_FILE"
}

health() {
  say "Gọi /health..."
  if exists curl; then
    curl -sS "http://127.0.0.1:$PORT/health" || true
    echo
  else
    warn "Máy chưa có curl."
  fi
}

usage() {
  cat <<USAGE
Usage: $0 <cmd>

cmd:
  setup        Tạo venv, cài deps, tạo .env (không chạy server)
  seed         Sinh 3 file JSON (D1/H4/H1)
  start        Chạy API foreground (blocking)
  start-bg     Chạy API background (nohup, có PID)
  stop         Dừng API (PID & theo port)
  status       Kiểm tra trạng thái
  logs         Xem log (follow)
  health       Gọi /health (nếu đã thêm endpoint)
  restart      stop rồi start-bg

Tips:
  PORT=8010 $0 start-bg    # đổi cổng nhanh
USAGE
}

case "${1:-}" in
  setup)     ensure_venv; ensure_env; install_deps; good "Setup xong";;
  seed)      ensure_venv; seed_data;;
  start)     start_fg;;
  start-bg)  start_bg;;
  stop)      stop;;
  status)    status;;
  logs)      logs;;
  health)    health;;
  restart)   stop; start_bg;;
  *)         usage; exit 1;;
esac
