//+------------------------------------------------------------------+
//| BiasServiceUtils.mqh – START / STOP AIScanBIAS micro-service     |
//+------------------------------------------------------------------+
#ifndef  __BIAS_SERVICE_UTILS_MQH__
#define  __BIAS_SERVICE_UTILS_MQH__

#define  SW_HIDE   0

//--- Import ShellExecuteW trực tiếp
#import "shell32.dll"
int ShellExecuteW(int hwnd, string lpOperation, string lpFile, string lpParameters, string lpDirectory, int nShowCmd);
#import

//--- Thư mục micro-service
string BiasServiceDir()
{
   return TerminalInfoString(TERMINAL_DATA_PATH) +
          "\\MQL5\\Experts\\Advisors\\Bot\\logic\\Detect\\AIScanBIAS";
}

//------------------------------------------------------------------
//| KHỞI CHẠY micro-service                                         |
//------------------------------------------------------------------
bool StartBiasService()
{
   string dir = BiasServiceDir();  // ví dụ: Z:\Users\...\AIScanBIAS

   // Đường dẫn python trong venv macOS/Linux
   string py_unix = dir + "\\.venv\\bin\\python";
   // Đường dẫn python trong venv Windows
   string py_win  = dir + "\\.venv\\Scripts\\python.exe";

   string pythonExe = "";
   if (FileIsExist(py_unix))
      pythonExe = py_unix;
   else if (FileIsExist(py_win))
      pythonExe = py_win;

   if (pythonExe == "")
   {
      Print("❌ Không tìm thấy Python trong venv. Hãy tạo venv & cài deps ở thư mục AIScanBIAS.");
      return false;
   }

   // Port 8001 theo yêu cầu của bạn
   string params = "-m uvicorn app.main:app --host 127.0.0.1 --port 8010";

   int rc = ShellExecuteW(0, "open", pythonExe, params, dir, SW_HIDE);
   if (rc <= 32)
   {
      PrintFormat("❌ ShellExecuteW thất bại (rc=%d). file=%s params=%s", rc, pythonExe, params);
      return false;
   }

   Print("✅ AIScanBIAS started (python -m uvicorn).");
   return true;
}

//------------------------------------------------------------------
//| DỪNG micro-service                                              |
//------------------------------------------------------------------
void StopBiasService()
{
   // Trên mac/Linux, uvicorn chạy qua python nên process name khác
   // Nếu muốn kill chuẩn, nên lưu pid khi start hoặc kill theo port
   ShellExecuteW(0, "open", "taskkill", "/IM uvicorn.exe /F", "", SW_HIDE);
   Print("⛔ AIScanBIAS stopped.");
}

#endif // __BIAS_SERVICE_UTILS_MQH__
