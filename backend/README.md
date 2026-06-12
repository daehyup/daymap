# Daymap Backend API

Daymap backend is a FastAPI service that turns natural-language schedule text into events and tasks, stores them in Supabase, and tracks task completion XP.

## Stack

- FastAPI
- Supabase
- Groq API
- Pydantic
- Uvicorn

## Setup

Install dependencies from the repository root:

```bash
pip install -r backend/requirements.txt
```

Create `backend/.env` with the required service credentials:

```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-supabase-service-role-key
GROQ_API_KEY=your-groq-api-key
FCM_SERVER_KEY=your-firebase-server-key
```

Run the API locally:

```bash
cd backend
uvicorn main:app --reload
```

Railway starts the service with `backend/Procfile`:

```text
web: uvicorn main:app --host 0.0.0.0 --port $PORT
```

Default base URL:

```text
http://127.0.0.1:8000
```

## Response Models

### Event

```json
{
  "user_id": "test-user",
  "title": "시험 준비",
  "description": "정보처리기사 실기 7월 20일",
  "scheduled_at": "2026-06-01T10:00:00",
  "event_type": "deadline",
  "color": "red",
  "end_date": "2026-06-25T18:00:00",
  "id": "event-id",
  "created_at": "2026-06-01T10:00:00"
}
```

### Task

```json
{
  "user_id": "test-user",
  "event_id": "event-id",
  "title": "정보처리기사 실기 공부",
  "duration_minutes": 60,
  "scheduled_at": "2026-06-02T09:00:00",
  "event_color": "red",
  "is_rescheduled": false,
  "id": "task-id",
  "is_completed": false,
  "completed_at": null,
  "created_at": "2026-06-01T10:00:00"
}
```

### Streak

```json
{
  "user_id": "test-user",
  "current_streak": 1,
  "longest_streak": 1,
  "total_xp": 10,
  "last_completed_at": "2026-06-01T15:00:00+00:00"
}
```

## Health

### GET `/health`

Returns API health status.

Response:

```json
{
  "status": "ok"
}
```

## Events

### POST `/events/`

Creates an event from natural-language input, asks Groq to distribute tasks, saves the event to `events`, and saves generated tasks to `tasks`.

Request body:

```json
{
  "user_id": "test-user",
  "raw_text": "정보처리기사 실기 7월 20일, 기말고사 6월 25일"
}
```

Success response:

```json
{
  "event": {
    "user_id": "test-user",
    "title": "시험 준비",
    "description": "정보처리기사 실기 7월 20일, 기말고사 6월 25일",
    "scheduled_at": "2026-06-01T10:00:00",
    "id": "event-id",
    "created_at": "2026-06-01T10:00:00"
  },
  "tasks": [
    {
      "user_id": "test-user",
      "event_id": "event-id",
      "title": "정보처리기사 실기 공부",
      "duration_minutes": 60,
      "scheduled_at": "2026-06-02T09:00:00",
      "id": "task-id",
      "is_completed": false,
      "completed_at": null,
      "created_at": "2026-06-01T10:00:00"
    }
  ]
}
```

Errors:

- `422`: `raw_text` is empty or whitespace
- `502`: Groq task distribution failed
- `500`: Supabase event or task insert failed

### GET `/events/{user_id}`

Returns all events for a user, sorted by `created_at` descending.

Response:

```json
[
  {
    "user_id": "test-user",
    "title": "시험 준비",
    "description": "정보처리기사 실기 7월 20일",
    "scheduled_at": "2026-06-01T10:00:00",
    "id": "event-id",
    "created_at": "2026-06-01T10:00:00"
  }
]
```

### DELETE `/events/{event_id}`

Deletes tasks connected to the event, then deletes the event.

Response:

```json
{
  "deleted": "event-id"
}
```

Errors:

- `404`: event not found

## Tasks

### POST `/tasks/`

Status: not implemented.

Current response:

```json
{
  "detail": "Not implemented"
}
```

### GET `/tasks/{user_id}/today`

Returns today's tasks for a user, filtered by `scheduled_at` from local start of day through start of tomorrow, sorted by `scheduled_at` ascending.

Response:

```json
[
  {
    "user_id": "test-user",
    "event_id": "event-id",
    "title": "기말고사 공부",
    "duration_minutes": 60,
    "scheduled_at": "2026-06-01T14:00:00",
    "id": "task-id",
    "is_completed": false,
    "completed_at": null,
    "created_at": "2026-06-01T10:00:00"
  }
]
```

