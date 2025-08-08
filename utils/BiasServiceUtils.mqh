//+------------------------------------------------------------------+
//| BiasServiceUtils.mqh – START / STOP AIScanBIAS micro-service     |
//+------------------------------------------------------------------+
#ifndef  __BIAS_SERVICE_UTILS_MQH__
#define  __BIAS_SERVICE_UTILS_MQH__

#define  SW_HIDE   0

#import "shell32.dll"
int ShellExecuteW(int hwnd, string lpOperation, string lpFile, string lpParameters, string lpDirectory, int nShowCmd);
#import

string BiasServiceDir()
{
   return TerminalInfoString(TERMINAL_DATA_PATH) +
          "\\MQL5\\Experts\\Advisors\\Bot\\logic\\Detect\\AIScanBIAS";
}

bool StartBiasService()
{
   string dir = BiasServiceDir();

   string py_unix = dir + "\\.venv\\bin\\python";          // mac/linux venv
   string py_win  = dir + "\\.venv\\Scripts\\python.exe";  // windows venv

   string pythonExe = "";
   if (FileIsExist(py_unix)) pythonExe = py_unix;
   else if (FileIsExist(py_win)) pythonExe = py_win;

   if (pythonExe == "")
   {
      Print("❌ Không tìm thấy Python trong venv. Hãy tạo venv & cài deps ở thư mục AIScanBIAS.");
      return false;
   }

   string params = "-m uvicorn app.main:app --host 127.0.0.1 --port 8001";
   int rc = ShellExecuteW(0, "open", pythonExe, params, dir, SW_HIDE);
   if (rc <= 32)
   {
      PrintFormat("❌ ShellExecuteW thất bại (rc=%d). file=%s params=%s", rc, pythonExe, params);
      return false;
   }

   Print("✅ AIScanBIAS started (python -m uvicorn).");
   return true;
}

void StopBiasService()
{
   // Kill theo port cho chắc (trên mac chạy qua python, không phải uvicorn.exe)
   // Bạn có thể gọi thủ công bằng script riêng. Tạm giữ placeholder:
   Print("⛔ Gợi ý dừng: lsof -ti :8001 | xargs -r kill");
}

#endif // __BIAS_SERVICE_UTILS_MQH__
