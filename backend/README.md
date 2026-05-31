# Daymap Backend API

FastAPI backend for Daymap, an AI-powered daily planner. The backend accepts natural-language schedule text, uses Groq to distribute tasks, stores events and tasks in Supabase, and exposes task completion APIs for XP updates.

## Stack

- FastAPI
- Supabase
- Groq API
- Pydantic
- Uvicorn

## Setup

Install dependencies:

```bash
pip install -r backend/requirements.txt
```

Create `backend/.env` based on `backend/.env.example`:

```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-supabase-service-role-key
GROQ_API_KEY=your-groq-api-key
FCM_SERVER_KEY=your-firebase-server-key
```

Run the API server:

```bash
cd backend
uvicorn main:app --reload
```

Default local base URL:

```text
http://127.0.0.1:8000
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

Creates an event from natural-language input, asks Groq to distribute tasks, then saves the event and generated tasks to Supabase.

Request body:

```json
{
  "user_id": "test-user",
  "raw_text": "정보처리기사 실기 7월 20일, 기말고사 6월 25일"
}
```

Validation:

- `raw_text` must not be empty or whitespace.

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

- `422`: empty schedule text
- `502`: Groq task distribution failed
- `500`: Supabase event or task insert failed

### GET `/events/{user_id}`

Returns events for a user, sorted by `created_at` descending.

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

Returns today's tasks for the user, filtered by `scheduled_at` and sorted by `scheduled_at` ascending.

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

Marks a task as completed and adds 10 XP to the user's streak record. If the user does not have a streak row, one is created.

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

### POST `/streaks/{user_id}/penalty`

Status: not implemented.

## Manual API Test

Run:

```bash
python3 backend/test_api.py
```

Expected prerequisite: the FastAPI server is running and environment variables in `backend/.env` are valid.
