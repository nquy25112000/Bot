from datetime import datetime
from typing import List, Literal
from pydantic import BaseModel, Field

class Bar(BaseModel):
    t: int
    o: float; h: float; l: float; c: float

class AnalyzeRequest(BaseModel):
    symbol: str
    timeframe: Literal["H1", "H4", "D1"]
    bars: List[Bar] = Field(..., min_items=5, max_items=100)

class BiasResult(BaseModel):
    symbol: str
    timeframe: Literal["H1", "H4", "D1"]
    type: Literal["BUY", "SELL", "NONE"]
    percent: float
    bullScore: float
    bearScore: float
    patternId: int
    patternName: str
    patternScore: float
    patternCandles: int
    patternShift: int
    patternTime: datetime
    patternStrength: str
