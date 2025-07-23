#ifndef __GETTOTALPROFITFROM_MQH__
#define __GETTOTALPROFITFROM_MQH__

// Hàm tính tổng lợi nhuận từ thời điểm fromTime
double GetTotalProfitFrom(datetime fromTime) {
  double totalProfit = 0;
  int total = PositionsTotal();
  for (int i = 0; i < total; i++) {
    ulong ticket = PositionGetTicket(i);
    if (PositionSelectByTicket(ticket)) {
      totalProfit += PositionGetDouble(POSITION_PROFIT);
    }
  }

  bool existHistoryDeal = HistorySelect(fromTime, TimeCurrent());
  if (!existHistoryDeal) return 0;

  int deals = HistoryDealsTotal();
  for (int i = 0; i < deals; i++) {
    ulong ticket = HistoryDealGetTicket(i);
    if (HistoryDealSelect(ticket)) {
      long dealType = HistoryDealGetInteger(ticket, DEAL_TYPE);
      long dealEntry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if ((dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL) && dealEntry == DEAL_ENTRY_OUT) {
        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
        totalProfit += profit;
      }
    }
  }

  return totalProfit;
}

#endif // __GETTOTALPROFITFROM_MQH__
