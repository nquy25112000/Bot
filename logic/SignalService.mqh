#ifndef __SIGNAL_SERVICE_MQH__
#define __SIGNAL_SERVICE_MQH__
#include "../common/Globals.mqh"
#include "../data/MarketDataService.mqh"

void StartDailyBias()
{
   dailyBiasRunning = true;
   double p0 = GetCurrentPrice(orderTypeDailyBias);
   dailyBiasSL = (orderTypeDailyBias==ORDER_TYPE_BUY ? p0 - jump : p0 + jump);
   dailyBiasTP = (orderTypeDailyBias==ORDER_TYPE_BUY ? p0 + 2*jump : p0 - 2*jump);

   ticketCount = 0;

   // OPEN
   {
      ulong t0 = PlaceOrder(orderTypeDailyBias, p0, m_volumes[0], dailyBiasSL, dailyBiasTP);
      TicketInfo ti = {};
      ti.ticketId    = t0;
      ti.volume      = m_volumes[0];
      ti.state       = STATE_OPEN;
      ti.price       = p0;
      ti.activePrice = 0.0;
      m_tickets[ticketCount++] = ti;
   }

   // WAITING_STOP entries
   for(int i=1; i<ArraySize(m_volumes); i++)
   {
      double pos = p0 + ((orderTypeDailyBias==ORDER_TYPE_BUY)? -i*jump : i*jump);
      double act = pos + ((orderTypeDailyBias==ORDER_TYPE_BUY)? -jump : jump);
      TicketInfo ti = {};
      ti.ticketId    = 0;
      ti.volume      = m_volumes[i];
      ti.state       = STATE_WAITING_STOP;
      ti.price       = pos;
      ti.activePrice = act;
      m_tickets[ticketCount++] = ti;
   }
}

void ScanDailyBias()
{
   if(!dailyBiasRunning || ticketCount==0) { dailyBiasRunning=false; return; }

   double cur = GetCurrentPrice(orderTypeDailyBias);
   double totVol=0, sumPV=0;
   int    actIdx=-1;

   // accumulate open & active
   for(int i=0;i<ticketCount;i++)
   {
      TicketInfo ti = m_tickets[i];
      if(ti.state==STATE_OPEN || ti.state==STATE_ACTIVE_STOP)
      {
         totVol += ti.volume;
         sumPV  += ti.price * ti.volume;
      }
      if(ti.state==STATE_WAITING_STOP &&
         ((orderTypeDailyBias==ORDER_TYPE_BUY && cur<=ti.activePrice) ||
          (orderTypeDailyBias==ORDER_TYPE_SELL && cur>=ti.activePrice)))
      {
         actIdx = i; break;
      }
   }

   if(actIdx>=0)
   {
      TicketInfo ti = m_tickets[actIdx];
      ti.ticketId = PlaceOrder(
         (orderTypeDailyBias==ORDER_TYPE_BUY)? ORDER_TYPE_BUY_STOP: ORDER_TYPE_SELL_STOP,
         ti.price, totVol, 0, 0
      );
      ti.state = STATE_ACTIVE_STOP;
      totVol += ti.volume; sumPV += ti.price * ti.volume;

      double avg = sumPV / totVol;
      double tp  = CalcTP(avg, totVol, actIdx);

      trade.OrderModify(ti.ticketId, ti.price, 0, tp, 0, 0);
      for(int j=0;j<ticketCount;j++)
         if(m_tickets[j].state==STATE_OPEN)
            trade.PositionModify(m_tickets[j].ticketId, 0, tp);

      for(int k=1;k<actIdx;k++)
         if(m_tickets[k].state!=STATE_OPEN)
         {
            CloseByTicket(m_tickets[k].ticketId);
            m_tickets[k].state = STATE_SKIP;
         }
   }
}

double CalcTP(double avg, double totVol, int idx)
{
   double cent = (idx<targetByIndex1?630:(idx<targetByIndex2?720:900));
   return avg + ((orderTypeDailyBias==ORDER_TYPE_BUY)? cent/(totVol*100.0): -cent/(totVol*100.0));
}

#endif // __SIGNAL_SERVICE_MQH__
