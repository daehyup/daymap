from datetime import datetime, timezone

from fastapi import APIRouter
from pydantic import BaseModel

from services.supabase_client import get_supabase

router = APIRouter()


class FcmTokenRequest(BaseModel):
    fcm_token: str


@router.post("/{user_id}/fcm-token")
def register_fcm_token(user_id: str, body: FcmTokenRequest):
    db = get_supabase()
    db.table("users").upsert({
        "user_id": user_id,
        "fcm_token": body.fcm_token,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).execute()
    return {"message": "FCM 토큰 등록 완료"}
