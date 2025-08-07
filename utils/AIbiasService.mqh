//+------------------------------------------------------------------+
//| BiasServiceUtils.mqh – START / STOP AIScanBIAS micro-service     |
//+------------------------------------------------------------------+
#ifndef __BIAS_SERVICE_UTILS_MQH__          // <-- Header-guard DUY NHẤT
#define __BIAS_SERVICE_UTILS_MQH__

#define SW_HIDE  0                          // Ẩn cửa sổ CMD

/* -------------------- IMPORT ShellExecuteW --------------------- */
/*  MQL yêu cầu #import … #import đứng MỘT LẦN duy nhất trong file */
#import "shell32.dll"                       // Windows native DLL
int ShellExecuteW( int     hwnd,
                   string  lpOperation,
                   string  lpFile,
                   string  lpParameters,
                   string  lpDirectory,
                   int     nShowCmd );
#import
/* --------------------------------------------------------------- */

/* ----------- Đường dẫn thư mục chứa micro-service -------------- */
string BiasServiceDir()                     // hàm tiện ích
{
   return TerminalInfoString(TERMINAL_DATA_PATH) +
          "\\MQL5\\Experts\\Advisors\\Bot\\logic\\Detect\\AIScanBIAS";
}

/* ------------------ KHỞI CHẠY micro-service -------------------- */
void StartBiasService()                     // KHÔNG trả về giá trị
{
   string exe = BiasServiceDir() + "\\.venv\\Scripts\\uvicorn.exe";
   if(!FileIsExist(exe))
   {
      PrintFormat("❌ StartBiasService: Không tìm thấy %s", exe);
      return;                               // hàm void: return OK
   }
   string params = "app.main:app --host 127.0.0.1 --port 8000";
   ShellExecuteW(0, "open", exe, params, BiasServiceDir(), SW_HIDE);
   Print("✅ AIScanBIAS started.");
}

/* ------------------ DỪNG micro-service ------------------------- */
void StopBiasService()
{
   // Dùng taskkill diệt toàn bộ process uvicorn
   ShellExecuteW(0, "open", "taskkill", "/IM uvicorn.exe /F", "", SW_HIDE);
   Print("⛔ AIScanBIAS stopped.");
}

#endif  // __BIAS_SERVICE_UTILS_MQH__
