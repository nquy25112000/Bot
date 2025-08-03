//+------------------------------------------------------------------+
//| AI_Client.mqh                                                    |
//| Gọi trực tiếp OpenAI để nhận kết quả Bias cho BOT               |
//+------------------------------------------------------------------+
#ifndef __AI_CLIENT_MQH__
#define __AI_CLIENT_MQH__

#include <Trade\WebRequest.mqh>

//--- Inputs (đặt trong Inputs của EA) --------------------------------
extern string OpenAI_API_Key;               // API key của bạn
extern string OpenAI_Model      = "text-davinci-003";
extern int    OpenAI_MaxTokens  = 128;
extern double OpenAI_Temperature = 0.0;

//--- Kiểu Timeframe của BiasResult -----------------------------------
enum BiasTF
{
   BIAS_TF_H1 = 0,
   BIAS_TF_H4 = 1,
   BIAS_TF_D1 = 2
};

//--- Struct chứa kết quả trả về --------------------------------------
struct BiasResult
{
   string   symbol;
   BiasTF   timeframe;
   string   type;          // "BUY" | "SELL" | "NONE"
   double   percent;
   double   bullScore;
   double   bearScore;
   int      patternId;
   string   patternName;
   double   patternScore;
   int      patternCandles;
   int      patternShift;
   datetime patternTime;
   string   patternStrength;
};

//--- Helper: escape JSON string --------------------------------------
string JsonEscape(const string s)
{
   string out="";
   for(int i=0;i<StringLen(s);i++)
   {
      uchar c = StringGetCharacter(s,i);
      if(c==34) out+="\\\\\"";  // dấu "
      else       out+=StringFormat("%c",c);
   }
   return out;
}

//--- Build JSON prompt từ n cây nến gần nhất ------------------------
string FormatPrompt(const string symbol, const ENUM_TIMEFRAMES tf, int bars_count)
{
   // Lấy dữ liệu nến (bỏ bar hiện tại, từ vị trí 1)
   MqlRates rates[];
   int copied = CopyRates(symbol, tf, 1, bars_count, rates);
   if(copied<=0)
   {
      PrintFormat("CopyRates lỗi: %d", GetLastError());
      return("");
   }

   // Chuyển thành mảng JSON bars
   string bars="[";
   for(int i=0;i<copied;i++)
   {
      if(i>0) bars+=",";
      bars+=Format(
         "{\"t\":%d,\"o\":%.5f,\"h\":%.5f,\"l\":%.5f,\"c\":%.5f}",
         rates[i].time,
         rates[i].open,
         rates[i].high,
         rates[i].low,
         rates[i].close
      );
   }
   bars+="]";

   // Chuyển ENUM_TIMEFRAMES sang chữ
   string tf_str = (tf==PERIOD_D1 ? "D1" :
                    tf==PERIOD_H4 ? "H4" : "H1");

   // Tạo prompt tiếng Việt hoặc tiếng Anh tuỳ bạn
   return Format(
      "Dựa trên %d cây nến gần nhất của %s khung %s: %s\n"
      "Hãy phân tích và trả về kết quả Bias dưới dạng JSON đúng cấu trúc của struct BiasResult.",
      bars_count, symbol, tf_str, bars
   );
}

//--- Gửi request và parse kết quả vào BiasResult --------------------
bool RequestBias(const string symbol, const ENUM_TIMEFRAMES tf, BiasResult &res)
{
   // 1) Build prompt
   string raw = FormatPrompt(symbol, tf, 20);
   if(StringLen(raw)==0) return(false);

   // 2) Escape và tạo body JSON
   string esc = JsonEscape(raw);
   string body = Format(
      "{\"model\":\"%s\",\"prompt\":\"%s\",\"max_tokens\":%d,\"temperature\":%.2f}",
      OpenAI_Model, esc, OpenAI_MaxTokens, OpenAI_Temperature
   );
   uchar bytes[];
   int   len = StringToCharArray(body, bytes, 0, CP_UTF8);

   // 3) Tiêu đề HTTP
   string headers =
      "Content-Type: application/json\r\n"
      "Authorization: Bearer " + OpenAI_API_Key;

   // 4) Gọi WebRequest
   ResetLastError();
   char resp[];
   int  code = WebRequest(
      "POST",
      "https://api.openai.com/v1/completions",
      headers,
      30000,
      bytes, len,
      resp, NULL
   );
   if(code!=200)
   {
      PrintFormat("OpenAI API lỗi HTTP %d (Err=%d)", code, GetLastError());
      return(false);
   }

   // 5) Chuyển về string và trích JSON phần AI trả về
   string reply = CharArrayToString(resp);
   int    p     = StringFind(reply, "{");
   if(p<0)
   {
      Print("Không tìm thấy JSON trong reply");
      return(false);
   }
   string json = StringSubstr(reply, p);

   // 6) Parse JSON thành struct (bạn tự implement)
   if(!ParseBiasResultFromJson(json, res))
   {
      Print("ParseBiasResultFromJson thất bại");
      return(false);
   }

   // 7) Gán lại trường timeframe trong struct
   res.timeframe = (tf==PERIOD_D1?BIAS_TF_D1:
                   (tf==PERIOD_H4?BIAS_TF_H4:BIAS_TF_H1));

   return(true);
}

#endif // __AI_CLIENT_MQH__
