from fastapi import FastAPI, HTTPException
from .scheduler import start
from .storage import load
from .service import scan

app = FastAPI(title="AIScanBIAS")

@app.on_event("startup")
def _st(): start()

@app.get("/health")
def health(): return {"ok": True}

@app.post("/scan")
def run_scan():
    scan()
    return {"status":"ok"}

@app.get("/bias/{tf}")
def get(tf:str):
    data = load(tf.upper())
    if data: return data
    raise HTTPException(404,"Not found")
