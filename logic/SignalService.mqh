#ifndef __SIGNAL_SERVICE_MQH__
#define __SIGNAL_SERVICE_MQH__

//-------------------------------------------------------------
// Khởi động chiến lược Daily Bias:
// Tạo lệnh đầu tiên và thiết lập các lệnh chờ (trạng thái WAITING_STOP)
//-------------------------------------------------------------
void startBias(string biasType) {

  dailyBiasRuning = true;
  ENUM_ORDER_TYPE orderTypeByBiasType = getBiasOrderType(biasType);
  double currentPrice = getCurrentPrice(orderTypeByBiasType);
  // clear toàn bộ data cũ
  clearDataByType(biasType);
  // Khởi tạo lệnh STOP cách lệnh đầu tiên 2 giá thuận xu hướng
  //orderStopFollowTrend(orderTypeByBiasType == ORDER_TYPE_BUY ? currentPrice + 1: currentPrice - 1); // hàm này nó cộng sẵn 1 rồi nên chỉ cần truyền currentPrice + 1
  // Khởi tạo DCA âm
  initDCANegative(biasType);
}

#endif // __SIGNAL_SERVICE_MQH__
