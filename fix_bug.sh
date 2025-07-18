#!/usr/bin/env bash
set -e

### 1) Replace data/MarketDataService.mqh with clean version ##############
cat > data/MarketDataService.mqh <<'EOF'
#ifndef __MARKET_DATA_SERVICE_MQH__
#define __MARKET_DATA_SERVICE_MQH__

#include "../common/Globals.mqh"

//------------------------------------------------------------
// InitVolumes : copy profile to global m_volumes,
//               reset ticket array & state
//------------------------------------------------------------
void InitVolumes(const double &sourceVolumes[], int size, int inJump)
{
   jump = inJump;

   ArrayResize(m_volumes, size);
   for(int i = 0; i < size; i++)
      m_volumes[i] = sourceVolumes[i];

   ticketCount = 0;
   ArrayResize(m_tickets, size);
   dailyBiasRunning = false;
}

//------------------------------------------------------------
// GetCurrentPrice : ASK for BUY, BID for SELL
//------------------------------------------------------------
double GetCurrentPrice(ENUM_ORDER_TYPE type)
{
   if(type == ORDER_TYPE_BUY)  return(SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   if(type == ORDER_TYPE_SELL) return(SymbolInfoDouble(_Symbol, SYMBOL_BID));
   return(0.0);
}

#endif // __MARKET_DATA_SERVICE_MQH__
EOF
echo "✅ Re-written data/MarketDataService.mqh"

### 2) Fix include paths inside ea/BiasBot.mq5 ###########################
BOT="ea/BiasBot.mq5"
cp "$BOT" "${BOT}.bak"

# choose sed syntax depending on OS
if sed --version >/dev/null 2>&1; then  # GNU sed (Linux)
  SED_INPLACE="sed -i"
else                                    # BSD sed (macOS)
  SED_INPLACE="sed -i ''"
fi

$SED_INPLACE -E '
  s#\.\./includes/Globals\.mqh#../common/Globals.mqh#;
  s#\.\./includes/MarketDataService\.mqh#../data/MarketDataService.mqh#;
  s#\.\./includes/SignalService\.mqh#../logic/SignalService.mqh#;
  s#\.\./includes/TradeService\.mqh#../logic/TradeService.mqh#;
  s#\.\./includes/TicketService\.mqh#../logic/TicketService.mqh#;
' "$BOT"

echo "✅ Fixed include paths in ea/BiasBot.mq5   (backup: ${BOT}.bak)"

echo "🎉  Hoàn tất! Bây giờ hãy reload MetaEditor và nhấn Compile –  \
các lỗi 'unexpected token', 'sourceVolumes', 'ambiguous access' sẽ biến mất."