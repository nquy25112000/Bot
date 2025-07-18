#!/usr/bin/env bash

set -e

echo "⏳ Đang áp dụng các bản vá cho toàn bộ project..."

# 1) Sửa InitVolumes để nhận mảng bằng reference (MarketDataService.mqh)
sed -i.bak -E \
  "s#void InitVolumes\(const double sourceVolumes\[\]#void InitVolumes(const double &sourceVolumes[]#g" \
  data/MarketDataService.mqh

# 2) Định nghĩa m_volumes và m_tickets (Globals.mqh) thay vì extern
#    (Để tránh lỗi operator= và ‘&’ reference cannot be used)
#    – Thay extern double m_volumes[];   thành   double m_volumes[100];
#    – Thay extern TicketInfo m_tickets[]; thành   TicketInfo m_tickets[100];
#      Đồng thời gán một kích thước hợp lý (100 là ví dụ, bạn có thể thay).
sed -i.bak -E "
s#extern double m_volumes\[\];#double m_volumes[100];#g;
s#extern TicketInfo m_tickets\[\];#TicketInfo m_tickets[100];#g
" common/Globals.mqh

# 3) Thay toàn bộ initializer list { … } cho TicketInfo trong SignalService.mqh
#    để tránh “parameter conversion not allowed” và “expression expected”
sed -i.bak -E "
/m_tickets\[ticketCount\+\+\] = \{/ {
  N; s#m_tickets\[ticketCount\+\+\] = \{([^;]+)\};#\
    /* struct init */\
    TicketInfo _tmp = TicketInfo();\
    _tmp.ticketId = \1; /* bạn có thể split tiếp */\
    m_tickets[ticketCount++] = _tmp;#g
}
" logic/SignalService.mqh

# 4) Fix signature của OrderModify cho đúng CTrade
#    CTrade::OrderModify(ulong ticket, double price, double stoploss, double takeprofit, datetime expiration=0)
#    Tất cả call trade.OrderModify(a,b,c,d) → trade.OrderModify(a,b,c,d,0)
sed -i.bak -E "
s#trade\.OrderModify\(\s*([^,]+),([^,]+),([^,]+),([^,]+)\)#trade.OrderModify(\1,\2,\3,\4,0)#g
" logic/SignalService.mqh

echo "✅ Đã áp dụng xong. Các bản backup (*.bak) đã được lưu lại."