from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class EventTextInput(BaseModel):
    user_id: str
    raw_text: str  # 유저가 자유 형식으로 입력한 일정 텍스트


class EventCreate(BaseModel):
    user_id: str
    title: str
    description: Optional[str] = None
    scheduled_at: datetime


class EventResponse(EventCreate):
    id: str
    created_at: datetime


class TaskCreate(BaseModel):
    user_id: str
    event_id: Optional[str] = None
    title: str
    duration_minutes: int
    scheduled_at: datetime


class TaskResponse(TaskCreate):
    id: str
    is_completed: bool
    completed_at: Optional[datetime] = None
    created_at: datetime


class EventWithTasksResponse(BaseModel):
    event: EventResponse
    tasks: list[TaskResponse]


class StreakResponse(BaseModel):
    user_id: str
    current_streak: int
    longest_streak: int
    total_xp: int
    last_completed_at: Optional[datetime] = None
