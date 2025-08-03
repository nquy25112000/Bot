import os, json, openai
from fastapi import FastAPI, HTTPException
from dotenv import load_dotenv
from models import AnalyzeRequest, BiasResult

load_dotenv()
openai.api_key = os.getenv("OPENAI_API_KEY")
MODEL          = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
TEMPERATURE    = float(os.getenv("TEMPERATURE", 0))

SYSTEM_PROMPT = (
    "Bạn là chuyên gia phân tích kỹ thuật ngoại hối với 15 năm kinh nghiệm. "
    "Nhận dữ liệu nến, hãy trả về JSON theo đúng schema BiasResult, "
    "không kèm chú thích."
)

app = FastAPI(title="BiasService")

def ask_openai(prompt: str) -> dict:
    rsp = openai.chat.completions.create(
        model=MODEL,
        temperature=TEMPERATURE,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user",   "content": prompt}
        ]
    )
    content = rsp.choices[0].message.content.strip()
    return json.loads(content)

@app.post("/analyze", response_model=BiasResult)
def analyze(req: AnalyzeRequest):
    bars_json = json.dumps([b.model_dump() for b in req.bars], ensure_ascii=False)
    prompt = (
        f"Symbol: {req.symbol}\n"
        f"Timeframe: {req.timeframe}\n"
        f"Bars: {bars_json}\n"
        "Trả về BiasResult JSON."
    )
    try:
        data = ask_openai(prompt)
        return BiasResult(**data)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
