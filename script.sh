#!/usr/bin/env bash
# Ghi lại StartBiasService.mqh và chép StartBiasService.cmd vào cả Data & Tester
set -euo pipefail

BOT_DIR="$(cd "$(dirname "$0")" && pwd)"
MQH="$BOT_DIR/logic/Detect/StartBiasService.mqh"
CMD_SRC="$BOT_DIR/logic/Detect/BiasService/StartBiasService.cmd"

# 1) ghi mqh (dùng cat << 'EOF' … EOF như hướng dẫn ở trên)
#    …

# 2) copy .cmd sang Tester agents hiện có (để back-test không lỗi)
for AG in "$HOME/Library/Application Support"/net.metaquotes.wine.metatrader5/**/Tester/agent-*; do
  [[ -d "$AG" ]] || continue
  DEST="$AG/MQL5/Experts/Advisors/Bot/logic/Detect/BiasService"
  mkdir -p "$DEST"
  cp "$CMD_SRC" "$DEST"
done

echo "✅ Đã cập nhật .mqh & copy StartBiasService.cmd cho Tester."
