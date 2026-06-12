from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException
from postgrest.exceptions import APIError
from models.schemas import TaskCreate, TaskResponse
from services.supabase_client import get_supabase

XP_PER_COMPLETION = 10
KST = timezone(timedelta(hours=9))

router = APIRouter()


def _is_missing_column_error(exc: APIError) -> bool:
    message = str(exc)
    return "PGRST204" in message or "schema cache" in message or "Could not find" in message


@router.post("/", response_model=TaskResponse)
async def create_task(task: TaskCreate):
    # TODO: 태스크 생성
    raise HTTPException(status_code=501, detail="Not implemented")


@router.get("/{user_id}/today", response_model=list[TaskResponse])
def get_today_tasks(user_id: str):
    today = datetime.now(KST).date()
    start_of_day = datetime(today.year, today.month, today.day, tzinfo=KST)
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
    now = datetime.now(KST)
    now_iso = now.isoformat()

    task_res = (
        db.table("tasks")
        .update({"is_completed": True, "completed_at": now_iso})
        .eq("id", task_id)
        .execute()
    )

    if not task_res.data:
        raise HTTPException(status_code=404, detail="태스크를 찾을 수 없습니다")

    task = task_res.data[0]
    user_id = task["user_id"]

    streak_res = db.table("streaks").select("*").eq("user_id", user_id).execute()
    today = now.date()

    if streak_res.data:
        row = streak_res.data[0]
        current_streak = row.get("current_streak") or 0
        longest_streak = row.get("longest_streak") or 0
        total_xp = row.get("total_xp") or 0
        last_completed_at = row.get("last_completed_at")

        if last_completed_at:
            last_date = datetime.fromisoformat(
                str(last_completed_at).replace("Z", "+00:00")
            ).astimezone(KST).date()
            days_diff = (today - last_date).days

            if days_diff == 0:
                new_streak = current_streak
            elif days_diff == 1:
                new_streak = current_streak + 1
            else:
                new_streak = 1
        else:
            new_streak = 1

        new_longest = max(longest_streak, new_streak)
        update_payload = {
            "total_xp": total_xp + XP_PER_COMPLETION,
            "current_streak": new_streak,
            "longest_streak": new_longest,
            "last_completed_at": now_iso,
        }
        try:
            db.table("streaks").update(update_payload).eq("user_id", user_id).execute()
        except APIError as exc:
            if not _is_missing_column_error(exc):
                raise
            update_payload.pop("last_completed_at", None)
            db.table("streaks").update(update_payload).eq("user_id", user_id).execute()
    else:
        insert_payload = {
            "user_id": user_id,
            "total_xp": XP_PER_COMPLETION,
            "current_streak": 1,
            "longest_streak": 1,
            "last_completed_at": now_iso,
        }
        try:
            db.table("streaks").insert(insert_payload).execute()
        except APIError as exc:
            if not _is_missing_column_error(exc):
                raise
            insert_payload.pop("last_completed_at", None)
            db.table("streaks").insert(insert_payload).execute()

    return TaskResponse(**task)
