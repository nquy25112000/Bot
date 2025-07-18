// Include
#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>

// Generate Global Variable
CTrade trade;
struct TicketInfo {
  ulong    ticketId;
  double volume;
  string state;
  double price;
  double activePrice;
};

// Define state
//OPEN,
//WAITING_STOP,
//ACTIVE_STOP

string m_tickets[];
int jump = 2;
double m_volumes[];
double m_volumes1[19] = {
  0.03,
  0.04,
  0.05,
  0.06,
  0.07,
  0.08,
  0.09,
  0.1,
  0.1,
  0.09,
  0.08,
  0.07,
  0.06,
  0.05,
  0.05,
  0.05,
  0.04,
  0.03,
  0.03
};

double m_volumes2[10] = {
   0.05,
   0.07,
   0.09,
   0.11,
   0.13,
   0.16,
   0.16,
   0.13,
   0.09,
   0.07
};


int dailyBiasRuning = 0;
double dailyBiasSL;
double dailyBiasTP;
ENUM_ORDER_TYPE orderTypeDailyBias = ORDER_TYPE_BUY; // chỗ này gọi hàm check là hôm nay buy or sell, mặc định gọi BUY trước để test

int OnInit()
{
  if (jump == 1) {
    ArrayResize(m_tickets, 0);
    ArrayResize(m_tickets, ArraySize(m_volumes1));
    ArrayCopy(m_volumes, m_volumes1);  // ✅ Gán mảng đúng cách
  }
  else {
    ArrayResize(m_tickets, 0);
    ArrayResize(m_tickets, ArraySize(m_volumes2));
    ArrayCopy(m_volumes, m_volumes2);
  }
  EventSetTimer(1); // Set cho Ontimer chạy mỗi giây
  return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
  //---

}

void OnTick()
{

}


void OnTimer() {
  datetime now = TimeCurrent();
  MqlDateTime dt;
  TimeToStruct(now, dt);
  if (dt.hour == 7 && dt.min == 0 && dt.sec == 0 && dailyBiasRuning == 0) {
    startDailyBias();
    Print("run daily on: ", now);
  }

  if (dailyBiasRuning == 1) {
    scanDailyBias();
  }

}

// Hàm lấy giá hiện tại mua và bán 
double getCurrentPrice(ENUM_ORDER_TYPE orderType) {
  double currentPrice;
  if (orderType == ORDER_TYPE_BUY) {
    currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  }
  else if (orderType == ORDER_TYPE_SELL) {
    currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
  }
  else {
    return NULL;
  }
  return currentPrice;
}

void startDailyBias() {
  dailyBiasRuning = 1;
  double currentPrice = getCurrentPrice(orderTypeDailyBias);
  currentPrice = NormalizeDouble(currentPrice, 3);
  ArrayResize(m_tickets, 0);
  ArrayResize(m_tickets, ArraySize(m_volumes));

  // Khởi tạo lệnh đầu tiên
  dailyBiasSL = currentPrice - 100; // => chưa handler
  dailyBiasTP = currentPrice + 2; // => chưa handler
  ulong ticketId = PlaceOrder(orderTypeDailyBias, currentPrice, m_volumes[0], dailyBiasSL, dailyBiasTP);
  string mapFirstValue = StringFormat("T%i V%.2f S%s P%.3f A%.3f", ticketId, m_volumes[0], "OPEN", currentPrice, 0);
  Print(mapFirstValue);
  m_tickets[0] = mapFirstValue;
  // Khởi tạo lệnh đầu tiên


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
    string mapValue = StringFormat("T%i V%.2f S%s P%.3f A%.3f", 0, volume, "WAITING_STOP", price, activePrice);
    Print(mapValue);
    m_tickets[i] = mapValue;
  }
}

