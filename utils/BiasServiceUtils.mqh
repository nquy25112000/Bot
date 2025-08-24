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
   string envExe = "Z:\\usr\\bin\\env"; // Wine map /usr/bin/env
   string script = dir + "\\run_api.sh";

   if(!FileIsExist(envExe))
   {
      Print("❌ Không tìm thấy Z:\\usr\\bin\\env");
      return false;
   }
   if(!FileIsExist(script))
   {
      PrintFormat("❌ Không thấy script: %s", script);
      return false;
   }

   string args = "bash \"" + script + "\"";
   int rc = ShellExecuteW(0, "open", envExe, args, dir, SW_HIDE);
   if (rc <= 32)
   {
      PrintFormat("❌ ShellExecuteW thất bại (rc=%d)", rc);
      return false;
   }

   Print("🚀 AIScanBIAS script started");
   return true;
}


void StopBiasService()
{
   // Kill theo port cho chắc (trên mac chạy qua python, không phải uvicorn.exe)
   // Bạn có thể gọi thủ công bằng script riêng. Tạm giữ placeholder:
   Print("⛔ Gợi ý dừng: lsof -ti :8001 | xargs -r kill");
}

#endif // __BIAS_SERVICE_UTILS_MQH__
