#ifndef __FROZEN_HANDLE_MQH__
#define __FROZEN_HANDLE_MQH__

void orderFrozenByTicketId(ulong frozenByTicketId){
   ulong ticketId;
    if (orderTypeDailyBias == ORDER_TYPE_BUY) { // frozen thì ngược lại xu hướng để đóng băng
      ticketId = PlaceOrder(ORDER_TYPE_SELL_STOP, priceFirstEntryDailyBias, dcaPositiveVol, 0, 0); // dùng đúng vol đã vào lệnh DCA dương
    }
    else {
      ticketId = PlaceOrder(ORDER_TYPE_BUY_STOP, priceFirstEntryDailyBias, dcaPositiveVol, 0, 0);
    }
    TicketInfo ticket = {
     ticketId,
     dcaPositiveVol,
     STATE_ACTIVE_FROZEN,
     priceFirstEntryDailyBias,
     0,
     frozenByTicketId,
    };
    AddFrozenTicketToArray(m_frozenTickets, ticket);
}

// đóng lệnh frozen và update lại state cho nó là close
void closeFrozenActiveStopByTicketId(ulong frozenByTicketId){
   for(uint i = 0; i < m_frozenTickets.Size(); i++){
      TicketInfo ticket = m_frozenTickets[i];
      if(frozenByTicketId == ticket.frozenByTicketId && ticket.state == STATE_ACTIVE_FROZEN){
         CloseByTicket(ticket.ticketId);
         ticket.state = STATE_CLOSE;
         m_frozenTickets[i] = ticket;
      }
   }
}

// đóng tất cả lệnh frozentTicket;
void closeAllFrozenTicket(){
   for(uint i = 0; i < m_frozenTickets.Size(); i++){
      TicketInfo ticket = m_frozenTickets[i];
      if(ticket.state == STATE_OPEN_FROZEN){
         CloseByTicket(ticket.ticketId);
         ticket.state = STATE_CLOSE;
         m_frozenTickets[i] = ticket;
      }
   }
}

// update lại state khi khớp lệnh frozen
void updateFrozenInfo(ulong ticketId){
   for(uint i = 0; i < m_frozenTickets.Size(); i++){
      TicketInfo ticket = m_frozenTickets[i];
      if(ticket.ticketId == ticketId){
         ticket.state = STATE_OPEN_FROZEN;
         m_frozenTickets[i] = ticket;
      }
   }
}

// Thêm phần tử vào mảng FrozenTicket
void AddFrozenTicketToArray(TicketInfo& arr[], const TicketInfo& value) {
  int size = ArraySize(arr);
  ArrayResize(arr, size + 1);
  arr[size] = value;
}

// check xem thử ticketDCA có frozen nào đang open không
bool isExistsFrozenOpen(double frozenByTicketId){
   for(uint i = 0; i < m_frozenTickets.Size(); i++){
      TicketInfo ticket = m_frozenTickets[i];
      if(ticket.frozenByTicketId == frozenByTicketId && ticket.state == STATE_OPEN_FROZEN){
         return true;
      }
   }
   return false;
}

#endif // __FROZEN_HANDLE_MQH__
