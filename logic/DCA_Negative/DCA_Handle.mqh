#ifndef __DCA_NEGATIVE_HANDLE_MQH__
#define __DCA_NEGATIVE_HANDLE_MQH__

void initDCANegative(double currentPrice) {
    ArrayResize(m_tickets, 0);
    ArrayResize(m_tickets, ArraySize(m_volumes));
    priceFirstEntryDailyBias = currentPrice;
    // Khởi tạo lệnh đầu tiên
    double tp = CalcTP(currentPrice, m_volumes[0], 0);
    ulong ticketId = PlaceOrder(orderTypeDailyBias, currentPrice, m_volumes[0], 0, tp);
    TicketInfo firstTicket = {
      ticketId,
      m_volumes[0],
      STATE_OPEN,
      currentPrice,
      0
    };
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


  int beautifulEntryIndex = 2;
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

  // Clear lệnh xấu từ beautifulEntryIndex trở về trước => DONE
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

  if (isUpdateTP) {
    updateTpForOpenTicket();
  }
}


#endif // __DCA_NEGATIVE_HANDLE_MQH__