#ifndef __MARKET_DATA_SERVICE_MQH__
#define __MARKET_DATA_SERVICE_MQH__

//-----------------------------------------------------------------
// Các profile khối lượng mẫu, dùng để khởi tạo chiến lược
// - m_volumes1: 19 phần tử, phân phối đối xứng
// - m_volumes2: 10 phần tử, dốc đều rồi giảm lại
//-----------------------------------------------------------------
static const double m_volumes1[19] = { 0.03,0.04,0.05,0.06,0.07,0.08,0.09,0.1,0.1,
                                    0.09,0.08,0.07,0.06,0.05,0.05,0.05,0.04,0.03,0.03 };
static const double m_volumes2[10] = { 0.05,0.07,0.09,0.11,0.13,0.16,0.16,0.13,0.09,0.07 };

//-----------------------------------------------------------------
// InitVolumes
// ---------------------------------------------------------------
// Mục đích:
//   - Copy profile volume đầu vào vào mảng toàn cục `m_volumes`
//   - Resize lại mảng `m_tickets` để khớp với kích thước volume
//
// Params:
//   - sourceVolumes[]: mảng khối lượng đầu vào để khởi tạo
//-----------------------------------------------------------------
void InitVolumes(const double& sourceVolumes[])
{
   uint volumeSize = sourceVolumes.Size();
   ArrayResize(m_volumes, volumeSize);
   for (uint i = 0; i < volumeSize; i++)
      m_volumes[i] = sourceVolumes[i];

   ArrayResize(m_tickets, volumeSize);
}

//-----------------------------------------------------------------
// getCurrentPrice
// ---------------------------------------------------------------
// Mục đích:
//   - Trả về giá hiện tại theo loại lệnh:
//       + BUY: trả về giá ASK (giá mua vào)
//       + SELL: trả về giá BID (giá bán ra)
//
// Params:
//   - type: loại lệnh (ORDER_TYPE_BUY hoặc ORDER_TYPE_SELL)
//
// Return:
//   - Giá hiện tại phù hợp với loại lệnh
//-----------------------------------------------------------------
double getCurrentPrice(ENUM_ORDER_TYPE type)
{
   if (type == ORDER_TYPE_BUY)  return(SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   if (type == ORDER_TYPE_SELL) return(SymbolInfoDouble(_Symbol, SYMBOL_BID));
   return(0.0);
}

#endif // __MARKET_DATA_SERVICE_MQH__
