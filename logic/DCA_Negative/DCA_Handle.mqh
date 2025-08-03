#ifndef __DCA_NEGATIVE_HANDLE_MQH__
#define __DCA_NEGATIVE_HANDLE_MQH__

void initDCANegative(string biasType) {

  // lấy mảng volume theo bias type
  double negativeVolumes[];
  GetVolumeNegativeByType(biasType, negativeVolumes);

  // tạo mảng ticket theo size của mảng volume
  TicketInfo ticketInfos[];
  ArrayResize(ticketInfos, ArraySize(negativeVolumes));

  ENUM_ORDER_TYPE orderType = getBiasOrderType(biasType);

  // Khởi tạo lệnh đầu tiên
  ulong ticketId = PlaceOrder(orderType, 0.0, negativeVolumes[0], 0, 0);

  double priceFirstEntry = priceInitEntry;
  if (PositionSelectByTicket(ticketId)) {
    priceFirstEntry = PositionGetDouble(POSITION_PRICE_OPEN);
  }

  TicketInfo firstTicket = {
    ticketId,
    negativeVolumes[0],
    STATE_OPEN,
    priceFirstEntry,
    0,
    -1
  };

  ticketInfos[0] = firstTicket;

  int jump = 1;
  for (int i = 1; i < ArraySize(negativeVolumes); i++) {
    double price;
    double activePrice;
    int gap = i * jump;
    if (orderTypeBias == ORDER_TYPE_BUY) {
      price = priceFirstEntry - gap;
      activePrice = price - jump;
    }
    else {
      price = priceFirstEntry + gap;
      activePrice = price + jump;
    }
    double volume = negativeVolumes[i];
    TicketInfo ticket = {
       0,
       volume,
       STATE_WAITING_STOP,
       price,
       activePrice
    };
    ticketInfos[i] = ticket;
  }

  for (uint i = 0; i < ticketInfos.Size();i++) {
    TicketInfo ticket;
    ticket = ticketInfos[i];
    string ticketFormat = StringFormat("DCA Âm %i %s %.2f %.3f %.3f", ticket.ticketId, ticket.state, ticket.volume, ticket.price, ticket.activePrice);
    Print(ticketFormat);
  }

  // update lại mảng toàn cục negative cho bias type
  updateBiasArray(NEGATIVE_ARRAY, ticketInfos);
}

