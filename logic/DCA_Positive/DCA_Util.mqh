#ifndef __DCA_UTIL_MQH__
#define __DCA_UTIL_MQH__

// Thêm phần tử vào mảng PositiveTicket
void AddPositiveTicketToArray(TicketInfo& arr[], const TicketInfo& value) {
  int size = ArraySize(arr);
  ArrayResize(arr, size + 1);
  arr[size] = value;
}

// đặt lệnh STOP DCA thuận xu hướng
ulong orderStopFollowTrend(double entry) {


  double entryStop = orderTypeBias == ORDER_TYPE_BUY ? entry + 1 : entry - 1;

  // check xem trong mảng DCA dương có lệnh nào đang active stop với giá này không, nếu có thì không vào lệnh mà trả về ID ticket đó luôn
  for (uint i = 0; i < posTicketList.Size(); i++) {
    TicketInfo ticket;
    ticket = posTicketList[i];
    if (ticket.price == entryStop && ticket.state != STATE_CLOSE) {
      return ticket.ticketId;
    }
  }

  ulong ticketId;
  if (orderTypeBias == ORDER_TYPE_BUY) {
    ticketId = PlaceOrder(ORDER_TYPE_BUY_STOP, entryStop, dcaPositiveVol, 0, 0);
  }
  else {
    ticketId = PlaceOrder(ORDER_TYPE_SELL_STOP, entryStop, dcaPositiveVol, 0, 0);
  }


  TicketInfo ticket = {
     ticketId,
     dcaPositiveVol,
     STATE_ACTIVE_STOP_DCA,
     entryStop
  };
  AddPositiveTicketToArray(posTicketList, ticket);

  return ticketId;
}

#endif // __DCA_UTIL_MQH__
