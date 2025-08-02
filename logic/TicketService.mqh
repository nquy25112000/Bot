#ifndef __TICKET_SERVICE_MQH__
#define __TICKET_SERVICE_MQH__

//--------------------------------------------------------------------------
// TicketOnTradeTransaction
// -------------------------------------------------------------------------
// Mục đích:
//   - Bắt sự kiện giao dịch xảy ra (deal được thêm vào lịch sử)
//   - Nếu lý do của deal là "Take Profit" (DEAL_REASON_TP),
//     (Tức là đã chốt lời, không cần tạo thêm lệnh nào nữa)
//
// Params:
//   - trans: thông tin giao dịch (deal) vừa xảy ra
//   - req: yêu cầu gửi lệnh (không dùng trong logic này)
//   - res: kết quả thực thi lệnh (không dùng trong logic này)
//--------------------------------------------------------------------------
void TicketOnTradeTransaction(const MqlTradeTransaction& trans,
   const MqlTradeRequest& req,
   const MqlTradeResult& res)
{

   if (trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong deal_ticket = trans.deal;
      if (HistoryDealSelect(deal_ticket))
      {
         ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(deal_ticket, DEAL_REASON);
         if (reason == DEAL_REASON_TP) {
            double targetCentDailyBias = getTargetCentDailyBias(negativeTicketIndex);
            double totalProfitFromTime = GetTotalProfitFrom(dailyBiasStartTime);
            CloseAllOrders();
            // tổng lợi nhuận từ lúc start dailyBias lớn hơn targetCentDailyBias dù còn lệnh frozen thì đóng tất cả luôn
            if(totalProfitFromTime >= targetCentDailyBias){
               CloseAllPosition();
               dailyBiasRuning = 0;
            } else {
               // đoạn này kích hoạt hedging cho các lệnh frozen nếu còn lệnh nhưng chưa có logic hedging thì tạm đóng all lệnh và ngừng dailybias
               ArrayFree(negTicketList);
               ArrayFree(posTicketList);
               CloseAllPosition();
               dailyBiasRuning = 0;
            }
         }
         else if (reason == DEAL_REASON_SL) {
            // update state cho các lệnh DCA
            updateStateCloseDCAPositive(trans.position);
            // SL các lệnh DCA thì update lại các lệnh còn mở hiện tại
            updateTpForOpenTicket();
         }
         ENUM_DEAL_TYPE type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
         ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
         if ((type == DEAL_TYPE_BUY || type == DEAL_TYPE_SELL) && entry == DEAL_ENTRY_IN)
         {
            handleDCAPositive(trans.position);
            updateTicketInfo(trans.position, trans.price);
            updateFrozenInfo(trans.position);
            updateTpForOpenTicket();
         }
      }
   }
}

#endif // __TICKET_SERVICE_MQH__
