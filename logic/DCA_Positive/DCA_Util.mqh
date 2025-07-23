#ifndef __DCA_UTIL_MQH__
#define __DCA_UTIL_MQH__

#include "../../common/Globals.mqh"
#include "../../data/MarketDataService.mqh"

// Thêm phần tử vào mảng PositiveTicket
void AddPositiveTicketToArray(PositiveTicket& arr[], const PositiveTicket& value) {
  int size = ArraySize(arr);
  ArrayResize(arr, size + 1);
  arr[size] = value;
}

// đặt lệnh STOP DCA thuận xu hướng
void orderStopFollowTrend(double entry) {
  double entryStop;
  ulong ticketId;
  if (orderTypeDailyBias == ORDER_TYPE_BUY) {
    entryStop = entry + 1;
    ticketId = PlaceOrder(ORDER_TYPE_BUY_STOP, entryStop, dcaPositiveVol, 0, 0);
  } else {
    entryStop = entry - 1;
    ticketId = PlaceOrder(ORDER_TYPE_SELL_STOP, entryStop, dcaPositiveVol, 0, 0);
  }
  PositiveTicket ticket = {
     ticketId,
     dcaPositiveVol,
     STATE_ACTIVE_STOP_DCA,
     entryStop
  };
  AddPositiveTicketToArray(m_positiveTickets, ticket);
}

#endif // __DCA_UTIL_MQH__
