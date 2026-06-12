from calendar import monthrange
from datetime import date, datetime, time, timedelta

from fastapi import APIRouter, HTTPException, Query
from postgrest.exceptions import APIError

from models.schemas import (
    CalendarDayResponse,
    DayDetailResponse,
    EventResponse,
    GenerateScheduleResponse,
    MonthlyCalendarResponse,
    MonthlyPlanInput,
    TaskResponse,
)
from services.ai_service import distribute_monthly_plan
from services.supabase_client import get_supabase

router = APIRouter()

EVENT_TYPES = {"deadline", "recurring", "goal"}
EVENT_COLORS = {"red", "blue", "green", "orange"}


def _month_bounds(year: int, month: int) -> tuple[datetime, datetime]:
    if month < 1 or month > 12:
        raise HTTPException(status_code=422, detail="month는 1~12 사이여야 합니다.")
    start = datetime(year, month, 1)
    if month == 12:
        end = datetime(year + 1, 1, 1)
    else:
        end = datetime(year, month + 1, 1)
    return start, end


def _date_bounds(raw_date: date) -> tuple[datetime, datetime]:
    start = datetime.combine(raw_date, time.min)
    end = start + timedelta(days=1)
    return start, end


def _safe_event_type(value: str | None) -> str:
    return value if value in EVENT_TYPES else "goal"


def _safe_color(value: str | None, event_type: str) -> str:
    if value in EVENT_COLORS:
        return value
    return {
        "deadline": "red",
        "recurring": "blue",
        "goal": "green",
    }.get(event_type, "orange")


def _is_missing_column_error(exc: APIError) -> bool:
    message = str(exc)
    return "PGRST204" in message or "schema cache" in message or "Could not find" in message


def _insert_event(db, payload: dict) -> dict:
    try:
        res = db.table("events").insert(payload).execute()
    except APIError as exc:
        if not _is_missing_column_error(exc):
            raise
        legacy_payload = {
            key: value
            for key, value in payload.items()
            if key not in {"event_type", "color", "end_date"}
        }
        res = db.table("events").insert(legacy_payload).execute()
    if not res.data:
        raise HTTPException(status_code=500, detail="이벤트 저장 실패")
    return res.data[0]


def _insert_tasks(db, payloads: list[dict]) -> list[dict]:
    if not payloads:
        return []
    try:
        res = db.table("tasks").insert(payloads).execute()
    except APIError as exc:
        if not _is_missing_column_error(exc):
            raise
        legacy_payloads = [
            {key: value for key, value in payload.items() if key != "event_color"}
            for payload in payloads
        ]
        res = db.table("tasks").insert(legacy_payloads).execute()
    if not res.data:
        raise HTTPException(status_code=500, detail="태스크 저장 실패")
    return res.data


def _normalize_event(raw_event: dict, index: int) -> dict:
    event_type = _safe_event_type(raw_event.get("type") or raw_event.get("event_type"))
    return {
        "title": str(raw_event.get("title") or f"일정 {index + 1}")[:20],
        "event_type": event_type,
        "color": _safe_color(raw_event.get("color"), event_type),
        "tasks": raw_event.get("tasks") if isinstance(raw_event.get("tasks"), list) else [],
    }


