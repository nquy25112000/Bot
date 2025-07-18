#!/usr/bin/env bash

# Tạo cấu trúc thư mục
mkdir -p ea common data logic

# 1. ea/BiasBot.mq5
cat > ea/BiasBot.mq5 << 'EOF'
#include <Trade\Trade.mqh>                      // Kết nối thư viện giao dịch
#include "../common/Globals.mqh"               // Biến toàn cục và struct
#include "../data/MarketDataService.mqh"       // Dịch vụ lấy dữ liệu giá/volume
#include "../logic/SignalService.mqh"          // Dịch vụ sinh tín hiệu
#include "../logic/TradeService.mqh"           // Dịch vụ đặt/đóng lệnh
#include "../logic/TicketService.mqh"          // Dịch vụ quản lý ticket

static const double volumes1[19] = { /* volume profile 1 */ };
static const double volumes2[10] = { /* volume profile 2 */ };

int jump = 1;                  // Khoảng giá (point) để chia entry
int targetByIndex1;            // Mốc entry 1 để tính TP
int targetByIndex2;            // Mốc entry 2 để tính TP
bool dailyBiasRunning = false; // Trạng thái chiến lược daily

int OnInit() {
  // Khởi tạo volumes và timer
  if(jump==1) {
    InitVolumes(volumes1, ArraySize(volumes1), 1);
    targetByIndex1=12; targetByIndex2=19;
  } else {
    InitVolumes(volumes2, ArraySize(volumes2), 1);
    targetByIndex1=5;  targetByIndex2=10;
  }
  EventSetTimer(1);   // OnTimer mỗi 1s
  TicketInit();       // Khởi tạo theo dõi ticket
  return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
  EventKillTimer();   // Hủy timer khi tắt EA
}

void OnTick() {
  UpdateTickets();    // Cập nhật trạng thái ticket (đóng khi TP)
}

void OnTimer() {
  // Thực thi theo giờ: StartDailyBias lúc 07:00, scan liên tục
  static bool initToday=false;
  MqlDateTime tm; TimeToStruct(TimeCurrent(), tm);
  if(tm.hour==7 && tm.min==0 && !initToday) {
    StartDailyBias();
    initToday=true;
  }
  if(dailyBiasRunning) ScanDailyBias();
  if(tm.hour!=7) initToday=false;
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result) {
  // Cập nhật ticket khi TP xảy ra
  TicketOnTradeTransaction(trans, request, result);
}
EOF

# 2. common/Globals.mqh
cat > common/Globals.mqh << 'EOF'
#ifndef __GLOBALS_MQH__
#define __GLOBALS_MQH__

#include <Trade\Trade.mqh>
extern CTrade trade;  // Đối tượng giao dịch

// Thông tin ticket (position)
struct TicketInfo {
  ulong    ticketId;
  double   volume;
  string   state;
  double   price;
  double   activePrice;
};

// Định nghĩa trạng thái ticket
#define STATE_OPEN         "OPEN"
#define STATE_WAITING_STOP "WAITING_STOP"
#define STATE_ACTIVE_STOP  "ACTIVE_STOP"
#define STATE_CLOSE        "CLOSE"
#define STATE_SKIP         "SKIP"

// Cấu hình chung
extern int    jump;
extern double m_volumes[];
extern int    targetByIndex1;
extern int    targetByIndex2;

// Trạng thái chiến lược daily
extern bool   dailyBiasRunning;
extern double dailyBiasSL;
extern double dailyBiasTP;
extern ENUM_ORDER_TYPE orderTypeDailyBias;

// Lưu trữ ticket
extern TicketInfo m_tickets[];
extern int        ticketCount;

#endif // __GLOBALS_MQH__
EOF

# 3. data/PriceVolume.mqh
cat > data/PriceVolume.mqh << 'EOF'
class PriceVolume : public CObject
{
private:
  double m_price, m_volume;
  ulong  m_ticketId;
  bool   m_isOpen, m_isActiveStop;

public:
  PriceVolume(double price,double volume) {
    m_price=price; m_volume=volume;
    m_ticketId=-1; m_isOpen=false;
  }
  double Price() const { return m_price; }
  void   SetPrice(double p) { m_price=p; }
  double Volume() const { return m_volume; }
  void   SetVolume(double v) { m_volume=v; }
  ulong  TicketId() const { return m_ticketId; }
  void   SetTicketId(ulong t) { m_ticketId=t; }
  bool   IsOpen() const { return m_isOpen; }
  void   SetIsOpen(bool o) { m_isOpen=o; }
  bool   IsActiveStop() const { return m_isActiveStop; }
  void   SetIsActiveStop(bool s) { m_isActiveStop=s; }
  string ToString() const {
    return StringFormat("Price: %.3f | Volume: %.3f | Ticket: %d | IsOpen: %s",
                        m_price, m_volume, m_ticketId, m_isOpen?"true":"false");
  }
};
EOF

