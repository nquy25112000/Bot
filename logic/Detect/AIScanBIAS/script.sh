#!/usr/bin/env bash
set -e

# ====== CONFIG ======
# Thay đường dẫn dưới đây thành đúng thư mục AIScanBIAS của bạn
AIS_DIR="/Users/vmaxthunder/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/Tester/Agent-127.0.0.1-3000/MQL5/Experts/Advisors/Bot/logic/Detect/AIScanBIAS"

# ====== STEP 1: CD vào thư mục ======
echo "📂 Chuyển vào thư mục AIScanBIAS..."
cd "$AIS_DIR"

# ====== STEP 2: Tạo venv nếu chưa có ======
if [ ! -d ".venv" ]; then
  echo "🐍 Tạo virtualenv..."
  python3 -m venv .venv
fi

# ====== STEP 3: Cài requirements ======
echo "📦 Cài dependencies..."
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# ====== STEP 4: Tạo .env nếu chưa có ======
if [ ! -f ".env" ]; then
  echo "🔑 Tạo file .env..."
  read -p "Nhập OPENAI_API_KEY của bạn: " API_KEY
  echo "OPENAI_API_KEY=$API_KEY" > .env
  echo "✅ Đã tạo .env với OPENAI_API_KEY"
else
  echo "ℹ️ File .env đã tồn tại, bỏ qua."
fi

# ====== STEP 5: Test chạy thử API ======
echo "🚀 Chạy thử uvicorn..."
python -m uvicorn app.main:app --host 127.0.0.1 --port 8001
