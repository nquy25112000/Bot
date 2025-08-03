#ifndef __DCA_UTIL_MQH__
#define __DCA_UTIL_MQH__

// Thêm phần tử vào mảng PositiveTicket
void AddPositiveTicketToArray(TicketInfo& arr[], const TicketInfo& value) {
  int size = ArraySize(arr);
  ArrayResize(arr, size + 1);
  arr[size] = value;
}

// đặt lệnh STOP DCA thuận xu hướng
ulong orderStopFollowTrend(string biasType, double entry) {

  ENUM_ORDER_TYPE orderType = getBiasOrderType(biasType);

  double entryStop = orderType == ORDER_TYPE_BUY ? entry + 1 : entry - 1;

  TicketInfo positiveTicketByBiasType[];
  getBiasArray(POSITIVE_ARRAY, positiveTicketByBiasType);

  // check xem trong mảng DCA dương có lệnh nào đang active stop với giá này không, nếu có thì không vào lệnh mà trả về ID ticket đó luôn
  for (uint i = 0; i < positiveTicketByBiasType.Size(); i++) {
    TicketInfo ticket;
    ticket = positiveTicketByBiasType[i];
    if (ticket.price == entryStop && ticket.state != STATE_CLOSE) {
      return ticket.ticketId;
    }
  }

  ulong ticketId;
  if (orderType == ORDER_TYPE_BUY) {
    ticketId = PlaceOrder(ORDER_TYPE_BUY_STOP, entryStop, dcaPositiveVol, 0, 0);
  }
  else {
    ticketId = PlaceOrder(ORDER_TYPE_SELL_STOP, entryStop, dcaPositiveVol, 0, 0);
  }

  // thêm ticketId vào mảng id theo loại
  AddTicketIdByType(biasType, ticketId);


  TicketInfo ticket = {
     ticketId,
     dcaPositiveVol,
     STATE_ACTIVE_STOP_DCA,
     entryStop
  };
  AddPositiveTicketToArray(positiveTicketByBiasType, ticket);

  updateBiasArray(POSITIVE_ARRAY, positiveTicketByBiasType);
  return ticketId;
}

#endif // __DCA_UTIL_MQH__
