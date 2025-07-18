#!/usr/bin/env bash
set -e

echo "🛠️  Fixing array‐by‐reference signature for InitVolumes..."

# 1. Thay đổi chữ ký trong MarketDataService.mqh
FILE="data/MarketDataService.mqh"
cp "$FILE" "${FILE}.bak"
sed -i.bak -E \
  's#void InitVolumes\(const double sourceVolumes\[\],#void InitVolumes(const double &sourceVolumes[],#' \
  "$FILE"
echo "  • Updated signature in $FILE (backup at ${FILE}.bak)"

# 2. Nếu bạn có khai lại InitVolumes trong BiasBot.mq5, cũng thay tương tự
FILE2="ea/BiasBot.mq5"
if grep -q "InitVolumes" "$FILE2"; then
  cp "$FILE2" "${FILE2}.bak"
  sed -i.bak -E \
    's#InitVolumes\(([^,]+),#InitVolumes(\1,#' \
    "$FILE2"
  echo "  • Checked calls in $FILE2 (backup at ${FILE2}.bak)"
fi

echo "✅ Done. Hãy reload VS Code và rebuild EA."
