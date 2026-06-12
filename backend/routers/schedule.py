from calendar import monthrange
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException, Query
from postgrest.exceptions import APIError

from models.schemas import (
    CalendarDayResponse,
    DayDetailResponse,
    EventResponse,
    EventProgressResponse,
    GenerateScheduleResponse,
    MonthlyCalendarResponse,
    MonthlyPlanInput,
    ProgressSummaryResponse,
    RedistributeResponse,
    TaskResponse,
)
from services.ai_service import distribute_monthly_plan, redistribute_tasks
from services.supabase_client import get_supabase

router = APIRouter()

EVENT_TYPES = {"deadline", "recurring", "goal"}
EVENT_COLORS = {"red", "blue", "green", "orange"}
KST = timezone(timedelta(hours=9))


def _month_bounds(year: int, month: int) -> tuple[datetime, datetime]:
    if month < 1 or month > 12:
        raise HTTPException(status_code=422, detail="month는 1~12 사이여야 합니다.")
    start = datetime(year, month, 1, tzinfo=KST)
    if month == 12:
        end = datetime(year + 1, 1, 1, tzinfo=KST)
    else:
        end = datetime(year, month + 1, 1, tzinfo=KST)
    return start, end


def _date_bounds(raw_date: date) -> tuple[datetime, datetime]:
    start = datetime(raw_date.year, raw_date.month, raw_date.day, tzinfo=KST)
    end = start + timedelta(days=1)
    return start, end


def _parse_datetime(value: object) -> datetime:
    parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=KST)
    return parsed.astimezone(KST)


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
            {
                key: value
                for key, value in payload.items()
                if key not in {"event_color", "is_rescheduled"}
            }
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
    today = datetime.now(KST)
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
            _parse_datetime(task["scheduled_at"])
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
            if _parse_datetime(task["scheduled_at"]).date() == current
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


@router.post("/{user_id}/redistribute", response_model=RedistributeResponse)
def redistribute_incomplete_tasks(user_id: str):
    """
    어제 이전 미완료 태스크를 이벤트별 마감일까지 AI 재배분.
    앱 시작 시 또는 사용자가 '재배분' 버튼 탭 시 호출.
    """
    db = get_supabase()
    today = datetime.now(KST)
    yesterday_end = datetime(today.year, today.month, today.day, tzinfo=KST)

    past_incomplete = (
        db.table("tasks")
        .select("*")
        .eq("user_id", user_id)
        .eq("is_completed", False)
        .eq("is_rescheduled", False)
        .lt("scheduled_at", yesterday_end.isoformat())
        .execute()
    ).data or []

    if not past_incomplete:
        return RedistributeResponse(
            rescheduled_count=0,
            new_tasks=[],
            message="재배분할 미완료 태스크가 없습니다",
        )

    tasks_by_event: dict[str, list[dict]] = defaultdict(list)
    for task in past_incomplete:
        tasks_by_event[task.get("event_id") or "__no_event__"].append(task)

    event_ids = [event_id for event_id in tasks_by_event if event_id != "__no_event__"]
    events_data = {}
    if event_ids:
        events_res = (
            db.table("events")
            .select("id, end_date, title, color")
            .in_("id", event_ids)
            .execute()
        )
        for event in (events_res.data or []):
            events_data[event["id"]] = event

    future_tasks_res = (
        db.table("tasks")
        .select("scheduled_at, duration_minutes")
        .eq("user_id", user_id)
        .eq("is_completed", False)
        .gte("scheduled_at", today.isoformat())
        .execute()
    )
    existing_schedule: dict[str, int] = defaultdict(int)
    for task in (future_tasks_res.data or []):
        scheduled_date = _parse_datetime(task["scheduled_at"]).strftime("%Y-%m-%d")
        existing_schedule[scheduled_date] += int(task.get("duration_minutes") or 60)

    all_new_tasks: list[dict] = []
    old_task_ids: list[str] = []

    for event_id, incomplete in tasks_by_event.items():
        event = events_data.get(event_id, {})
        deadline_str = event.get("end_date")

        if deadline_str:
            deadline = _parse_datetime(deadline_str)
        else:
            deadline = today + timedelta(days=14)

        if deadline.date() <= today.date():
            deadline = today + timedelta(days=3)

        try:
            ai_result = redistribute_tasks(
                incomplete_tasks=incomplete,
                existing_schedule=dict(existing_schedule),
                today=today,
                deadline=deadline,
            )
        except Exception:
            continue

        event_color = event.get("color", "green")
        event_new_count = 0
        for new_task in ai_result.get("tasks", []):
            scheduled_at = new_task.get("scheduled_at")
            if not scheduled_at:
                continue

            duration_minutes = int(new_task.get("duration_minutes") or 60)
            all_new_tasks.append({
                "user_id": user_id,
                "event_id": event_id if event_id != "__no_event__" else None,
                "title": str(new_task.get("title") or ""),
                "scheduled_at": scheduled_at,
                "duration_minutes": duration_minutes,
                "is_completed": False,
                "is_rescheduled": False,
                "event_color": event_color,
            })
            event_new_count += 1

            scheduled_date = _parse_datetime(scheduled_at).strftime("%Y-%m-%d")
            existing_schedule[scheduled_date] += duration_minutes

        if event_new_count:
            old_task_ids.extend([task["id"] for task in incomplete])

    if not all_new_tasks:
        return RedistributeResponse(
            rescheduled_count=0,
            new_tasks=[],
            message="AI 재배분 결과가 없습니다",
        )

    if old_task_ids:
        db.table("tasks").update({"is_rescheduled": True}).in_("id", old_task_ids).execute()

    created = _insert_tasks(db, all_new_tasks)
    count = len(created)
    return RedistributeResponse(
        rescheduled_count=count,
        new_tasks=[TaskResponse(**task) for task in created],
        message=f"{count}개 태스크를 재배분했습니다",
    )


