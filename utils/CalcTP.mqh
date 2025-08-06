#ifndef __CALCTP_MQH__
#define __CALCTP_MQH__

//-------------------------------------------------------------
// Tính toán Take Profit dựa vào:
// - Giá trung bình các lệnh
// - Tổng khối lượng
// - Mức entryIndex để chọn target lợi nhuận tương ứng
//
// Trả về: giá TP cần thiết để đạt số cent lợi nhuận theo từng mức
//-------------------------------------------------------------
double CalcTP(double avgPrice, double totalVol, int entryIndex)
{
  if (totalVol <= 0.0)
    return EMPTY_VALUE;      // tránh chia 0

  double targetCent = getTargetCentDailyBias(entryIndex);

  double deltaP = targetCent / (totalVol * 100.0);
  return (avgPrice + (orderTypeBias == ORDER_TYPE_BUY ? deltaP : - deltaP));
}

double getTargetCentDailyBias(int entryIndex){
  if (entryIndex < targetByIndex1)
    return targetCentList[0];
  else if (entryIndex < targetByIndex2)
    return targetCentList[1];
  else
    return targetCentList[2];
}

#endif // __CALCTP_MQH__
