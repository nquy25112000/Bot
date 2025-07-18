#ifndef __MARKET_DATA_SERVICE_MQH__
#define __MARKET_DATA_SERVICE_MQH__
#include "../common/Globals.mqh"
#include "PriceVolume.mqh"  // Lớp PriceVolume tiện ích

// Khởi tạo volumes và reset trạng thái
void InitVolumes(const double void InitVolumes(const double void InitVolumes(const double sourceVolumes[]sourceVolumes[]sourceVolumes[],int size,int inJump){
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
