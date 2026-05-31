from datetime import datetime
from fastapi import APIRouter, HTTPException

from models.schemas import (
    EventTextInput,
    EventResponse,
    TaskResponse,
    EventWithTasksResponse,
)
from services.supabase_client import get_supabase
from services.ai_service import distribute_tasks

router = APIRouter()


@router.post("/", response_model=EventWithTasksResponse)
def create_event(payload: EventTextInput):
    if not payload.raw_text.strip():
        raise HTTPException(status_code=422, detail="일정을 입력해주세요.")

    db = get_supabase()
    today = datetime.now()

    # 1. Groq로 날짜별 할일 배분
    try:
        ai_result = distribute_tasks(payload.raw_text, today)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"AI 배분 실패: {e}")

    # 2. events 테이블에 저장
    event_insert = db.table("events").insert({
        "user_id": payload.user_id,
        "title": ai_result["event_title"],
        "description": payload.raw_text,
        "scheduled_at": today.isoformat(),
    }).execute()

    if not event_insert.data:
        raise HTTPException(status_code=500, detail="일정 저장 실패")

    event = event_insert.data[0]

    # 3. tasks 테이블에 일괄 저장
    tasks_payload = [
        {
            "user_id": payload.user_id,
            "event_id": event["id"],
            "title": t["title"],
            "scheduled_at": t["scheduled_at"],
            "duration_minutes": t["duration_minutes"],
            "is_completed": False,
        }
        for t in ai_result["tasks"]
    ]

    tasks_insert = db.table("tasks").insert(tasks_payload).execute()

    if not tasks_insert.data:
        raise HTTPException(status_code=500, detail="태스크 저장 실패")

    return EventWithTasksResponse(
        event=EventResponse(**event),
        tasks=[TaskResponse(**t) for t in tasks_insert.data],
    )


@router.get("/{user_id}", response_model=list[EventResponse])
def get_events(user_id: str):
    db = get_supabase()
    res = (
        db.table("events")
        .select("*")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .execute()
    )
    return res.data


@router.delete("/{event_id}")
def delete_event(event_id: str):
    db = get_supabase()
    # 연결된 태스크 먼저 삭제
    db.table("tasks").delete().eq("event_id", event_id).execute()
    res = db.table("events").delete().eq("id", event_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="일정을 찾을 수 없습니다")
    return {"deleted": event_id}
