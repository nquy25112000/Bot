from openai import OpenAI
from .config import OPENAI_API_KEY
def ask_bias(tf: str, data: dict) -> str:
    client = OpenAI(api_key=OPENAI_API_KEY)
    prompt = (
        f"Dữ liệu {tf}: {data}\n"
        "Trả về JSON đúng struct BiasResult (BUY/SELL/NONE, percent, bullScore…)"
    )
    r = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role":"system","content":"Chuyên gia price-action."},
                  {"role":"user","content":prompt}]
    )
    return r.choices[0].message.content
