#include "utils/StringUtils.mqh"
#ifndef __STRING_UTILS_MQH__
#define __STRING_UTILS_MQH__

//-------------------------------------------------------------
// Tách chuỗi theo ký tự phân tách và lưu vào mảng result[]
//
// Params:
// - source: chuỗi đầu vào
// - delimiter: ký tự phân tách (ví dụ: " ")
// - result[]: mảng string đầu ra sau khi tách
//-------------------------------------------------------------
void SplitString(string source, string delimiter, string& result[]) {
  ArrayResize(result, 0);
  int start = 0, pos;
  while ((pos = StringFind(source, delimiter, start)) != -1) {
    int n = ArraySize(result);
    ArrayResize(result, n+1);
    result[n] = StringSubstr(source, start, pos - start);
    start = pos + StringLen(delimiter);
  }
  if (start <= StringLen(source)) {
    int n = ArraySize(result);
    ArrayResize(result, n+1);
    result[n] = StringSubstr(source, start);
  }
}

//-------------------------------------------------------------
// Hàm thêm một phần tử vào mảng string
//-------------------------------------------------------------
void AddToStringArray(string& arr[], const string value) {
  int n = ArraySize(arr);
  ArrayResize(arr, n+1);
  arr[n] = value;
}

#endif // __STRING_UTILS_MQH__
