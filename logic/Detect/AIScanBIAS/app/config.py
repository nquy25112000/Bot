from pathlib import Path
import os, dotenv
BASE_DIR = Path(__file__).resolve().parent.parent
dotenv.load_dotenv(BASE_DIR / ".env")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
TIMEZONE = "Asia/Ho_Chi_Minh"