@router.post("/generate", response_model=GenerateScheduleResponse)
def generate_schedule(payload: MonthlyPlanInput):
    if not payload.raw_text.strip():
        raise HTTPException(status_code=422, detail="일정을 입력해주세요.")

    start_of_month, start_of_next_month = _month_bounds(payload.plan_year, payload.plan_month)
    today = datetime.now()
    end_date = start_of_next_month - timedelta(seconds=1)

    try:
        ai_result = distribute_monthly_plan(payload.raw_text, today, end_date)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"AI 월간 배분 실패: {exc}")

    db = get_supabase()
    created_events: list[EventResponse] = []
    total_tasks = 0

    for index, raw_event in enumerate(ai_result.get("events", [])):
        normalized = _normalize_event(raw_event, index)
        raw_tasks = normalized["tasks"]
        task_dates = [
            datetime.fromisoformat(str(task["scheduled_at"]).replace("Z", "+00:00"))
            for task in raw_tasks
            if task.get("scheduled_at")
        ]
        scheduled_at = min(task_dates).isoformat() if task_dates else start_of_month.isoformat()
        end_at = max(task_dates).isoformat() if task_dates else None

        event = _insert_event(
            db,
            {
                "user_id": payload.user_id,
                "title": normalized["title"],
                "description": payload.raw_text,
                "scheduled_at": scheduled_at,
                "event_type": normalized["event_type"],
                "color": normalized["color"],
                "end_date": end_at,
            },
        )

        tasks_payload = [
            {
                "user_id": payload.user_id,
                "event_id": event["id"],
                "title": str(task.get("title") or normalized["title"]),
                "scheduled_at": task["scheduled_at"],
                "duration_minutes": int(task.get("duration_minutes") or 60),
                "is_completed": False,
                "event_color": normalized["color"],
            }
            for task in raw_tasks
            if task.get("scheduled_at")
        ]
        created_tasks = _insert_tasks(db, tasks_payload)
        total_tasks += len(created_tasks)
        created_events.append(EventResponse(**event))

    return GenerateScheduleResponse(events=created_events, total_tasks=total_tasks)


@router.get("/{user_id}/month", response_model=MonthlyCalendarResponse)
def get_monthly_calendar(user_id: str, year: int = Query(...), month: int = Query(...)):
    start, end = _month_bounds(year, month)
    db = get_supabase()

    task_res = (
        db.table("tasks")
        .select("*")
        .eq("user_id", user_id)
        .gte("scheduled_at", start.isoformat())
        .lt("scheduled_at", end.isoformat())
        .order("scheduled_at")
        .execute()
    )
    tasks = task_res.data or []

    event_res = (
        db.table("events")
        .select("*")
        .eq("user_id", user_id)
        .order("scheduled_at")
        .execute()
    )
    events = event_res.data or []
    event_by_id = {event.get("id"): event for event in events}

    days = []
    for day in range(1, monthrange(year, month)[1] + 1):
        current = date(year, month, day)
        current_tasks = [
            task for task in tasks
            if datetime.fromisoformat(str(task["scheduled_at"]).replace("Z", "+00:00")).date() == current
        ]
        task_events = [event_by_id.get(task.get("event_id"), {}) for task in current_tasks]
        days.append(
            CalendarDayResponse(
                date=current.isoformat(),
                tasks=[TaskResponse(**task) for task in current_tasks],
                has_deadline=any(event.get("event_type") == "deadline" for event in task_events),
                has_recurring=any(event.get("event_type") == "recurring" for event in task_events),
            )
        )

    return MonthlyCalendarResponse(
        year=year,
        month=month,
        days=days,
        events=[EventResponse(**event) for event in events],
    )


@router.get("/{user_id}/day", response_model=DayDetailResponse)
def get_day_detail(user_id: str, date: date = Query(...)):
    start, end = _date_bounds(date)
    db = get_supabase()
    res = (
        db.table("tasks")
        .select("*")
        .eq("user_id", user_id)
        .gte("scheduled_at", start.isoformat())
        .lt("scheduled_at", end.isoformat())
        .order("scheduled_at")
        .execute()
    )
    tasks = res.data or []
    completed = sum(1 for task in tasks if task.get("is_completed") is True)
    by_color = {
        "green": sum(1 for task in tasks if task.get("event_color", "green") == "green"),
        "blue": sum(1 for task in tasks if task.get("event_color") == "blue"),
        "red": sum(1 for task in tasks if task.get("event_color") == "red"),
    }
    parts = []
    if by_color["green"]:
        parts.append(f"공부 {by_color['green']}개")
    if by_color["blue"]:
        parts.append(f"반복 {by_color['blue']}개")
    if by_color["red"]:
        parts.append(f"마감 {by_color['red']}개")
    parts.append(f"완료 {completed}개")
    return DayDetailResponse(
        date=date.isoformat(),
        tasks=[TaskResponse(**task) for task in tasks],
        summary=" · ".join(parts),
    )
