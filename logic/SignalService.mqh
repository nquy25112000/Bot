#ifndef __SIGNAL_SERVICE_MQH__
#define __SIGNAL_SERVICE_MQH__

//-------------------------------------------------------------
// Khởi động chiến lược Daily Bias:
// Tạo lệnh đầu tiên và thiết lập các lệnh chờ (trạng thái WAITING_STOP)
//-------------------------------------------------------------
void startBias(string biasType) {
  clearDataByType();
  biasTYPE = biasType;
  dcaPositiveVol = biasType == DAILY_BIAS ? 0.1 : (biasType == H4_BIAS ? 0.08 : 0.06);
  ENUM_ORDER_TYPE orderTypeByBiasType = getBiasOrderType(biasType); // BUY hoặc SELL
  printf("TYPE BIAS: %s, orderTypeByBiasType: %d", biasTYPE, orderTypeByBiasType);
  if (orderTypeByBiasType == NULL) {
    return;
  }

  double currentPrice = getCurrentPrice(orderTypeByBiasType);
  // clear toàn bộ data cũ
  // Khởi tạo lệnh STOP cách lệnh đầu tiên 2 giá thuận xu hướng
  //orderStopFollowTrend(orderTypeByBiasType == ORDER_TYPE_BUY ? currentPrice + 1: currentPrice - 1); // hàm này nó cộng sẵn 1 rồi nên chỉ cần truyền currentPrice + 1
  // Khởi tạo DCA âm
  initDCANegative(biasType);
}

#endif // __SIGNAL_SERVICE_MQH__
