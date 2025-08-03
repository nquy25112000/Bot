# BiasService

Micro-service FastAPI nhận dữ liệu nến, gọi OpenAI và trả về kết quả dạng `BiasResult`.

## Cài đặt nhanh
```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env     # điền OPENAI_API_KEY
uvicorn app:app --host 0.0.0.0 --port 8000
