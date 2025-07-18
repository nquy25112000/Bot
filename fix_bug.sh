#!/usr/bin/env bash
set -e

# 1. ea/BiasBot.mq5
cat > ea/BiasBot.mq5 << 'EOF'
#include <Trade\Trade.mqh>
#include "common/Globals.mqh"
#include "data/MarketDataService.mqh"
#include "logic/SignalService.mqh"
#include "logic/TradeService.mqh"
#include "logic/TicketService.mqh"

// Profiles volumes
static const double volumes1[19] = {0.03,0.04,0.05,0.06,0.07,0.08,0.09,0.1,0.1,
                                    0.09,0.08,0.07,0.06,0.05,0.05,0.05,0.04,0.03,0.03};
static const double volumes2[10] = {0.05,0.07,0.09,0.11,0.13,0.16,0.16,0.13,0.09,0.07};

int jump = 1;
int targetByIndex1, targetByIndex2;
bool dailyBiasRunning = false;

int OnInit()
{
   if(jump==1)
   {
      InitVolumes(volumes1, ArraySize(volumes1), 1);
      targetByIndex1 = 12;  targetByIndex2 = 19;
   }
   else
   {
      InitVolumes(volumes2, ArraySize(volumes2), 1);
      targetByIndex1 = 5;   targetByIndex2 = 10;
   }
   EventSetTimer(1);
   TicketInit();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
}

void OnTick()
{
   UpdateTickets();
}

void OnTimer()
{
   static bool doneToday = false;
   MqlDateTime tm;  TimeToStruct(TimeCurrent(), tm);
   if(tm.hour==7 && tm.min==0 && !doneToday)
   {
      StartDailyBias();
      doneToday = true;
   }
   if(dailyBiasRunning) ScanDailyBias();
   if(tm.hour!=7) doneToday = false;
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &req,
                        const MqlTradeResult      &res)
{
   TicketOnTradeTransaction(trans, req, res);
}
EOF

# 2. common/Globals.mqh
cat > common/Globals.mqh << 'EOF'
#ifndef __GLOBALS_MQH__
#define __GLOBALS_MQH__

#include <Trade\Trade.mqh>
CTrade trade;

double       m_volumes[];
TicketInfo   m_tickets[];
int          ticketCount;

int    jump;
int    targetByIndex1, targetByIndex2;
bool   dailyBiasRunning;
double dailyBiasSL, dailyBiasTP;
ENUM_ORDER_TYPE orderTypeDailyBias;

struct TicketInfo
{
   ulong  ticketId;
   double volume;
   string state;
   double price;
   double activePrice;
};

#define STATE_OPEN         "OPEN"
#define STATE_WAITING_STOP "WAITING_STOP"
#define STATE_ACTIVE_STOP  "ACTIVE_STOP"
#define STATE_CLOSE        "CLOSE"
#define STATE_SKIP         "SKIP"

#endif // __GLOBALS_MQH__
EOF

# 3. data/MarketDataService.mqh
cat > data/MarketDataService.mqh << 'EOF'
#ifndef __MARKET_DATA_SERVICE_MQH__
#define __MARKET_DATA_SERVICE_MQH__
#include "../common/Globals.mqh"

void InitVolumes(const double sourceVolumes[], int size, int inJump)
{
   jump = inJump;
   ArrayResize(m_volumes, size);
   for(int i=0; i<size; i++)
      m_volumes[i] = sourceVolumes[i];

   ticketCount = 0;
   ArrayResize(m_tickets, size);
   dailyBiasRunning = false;
}

double GetCurrentPrice(ENUM_ORDER_TYPE type)
{
   if(type==ORDER_TYPE_BUY)  return SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(type==ORDER_TYPE_SELL) return SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return(0.0);
}

#endif // __MARKET_DATA_SERVICE_MQH__
EOF

# 4. logic/SignalService.mqh
cat > logic/SignalService.mqh << 'EOF'
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
      TicketInfo &ti = m_tickets[i];
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
      TicketInfo &ti = m_tickets[actIdx];
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
EOF

# 5. logic/TradeService.mqh
cat > logic/TradeService.mqh << 'EOF'
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
EOF

# 6. logic/TicketService.mqh
cat > logic/TicketService.mqh << 'EOF'
#ifndef __TICKET_SERVICE_MQH__
#define __TICKET_SERVICE_MQH__
#include "../common/Globals.mqh"

void TicketInit()
{
   ticketCount = 0;
}

void TicketOnTradeTransaction(const MqlTradeTransaction &trans,
                              const MqlTradeRequest     &req,
                              const MqlTradeResult      &res)
{
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD &&
      HistoryDealGetInteger(trans.deal, DEAL_ENTRY)==DEAL_ENTRY_OUT &&
      HistoryDealGetInteger(trans.deal, DEAL_REASON)==DEAL_REASON_TP)
   {
      ulong pos = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
      for(int i=0;i<ticketCount;i++)
         if(m_tickets[i].ticketId==pos)
            m_tickets[i].state = STATE_CLOSE;
   }
}

void UpdateTickets()
{
   for(int i=0;i<ticketCount;i++)
   {
      if(m_tickets[i].state == STATE_CLOSE)
      {
         m_tickets[i] = m_tickets[--ticketCount];
         i--;
      }
   }
}

#endif // __TICKET_SERVICE_MQH__
EOF

echo "✅ All files overwritten with cleaned-up code. Now reload & compile!"