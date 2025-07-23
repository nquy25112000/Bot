#!/usr/bin/env bash
set -euo pipefail

# 1) tìm file
FILE=$(find . -type f -name SignalService.mqh | head -n1)
if [[ ! -f "$FILE" ]]; then
  echo "❌ Không tìm thấy SignalService.mqh"
  exit 1
fi
echo "✏️  Cập nhật $FILE …"

# 2) chèn includes utils nếu chưa có
sed -i.bak -E '/#include "\.\.\/data\/MarketDataService.mqh"/a\
#include "utils/StringUtils.mqh"\
#include "utils/ULongUtils.mqh"\
#include "utils/TicketInfoUtils.mqh"\
#include "utils/ProfitCalculator.mqh"
' "$FILE"

# 3) xóa định nghĩa các hàm util
for func in SplitString AddToStringArray StringToULong ULongToString stringToTicketInfo TicketInfoToString CalcTP; do
  awk -v F="$func" '
    BEGIN {del=0}
    {
      # tìm đến dòng khai báo hàm -> bắt đầu xóa
      if (del==0 && $0 ~ "\\<"F"\\s*\\(") { del=1; next }
      # khi đang xóa và gặp dòng chỉ chứa dấu '}' (đóng hàm), chuyển sang trạng thái đợi blank line
      if (del==1 && $0 ~ /^[[:space:]]*\}[[:space:]]*$/) { del=2; next }
      # khi đã đóng hàm và gặp blank line, kết thúc xóa
      if (del==2 && $0 ~ /^[[:space:]]*$/) { del=0; next }
      # nếu không trong vùng xóa thì in ra
      if (del==0) print
    }
  ' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
done

# 4) dọn file backup
rm -f "$FILE.bak"

echo "✅ Hoàn tất! SignalService.mqh đã import utils và loại bỏ định nghĩa cũ."