# 4. data/MarketDataService.mqh
cat > data/MarketDataService.mqh << 'EOF'
#ifndef __MARKET_DATA_SERVICE_MQH__
#define __MARKET_DATA_SERVICE_MQH__
#include "../common/Globals.mqh"
#include "PriceVolume.mqh"  // Lớp PriceVolume tiện ích

// Khởi tạo volumes và reset trạng thái
void InitVolumes(const double sourceVolumes[],int size,int inJump){
  jump=inJump;
  ArrayResize(m_volumes,size);
  for(int i=0;i<size;i++) m_volumes[i]=sourceVolumes[i];
  ticketCount=0;
  ArrayResize(m_tickets,size);
  dailyBiasRunning=false;
}

// Lấy giá ASK/BID tùy loại lệnh
double GetCurrentPrice(ENUM_ORDER_TYPE orderType){
  return (orderType==ORDER_TYPE_BUY)? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
       : (orderType==ORDER_TYPE_SELL)? SymbolInfoDouble(_Symbol, SYMBOL_BID)
       : 0.0;
}
#endif // __MARKET_DATA_SERVICE_MQH__
EOF

# 5. logic/SignalService.mqh
cat > logic/SignalService.mqh << 'EOF'
#ifndef __SIGNAL_SERVICE_MQH__
#define __SIGNAL_SERVICE_MQH__
#include "../common/Globals.mqh"
#include "../data/MarketDataService.mqh"

// Bắt đầu chuỗi lệnh daily: OPEN rồi WAITING_STOP
void StartDailyBias(){
  dailyBiasRunning=true;
  double price0=GetCurrentPrice(orderTypeDailyBias);
  dailyBiasSL=(orderTypeDailyBias==ORDER_TYPE_BUY?price0-jump:price0+jump);
  dailyBiasTP=(orderTypeDailyBias==ORDER_TYPE_BUY?price0+2*jump:price0-2*jump);
  ticketCount=0;
  // Tạo lệnh OPEN đầu tiên
  ulong t0=PlaceOrder(orderTypeDailyBias,price0,m_volumes[0],dailyBiasSL,dailyBiasTP);
  m_tickets[ticketCount++]={t0,m_volumes[0],STATE_OPEN,price0,0.0};
  // Tạo các entry chờ
  for(int i=1;i<ArraySize(m_volumes);i++){
    double posPrice=price0+((orderTypeDailyBias==ORDER_TYPE_BUY)?-i*jump:i*jump);
    double actPrice=posPrice+((orderTypeDailyBias==ORDER_TYPE_BUY)?-jump:jump);
    m_tickets[ticketCount++]={0,m_volumes[i],STATE_WAITING_STOP,posPrice,actPrice};
  }
}

// Quét và kích hoạt stop, tính/modify TP
void ScanDailyBias(){
  if(!dailyBiasRunning||ticketCount==0){dailyBiasRunning=false;return;}
  double cur=GetCurrentPrice(orderTypeDailyBias);
  double totVol=0,sumPV=0; int actIdx=-1;
  for(int i=0;i<ticketCount;i++){
    TicketInfo &ti=m_tickets[i];
    if(ti.state==STATE_OPEN||ti.state==STATE_ACTIVE_STOP){
      totVol+=ti.volume; sumPV+=ti.price*ti.volume;
    }
    if(ti.state==STATE_WAITING_STOP&&
       ((orderTypeDailyBias==ORDER_TYPE_BUY&&cur<=ti.activePrice)||
        (orderTypeDailyBias==ORDER_TYPE_SELL&&cur>=ti.activePrice))){
      actIdx=i; break;
    }
  }
  if(actIdx>=0){
    TicketInfo &ti=m_tickets[actIdx];
    ti.ticketId=PlaceOrder((orderTypeDailyBias==ORDER_TYPE_BUY)?ORDER_TYPE_BUY_STOP:ORDER_TYPE_SELL_STOP,
                            ti.price,totVol,0,0);
    ti.state=STATE_ACTIVE_STOP; totVol+=ti.volume; sumPV+=ti.price*ti.volume;
    double avg=sumPV/totVol; double tp=CalcTP(avg,totVol,actIdx);
    trade.OrderModify(ti.ticketId,ti.price,0,tp,ORDER_TIME_GTC);
    for(int j=0;j<ticketCount;j++) if(m_tickets[j].state==STATE_OPEN)
      trade.PositionModify(m_tickets[j].ticketId,0,tp);
    for(int k=1;k<actIdx;k++) if(m_tickets[k].state!=STATE_OPEN){
      CloseByTicket(m_tickets[k].ticketId); m_tickets[k].state=STATE_SKIP;
    }
  }
}

