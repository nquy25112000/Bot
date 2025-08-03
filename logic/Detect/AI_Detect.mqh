//+------------------------------------------------------------------+
//| AI_Detect.mqh – khởi chạy BiasService + gửi bars lấy BiasResult  |
//+------------------------------------------------------------------+
#ifndef __AI_DETECT_MQH__
#define __AI_DETECT_MQH__

//──── 1. WinExec để chạy StartBiasService.cmd ──────────────────────
#import "kernel32.dll"
   int  WinExec(string cmd, int nShow);      // nShow = 0 ẩn cửa sổ
#import

//──── 2. Inputs cấu hình ───────────────────────────────────────────
input bool   Skip_StartBiasService      = false;   // tự chạy service trước
input bool   Allow_Init_Without_Service = true;    // cho EA chạy dù service offline
input int    WaitOnlineSec              = 20;      // max chờ service online
input string HealthURL                  = "http://127.0.0.1:8000/healthz";
input string BiasService_URL            = "http://127.0.0.1:8000/analyze";
input int    BiasService_TimeoutMs      = 30000;   // timeout POST (ms)
input int    Bars_To_Send               = 20;      // số nến gửi AI

#define MAX_WAIT_MS (WaitOnlineSec*1000)

//──── 3. Khởi chạy / health-check BiasService ──────────────────────
bool StartBiasService()
{
   uchar  dummy_send[];                    // body trống
   uchar  resp[];  string hdr="";

   if(Skip_StartBiasService) return true;

   // ① thử healthz
   if(WebRequest("GET",HealthURL,"",3000,dummy_send,0,resp,hdr) == 200)
   {  Print("🟢 BiasService đã chạy.");  return true; }

   Print("ℹ️  BiasService chưa chạy – khởi động…");

   // ② tìm StartBiasService.cmd
   string eaPath = MQLInfoString(MQL_PROGRAM_PATH);
   int p = StringFind(eaPath,"\\Experts\\");
   if(p<0){ Print("❌ Không tìm thấy \\Experts\\."); return false; }

   string expertsDir = StringSubstr(eaPath,0,p+8);
   string cmdFile = expertsDir+"\\Advisors\\Bot\\logic\\Detect\\BiasService\\StartBiasService.cmd";
   if(!FileIsExist(cmdFile)){ PrintFormat("❌ Thiếu %s",cmdFile); return false; }

   // ③ WinExec
   if(WinExec(cmdFile,0) < 31){ Print("❌ WinExec lỗi – kiểm DLL."); return false; }

   // ④ chờ online
   ulong t0 = GetTickCount();
   while(GetTickCount()-t0 < MAX_WAIT_MS)
   {
      if(WebRequest("GET",HealthURL,"",1500,dummy_send,0,resp,hdr) == 200)
      {  Print("✅ BiasService online");  return true; }
      Sleep(500);
   }
   PrintFormat("⚠️  Chưa online sau %d s.", WaitOnlineSec);
   return false;
}

bool EnsureBiasService()
{
   if(StartBiasService())       return true;
   if(Allow_Init_Without_Service)
   {  Print("⚠️  Chạy EA dù BiasService offline"); return true; }
   return false;
}

//──── 4. Tạo JSON body từ bars ─────────────────────────────────────
string BuildRequestBody(const string symbol,const ENUM_TIMEFRAMES tf,int bars_n)
{
   MqlRates rates[];
   int copied = CopyRates(symbol, tf, 1, bars_n, rates);
   if(copied<=0){ PrintFormat("CopyRates err %d", GetLastError()); return ""; }

   string bars="[";
   for(int i=copied-1;i>=0;i--)               // cũ → mới
   {
      if(i!=copied-1) bars+=",";
      bars += StringFormat(
              "{\"t\":%d,\"o\":%.5f,\"h\":%.5f,\"l\":%.5f,\"c\":%.5f}",
              rates[i].time,rates[i].open,rates[i].high,rates[i].low,rates[i].close);
   }
   bars+="]";

   string tf_s = (tf==PERIOD_D1?"D1": tf==PERIOD_H4?"H4":"H1");
   return StringFormat("{\"symbol\":\"%s\",\"timeframe\":\"%s\",\"bars\":%s}", symbol, tf_s, bars);
}

//──── 5. Gửi & Parse BiasResult ────────────────────────────────────
bool ParseBiasResultFromJson(const string json, BiasResult &out);   // phải implement ở file khác

bool RequestBias(const string symbol,const ENUM_TIMEFRAMES tf,BiasResult &out)
{
   string body = BuildRequestBody(symbol, tf, Bars_To_Send);
   if(StringLen(body)==0) return false;

   uchar  bytes[];   int len = StringToCharArray(body, bytes, 0, CP_UTF8);
   string headers = "Content-Type: application/json\r\n";

   char   resp[];
   string respHdr="";
   ResetLastError();
   int code = WebRequest("POST", BiasService_URL, headers,
                         BiasService_TimeoutMs,
                         bytes, len,
                         resp, respHdr);

   if(code != 200)
   {  PrintFormat("BiasService HTTP %d (Err=%d)", code, GetLastError()); return false; }

   string json = CharArrayToString(resp);
   if(!ParseBiasResultFromJson(json, out))
   {  Print("ParseBiasResultFromJson fail"); return false; }

   // out.timeframe nên gán trong ParseBiasResultFromJson; nếu không, sửa tại đây.
   return true;
}

#endif // __AI_DETECT_MQH__
