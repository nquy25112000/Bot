//+------------------------------------------------------------------+
//| BiasServiceUtils.mqh – START / STOP AIScanBIAS micro-service     |
//+------------------------------------------------------------------+
#ifndef  __BIAS_SERVICE_UTILS_MQH__          // ← ĐÚNG ID
#define  __BIAS_SERVICE_UTILS_MQH__

#define  SW_HIDE   0

//--- Import ShellExecuteW trực tiếp
#import "shell32.dll"
int ShellExecuteW( int  hwnd,
                   string lpOperation,
                   string lpFile,
                   string lpParameters,
                   string lpDirectory,
                   int    nShowCmd );
#import

//--- Thư mục micro-service
string BiasServiceDir()
{
   return TerminalInfoString(TERMINAL_DATA_PATH) +
          "\\MQL5\\Experts\\Advisors\\Bot\\logic\\Detect\\AIScanBIAS";
}

//------------------------------------------------------------------
//| KHỞI CHẠY micro-service                                          |
//------------------------------------------------------------------
void StartBiasService()
{
   string exe = BiasServiceDir() + "\\.venv\\Scripts\\uvicorn.exe";
   if(!FileIsExist(exe))
   {
      PrintFormat("❌ Không tìm thấy: %s", exe);
      return;
   }
   string params = "app.main:app --host 127.0.0.1 --port 8000";
   ShellExecuteW(0, "open", exe, params, BiasServiceDir(), SW_HIDE);
   Print("✅ AIScanBIAS started.");
}

//------------------------------------------------------------------
//| DỪNG micro-service                                               |
//------------------------------------------------------------------
void StopBiasService()
{
   ShellExecuteW(0, "open", "taskkill", "/IM uvicorn.exe /F", "", SW_HIDE);
   Print("⛔ AIScanBIAS stopped.");
}

#endif // __BIAS_SERVICE_UTILS_MQH__
