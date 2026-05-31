import os
import json
from datetime import datetime
from groq import Groq

_client: Groq | None = None


def _get_client() -> Groq:
    global _client
    if _client is None:
        _client = Groq(api_key=os.environ["GROQ_API_KEY"])
    return _client


_PROMPT_TEMPLATE = """오늘 날짜: {today}

아래 일정 텍스트를 분석해서 구체적인 날짜별 할일로 배분해주세요.

규칙:
- 오전 9시 ~ 오후 10시 사이에 배치
- 현실적인 소요 시간 추정
- 하나의 큰 일정은 작은 단계로 쪼개기
- 날짜가 명시되지 않으면 오늘부터 적절히 배분

일정:
{raw_text}

반드시 아래 JSON 형식으로만 반환하세요:
{{
  "event_title": "일정 제목 (한국어, 20자 이내)",
  "tasks": [
    {{
      "title": "할일 제목 (한국어, 구체적으로)",
      "scheduled_at": "YYYY-MM-DDTHH:MM:SS",
      "duration_minutes": 30
    }}
  ]
}}"""


def distribute_tasks(raw_text: str, today: datetime) -> dict:
    """
    유저 입력 텍스트 → Groq(llama-3.3-70b)가 날짜별 할일로 배분
    Returns: {"event_title": str, "tasks": [{"title", "scheduled_at", "duration_minutes"}]}
    """
    prompt = _PROMPT_TEMPLATE.format(
        today=today.strftime("%Y-%m-%d (%A)"),
        raw_text=raw_text,
    )

    response = _get_client().chat.completions.create(
        model="llama-3.3-70b-versatile",
        response_format={"type": "json_object"},
        messages=[{"role": "user", "content": prompt}],
    )

    try:
        result = json.loads(response.choices[0].message.content)
    except json.JSONDecodeError as e:
        raise ValueError(f"AI 응답 파싱 실패: {e}")

    if "event_title" not in result or "tasks" not in result:
        raise ValueError("AI 응답에 필수 필드가 없습니다")

    return result
