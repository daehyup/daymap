from datetime import datetime, time, timedelta, timezone

from fastapi import APIRouter, HTTPException
from models.schemas import TaskCreate, TaskResponse
from services.supabase_client import get_supabase

XP_PER_COMPLETION = 10

router = APIRouter()


@router.post("/", response_model=TaskResponse)
async def create_task(task: TaskCreate):
    # TODO: 태스크 생성
    raise HTTPException(status_code=501, detail="Not implemented")


@router.get("/{user_id}/today", response_model=list[TaskResponse])
def get_today_tasks(user_id: str):
    today = datetime.now().date()
    start_of_day = datetime.combine(today, time.min)
    start_of_tomorrow = start_of_day + timedelta(days=1)

    db = get_supabase()
    res = (
        db.table("tasks")
        .select("*")
        .eq("user_id", user_id)
        .gte("scheduled_at", start_of_day.isoformat())
        .lt("scheduled_at", start_of_tomorrow.isoformat())
        .order("scheduled_at")
        .execute()
    )
    return res.data


@router.patch("/{task_id}/complete", response_model=TaskResponse)
def complete_task(task_id: str):
    db = get_supabase()
    now = datetime.now(timezone.utc).isoformat()

    # 1. tasks 업데이트
    task_res = (
        db.table("tasks")
        .update({"is_completed": True, "completed_at": now})
        .eq("id", task_id)
        .execute()
    )

    if not task_res.data:
        raise HTTPException(status_code=404, detail="태스크를 찾을 수 없습니다")

    task = task_res.data[0]
    user_id = task["user_id"]

    # 2. streaks XP 추가 (행이 없으면 신규 생성)
    streak_res = db.table("streaks").select("*").eq("user_id", user_id).execute()

    if streak_res.data:
        current_xp = streak_res.data[0]["total_xp"]
        db.table("streaks").update({
            "total_xp": current_xp + XP_PER_COMPLETION,
            "last_completed_at": now,
        }).eq("user_id", user_id).execute()
    else:
        db.table("streaks").insert({
            "user_id": user_id,
            "total_xp": XP_PER_COMPLETION,
            "current_streak": 1,
            "longest_streak": 1,
            "last_completed_at": now,
        }).execute()

    return TaskResponse(**task)


@router.patch("/{task_id}/redistribute")
async def redistribute_task(task_id: str):
    # TODO: 미완료 태스크 AI 재배분
    raise HTTPException(status_code=501, detail="Not implemented")
