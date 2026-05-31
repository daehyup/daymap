from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

from routers import events, tasks, streaks

load_dotenv()

app = FastAPI(title="Daymap API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(events.router, prefix="/events", tags=["events"])
app.include_router(tasks.router, prefix="/tasks", tags=["tasks"])
app.include_router(streaks.router, prefix="/streaks", tags=["streaks"])


@app.get("/health")
def health_check():
    return {"status": "ok"}
