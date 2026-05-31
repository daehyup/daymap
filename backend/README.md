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

### PATCH `/tasks/{task_id}/redistribute`

Status: not implemented.

Current response:

```json
{
  "detail": "Not implemented"
}
```

## Streaks

### GET `/streaks/{user_id}`

Status: not implemented.

Current response:

```json
{
  "detail": "Not implemented"
}
```

### POST `/streaks/{user_id}/penalty`

Status: not implemented.

Current response:

```json
{
  "detail": "Not implemented"
}
```

## Manual Smoke Test

Run from the repository root while the FastAPI server is running:

```bash
python3 backend/test_api.py
```

The test posts two valid natural-language event inputs and one empty input. A successful run prints:

```text
Summary: 3/3 passed
```
