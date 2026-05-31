from fastapi import APIRouter, HTTPException
from models.schemas import StreakResponse

router = APIRouter()


@router.get("/{user_id}", response_model=StreakResponse)
async def get_streak(user_id: str):
    # TODO: 유저 스트릭 및 XP 조회
    raise HTTPException(status_code=501, detail="Not implemented")


@router.post("/{user_id}/penalty")
async def apply_penalty(user_id: str):
    # TODO: 미완료 페널티 적용 (스트릭 초기화)
    raise HTTPException(status_code=501, detail="Not implemented")
