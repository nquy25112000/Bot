#ifndef __DCA_NEGATIVE_UPDATE_MQH__
#define __DCA_NEGATIVE_UPDATE_MQH__

void updateTpForOpenTicket() {
  double sumVolumeOpen = 0;
  double sumPriceOpen  = 0;

  // Tính tổng volume và weighted price
  for (uint i = 0; i < m_tickets.Size(); i++) {
    TicketInfo ti = m_tickets[i];
    if (ti.state == STATE_OPEN || ti.state == STATE_ACTIVE_STOP) {
      sumVolumeOpen += ti.volume;
      sumPriceOpen  += ti.price * ti.volume;
    }
  }

  double averagePrice = sumPriceOpen / sumVolumeOpen;
  double tp           = CalcTP(averagePrice, sumVolumeOpen, negativeTicketIndex);

  // Update TP và in log gọn
  for (uint i = 0; i < m_tickets.Size(); i++) {
    TicketInfo ti = m_tickets[i];
    bool res;
    string stateStr = (ti.state == STATE_ACTIVE_STOP ? "STOP" : "OPEN");

    if (ti.state == STATE_ACTIVE_STOP) {
      res = trade.OrderModify(ti.ticketId, ti.price, 0, tp, ORDER_TIME_GTC, 0, 0);
    }
    else if (ti.state == STATE_OPEN) {
      res = trade.PositionModify(ti.ticketId, 0, tp);
    }
    else {
      continue;
    }

    // 1 print duy nhất cho cả success & fail
    PrintFormat("%s cập nhật TP cho ticket %d [%s] → TP=%.3f%s",
                res ? "✅" : "❌",
                ti.ticketId,
                stateStr,
                tp,
                res ? "" : " (thất bại)");
  }
}

#endif // __DCA_NEGATIVE_UPDATE_MQH__