void scanDailyBias() {
  if (m_tickets.Size() == 0) {
    dailyBiasRuning = false;
  }
  double currentPrice = getCurrentPrice(orderTypeDailyBias);
  int beautifulEntryIndex = 2;

  double totalVolume = 0;
  // Scan qua mảng giá đã tạo rồi active lệnh khớp với điều kiện currentPrice <= ticketInfo.activePrice => DONE
  for (uint i = 1;i < m_tickets.Size(); i++)
  {
    TicketInfo ticketInfo = parsePrefix(m_tickets[i]);
    totalVolume = totalVolume + ticketInfo.volume;
    if (currentPrice <= ticketInfo.activePrice && ticketInfo.state == "WAITING_STOP") {
      beautifulEntryIndex = (int)i;
      ticketInfo.ticketId = PlaceOrder(ORDER_TYPE_BUY_STOP, ticketInfo.price, totalVolume, dailyBiasSL, dailyBiasTP);
      ticketInfo.state = "ACTIVE_STOP";
      m_tickets[i] = TicketInfoToString(ticketInfo);
      break;
    }
  }

  // Clear lệnh xấu từ beautifulEntryIndex trở về trước => DONE
  for (int i = 1; i < beautifulEntryIndex; i++) {
    TicketInfo info = parsePrefix(m_tickets[i]);
    if (info.state != "OPEN") {
      if (info.state == "ACTIVE_STOP") {
        CloseByTicket(info.ticketId);
      }
      info.state = "SKIP";
      m_tickets[i] = TicketInfoToString(info);
    }
  }
}


// Hàm tiện lợi
void SplitString(string source, string delimiter, string& result[])
{
  ArrayResize(result, 0);  // clear mảng đầu ra
  int start = 0;
  int pos;

  while ((pos = StringFind(source, delimiter, start)) != -1)
  {
    int count = ArraySize(result);
    ArrayResize(result, count + 1);
    result[count] = StringSubstr(source, start, pos - start);
    start = pos + StringLen(delimiter);
  }

  // Thêm phần cuối nếu còn lại
  if (start <= StringLen(source))
  {
    int count = ArraySize(result);
    ArrayResize(result, count + 1);
    result[count] = StringSubstr(source, start);
  }
}


TicketInfo parsePrefix(string s) {
  TicketInfo info;
  string tokens[];
  SplitString(s, " ", tokens);

  for (int i = 0; i < ArraySize(tokens); i++) {
    string tok = tokens[i];
    string prefix = StringSubstr(tok, 0, 1);
    string value = StringSubstr(tok, 1);

    if (prefix == "T")
      info.ticketId = StringToULong(value);
    else if (prefix == "V")
      info.volume = StringToDouble(value);
    else if (prefix == "S")
      info.state = value;
    else if (prefix == "P")
      info.price = StringToDouble(value);
    else if (prefix == "A")
      info.activePrice = StringToDouble(value);
  }

  return info;
}

string TicketInfoToString(const TicketInfo& info)
{
  return StringFormat("T%i V%.2f S%s P%.3f A%.3f",
    info.ticketId,
    info.volume,
    info.state,
    info.price,
    info.activePrice);
}

// Place Order
ulong PlaceOrder(ENUM_ORDER_TYPE orderType, double price, double volume, double sl, double tp) {
  bool result = false;

  price = NormalizeDouble(price, 3);
  sl = NormalizeDouble(sl, 3);
  tp = NormalizeDouble(tp, 3);
  volume = NormalizeDouble(volume, 2);
  if (orderType == ORDER_TYPE_BUY) {
    result = trade.Buy(volume, _Symbol, price, sl, tp);
  }
  else if (orderType == ORDER_TYPE_SELL) {
    result = trade.Sell(volume, _Symbol, price, sl, tp);
  }
  else if (orderType == ORDER_TYPE_BUY_STOP) {
    result = trade.BuyStop(volume, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0);
  }
  else if (orderType == ORDER_TYPE_SELL_STOP) {
    result = trade.SellStop(volume, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0);
  }
  else {
    Print("❌ orderType không hợp lệ");
    return -1;
  }

  if (!result) {
    Print("❌ Đặt lệnh thất bại: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
    return -1;
  }

  ulong ticket = trade.ResultOrder(); // lấy ID của order

  return ticket;
}

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

ulong StringToULong(const string s)
{
  ulong result = 0;
  int len = StringLen(s);

  for (int i = 0; i < len; i++)
  {
    ushort c = StringGetCharacter(s, i);
    if (c < '0' || c > '9')
      break;  // bỏ qua nếu không phải số

    result = result * 10 + (ulong)(c - '0');
  }

  return result;
}

string ULongToString(ulong value)
{
  if (value == 0)
    return "0";

  string result = "";
  while (value > 0)
  {
    int digit = (int)(value % 10);
    result = IntegerToString(digit) + result;
    value = value / 10;
  }

  return result;
}
