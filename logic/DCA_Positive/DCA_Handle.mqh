#ifndef __DCA_HANDLE_MQH__
#define __DCA_HANDLE_MQH__

// Hàm handle lệnh DCA Dương
// logic
// ta có 3 điểm 3005 3006 và 3007
// nếu đã có 1 lệnh BUY đã vào lệnh là 3305 -> giá chạm 3306 thì đặt BUY STOP ở 3307, đồng thời dời SL của 3305 về 3305.5
// tiếp tục nếu gá chạm 3307 thi đặt 1 lệnh BUY STOP ở 3308 đồng thời dời SL của 3305 và 3306 lên 3306.5
void handleDCAPositive(ulong ticketId) {
  double entryToNextAction = 0;
  for (uint i = 0; i < m_positiveTickets.Size(); i++) {
    TicketInfo ticket = m_positiveTickets[i];
    if (ticket.ticketId == ticketId) {
      ticket.state = STATE_OPEN_DCA;
      m_positiveTickets[i] = ticket;
      entryToNextAction = ticket.price;
      // khớp lệnh stop thuận hướng thì đặt 1 lệnh stop ngược hướng
      orderFrozenByTicketId(ticketId);
      break;
    }
  }
  // không khớp lệnh nào khớp, không có hành động tiếp theo
  if (entryToNextAction == 0) return;
  // gọi isOnlyFirst trước khi gọi orderStopFollowTrend bởi vì orderStopFollowTrend sẽ thêm 1 phần tử vào mảng
  bool isOnlyFirst = m_positiveTickets.Size() == 1;
  orderStopFollowTrend(entryToNextAction);
  // nếu vô hàm này mà mảng chỉ có 1 phần tử thì có nghĩa là khớp lệnh lần đầu tiên nên return chứ k có step dời SL
  if (isOnlyFirst) {
    return;
  }

  // khi mảng m_positiveTickets có 2 phần tử trở lên nghĩa là lệnh cao nhất đã khớp, khớp thì dời sl lệnh thấp về giá của lệnh cao nhất - 0.5 giá
  for (uint i = 0; i < m_positiveTickets.Size(); i++) {
    TicketInfo ticket = m_positiveTickets[i];
    double sl = 0;
    if (ticket.state == STATE_OPEN_DCA && !isExistsFrozenOpen(ticket.ticketId)) { // test chỉ set sl cho những lệnh có frozen chưa OPEN -> lợi nhuận ổn định hơn. 1/1/2025 - 6/6/2025 = 76.343 đồng
      if (orderTypeDailyBias == ORDER_TYPE_BUY && ticket.price < entryToNextAction) {
        // nếu lần đầu DCA dương thì SL của từng lệnh sẽ là giá vào lệnh cộng nửa giá
        // còn nếu không phải lần đầu thì lấy giá của lệnh vừa khớp ở trên cao trừ cho nửa giá
        sl = checkFirstDCAPositive() ? (ticket.price + 0.5) : (entryToNextAction - 0.5);
      }
      else if(orderTypeDailyBias == ORDER_TYPE_SELL && ticket.price > entryToNextAction) {
        // với sell thì ngược lại cái trên
        sl = checkFirstDCAPositive() ? (ticket.price - 0.5) : (entryToNextAction + 0.5);
      }
    }
    if(sl != 0){
      if(trade.PositionModify(ticket.ticketId, sl, 0)){
         m_positiveTickets[i] = ticket;
         // lệnh nào set SL thành công thì close lệnh sell stop frozen đi, còn lệnh nào đang open rồi là nó đang vào lệnh không close nó
         // tại vì chỉ frozen cho lệnh cao nhất, khi đã vào set SL cho lệnh thấp nghĩa là lệnh cao nhất đã được mở và đã có frozen, lệnh này k frozen nữa
         closeFrozenActiveStopByTicketId(ticket.ticketId);
      }
    }
  }
}

bool checkFirstDCAPositive() {
   if (m_positiveTickets.Size() < 2) return true;
   // phần tử đầu tiên của mảng luôn luôn là lệnh DCA Dương đầu tiên trong ngày.
   // check DCA lần 2 bằng cách check xem thử trong mảng còn phần tử nào có price bằng với price của lệnh đầu DCA dương đầu tiên hay k
   // nếu có thì chắc chắn giá đã từng tuột xuống dưới mảng DCA âm và đã order 1 lệnh DCA Dương lại
   // trong hàm scanDCANegative sẽ thực hiện order 1 ticket DCA dương nếu đủ điều kiện
   TicketInfo ticket = m_positiveTickets[0];
   for(uint i = 1; i < m_positiveTickets.Size(); i++) {
      TicketInfo nextTicket = m_positiveTickets[i];
      if(ticket.price == nextTicket.price) {
         return false;
      }
   }
   return true;
}


#endif // __DCA_HANDLE_MQH__
