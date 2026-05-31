from fastapi import APIRouter, HTTPException
from models.schemas import TaskCreate, TaskResponse

router = APIRouter()


@router.post("/", response_model=TaskResponse)
async def create_task(task: TaskCreate):
    # TODO: 태스크 생성
    raise HTTPException(status_code=501, detail="Not implemented")


@router.get("/{user_id}/today")
async def get_today_tasks(user_id: str):
    # TODO: 오늘의 태스크 목록 조회
    raise HTTPException(status_code=501, detail="Not implemented")


@router.patch("/{task_id}/complete")
async def complete_task(task_id: str):
    # TODO: 태스크 완료 처리 + XP 지급
    raise HTTPException(status_code=501, detail="Not implemented")


@router.patch("/{task_id}/redistribute")
async def redistribute_task(task_id: str):
    # TODO: 미완료 태스크 AI 재배분
    raise HTTPException(status_code=501, detail="Not implemented")
