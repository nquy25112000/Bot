#!/bin/bash

SIGNAL_FILE="./logic/SignalService.mqh"
BACKUP_FILE="${SIGNAL_FILE}.bak"
TMP_FILE="${SIGNAL_FILE}.tmp"

# Bước 1: Tạo bản sao lưu
cp "$SIGNAL_FILE" "$BACKUP_FILE"

# Bước 2: Thêm include vào sau dòng MarketDataService.mqh
awk '
BEGIN { inserted = 0 }
{
  print $0;
  if (!inserted && match($0, /#include "..\/data\/MarketDataService\.mqh"/)) {
    print "#include \"./DCA_Positive/handleDCAPositive.mqh\"";
    print "#include \"./DCA_Positive/updateStateCloseDCAPositive.mqh\"";
    print "#include \"./DCA_Positive/AddPositiveTicketToArray.mqh\"";
    print "#include \"../utils/CalcTP.mqh\"";
    print "#include \"../utils/GetTotalProfitFrom.mqh\"";
    print "#include \"../utils/updateTicketInfo.mqh\"";
    inserted = 1;
  }
}' "$SIGNAL_FILE" > "$TMP_FILE"

# Bước 3: Xoá các hàm đã tách ra khỏi SignalService.mqh
sed -E -i '
/^\/\/ đặt lệnh STOP DCA thuận xu hướng/,/^}/d;
/^\/\/ Hàm handle lệnh DCA Dương/,/^}/d;
/^\(\s*\)void handleDCAPositive\(/,/^\}/d;
/^\/\*/,/\*\//d;
/^void updateStateCloseDCAPositive\(/,/^\}/d;
/^void AddPositiveTicketToArray\(/,/^\}/d;
/^double CalcTP\(/,/^\}/d;
/^double GetTotalProfitFrom\(/,/^\}/d;
/^void updateTicketInfo\(/,/^\}/d
' "$TMP_FILE"

# Bước 4: Ghi đè file gốc
mv "$TMP_FILE" "$SIGNAL_FILE"

echo "✅ Đã cập nhật $SIGNAL_FILE thành công."
echo "📦 Đã tạo bản sao lưu tại $BACKUP_FILE"
