#ifndef __UPDATETICKETINFO_MQH__
#define __UPDATETICKETINFO_MQH__

// hàm update lại price khi khớp lệnh và state cho nó. bởi vì có thể trượt giá khớp lệnh
void updateTicketInfo(ulong ticketId, double price) {
  for (uint i = 0; i < m_tickets.Size(); i++) {
    TicketInfo ticket = m_tickets[i];
    if (ticket.ticketId == ticketId) {
      ticket.state = STATE_OPEN;
      ticket.price = price;
      m_tickets[i] = ticket;
    }
  }
}

#endif // __UPDATETICKETINFO_MQH__
