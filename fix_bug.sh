#!/usr/bin/env bash
# ------------------------------------------------------------------
# fix_ambiguous.sh – Xử lý lỗi “ambiguous access” do khai báo biến lặp
# ------------------------------------------------------------------
set -e

# Chọn cú pháp sed in-place tương thích macOS / Linux
if sed --version >/dev/null 2>&1; then SED_INPLACE="sed -i"; else SED_INPLACE="sed -i ''"; fi

#####################################################################
# 1) Gỡ khai báo trùng trong ea/BiasBot.mq5
#####################################################################
BOT="ea/BiasBot.mq5"
cp "$BOT" "${BOT}.bak"

$SED_INPLACE -E '
  /^[[:space:]]*int[[:space:]]+jump[[:space:]]*=.*;/d;
  /^[[:space:]]*bool[[:space:]]+dailyBiasRunning[[:space:]]*=?.*;/d;
  /^[[:space:]]*int[[:space:]]+targetByIndex1[[:space:]]*[,;]/d;
  /^[[:space:]]*int[[:space:]]+targetByIndex2[[:space:]]*[,;]/d
' "$BOT"

echo "✅ Đã xoá khai báo trùng trong $BOT  (backup: ${BOT}.bak)"

#####################################################################
# 2) Khởi tạo biến toàn cục trong common/Globals.mqh
#####################################################################
GLO="common/Globals.mqh"
cp "$GLO" "${GLO}.bak"

$SED_INPLACE -E '
  s/^[[:space:]]*int[[:space:]]+jump[[:space:]]*;[[:space:]]*$/int    jump = 1;/
  s/^[[:space:]]*bool[[:space:]]+dailyBiasRunning[[:space:]]*;[[:space:]]*$/bool   dailyBiasRunning = false;/
  s/^[[:space:]]*int[[:space:]]+targetByIndex1[[:space:]]*,[[:space:]]*targetByIndex2[[:space:]]*;[[:space:]]*$/int    targetByIndex1 = 0, targetByIndex2 = 0;/
' "$GLO"

echo "✅ Đã khởi tạo biến trong $GLO      (backup: ${GLO}.bak)"

echo "🎉  Hoàn tất! Hãy Compile lại EA – lỗi 'ambiguous access' sẽ biến mất."

# file này là để script fix bug xong chạy là nó tự apply vào code mình