// Tính TP dựa trên entryIndex và tổng volume
double CalcTP(double avg,double totVol,int idx){
  double tgt=(idx<targetByIndex1?630:(idx<targetByIndex2?720:900));
  return avg + ((orderTypeDailyBias==ORDER_TYPE_BUY)?tgt/(totVol*100.0):-tgt/(totVol*100.0));
}
#endif // __SIGNAL_SERVICE_MQH__
EOF

# 6. logic/TradeService.mqh
cat > logic/TradeService.mqh << 'EOF'
#ifndef __TRADE_SERVICE_MQH__
#define __TRADE_SERVICE_MQH__
#include "../common/Globals.mqh"

// Đặt lệnh theo type, giá, volume, SL, TP
ulong PlaceOrder(ENUM_ORDER_TYPE type,double price,double volume,double sl,double tp){
  price=NormalizeDouble(price,_Digits);
  sl   =NormalizeDouble(sl,_Digits);
  tp   =NormalizeDouble(tp,_Digits);
  volume=NormalizeDouble(volume,2);
  bool ok=false;
  switch(type){
    case ORDER_TYPE_BUY:       ok=trade.Buy(volume,_Symbol,price,sl,tp); break;
    case ORDER_TYPE_SELL:      ok=trade.Sell(volume,_Symbol,price,sl,tp);break;
    case ORDER_TYPE_BUY_STOP:  ok=trade.BuyStop(volume,price,_Symbol,sl,tp);break;
    case ORDER_TYPE_SELL_STOP: ok=trade.SellStop(volume,price,_Symbol,sl,tp);break;
  }
  if(!ok){Print("Order failed:",trade.ResultRetcode());return 0;}
  return trade.ResultOrder();
}

// Đóng hoặc xóa lệnh theo ticketId
bool CloseByTicket(ulong ticket){
  if(PositionSelectByTicket(ticket)) return trade.PositionClose(ticket);
  if(OrderSelect(ticket))            return trade.OrderDelete(ticket);
  return false;
}
#endif // __TRADE_SERVICE_MQH__
EOF

# 7. logic/TicketService.mqh
cat > logic/TicketService.mqh << 'EOF'
#ifndef __TICKET_SERVICE_MQH__
#define __TICKET_SERVICE_MQH__
#include "../common/Globals.mqh"

// Reset mảng ticket
void TicketInit(){ ticketCount=0; }

// Xử lý transaction: đánh dấu CLOSED khi TP
void TicketOnTradeTransaction(const MqlTradeTransaction& trans,
                              const MqlTradeRequest& request,
                              const MqlTradeResult& result){
  if(trans.type==TRADE_TRANSACTION_DEAL_ADD &&
     HistoryDealGetInteger(trans.deal,DEAL_ENTRY)==DEAL_ENTRY_OUT &&
     HistoryDealGetInteger(trans.deal,DEAL_REASON)==DEAL_REASON_TP){
    ulong pos=HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);
    for(int i=0;i<ticketCount;i++) if(m_tickets[i].ticketId==pos)
      m_tickets[i].state=STATE_CLOSE;
  }
}

// Xóa ticket đã CLOSED khỏi mảng
void UpdateTickets(){
  for(int i=0;i<ticketCount;i++){
    if(m_tickets[i].state==STATE_CLOSE){
      m_tickets[i]=m_tickets[--ticketCount]; i--;
    }
  }
}
#endif // __TICKET_SERVICE_MQH__
EOF

echo "✅ All commented files have been created."


# câu lệnh để sử dụng fle này# Lưu mã trên vào file create_biasbot.sh
# Sau đó, chạy các lệnh sau trong terminal:
# chmod +x create_biasbot.sh
# bash create_biasbot.sh