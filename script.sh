#!/usr/bin/env bash
# Ghi đè StartBiasService.mqh và copy StartBiasService.cmd vào tất cả agent Tester
set -euo pipefail

BOT_DIR="$(cd "$(dirname "$0")" && pwd)"
MQH="$BOT_DIR/logic/Detect/StartBiasService.mqh"
CMD_SRC="$BOT_DIR/logic/Detect/BiasService/StartBiasService.cmd"

# 1) Ghi file .mqh (nội dung y hệt ở trên) --------------------------
cat > "$MQH" <<'EOF'
// (dán nguyên nội dung StartBiasService.mqh vừa cung cấp ở trên)
EOF
echo "✅ Đã cập nhật $MQH"

# 2) Sao chép .cmd cho mọi tester agent -----------------------------
find "$HOME/Library/Application Support/net.metaquotes.wine.metatrader5" \
     -type d -name 'agent-*' | while read -r AG; do
    DEST="$AG/MQL5/Experts/Advisors/Bot/logic/Detect/BiasService"
    mkdir -p "$DEST"
    cp "$CMD_SRC" "$DEST"
done
echo "✅ Đã copy StartBiasService.cmd vào sandbox Tester"
