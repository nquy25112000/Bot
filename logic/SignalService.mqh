#ifndef __SIGNAL_SERVICE_MQH__
#define __SIGNAL_SERVICE_MQH__

//-------------------------------------------------------------
// Khởi động chiến lược Daily Bias:
// Tạo lệnh đầu tiên và thiết lập các lệnh chờ (trạng thái WAITING_STOP)
//-------------------------------------------------------------
void startBias() {
  clearData();

  orderTypeBias = getBiasOrderTypeByHour(scanHour); // BUY hoặc SELL
  printf("TYPE BIAS: %s, orderTypeBias: %d", biasType, orderTypeBias);
  if (orderTypeBias == -1) {
    datetime now = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(now, dt);
    scanHour = dt.hour + 1; // nếu không có signal gì thì scanHour + 1 cho giờ tiếp theo tiếp tục quét
    return;
  }
  isRunningBIAS = true;
  // Khởi tạo DCA âm
  initDCANegative();
  // Khởi tạo lệnh STOP cách lệnh đầu tiên 2 giá thuận xu hướng. priceInitEntry là price đã được set cho lệnh đầu tiên DCA âm tại hàm initDCANegative();
  orderStopFollowTrend(orderTypeBias == ORDER_TYPE_BUY ? priceInitEntry + 1: priceInitEntry - 1); // hàm này nó cộng sẵn 1 rồi nên chỉ cần truyền priceInitEntry + 1
  initTargetCentList();
}

#endif // __SIGNAL_SERVICE_MQH__