@router.get("/{user_id}/progress", response_model=ProgressSummaryResponse)
def get_progress(user_id: str):
    """
    사용자의 모든 활성 이벤트별 달성 가능성 피드백 카드 반환.
    달력 화면 상단 카드 슬라이더에 사용.
    """
    db = get_supabase()
    today = datetime.now(KST).date()

    events_res = (
        db.table("events")
        .select("*")
        .eq("user_id", user_id)
        .execute()
    )
    events = events_res.data or []

    if not events:
        return ProgressSummaryResponse(cards=[], overall_completion_rate=0.0)

    tasks_res = (
        db.table("tasks")
        .select("event_id, is_completed, scheduled_at, duration_minutes")
        .eq("user_id", user_id)
        .eq("is_rescheduled", False)
        .execute()
    )
    all_tasks = tasks_res.data or []

    tasks_by_event: dict[str, list[dict]] = defaultdict(list)
    for task in all_tasks:
        if task.get("event_id"):
            tasks_by_event[task["event_id"]].append(task)

    cards = []
    total_completed = 0
    total_tasks = 0

    for event in events:
        event_id = event["id"]
        event_tasks = tasks_by_event.get(event_id, [])

        if not event_tasks:
            continue

        task_total = len(event_tasks)
        task_completed = sum(1 for task in event_tasks if task.get("is_completed") is True)
        completion_rate = round((task_completed / task_total) * 100, 1) if task_total else 0.0

        total_tasks += task_total
        total_completed += task_completed

        end_date_str = event.get("end_date")
        deadline_date = None
        days_until = None
        if end_date_str:
            deadline_date = _parse_datetime(end_date_str).date()
            days_until = (deadline_date - today).days

        status, status_label, message = _calculate_status(
            completion_rate=completion_rate,
            days_until_deadline=days_until,
            total_tasks=task_total,
            completed_tasks=task_completed,
            event_title=event.get("title", ""),
            event_type=event.get("event_type", "goal"),
        )

        cards.append(EventProgressResponse(
            event_id=event_id,
            event_title=event.get("title", ""),
            event_type=event.get("event_type", "goal"),
            color=event.get("color", "green"),
            deadline=deadline_date.isoformat() if deadline_date else None,
            days_until_deadline=days_until,
            total_tasks=task_total,
            completed_tasks=task_completed,
            completion_rate=completion_rate,
            remaining_tasks=task_total - task_completed,
            status=status,
            status_label=status_label,
            message=message,
        ))

    cards.sort(key=lambda card: (
        0 if card.event_type == "deadline" else 1,
        card.days_until_deadline if card.days_until_deadline is not None else 999,
    ))

    overall = round((total_completed / total_tasks) * 100, 1) if total_tasks else 0.0
    return ProgressSummaryResponse(cards=cards, overall_completion_rate=overall)


