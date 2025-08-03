//+------------------------------------------------------------------+
//| AI_Detect.mqh – khởi chạy BiasService + lấy BiasResult           |
//+------------------------------------------------------------------+
#ifndef __AI_DETECT_MQH__
#define __AI_DETECT_MQH__

//── WinExec (ẩn cửa sổ .cmd) ───────────────────────────────────────
#import "kernel32.dll"
   int  WinExec(const string lpCmdLine, uint uCmdShow);
#import

//── Tham số cấu hình (  để EA chỉnh) ──────────────────────────
  bool   Skip_StartBiasService      = false;
  bool   Allow_Init_Without_Service = true;
  int    WaitOnlineSec              = 20;
  string HealthURL                  = "http://127.0.0.1:8000/healthz";
  string BiasService_URL            = "http://127.0.0.1:8000/analyze";
  int    BiasService_TimeoutMs      = 30000;
  int    Bars_To_Send               = 20;

#define MAX_WAIT_MS (WaitOnlineSec*1000)

//────────────────────────────────────────────────────────────────────
// 1) Khởi động / kiểm tra BiasService
//────────────────────────────────────────────────────────────────────
bool StartBiasService()
{
   uchar dummy[]; uchar resp[]; string hdr="";

   if(Skip_StartBiasService) return true;

   // Đã online?
   if(WebRequest("GET", HealthURL, "", 3000, dummy, resp, hdr) == 200)
   {  Print("🟢 BiasService đã chạy."); return true; }

   Print("ℹ️  Khởi động BiasService…");

   string ea = MQLInfoString(MQL_PROGRAM_PATH);
   int p = StringFind(ea, "\\Experts\\");
   if(p < 0){ Print("❌ Không tìm thấy \\Experts\\."); return false; }

   string cmd = StringSubstr(ea,0,p+8)+"\\Advisors\\Bot\\logic\\Detect\\BiasService\\StartBiasService.cmd";
   if(!FileIsExist(cmd)){ PrintFormat("❌ Thiếu %s",cmd); return false; }

   if(WinExec(cmd,0) < 31){ Print("❌ WinExec lỗi."); return false; }

   ulong t0 = GetTickCount();
   while(GetTickCount()-t0 < MAX_WAIT_MS)
   {
      if(WebRequest("GET", HealthURL, "", 1500, dummy, resp, hdr) == 200)
      {  Print("✅ BiasService online"); return true; }
      Sleep(500);
   }
   PrintFormat("⚠️  Chưa online sau %d giây", WaitOnlineSec);
   return false;
}

bool EnsureBiasService()
{
   if(StartBiasService()) return true;
   if(Allow_Init_Without_Service)
   { Print("⚠️  Tiếp tục chạy dù BiasService offline"); return true; }
   return false;
}

//────────────────────────────────────────────────────────────────────
// 2) Build JSON body gửi AI
//────────────────────────────────────────────────────────────────────
string BuildRequestBody(const string sym,const ENUM_TIMEFRAMES tf,int bars_n)
{
   MqlRates r[]; int n=CopyRates(sym,tf,1,bars_n,r);
   if(n<=0){ Print("CopyRates err ",GetLastError()); return""; }

   string js="[";                       // bars JSON
   for(int i=n-1;i>=0;i--)
   {
      if(i!=n-1) js+=",";
      js+=StringFormat("{\"t\":%d,\"o\":%.5f,\"h\":%.5f,\"l\":%.5f,\"c\":%.5f}",
                       r[i].time,r[i].open,r[i].high,r[i].low,r[i].close);
   }
   js+="]";
   string tf_s=(tf==PERIOD_D1?"D1":tf==PERIOD_H4?"H4":"H1");
   return StringFormat("{\"symbol\":\"%s\",\"timeframe\":\"%s\",\"bars\":%s}",sym,tf_s,js);
}

//────────────────────────────────────────────────────────────────────
// 3) Gửi & parse BiasResult
//────────────────────────────────────────────────────────────────────
bool ParseBiasResultFromJson(const string json, BiasResult &out); // bạn cài đặt

bool RequestBias(const string sym,const ENUM_TIMEFRAMES tf,BiasResult &out)
{
   string body=BuildRequestBody(sym,tf,Bars_To_Send); if(body=="") return false;

   uchar data[]; int len=StringToCharArray(body,data,0,CP_UTF8);
   uchar resp[]; string hdr="";

   int code=WebRequest("POST", BiasService_URL, "Content-Type: application/json\r\n",
                       BiasService_TimeoutMs,
                       data, resp, hdr);

   if(code!=200){ Print("BiasService HTTP ",code," err=",GetLastError()); return false; }

   string json=CharArrayToString(resp);
   if(!ParseBiasResultFromJson(json,out)){ Print("ParseBiasResultFromJson fail"); return false; }

   return true;
}

#endif // __AI_DETECT_MQH__
