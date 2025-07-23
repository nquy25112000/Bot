#include "utils/ULongUtils.mqh"
#include "utils/StringUtils.mqh"
#include "utils/TicketInfoUtils.mqh"
#ifndef __TICKET_INFO_UTILS_MQH__
#define __TICKET_INFO_UTILS_MQH__

#include "StringUtils.mqh"
#include "ULongUtils.mqh"

//-------------------------------------------------------------
// Phân tích chuỗi ticket thành struct TicketInfo
// Dạng chuỗi mẫu: "T123456 V0.05 SOPEN P2314.000 A2300.000"
//-------------------------------------------------------------
TicketInfo stringToTicketInfo(string s) {
  TicketInfo info;
  string tokens[];
  SplitString(s, " ", tokens);
  for(int i=0; i<ArraySize(tokens); i++) {
    string tok = tokens[i];
    string pref = StringSubstr(tok, 0, 1);
    string val  = StringSubstr(tok, 1);
    if(pref == "T") info.ticketId      = StringToULong(val);
    else if(pref == "V") info.volume    = StringToDouble(val);
    else if(pref == "S") info.state     = val;
    else if(pref == "P") info.price     = StringToDouble(val);
    else if(pref == "A") info.activePrice = StringToDouble(val);
  }
  return info;
}

//-------------------------------------------------------------
// Chuyển struct TicketInfo thành chuỗi theo format chuẩn
// Dùng để lưu trữ và hiển thị trạng thái của lệnh
//-------------------------------------------------------------
string TicketInfoToString(const TicketInfo& info) {
  return StringFormat("T%i V%.2f S%s P%.3f A%.3f",
    info.ticketId, info.volume, info.state, info.price, info.activePrice);
}

#endif // __TICKET_INFO_UTILS_MQH__
