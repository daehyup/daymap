import os
import json
import re
from datetime import datetime
from groq import Groq

_client: Groq | None = None


def _get_client() -> Groq:
    global _client
    if _client is None:
        _client = Groq(api_key=os.environ["GROQ_API_KEY"])
    return _client


_PROMPT_TEMPLATE = """오늘 날짜: {today}
분석 기간: {today} ~ {end_date}

아래 일정들을 분석해서 날짜별 할일 계획을 세워주세요.

입력 일정:
{raw_text}

분석 규칙:
0. 언어 규칙:
   - 모든 title은 반드시 자연스러운 한국어로만 작성
   - 영어, 중국어, 일본어, 러시아어, 로마자 표기를 절대 섞지 않음
   - invitation은 "초대장", guest는 "하객", preparation은 "준비", attendance는 "참석"처럼 한국어로 번역
   - 외국어 고유명사가 꼭 필요해도 한국어 발음 또는 한국어 설명으로 작성

1. 마감일이 있는 일정(시험, 과제, 제출 등):
   - 마감일 자체는 tasks에 포함하지 않음
   - 마감일까지 남은 날짜를 역산해서 준비 일정 배분
   - 마감 가까울수록 학습량 증가

2. 반복 일정(알바, 수업 등):
   - 해당 요일에 고정 블록으로 배치
   - 반복 일정이 있는 날은 다른 일정 부담 줄이기

3. 배치 시간:
   - 오전 9시 ~ 오후 10시 사이
   - 반복 일정(알바 등)은 시간 명시 없으면 오후 2시~6시로 가정
   - 하루 최대 학습/준비 시간: 3~4시간

4. 일정 유형 구분:
   - type "deadline": 시험, 제출, 마감 등
   - type "recurring": 알바, 수업 등 반복
   - type "goal": 공부, 준비, 운동 등

반드시 아래 JSON 형식으로만 반환하세요:
{{
  "events": [
    {{
      "title": "이벤트 제목 (20자 이내)",
      "type": "deadline | recurring | goal",
      "color": "red | blue | green | orange",
      "tasks": [
        {{
          "title": "구체적 할일",
          "scheduled_at": "YYYY-MM-DDTHH:MM:SS",
          "duration_minutes": 60,
          "event_index": 0
        }}
      ]
    }}
  ]
}}

color 규칙: deadline=red, recurring=blue, goal=green, 기타=orange
"""

_FOREIGN_TEXT_RE = re.compile(r"[A-Za-z\u3040-\u30ff\u3400-\u9fff\u0400-\u04ff]+")
_SPACE_RE = re.compile(r"\s+")
_KOREAN_REPLACEMENTS = {
    "結婚式": "결혼식",
    "結婚": "결혼",
    "出席": "참석",
    "invitiation": "초대장",
    "invitation": "초대장",
    "guest": "하객",
    "gue스트": "하객",
    "preparation": "준비",
    "attendance": "참석",
    "подготов": "준비",
    "확율": "확률",
    "액세사리": "액세서리",
}


def _sanitize_korean_text(value: object, fallback: str) -> str:
    text = str(value or fallback).strip()
    for source, target in _KOREAN_REPLACEMENTS.items():
        text = text.replace(source, target)
    text = _FOREIGN_TEXT_RE.sub("", text)
    text = _SPACE_RE.sub(" ", text).strip(" -_/·,")
    return text or fallback


def _sanitize_ai_result(result: dict) -> dict:
    for event in result.get("events", []):
        event["title"] = _sanitize_korean_text(event.get("title"), "일정")
        for task in event.get("tasks", []):
            task["title"] = _sanitize_korean_text(task.get("title"), event["title"])
    return result


