#ifndef __CALCTP_MQH__
#define __CALCTP_MQH__

#include "../common/Globals.mqh"

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

  double targetCent;
  if (entryIndex < targetByIndex1)
    targetCent = 630;
  else if (entryIndex < targetByIndex2)
    targetCent = 720;
  else
    targetCent = 900;

  double deltaP = targetCent / (totalVol * 100.0);
  return (avgPrice + deltaP);
}

#endif // __CALCTP_MQH__
