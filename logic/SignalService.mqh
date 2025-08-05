#ifndef __SIGNAL_SERVICE_MQH__
#define __SIGNAL_SERVICE_MQH__

//-------------------------------------------------------------
// Khởi động chiến lược Daily Bias:
// Tạo lệnh đầu tiên và thiết lập các lệnh chờ (trạng thái WAITING_STOP)
//-------------------------------------------------------------
void startBias() {
  clearData();
  
  //orderTypeBias = getBiasOrderType(BIAS_TF_D1); // BUY hoặc SELL
  orderTypeBias = getOrder();
  printf("TYPE BIAS: %s, orderTypeByBiasType: %d", biasType, orderTypeBias);
  //if (orderTypeBias == NULL) {
    //return;
  //}
  isRunningBIAS = true;
  // Khởi tạo DCA âm
  initDCANegative();
  // Khởi tạo lệnh STOP cách lệnh đầu tiên 2 giá thuận xu hướng. priceInitEntry là price đã được set cho lệnh đầu tiên DCA âm tại hàm initDCANegative();
  orderStopFollowTrend(orderTypeBias == ORDER_TYPE_BUY ? priceInitEntry + 1: priceInitEntry - 1); // hàm này nó cộng sẵn 1 rồi nên chỉ cần truyền priceInitEntry + 1
}

#endif // __SIGNAL_SERVICE_MQH__
