#ifndef __START_BIAS_SERVICE_MQH__
#define __START_BIAS_SERVICE_MQH__

#import "kernel32.dll"
int  WinExec(string cmd, int nShow);
#import

input bool  Skip_StartBiasService = false;   // bật true nếu đã chạy service trước
#define  MAX_WAIT_MS  15000                 // 15s chờ service online

bool StartBiasService()
{
   const string HEALTH = "http://127.0.0.1:8000/healthz";
   uchar send[], recv[]; string hdr="";

   // 0) cho phép skip (hữu ích khi back-test hàng loạt)
   if(Skip_StartBiasService)
      return(true);

   // 1) service đã chạy?
   if(WebRequest("GET",HEALTH,"",3000,send,recv,hdr)==200)
   {  Print("🟢 BiasService đã chạy sẵn (HTTP 200).");  return true; }

   Print("ℹ️  BiasService chưa chạy – khởi động…");

   // 2) Xây đúng đường dẫn .cmd nằm cùng project
   string eaPath  = MQLInfoString(MQL_PROGRAM_PATH);      // …\Experts\Advisors\Bot\BiasBot.ex5
   int    posBot  = StringFind(eaPath,"\\Experts\\");     // tách tới gốc /Experts
   string rootDir = StringSubstr(eaPath,0,posBot+8);      // …\Experts
   string cmdFile = rootDir + "\\Advisors\\Bot\\logic\\Detect\\BiasService\\StartBiasService.cmd";

   if(!FileIsExist(cmdFile))
   {  PrintFormat("❌ Không tìm thấy %s", cmdFile); return false; }

   // 3) gọi WinExec (ẩn cửa sổ)
   if(WinExec(cmdFile,0)<31)
   {  Print("❌ WinExec thất bại – kiểm tra quyền DLL."); return false; }

   // 4) chờ tới khi online
   ulong t0=GetTickCount();
   while(GetTickCount()-t0 < MAX_WAIT_MS)
   {
      if(WebRequest("GET",HEALTH,"",1500,send,recv,hdr)==200)
      {  Print("✅ BiasService online, ready.");  return true; }
      Sleep(500);
   }
   Print("⚠️  Chưa online sau ", DoubleToString(MAX_WAIT_MS/1000,0),"s.");
   return false;
}
#endif
