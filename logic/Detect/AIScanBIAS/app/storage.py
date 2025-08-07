from pathlib import Path, PurePath
import json
DATA_DIR = PurePath(__file__).resolve().parent.parent / "data"
DATA_DIR.mkdir(exist_ok=True)
def save(tf:str, text:str): (DATA_DIR/f"bias_{tf}.json").write_text(text,'utf-8')
def load(tf:str):
    p = DATA_DIR/f"bias_{tf}.json"
    return json.loads(p.read_text('utf-8')) if p.exists() else None
