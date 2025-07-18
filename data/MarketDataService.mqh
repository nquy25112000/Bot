#ifndef __MARKET_DATA_SERVICE_MQH__
#define __MARKET_DATA_SERVICE_MQH__

#include "../common/Globals.mqh"

// Volume profiles defined in original file
static const double m_volumes1[19] = {0.03,0.04,0.05,0.06,0.07,0.08,0.09,0.1,0.1,
                                    0.09,0.08,0.07,0.06,0.05,0.05,0.05,0.04,0.03,0.03};
static const double m_volumes2[10] = {0.05,0.07,0.09,0.11,0.13,0.16,0.16,0.13,0.09,0.07};

//------------------------------------------------------------
// InitVolumes : copy profile to global m_volumes,
//               reset ticket array & state
//------------------------------------------------------------
void InitVolumes(const double &sourceVolumes[])
{
   uint volumeSize = sourceVolumes.Size();
   ArrayResize(m_volumes, volumeSize);
   for(uint i = 0; i < volumeSize; i++)
      m_volumes[i] = sourceVolumes[i];

   ArrayResize(m_tickets, volumeSize);
}

//------------------------------------------------------------
// GetCurrentPrice : ASK for BUY, BID for SELL
//------------------------------------------------------------
double getCurrentPrice(ENUM_ORDER_TYPE type)
{
   if(type == ORDER_TYPE_BUY)  return(SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   if(type == ORDER_TYPE_SELL) return(SymbolInfoDouble(_Symbol, SYMBOL_BID));
   return(0.0);
}

#endif // __MARKET_DATA_SERVICE_MQH__