### PATCH `/tasks/{task_id}/complete`

Marks a task as completed and sets `completed_at` to the current UTC timestamp. Adds 10 XP to the user's `streaks.total_xp`; if no streak row exists, creates one with `current_streak` and `longest_streak` set to 1.

Response:

```json
{
  "user_id": "test-user",
  "event_id": "event-id",
  "title": "기말고사 공부",
  "duration_minutes": 60,
  "scheduled_at": "2026-06-01T14:00:00",
  "id": "task-id",
  "is_completed": true,
  "completed_at": "2026-06-01T15:00:00+00:00",
  "created_at": "2026-06-01T10:00:00"
}
```

Errors:

- `404`: task not found

## Schedule

### POST `/schedule/generate`

Creates a monthly AI plan from natural-language input.

Request body:

```json
{
  "user_id": "test-user",
  "raw_text": "기말고사 6월 25일",
  "plan_year": 2026,
  "plan_month": 6
}
```

Response:

```json
{
  "events": [],
  "total_tasks": 12
}
```

### GET `/schedule/{user_id}/month?year=2026&month=6`

Returns calendar days and events for the requested month.

### GET `/schedule/{user_id}/day?date=2026-06-13`

Returns tasks and a short summary for one day.

### POST `/schedule/{user_id}/redistribute`

Moves unfinished tasks scheduled before today into new AI-generated future task slots, grouped by event deadline. Old past tasks are marked with `is_rescheduled=true`.

Response:

```json
{
  "rescheduled_count": 3,
  "new_tasks": [],
  "message": "3개 태스크를 재배분했습니다"
}
```

### GET `/schedule/{user_id}/progress`

Returns event-level progress cards for the calendar screen.

Response:

```json
{
  "cards": [
    {
      "event_id": "event-id",
      "event_title": "기말고사",
      "event_type": "deadline",
      "color": "red",
      "deadline": "2026-06-25",
      "days_until_deadline": 12,
      "total_tasks": 10,
      "completed_tasks": 4,
      "completion_rate": 40.0,
      "remaining_tasks": 6,
      "status": "warning",
      "status_label": "주의",
      "message": "D-12 · 하루 1개씩 하면 됩니다"
    }
  ],
  "overall_completion_rate": 40.0
}
```

### GET `/schedule/{user_id}/heatmap?year=2026`

Returns daily completion levels for the annual activity heatmap.

Response:

```json
{
  "year": 2026,
  "days": [
    {
      "date": "2026-06-13",
      "total": 4,
      "completed": 3,
      "rate": 75,
      "level": 3
    }
  ]
}
```

## Streaks

### GET `/streaks/{user_id}`

Returns streak and XP state. If no row exists yet, returns zeros.

```json
{
  "user_id": "test-user",
  "current_streak": 0,
  "longest_streak": 0,
  "total_xp": 0,
  "last_completed_at": null
}
```

### POST `/streaks/{user_id}/penalty`

Status: not implemented.

Current response:

```json
{
  "message": "페널티 적용 완료: 스트릭 초기화"
}
```

## Users

### POST `/users/{user_id}/fcm-token`

Registers or updates a user's FCM token.

Request body:

```json
{
  "fcm_token": "firebase-token"
}
```

Response:

```json
{
  "message": "FCM 토큰 등록 완료"
}
```

## Database Migration

Run these statements in Supabase SQL Editor:

```sql
ALTER TABLE events ADD COLUMN IF NOT EXISTS event_type text DEFAULT 'goal';
ALTER TABLE events ADD COLUMN IF NOT EXISTS color text DEFAULT 'green';
ALTER TABLE events ADD COLUMN IF NOT EXISTS end_date timestamptz;

ALTER TABLE tasks ADD COLUMN IF NOT EXISTS event_color text DEFAULT 'green';
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS is_rescheduled boolean DEFAULT false;

ALTER TABLE streaks ADD COLUMN IF NOT EXISTS last_completed_at timestamptz;

CREATE TABLE IF NOT EXISTS users (
    user_id text PRIMARY KEY,
    fcm_token text,
    updated_at timestamptz DEFAULT now()
);
```

## Manual Smoke Test

Run from the repository root while the FastAPI server is running:

```bash
python3 backend/test_api.py
```

For a deployed API:

```bash
DAYMAP_API_URL=https://your-railway-url python3 backend/test_api.py
```

The test posts two valid natural-language event inputs and one empty input. A successful run prints:

```text
Summary: 3/3 passed
```
