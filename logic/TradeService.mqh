#ifndef __TRADE_SERVICE_MQH__
#define __TRADE_SERVICE_MQH__
#include "../common/Globals.mqh"

ulong PlaceOrder(ENUM_ORDER_TYPE type, double price, double volume, double sl, double tp)
{
   price  = NormalizeDouble(price , _Digits);
   sl     = NormalizeDouble(sl    , _Digits);
   tp     = NormalizeDouble(tp    , _Digits);
   volume = NormalizeDouble(volume,   2);

   bool ok = false;
   switch(type)
   {
      case ORDER_TYPE_BUY:       ok=trade.Buy(volume,_Symbol,price,sl,tp);       break;
      case ORDER_TYPE_SELL:      ok=trade.Sell(volume,_Symbol,price,sl,tp);      break;
      case ORDER_TYPE_BUY_STOP:  ok=trade.BuyStop(volume,price,_Symbol,sl,tp);   break;
      case ORDER_TYPE_SELL_STOP: ok=trade.SellStop(volume,price,_Symbol,sl,tp);  break;
   }
   if(!ok) { Print("Order failed: ",trade.ResultRetcode()); return 0; }
   return trade.ResultOrder();
}

bool CloseByTicket(ulong ticket)
{
   if(PositionSelectByTicket(ticket)) return trade.PositionClose(ticket);
   if(OrderSelect(ticket))            return trade.OrderDelete(ticket);
   return false;
}

#endif // __TRADE_SERVICE_MQH__
