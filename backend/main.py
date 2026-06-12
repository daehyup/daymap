from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from pathlib import Path

from routers import events, schedule, tasks, streaks, users

load_dotenv(Path(__file__).resolve().parent / ".env")

app = FastAPI(title="Daymap API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(events.router, prefix="/events", tags=["events"])
app.include_router(schedule.router, prefix="/schedule", tags=["schedule"])
app.include_router(tasks.router, prefix="/tasks", tags=["tasks"])
app.include_router(streaks.router, prefix="/streaks", tags=["streaks"])
app.include_router(users.router, prefix="/users", tags=["users"])


@app.get("/health")
def health_check():
    return {"status": "ok"}
