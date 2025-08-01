#ifndef __DCA_NEGATIVE_UPDATE_MQH__
#define __DCA_NEGATIVE_UPDATE_MQH__


void updateTpForOpenTicket() { 

  /*//  chỉ tính cho DCA âm
  // sumVolumeOpen tính tổng vol của các lệnh đang mở và lệnh ACTIVE_STOP
  double sumVolumeOpen = 0; // (vol₁ + vol₂ + ... + volₙ)
  // sumPriceOpen tổng giá * vol của các lệnh đang mở và lệnh ACTIVE_STOP
  double sumPriceOpen = 0; // (price₁ × vol₁ + price₂ × vol₂ + ... + priceₙ × volₙ)

  for (uint i = 0; i < dailyBiasNegative.Size(); i++) {
    TicketInfo ticketInfo = dailyBiasNegative[i];
    if (ticketInfo.state == STATE_OPEN || ticketInfo.state == STATE_ACTIVE_STOP) {
      sumVolumeOpen += ticketInfo.volume;
      sumPriceOpen += ticketInfo.price * ticketInfo.volume;
    }
  }


  // Giá Trung Bình = (price₁ × vol₁ + price₂ × vol₂ + ... + priceₙ × volₙ) / (vol₁ + vol₂ + ... + volₙ)
  double averagePrice = sumPriceOpen / sumVolumeOpen;
  double tp = CalcTP(averagePrice, sumVolumeOpen, negativeTicketIndex);
  for (uint i = 0; i < dailyBiasNegative.Size(); i++) {
    TicketInfo ticketInfo = dailyBiasNegative[i];
    if (ticketInfo.state == STATE_ACTIVE_STOP) {
      if (trade.OrderModify(ticketInfo.ticketId, ticketInfo.price, 0, tp, ORDER_TIME_GTC, 0, 0)) {
        Print("✅ đã update tp cho lệnh stop với ticket: ", ticketInfo.ticketId, " với tp là: ", tp);
      }
      else {
        Print("❌ có lỗi khi update tp cho lệnh stop với ticket: ", ticketInfo.ticketId);
      }
    }
    if (ticketInfo.state == STATE_OPEN) {
      if (trade.PositionModify(ticketInfo.ticketId, 0, tp)) {
        Print("✅ đã update tp cho ticket: ", ticketInfo.ticketId, " với tp là: ", tp);
      }
      else {
        Print("❌ có lỗi khi update tp cho ticket: ", ticketInfo.ticketId);
      }
    }
  }*/
  
  
  // tính TP và update TP cho tất cả lệnh đang mở cùng chiều daily bias

  double sumVolumeOpen = 0; // (vol₁ + vol₂ + ... + volₙ)
  double sumPriceOpen = 0; // (price₁ × vol₁ + price₂ × vol₂ + ... + priceₙ × volₙ)
  int total = PositionsTotal();
  if(total == 0){
   return;
  }

  for (int i = 0; i < total; i++) {
    ulong ticket = PositionGetTicket(i);
      
    if (PositionSelectByTicket(ticket)) {
      ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ENUM_ORDER_TYPE orderType = positionTypeToOrderType(positionType);
      // chỉ lấy lệnh cùng chiều daily bias
      if(orderType == orderTypeDailyBias){
         sumVolumeOpen += PositionGetDouble(POSITION_VOLUME);
         sumPriceOpen += PositionGetDouble(POSITION_PRICE_OPEN) * PositionGetDouble(POSITION_VOLUME);
      }
      
    }
  }
  
  double averagePrice = sumPriceOpen / sumVolumeOpen;
  double tp = CalcTP(averagePrice, sumVolumeOpen, negativeTicketIndex);
  
  
  for (int i = 0; i < total; i++) {
    ulong ticket = PositionGetTicket(i);
    
    if (PositionSelectByTicket(ticket)) {
      ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ENUM_ORDER_TYPE orderType = positionTypeToOrderType(positionType);
      // chỉ lấy lệnh cùng chiều daily bias
      if(orderType == orderTypeDailyBias){
         double old_sl = PositionGetDouble(POSITION_SL);
         trade.PositionModify(ticket, old_sl, tp);
      }
    }
  }
}

ENUM_ORDER_TYPE positionTypeToOrderType(ENUM_POSITION_TYPE positionType) {
   if(positionType == POSITION_TYPE_BUY) {
      return ORDER_TYPE_BUY;
   }
   return ORDER_TYPE_SELL;
}

// hàm update lại price khi khớp lệnh và state cho nó. bởi vì có thể trượt giá khớp lệnh
void updateTicketInfo(ulong ticketId, double price) {
  for (uint i = 0; i < dailyBiasNegative.Size(); i++) {
    TicketInfo ticket = dailyBiasNegative[i];
    if (ticket.ticketId == ticketId) {
      ticket.state = STATE_OPEN;
      ticket.price = price;
      dailyBiasNegative[i] = ticket;
    }
  }
}
#endif // __DCA_NEGATIVE_UPDATE_MQH__