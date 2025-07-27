#ifndef __DCA_NEGATIVE_HANDLE_MQH__
#define __DCA_NEGATIVE_HANDLE_MQH__

void initDCANegative(double currentPrice) {
    ArrayResize(m_tickets, 0);
    ArrayResize(m_tickets, ArraySize(m_volumes));
    priceFirstEntryDailyBias = currentPrice;
    // Khởi tạo lệnh đầu tiên
    double tp = CalcTP(currentPrice, m_volumes[0], 0);
    ulong ticketId = PlaceOrder(orderTypeDailyBias, 0.0, m_volumes[0], 0, tp);
    TicketInfo firstTicket = {
      ticketId,
      m_volumes[0],
      STATE_OPEN,
      currentPrice,
      0
    };

    if(PositionSelectByTicket(ticketId))
    currentPrice = PositionGetDouble(POSITION_PRICE_OPEN);

    m_tickets[0] = firstTicket;
    priceFirstEntryDailyBias = currentPrice;

    for (int i = 1; i < ArraySize(m_volumes); i++) {
        double price;
        double activePrice;
        int gap = i * jump;
        if (orderTypeDailyBias == ORDER_TYPE_BUY) {
            price = currentPrice - gap;
            activePrice = price - jump;
        }
        else {
            price = currentPrice + gap;
            activePrice = price + jump;
        }
        double volume = m_volumes[i];
        TicketInfo firstTicket = {
           0,
           volume,
           STATE_WAITING_STOP,
           price,
           activePrice
        };
        m_tickets[i] = firstTicket;
    }

    for (uint i = 0; i < m_tickets.Size();i++) {
        TicketInfo ticket = m_tickets[i];
        string ticketFormat = StringFormat("DCA Âm %i %s %.2f %.3f %.3f", ticket.ticketId, ticket.state, ticket.volume, ticket.price, ticket.activePrice);
        Print(ticketFormat);
    }
}

