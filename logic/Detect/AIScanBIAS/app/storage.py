# app/storage.py
from pathlib import Path
import json

# Dùng Path (có resolve), không dùng PurePath
DATA_DIR = Path(__file__).resolve().parent.parent / "data"
DATA_DIR.mkdir(parents=True, exist_ok=True)

def save(tf: str, text: str):
    (DATA_DIR / f"bias_{tf}.json").write_text(text, 'utf-8')

def load(tf: str):
    p = DATA_DIR / f"bias_{tf}.json"
    return json.loads(p.read_text('utf-8')) if p.exists() else None
