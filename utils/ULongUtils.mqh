#include "utils/ULongUtils.mqh"
#ifndef __ULONG_UTILS_MQH__
#define __ULONG_UTILS_MQH__

//-------------------------------------------------------------
// Chuyển chuỗi số (dạng string) sang số nguyên không dấu (ulong)
// Bỏ qua ký tự không phải số
//-------------------------------------------------------------
ulong StringToULong(const string s) {
  ulong result = 0;
  for(int i=0; i<StringLen(s); i++) {
    ushort c = StringGetCharacter(s, i);
    if(c < '0' || c > '9') break;
    result = result*10 + (ulong)(c - '0');
  }
  return result;
}

//-------------------------------------------------------------
// Chuyển số nguyên không dấu (ulong) thành chuỗi tương ứng
//-------------------------------------------------------------
string ULongToString(ulong value) {
  if(value == 0) return "0";
  string r = "";
  while(value > 0) {
    int d = value % 10;
    r = IntegerToString(d) + r;
    value /= 10;
  }
  return r;
}

#endif // __ULONG_UTILS_MQH__
