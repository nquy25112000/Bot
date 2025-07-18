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
