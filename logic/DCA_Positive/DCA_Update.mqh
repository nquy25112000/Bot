#ifndef __DCA_UPDATE_MQH__
#define __DCA_UPDATE_MQH__

#include "../common/Globals.mqh"

// Khi lệnh DCA SL thì gọi để update mảng thành CLOSE để khỏi quét qua lại nhiều lần
void updateStateCloseDCAPositive(ulong ticketId) {
  for (uint i = 0; i < m_positiveTickets.Size(); i++) {
    PositiveTicket ticket = m_positiveTickets[i];
    if (ticket.ticketId == ticketId) {
      ticket.state = STATE_CLOSE;
      m_positiveTickets[i] = ticket;
    }
  }
}

#endif // __DCA_UPDATE_MQH__
