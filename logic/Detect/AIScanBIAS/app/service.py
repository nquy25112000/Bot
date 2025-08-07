from .openai_client import ask_bias
from .storage import save
def _chart(tf:str)->dict: return {"demo":True}  # TODO: lấy OHLCV thật
def scan():                               # D1 → H4 → H1
    for tf in ("D1","H4","H1"):
        save(tf, ask_bias(tf, _chart(tf)))
