#ifndef __TRADE_SERVICE_MQH__
#define __TRADE_SERVICE_MQH__

//--------------------------------------------------------------------------
// PlaceOrder
// -------------------------------------------------------------------------
// Mục đích:
//   - Gửi lệnh giao dịch theo loại (BUY, SELL, BUY_STOP, SELL_STOP)
//   - Chuẩn hóa các tham số về format chuẩn (giá 3 số lẻ, volume 2 số lẻ)
//
// Params:
//   - type: loại lệnh (ENUM_ORDER_TYPE)
//   - price: giá vào lệnh
//   - volume: khối lượng giao dịch (lot)
//   - sl: giá cắt lỗ (Stop Loss)
//   - tp: giá chốt lời (Take Profit)
//
// Return:
//   - Mã ticket của lệnh nếu thành công, 0 nếu thất bại
//--------------------------------------------------------------------------
ulong PlaceOrder(ENUM_ORDER_TYPE type, double price, double volume, double sl, double tp)
{
  price = NormalizeDouble(price, 3);
  sl = NormalizeDouble(sl, 3);
  tp = NormalizeDouble(tp, 3);
  volume = NormalizeDouble(volume, 2);

  bool ok = false;
  switch (type)
  {
  case ORDER_TYPE_BUY:       ok = trade.Buy(volume, _Symbol, price, sl, tp, StringFormat("BUY on: %.3f: ", price));       break;
  case ORDER_TYPE_SELL:      ok = trade.Sell(volume, _Symbol, price, sl, tp, StringFormat("SELL on: %.3f: ", price));      break;
  case ORDER_TYPE_BUY_STOP:  ok = trade.BuyStop(volume, price, _Symbol, sl, tp);   break;
  case ORDER_TYPE_SELL_STOP: ok = trade.SellStop(volume, price, _Symbol, sl, tp);  break;
  case ORDER_TYPE_BUY_LIMIT:  ok = trade.BuyLimit(volume, price, _Symbol, sl, tp);   break;
  case ORDER_TYPE_SELL_LIMIT:  ok = trade.SellLimit(volume, price, _Symbol, sl, tp);   break;
  }
  if (!ok) { Print("Order failed: ", trade.ResultRetcode()); return 0; }
  return trade.ResultOrder();
}

//--------------------------------------------------------------------------
// CloseByTicket
// -------------------------------------------------------------------------
// Mục đích:
//   - Đóng một position hiện tại (nếu có) hoặc xóa lệnh chờ theo ticket
//
// Params:
//   - ticket: mã lệnh cần đóng hoặc hủy
//
// Return:
//   - true nếu đóng/hủy thành công
//   - false nếu thất bại hoặc không tìm thấy
//--------------------------------------------------------------------------
bool CloseByTicket(ulong ticket) {
  if (PositionSelectByTicket(ticket)) {
    bool result = trade.PositionClose(ticket);
    if (result) {
      Print("✅ Đã đóng position - Ticket: ", ticket);
      return true;
    }
    else {
      Print("❌ Không thể đóng position - Ticket: ", ticket, " | ", trade.ResultRetcodeDescription());
      return false;
    }
  }

  if (OrderSelect(ticket)) {
    bool result = trade.OrderDelete(ticket);
    if (result) {
      Print("✅ Đã hủy lệnh chờ - Ticket: ", ticket);
      return true;
    }
    else {
      Print("❌ Không thể hủy lệnh chờ - Ticket: ", ticket, " | ", trade.ResultRetcodeDescription());
      return false;
    }
  }

  Print("⚠️ Không tìm thấy ticket trong position hoặc pending order: ", ticket);
  return false;
}

void CloseAllOrdersAndPositions()
{
   CloseAllOrders();
   CloseAllPosition();
}

void CloseAllOrders(){
  // 2️⃣ Xóa tất cả lệnh chờ (pending orders)
  int total_orders = OrdersTotal();
  ulong order_tickets[];

  ArrayResize(order_tickets, total_orders);
  for (int i = 0; i < total_orders; i++)
    order_tickets[i] = OrderGetTicket(i);

  for (int i = 0; i < total_orders; i++)
  {
    ulong ticket = order_tickets[i];
    if (OrderSelect(ticket))
    {
      if (!trade.OrderDelete(ticket))
        Print("❌ Không xóa được lệnh chờ ticket ", ticket, " | Lỗi: ", trade.ResultRetcode());
      //else
         //Print("✅ Đã xóa lệnh chờ ticket ", ticket);
    }
  }
}

void CloseAllPosition(){
  // 1️⃣ Đóng tất cả lệnh thị trường (positions)
  int total_positions = PositionsTotal();
  ulong position_tickets[];

  ArrayResize(position_tickets, total_positions);
  for (int i = 0; i < total_positions; i++)
    position_tickets[i] = PositionGetTicket(i);

  for (int i = 0; i < total_positions; i++)
  {
    ulong ticket = position_tickets[i];
    if (PositionSelectByTicket(ticket))
    {
      if (!trade.PositionClose(ticket))
        Print("❌ Không đóng được position ticket ", ticket, " | Lỗi: ", trade.ResultRetcode());
      //else
         //Print("✅ Đã đóng position ticket ", ticket);
    }
  }
}


//-----------------------------------------------------------------
// getCurrentPrice
// ---------------------------------------------------------------
// Mục đích:
//   - Trả về giá hiện tại theo loại lệnh:
//       + BUY: trả về giá ASK (giá mua vào)
//       + SELL: trả về giá BID (giá bán ra)
//
// Params:
//   - type: loại lệnh (ORDER_TYPE_BUY hoặc ORDER_TYPE_SELL)
//
// Return:
//   - Giá hiện tại phù hợp với loại lệnh
//-----------------------------------------------------------------
double getCurrentPrice(ENUM_ORDER_TYPE type)
{
   if (type == ORDER_TYPE_BUY)  return(SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   if (type == ORDER_TYPE_SELL) return(SymbolInfoDouble(_Symbol, SYMBOL_BID));
   return(0.0);
}


#endif // __TRADE_SERVICE_MQH__
