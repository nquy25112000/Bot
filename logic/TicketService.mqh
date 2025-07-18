#ifndef __TICKET_SERVICE_MQH__
#define __TICKET_SERVICE_MQH__
#include "../common/Globals.mqh"

void TicketInit()
{
   ticketCount = 0;
}

void TicketOnTradeTransaction(const MqlTradeTransaction &trans,
                              const MqlTradeRequest     &req,
                              const MqlTradeResult      &res)
{
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD &&
      HistoryDealGetInteger(trans.deal, DEAL_ENTRY)==DEAL_ENTRY_OUT &&
      HistoryDealGetInteger(trans.deal, DEAL_REASON)==DEAL_REASON_TP)
   {
      ulong pos = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
      for(int i=0;i<ticketCount;i++)
         if(m_tickets[i].ticketId==pos)
            m_tickets[i].state = STATE_CLOSE;
   }
}

void UpdateTickets()
{
   for(int i=0;i<ticketCount;i++)
   {
      if(m_tickets[i].state == STATE_CLOSE)
      {
         m_tickets[i] = m_tickets[--ticketCount];
         i--;
      }
   }
}

#endif // __TICKET_SERVICE_MQH__
