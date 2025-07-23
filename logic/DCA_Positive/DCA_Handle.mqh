#ifndef __DCA_HANDLE_MQH__
#define __DCA_HANDLE_MQH__

#include "../../common/Globals.mqh"
#include "../../data/MarketDataService.mqh"
#include "./DCA_Util.mqh"

// Hàm handle lệnh DCA Dương
// logic
// ta có 3 điểm 3005 3006 và 3007
// nếu đã có 1 lệnh BUY đã vào lệnh là 3305 -> giá chạm 3306 thì đặt BUY STOP ở 3307, đồng thời dời SL của 3305 về 3305.5
// tiếp tục nếu gá chạm 3307 thi đặt 1 lệnh BUY STOP ở 3308 đồng thời dời SL của 3305 và 3306 lên 3306.5
void handleDCAPositive(ulong ticketId) {
  double entryToNextAction = 0;
  bool isActiveStop = false;
  for (uint i = 0; i < m_positiveTickets.Size(); i++) {
    PositiveTicket ticket = m_positiveTickets[i];
    if (ticket.ticketId == ticketId) {
      ticket.state = STATE_OPEN_DCA;
      ticket.price = getCurrentPrice(orderTypeDailyBias);
      m_positiveTickets[i] = ticket;
      entryToNextAction = ticket.price;
      isActiveStop = true;
      break;
    }
  }
  if (!isActiveStop) return;

  bool isOnlyFirst = m_positiveTickets.Size() == 1;
  orderStopFollowTrend(entryToNextAction);
  if (isOnlyFirst) return;

  for (uint i = 0; i < m_positiveTickets.Size(); i++) {
    PositiveTicket ticket = m_positiveTickets[i];
    if (ticket.state == STATE_OPEN_DCA) {
      if (orderTypeDailyBias == ORDER_TYPE_BUY && ticket.price < entryToNextAction) {
        trade.PositionModify(ticket.ticketId, entryToNextAction - 0.5, 0);
      } else {
        trade.PositionModify(ticket.ticketId, entryToNextAction + 0.5, 0);
      }
    }
  }
}

#endif // __DCA_HANDLE_MQH__
