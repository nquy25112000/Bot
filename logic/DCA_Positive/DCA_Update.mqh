#ifndef __DCA_UPDATE_MQH__
#define __DCA_UPDATE_MQH__

// Khi lệnh DCA SL thì gọi để update mảng thành CLOSE để khỏi quét qua lại nhiều lần
void updateStateCloseDCAPositive(ulong ticketId) {
  for (uint i = 0; i < dailyBiasPositive.Size(); i++) {
    TicketInfo ticket = dailyBiasPositive[i];
    if (ticket.ticketId == ticketId) {
      ticket.state = STATE_CLOSE;
      dailyBiasPositive[i] = ticket;
    }
  }
}

#endif // __DCA_UPDATE_MQH__
