from fastapi import APIRouter, HTTPException
from models.schemas import StreakResponse
from services.supabase_client import get_supabase

router = APIRouter()


@router.get("/{user_id}", response_model=StreakResponse)
def get_streak(user_id: str):
    db = get_supabase()
    res = db.table("streaks").select("*").eq("user_id", user_id).execute()
    if not res.data:
        return StreakResponse(
            user_id=user_id,
            current_streak=0,
            longest_streak=0,
            total_xp=0,
        )
    return res.data[0]


@router.post("/{user_id}/penalty")
def apply_penalty(user_id: str):
    db = get_supabase()
    res = db.table("streaks").select("*").eq("user_id", user_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="스트릭 데이터가 없습니다")

    db.table("streaks").update({
        "current_streak": 0,
    }).eq("user_id", user_id).execute()

    return {"message": "페널티 적용 완료: 스트릭 초기화"}