//-------------------------------------------------------------
// Quét các điều kiện kích hoạt chiến lược Daily Bias:
// - Kiểm tra xem có nên kích hoạt lệnh STOP không
// - Cập nhật TP nếu có lệnh mới được kích hoạt
// - Loại bỏ lệnh không còn đẹp
//-------------------------------------------------------------
void scanDCANegative(string biasType) { // tên cũ nó là scanDailyBias
  double currentPrice = getCurrentPrice(orderTypeBias);

  ENUM_ORDER_TYPE orderTypeByBiasType = getBiasOrderType(biasType);
  double firstEntryByBiasType = priceInitEntry;
  // Giá hiện tại đi thuận xu hướng thì thoát chứ không có quét qua mảng giá âm
  if ((orderTypeByBiasType == ORDER_TYPE_BUY && currentPrice > firstEntryByBiasType)
    || (orderTypeByBiasType == ORDER_TYPE_SELL && currentPrice < firstEntryByBiasType)) {
    return;
  }

  TicketInfo negativeTicketsByBiasType[];
  getBiasArray(NEGATIVE_ARRAY, negativeTicketsByBiasType);

  TicketInfo positiveTicketsByBiasType[];
  getBiasArray(POSITIVE_ARRAY, positiveTicketsByBiasType);

  int beautifulEntryIndex = 0;
  // totalVolume để tính tổng vol của các lệnh trước đó gộp lại cho lệnh ở vị trí đẹp nhất
  double totalVolume = 0;
  // ACTIVE_STOP thì sẽ update lại TP
  bool isUpdateTP = false;
  // Scan qua mảng giá đã tạo rồi active lệnh khớp với điều kiện currentPrice <= ticketInfo.activePrice => DONE
  for (uint i = 1;i < negativeTicketsByBiasType.Size(); i++)
  {
    TicketInfo ticketInfo;
    ticketInfo = negativeTicketsByBiasType[i];
    totalVolume = totalVolume + ticketInfo.volume;
    if (ticketInfo.state == STATE_OPEN) {
      totalVolume = 0; // tại vì nếu đã thuộc OPEN hoặc ACTIVE_STOP thì những lệnh phía trên nó đã được gộp vol vô lệnh này nên set 0 bắt đầu lại
      continue;
    }
    if (ticketInfo.state == STATE_ACTIVE_STOP) {
      totalVolume = ticketInfo.volume; // nếu là active stop nghĩa là đối tượng này đã được cộng tổng vol của những đối tượng trước nó thì trả về vol
      continue;
    }
    // nếu là BUY thì check giá hiện tại bé hơn giá active thì đặt lệnh stop, còn nếu là sell thì check giá hiện tại lớn hơn giá active

    bool checkPriceActive = orderTypeByBiasType == ORDER_TYPE_BUY ? currentPrice <= ticketInfo.activePrice : currentPrice >= ticketInfo.activePrice;
    if (checkPriceActive && ticketInfo.state == STATE_WAITING_STOP) {
      beautifulEntryIndex = (int)i;
      negativeTicketIndex = beautifulEntryIndex;
      ticketInfo.ticketId = PlaceOrder(orderTypeByBiasType == ORDER_TYPE_BUY ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP, ticketInfo.price, totalVolume, 0, 0);
      ticketInfo.state = STATE_ACTIVE_STOP;
      ticketInfo.volume = totalVolume;
      negativeTicketsByBiasType[i] = ticketInfo;
      isUpdateTP = true;
      break;
    }
  }

  /*

  // negTicketList[1] là phần tử thứ 2 ở mảng DCA âm
  // nếu state nó OPEN nghĩa là mảng DCA âm tồn tại 1 ticket open -> đủ điều kiện order lại DCA dương
  // nếu state là ACTIVE_STOP nghĩa là nó chắc chắn sẽ khớp tại đó hoặc sẽ khớp lệnh ở 1 vị trí đẹp hơn phía dưới -> đủ điều kiện
  // nếu state là SKIP nghĩa là nó đã quét qua và khớp lệnh đẹp hơn phía dưới rồi -> đủ điều kiện
  // nếu state là CLOSE nghĩa là nó đã đạt đủ target ngày, đạt đủ rồi thì không cần DCA dương gì nữa -> đủ điều kiện

  // check thêm 1 điều kiện nữa là có lệnh DCA dương nào tại điểm priceInitEntry + 1 không để khỏi vô lệnh DCA dương nhiều lần
  TicketInfo ticket1 = negativeTicketsByBiasType[1];
  if(ticket1.state != STATE_WAITING_STOP) {
      bool isNotExistsDCAEntry = true;
      double entryDCAFirstPrice = orderTypeByBiasType == ORDER_TYPE_BUY ? priceInitEntry + 2 : priceInitEntry - 2; // + 2 bởi vì entry DCA đầu tiên cách entry của lệnh đầu ngày 2 giá
      for(uint i = 0; i < positiveTicketsByBiasType.Size(); i++){
         TicketInfo ticket = positiveTicketsByBiasType[i];
         // nếu có 1 phần tử tại (priceInitEntry + 2) và state nó khác close nghĩa là đang có lệnh DCA dương ở (priceInitEntry +  2) rồi
         if(ticket.price == entryDCAFirstPrice && ticket.state != STATE_CLOSE){
            isNotExistsDCAEntry = false;
            break;
         }
      }
      // không tồn tại entry DCA nào đang active ở điểm start DCA dương (isNotExistsDCAEntry = true) thì mới vào lại lệnh DCA dương
      if(isNotExistsDCAEntry){
         double entryFirstDCA = orderTypeBias == ORDER_TYPE_BUY ? priceInitEntry + 1 : priceInitEntry - 1;
         orderStopFollowTrend(entryFirstDCA); // hàm này cộng sẵn 1 để xử lý cho việc khớp lệnh DCA nữa nên chỉ cần + 1 ở entryFirstDCA;
      }
  }

  // close tất cả lệnh frozen nếu entry xuống tới 11
  if(beautifulEntryIndex >= 10){
      closeAllFrozenTicket();
  }
  */

  // Clear lệnh xấu từ beautifulEntryIndex trở về trước => DONE
  if (beautifulEntryIndex >= 2) {
    for (int i = 1; i < beautifulEntryIndex; i++) {
      TicketInfo info;
      info = negativeTicketsByBiasType[i];
      if (info.state != STATE_OPEN) {
        if (info.state == STATE_ACTIVE_STOP) {
          CloseByTicket(info.ticketId);
        }
        info.state = STATE_SKIP;
        negativeTicketsByBiasType[i] = info;
      }
    }
  }

  updateBiasArray(NEGATIVE_ARRAY, negativeTicketsByBiasType);
  updateBiasArray(POSITIVE_ARRAY, positiveTicketsByBiasType);
}


#endif // __DCA_NEGATIVE_HANDLE_MQH__