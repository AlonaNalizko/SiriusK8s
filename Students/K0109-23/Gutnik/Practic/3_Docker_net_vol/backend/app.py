import uvicorn
from fastapi import FastAPI
import psycopg2, os
import json

app = FastAPI()

def get_db():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost:5432"),
        database=os.getenv("DB_NAME", "postgres"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASS", "postgres"),
    )

@app.get("/api/items")
async def read_item():
    conn = get_db()
    cur = conn.cursor()
    cur.execute("SELECT id, name FROM items")
    rows = cur.fetchall()
    conn.close()
    return json.dumps([{"id": r[0], "name": r[1]} for r in rows])

@app.get('/health')
def health():
    return {"status": "ok"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000)