# app/openai_client.py
from openai import OpenAI
from .config import OPENAI_API_KEY, OPENAI_BASE_URL, OPENAI_MODEL, USE_MOCK

def _mock(tf: str, data: dict) -> str:
    return (
        '{{"type":"NONE","percent":0.0,"bullScore":0,"bearScore":0,'
        '"timeframe":"{}","note":"mocked"}}'.format(tf)
    )


def ask_bias(tf: str, data: dict) -> str:
    if USE_MOCK or not OPENAI_API_KEY:
        return _mock(tf, data)

    client = OpenAI(api_key=OPENAI_API_KEY, base_url=OPENAI_BASE_URL or None)
    prompt = (
        f"Dữ liệu {tf}: {data}\n"
        "Trả về JSON đúng struct BiasResult (BUY/SELL/NONE, percent, bullScore, bearScore, timeframe)."
    )
    try:
        r = client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=[
                {"role":"system","content":"Chuyên gia price-action."},
                {"role":"user","content":prompt}
            ],
            temperature=0.2,
        )
        return r.choices[0].message.content
    except Exception as e:
        # Fallback để không làm vỡ flow khi quota/billing lỗi
        return _mock(tf, {"error": str(e)})
