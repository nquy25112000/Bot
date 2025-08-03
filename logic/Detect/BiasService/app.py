import os, json, openai
from fastapi import FastAPI, HTTPException
from dotenv import load_dotenv
from models import AnalyzeRequest, BiasResult

load_dotenv()
openai.api_key = os.getenv("OPENAI_API_KEY")
MODEL          = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
TEMP           = float(os.getenv("TEMPERATURE", 0))

SYSTEM = ("Bạn là chuyên gia phân tích kỹ thuật 15 năm kinh nghiệm. "
          "Nhận dữ liệu nến và trả về JSON đúng schema BiasResult.")

app = FastAPI(title="BiasService")

def ask_ai(prompt:str)->dict:
    rsp=openai.chat.completions.create(
        model=MODEL,temperature=TEMP,
        messages=[{"role":"system","content":SYSTEM},
                  {"role":"user","content":prompt}]
    )
    return json.loads(rsp.choices[0].message.content.strip())

@app.post("/analyze", response_model=BiasResult)
def analyze(req:AnalyzeRequest):
    bars=json.dumps([b.model_dump() for b in req.bars], ensure_ascii=False)
    prompt=(f"Symbol:{req.symbol}\nTimeframe:{req.timeframe}\nBars:{bars}\n"
            "Hãy trả về BiasResult JSON.")
    try:
        return BiasResult(**ask_ai(prompt))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