@router.get("/{user_id}/heatmap")
def get_heatmap(user_id: str, year: int = Query(...)):
    """
    연간 날짜별 완료율 반환. Flutter 히트맵 화면에 사용.
    """
    db = get_supabase()
    start = datetime(year, 1, 1, tzinfo=KST)
    end = datetime(year + 1, 1, 1, tzinfo=KST)

    res = (
        db.table("tasks")
        .select("scheduled_at, is_completed")
        .eq("user_id", user_id)
        .eq("is_rescheduled", False)
        .gte("scheduled_at", start.isoformat())
        .lt("scheduled_at", end.isoformat())
        .execute()
    )
    tasks = res.data or []

    daily: dict[str, dict] = defaultdict(lambda: {"total": 0, "completed": 0})
    for task in tasks:
        day = _parse_datetime(task["scheduled_at"]).strftime("%Y-%m-%d")
        daily[day]["total"] += 1
        if task.get("is_completed"):
            daily[day]["completed"] += 1

    result = []
    for date_str, counts in sorted(daily.items()):
        total = counts["total"]
        completed = counts["completed"]
        rate = round((completed / total) * 100) if total else 0
        level = 0 if total == 0 else (
            4 if rate == 100 else
            3 if rate >= 67 else
            2 if rate >= 34 else 1
        )
        result.append({
            "date": date_str,
            "total": total,
            "completed": completed,
            "rate": rate,
            "level": level,
        })

    return {"year": year, "days": result}


def _calculate_status(
    completion_rate: float,
    days_until_deadline: Optional[int],
    total_tasks: int,
    completed_tasks: int,
    event_title: str,
    event_type: str,
) -> tuple[str, str, str]:
    remaining = total_tasks - completed_tasks

    if event_type == "recurring":
        return "on_track", "진행 중", f"매주 반복 · {completed_tasks}회 완료"

    if days_until_deadline is None:
        if completion_rate >= 80:
            return "comfortable", "여유", f"전체의 {completion_rate:.0f}% 완료했어요"
        if completion_rate >= 50:
            return "on_track", "순조", f"절반 이상 완료 · 남은 {remaining}개"
        return "warning", "주의", f"아직 {100 - completion_rate:.0f}% 남았어요"

    if days_until_deadline <= 0:
        if completion_rate >= 100:
            return "comfortable", "완료", f"{event_title} 모두 완료했어요!"
        return "critical", "마감", f"마감일이 지났어요 · {remaining}개 미완료"

    if days_until_deadline <= 3:
        if completion_rate >= 80:
            return "on_track", "순조", f"D-{days_until_deadline} · 마지막 정리만 남았어요"
        return "critical", "위험", f"D-{days_until_deadline} · 오늘 {min(remaining, 3)}개 이상 필요해요"

    daily_required = remaining / days_until_deadline if days_until_deadline > 0 else remaining

    if completion_rate >= 80:
        return "comfortable", "여유", f"D-{days_until_deadline} · 지금 페이스면 충분해요"
    if daily_required <= 2:
        return "on_track", "순조", f"D-{days_until_deadline} · 하루 {daily_required:.0f}개씩 하면 됩니다"
    if daily_required <= 4:
        return "warning", "주의", f"D-{days_until_deadline} · 하루 {daily_required:.0f}개 필요해요"
    return "critical", "위험", f"D-{days_until_deadline} · 오늘 집중이 필요합니다"
