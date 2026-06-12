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
    event_type: str = "goal"
    color: str = "green"
    end_date: Optional[datetime] = None


class EventResponse(EventCreate):
    id: str
    created_at: datetime


class TaskCreate(BaseModel):
    user_id: str
    event_id: Optional[str] = None
    title: str
    duration_minutes: int
    scheduled_at: datetime
    event_color: str = "green"


class TaskResponse(TaskCreate):
    id: str
    is_completed: bool
    completed_at: Optional[datetime] = None
    created_at: datetime


class EventWithTasksResponse(BaseModel):
    event: EventResponse
    tasks: list[TaskResponse]


class MonthlyPlanInput(BaseModel):
    user_id: str
    raw_text: str
    plan_year: int
    plan_month: int


class CalendarDayResponse(BaseModel):
    date: str
    tasks: list[TaskResponse]
    has_deadline: bool
    has_recurring: bool


class MonthlyCalendarResponse(BaseModel):
    year: int
    month: int
    days: list[CalendarDayResponse]
    events: list[EventResponse]


class DayDetailResponse(BaseModel):
    date: str
    tasks: list[TaskResponse]
    summary: str


class GenerateScheduleResponse(BaseModel):
    events: list[EventResponse]
    total_tasks: int


class StreakResponse(BaseModel):
    user_id: str
    current_streak: int
    longest_streak: int
    total_xp: int
    last_completed_at: Optional[datetime] = None