//-------------------------------------------------------------
// Quét các điều kiện kích hoạt chiến lược Daily Bias:
// - Kiểm tra xem có nên kích hoạt lệnh STOP không
// - Cập nhật TP nếu có lệnh mới được kích hoạt
// - Loại bỏ lệnh không còn đẹp
//-------------------------------------------------------------
void scanDCANegative() { // tên cũ nó là scanDailyBias
  double currentPrice = getCurrentPrice(orderTypeDailyBias);

  // Giá hiện tại đi thuận xu hướng thì thoát chứ không có quét qua mảng giá âm
  if ((orderTypeDailyBias == ORDER_TYPE_BUY && currentPrice > priceFirstEntryDailyBias)
    || (orderTypeDailyBias == ORDER_TYPE_SELL && currentPrice < priceFirstEntryDailyBias)) {
    return;
  }

  // khi nó đang DCA dương mà quay về mảng giá âm thì luôn luôn có 1 lệnh DCA stop ở trên cao chưa khớp. -> nên close nó
  // ví dụ khi khớp lệnh buy stop DCA dương ở 3333

  int beautifulEntryIndex = 0;
  // totalVolume để tính tổng vol của các lệnh trước đó gộp lại cho lệnh ở vị trí đẹp nhất
  double totalVolume = 0;
  // ACTIVE_STOP thì sẽ update lại TP
  bool isUpdateTP = false;
  // Scan qua mảng giá đã tạo rồi active lệnh khớp với điều kiện currentPrice <= ticketInfo.activePrice => DONE
  for (uint i = 1;i < m_tickets.Size(); i++)
  {
    TicketInfo ticketInfo = m_tickets[i];
    totalVolume = totalVolume + ticketInfo.volume;
    if (ticketInfo.state == STATE_OPEN) {
      totalVolume = 0; // tại vì nếu đã thuộc OPEN hoặc ACTIVE_STOP thì những lệnh phía trên nó đã được gộp vol vô lệnh này nên set 0 bắt đầu lại
      continue;
    }
    if (ticketInfo.state == STATE_ACTIVE_STOP) {
      totalVolume = ticketInfo.volume; // nếu là active stop nghĩa là đối tượng này đã được cộng tổng vol của những đối tượng trước nó thì trả về vol
      continue;
    }
    if (currentPrice <= ticketInfo.activePrice && ticketInfo.state == STATE_WAITING_STOP) {
      beautifulEntryIndex = (int)i;
      negativeTicketIndex = beautifulEntryIndex;
      ticketInfo.ticketId = PlaceOrder(ORDER_TYPE_BUY_STOP, ticketInfo.price, totalVolume, 0, 0);
      ticketInfo.state = STATE_ACTIVE_STOP;
      ticketInfo.volume = totalVolume;
      m_tickets[i] = ticketInfo;
      isUpdateTP = true;
      break;
    }
  }

  // m_tickets[1] là phần tử thứ 2 ở mảng DCA âm
  // nếu state nó OPEN nghĩa là mảng DCA âm tồn tại 1 ticket open -> đủ điều kiện order lại DCA dương
  // nếu state là ACTIVE_STOP nghĩa là nó chắc chắn sẽ khớp tại đó hoặc sẽ khớp lệnh ở 1 vị trí đẹp hơn phía dưới -> đủ điều kiện
  // nếu state là SKIP nghĩa là nó đã quét qua và khớp lệnh đẹp hơn phía dưới rồi -> đủ điều kiện
  // nếu state là CLOSE nghĩa là nó đã đạt đủ target ngày, đạt đủ rồi thì không cần DCA dương gì nữa -> đủ điều kiện

  // check thêm 1 điều kiện nữa là có lệnh DCA dương nào tại điểm priceFirstEntryDailyBias + 1 không để khỏi vô lệnh DCA dương nhiều lần
  TicketInfo ticket1 = m_tickets[1];
  if(ticket1.state != STATE_WAITING_STOP) {
      bool isNotExistsDCAEntry = true;
      for(uint i = 0; i < m_positiveTickets.Size(); i++){
         TicketInfo ticket = m_positiveTickets[i];
         // nếu có 1 phần tử tại (priceFirstEntryDailyBias + 2) và state nó khác close nghĩa là đang có lệnh DCA dương ở (priceFirstEntryDailyBias + 1) rồi
         double entryDCAFirstPrice = priceFirstEntryDailyBias + 2; // + 2 bởi vì entry DCA đầu tiên cách entry của lệnh đầu ngày 2 giá
         if(ticket.price == entryDCAFirstPrice && ticket.state != STATE_CLOSE){
            isNotExistsDCAEntry = false;
            break;
         }
      }
      // không tồn tại entry DCA nào đang active ở điểm start DCA dương (isNotExistsDCAEntry = true) thì mới vào lại lệnh DCA dương
      if(isNotExistsDCAEntry){
         orderStopFollowTrend(priceFirstEntryDailyBias + 1);
      }
  }

  // close tất cả lệnh frozen nếu entry xuống tới 11
  if(beautifulEntryIndex >= 10){
      closeAllFrozenTicket();
  }

  // Clear lệnh xấu từ beautifulEntryIndex trở về trước => DONE
  if(beautifulEntryIndex >= 2){
     for (int i = 1; i < beautifulEntryIndex; i++) {
       TicketInfo info = m_tickets[i];
       if (info.state != STATE_OPEN) {
         if (info.state == STATE_ACTIVE_STOP) {
           CloseByTicket(info.ticketId);
         }
         info.state = STATE_SKIP;
         m_tickets[i] = info;
       }
     }
  }

  // test chạy khỏi update TP luôn vì đang gặp phải issue
  // ở BiasBot ra điều kiện >= 900 thì đóng tất cả lệnh
  // nhưng trong mảng DCA âm này nó chưa chạm tới điểm 11 thì nó chỉ update TP ăn 630 đồng
  // sau khi ăn 630 đồng thì nó close tất cả các lệnh DCA âm đang mở, những điểm chưa mở ở dưới thấp hơn 11 thì vẫn còn đó
  // ở BiasBot ra điều kiện >= 900 thì mới đóng tất cả các lệnh để đánh done cho lần bias ngày hôm đó, nó chưa đóng dẫn đến giá lại scan qua mảng DCA âm
  // nó chạm điểm dưới thấp hơn 11 -> code update lại TP. update lại 1 lệnh với tp 720 hoặc 900 thì tp nó rất là xa, lủng logic
  // reprodure lại bằng cách đặt 1 con bug vô Print("❌ có lỗi khi update tp cho ticket: ", ticketInfo.ticketId); rồi chạy từ 1/1/2025
  // hoặc là phải có cơ chế đặt TP cho tất cả các lệnh cả DCA âm lẫn dương, hoặc là cứ tắt update tp cứ chạy đủ 900 thì dừng
  /*
  if (isUpdateTP) {
    updateTpForOpenTicket();
  } */
}


#endif // __DCA_NEGATIVE_HANDLE_MQH__