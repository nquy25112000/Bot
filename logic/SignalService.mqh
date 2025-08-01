#ifndef __SIGNAL_SERVICE_MQH__
#define __SIGNAL_SERVICE_MQH__

//-------------------------------------------------------------
// Khởi động chiến lược Daily Bias:
// Tạo lệnh đầu tiên và thiết lập các lệnh chờ (trạng thái WAITING_STOP)
//-------------------------------------------------------------
void startDailyBias() {
  BiasResult biasResult = DetectDailyBias();
  if (biasResult.type == "SELL") {
    orderTypeDailyBias = ORDER_TYPE_SELL;
  }
  else if (biasResult.type == "BUY") {
    orderTypeDailyBias = ORDER_TYPE_BUY;
  }
  else
  {
    return; // Không có bias, không khởi động Daily Bias
  }
  LogDailyBias(biasResult, 7); // 7 là timezone offset (UTC+7)
  double currentPrice = getCurrentPrice(orderTypeDailyBias);
  // clear toàn bộ data cũ
  ArrayFree(m_tickets);
  ArrayFree(m_positiveTickets);
  ArrayFree(m_frozenTickets);
  // Khởi tạo lệnh STOP cách lệnh đầu tiên 2 giá thuận xu hướng
  orderStopFollowTrend(orderTypeDailyBias == ORDER_TYPE_BUY ? currentPrice + 1 : currentPrice - 1); // hàm này nó cộng sẵn 1 rồi nên chỉ cần truyền currentPrice + 1
  // Khởi tạo DCA âm
  initDCANegative(currentPrice);
}

#endif // __SIGNAL_SERVICE_MQH__