def distribute_monthly_plan(raw_text: str, today: datetime, end_date: datetime) -> dict:
    """
    유저 입력 텍스트 → Groq가 월간 이벤트/할일 계획으로 배분
    Returns: {"events": [{"title", "type", "color", "tasks": [...]}]}
    """
    prompt = _PROMPT_TEMPLATE.format(
        today=today.strftime("%Y-%m-%d"),
        end_date=end_date.strftime("%Y-%m-%d"),
        raw_text=raw_text,
    )

    response = _get_client().chat.completions.create(
        model="llama-3.3-70b-versatile",
        response_format={"type": "json_object"},
        messages=[
            {
                "role": "system",
                "content": "당신은 한국어 일정 플래너입니다. 모든 출력 텍스트는 반드시 자연스러운 한국어로만 작성합니다.",
            },
            {"role": "user", "content": prompt},
        ],
    )

    try:
        result = json.loads(response.choices[0].message.content)
    except json.JSONDecodeError as e:
        raise ValueError(f"AI 응답 파싱 실패: {e}")

    if "events" not in result or not isinstance(result["events"], list):
        raise ValueError("AI 응답에 필수 필드가 없습니다")

    return _sanitize_ai_result(result)


_REDISTRIBUTE_PROMPT = """오늘 날짜: {today}
이벤트 마감일: {deadline}
남은 날짜: {days_remaining}일

아래 미완료 태스크들을 오늘({today})부터 마감일({deadline}) 사이에 재배분해주세요.

미완료 태스크:
{incomplete_tasks}

날짜별 이미 예약된 일정 (분 단위):
{existing_schedule}

재배분 규칙:
- 오전 9시 ~ 오후 10시 사이에 배치
- 하루 총 배치 시간은 기존 예약 포함 최대 240분
- 마감에 가까울수록 하루 할당량 늘리기
- 마감 3일 전부터: 복습/정리 위주 태스크로 제목 수정 가능
- 기존 예약된 시간대와 겹치지 않게

반드시 아래 JSON 형식으로만 반환:
{{
  "tasks": [
    {{
      "original_task_id": "원본_task_id",
      "title": "할일 제목",
      "scheduled_at": "YYYY-MM-DDTHH:MM:SS",
      "duration_minutes": 60
    }}
  ]
}}"""


def redistribute_tasks(
    incomplete_tasks: list[dict],
    existing_schedule: dict[str, int],
    today: datetime,
    deadline: datetime,
) -> dict:
    """
    미완료 태스크들을 today ~ deadline 사이에 AI로 재배분.
    Returns: {"tasks": [{"original_task_id", "title", "scheduled_at", "duration_minutes"}]}
    """
    days_remaining = (deadline.date() - today.date()).days

    tasks_text = "\n".join(
        f"- [{task['id']}] {task['title']} ({task['duration_minutes']}분)"
        for task in incomplete_tasks
    )
    schedule_text = "\n".join(
        f"- {date}: {minutes}분 예약됨"
        for date, minutes in existing_schedule.items()
    ) or "없음"

    prompt = _REDISTRIBUTE_PROMPT.format(
        today=today.strftime("%Y-%m-%d"),
        deadline=deadline.strftime("%Y-%m-%d"),
        days_remaining=days_remaining,
        incomplete_tasks=tasks_text,
        existing_schedule=schedule_text,
    )

    response = _get_client().chat.completions.create(
        model="llama-3.3-70b-versatile",
        response_format={"type": "json_object"},
        messages=[
            {
                "role": "system",
                "content": "당신은 한국어 일정 플래너입니다. 모든 출력 텍스트는 반드시 자연스러운 한국어로만 작성합니다.",
            },
            {"role": "user", "content": prompt},
        ],
    )

    try:
        result = json.loads(response.choices[0].message.content)
    except json.JSONDecodeError as e:
        raise ValueError(f"AI 재배분 응답 파싱 실패: {e}")

    if "tasks" not in result:
        raise ValueError("AI 재배분 응답에 tasks 필드가 없습니다")

    return result


def distribute_tasks(raw_text: str, today: datetime) -> dict:
    """기존 /events API 호환용 래퍼."""
    result = distribute_monthly_plan(raw_text, today, today)
    events = result.get("events") or []
    first_event = events[0] if events else {"title": "일정", "tasks": []}
    return {
        "event_title": first_event.get("title", "일정"),
        "tasks": first_event.get("tasks", []),
    }
