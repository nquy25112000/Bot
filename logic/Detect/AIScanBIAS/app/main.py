from fastapi import FastAPI, HTTPException
from .scheduler import start
from .storage import load
app = FastAPI(title="AIScanBIAS")
@app.on_event("startup")  # auto scheduler
def _st(): start()
@app.get("/bias/{tf}")
def get(tf:str):
    data=load(tf.upper());
    if data: return data
    raise HTTPException(404,"Not found")
