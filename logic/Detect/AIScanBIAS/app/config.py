# app/config.py
from pathlib import Path
import os, dotenv
BASE_DIR = Path(__file__).resolve().parent.parent
dotenv.load_dotenv(BASE_DIR / ".env")

OPENAI_API_KEY  = os.getenv("OPENAI_API_KEY", "")
OPENAI_BASE_URL = os.getenv("OPENAI_BASE_URL", None)
OPENAI_MODEL    = os.getenv("OPENAI_MODEL", "gpt-4o")
TIMEZONE        = os.getenv("TIMEZONE", "Asia/Ho_Chi_Minh")
USE_MOCK        = os.getenv("USE_MOCK", "0") in ("1","true","True","yes","YES")
