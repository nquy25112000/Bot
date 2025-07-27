#ifndef __DCA_UTIL_MQH__
#define __DCA_UTIL_MQH__

// Thêm phần tử vào mảng PositiveTicket
void AddPositiveTicketToArray(PositiveTicket& arr[], const PositiveTicket& value) {
  int size = ArraySize(arr);
  ArrayResize(arr, size + 1);
  arr[size] = value;
}

// đặt lệnh STOP DCA thuận xu hướng
ulong orderStopFollowTrend(double entry) {
  double entryStop = orderTypeDailyBias == ORDER_TYPE_BUY ? entry + 1 : entry - 1;
  // check xem trong mảng DCA dương có lệnh nào đang active stop với giá này không, nếu có thì không vào lệnh mà trả về ID ticket đó luôn
  for(uint i = 0; i < m_positiveTickets.Size(); i++){
      PositiveTicket ticket = m_positiveTickets[i];
      if(ticket.price == entryStop && ticket.state != STATE_CLOSE){
         return ticket.ticketId;
      }
  } 
  
  ulong ticketId;
  if (orderTypeDailyBias == ORDER_TYPE_BUY) {
    ticketId = PlaceOrder(ORDER_TYPE_BUY_STOP, entryStop, dcaPositiveVol, 0, 0);
  } else {
    ticketId = PlaceOrder(ORDER_TYPE_SELL_STOP, entryStop, dcaPositiveVol, 0, 0);
  }
 
  
  PositiveTicket ticket = {
     ticketId,
     dcaPositiveVol,
     STATE_ACTIVE_STOP_DCA,
     entryStop
  };
  AddPositiveTicketToArray(m_positiveTickets, ticket);
  return ticketId;
}

#endif // __DCA_UTIL_MQH__
