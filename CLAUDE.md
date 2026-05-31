# Daymap

## 프로젝트 개요
AI가 일정을 분석해서 하루 할일을 자동으로 짜주고,
푸시 알림 + 보상 시스템으로 실제로 실행하게 만드는 모바일 앱.

## 기술 스택
- 프론트: Flutter
- 백엔드: FastAPI
- DB: Supabase
- AI: Groq API (llama-3.3-70b-versatile)
- 푸시 알림: Firebase Cloud Messaging
- 배포: Railway

## 폴더 구조
- backend/ : FastAPI 서버 (터미널 1 담당)
- flutter_app/ : Flutter 앱 (터미널 2 담당)

## 핵심 기능
1. 일정 텍스트 입력 → AI 자동 배분
2. 푸시 알림으로 실행 유도
3. 완료 시 보상 (스트릭, XP)
4. 미완료 시 페널티 + 자동 재배분

## 현재 완료된 것
- POST /events/ : 텍스트 → AI 배분 → Supabase 저장
- GET /events/{user_id} : 일정 조회
- Flutter 화면 골격 3개 (홈/입력/오늘)
- 입력 화면 → API 연결

## 다음 작업 목록
### 백엔드 (터미널 1)
- PATCH /tasks/{task_id}/complete : 태스크 완료 + XP 지급
- GET /tasks/{user_id}/today : 오늘 할일 조회
- POST /streaks/{user_id} : 스트릭 업데이트

### Flutter (터미널 2)
- today_screen.dart : 실제 API 데이터 연결
- task_card.dart : 완료 시 애니메이션
- streak_widget.dart : 실제 스트릭 데이터 연결

## 작업 원칙
- 터미널 1은 backend/ 폴더만 담당
- 터미널 2는 flutter_app/ 폴더만 담당
- 작업 완료 후 자동으로 다음 할일 파악하고 진행
- 작업 완료 시 항상 git add . && git commit -m "feat: ..." 실행
- 승인 없이 자율적으로 작업 진행
- 한국어 우선

## Codex 역할 (터미널 3)
- QA: 백엔드나 Flutter 변경 후 python3 backend/test_api.py 자동 실행
- DevOps: 기능 완료 시 git add . && git commit && git push origin main 자동 실행
- Code Review: 코드 리뷰 요청 시 backend/ 또는 flutter_app/ 검토 후 개선사항 제안
- Documentation: backend/README.md를 항상 최신 API 문서로 유지

## 협업 원칙
- 터미널 1 백엔드 작업 완료 → 터미널 3 Codex가 테스트 실행 + 커밋
- 터미널 2 Flutter 작업 완료 → 터미널 3 Codex가 커밋
- 대협은 큰 방향만 지시, 세부 작업은 AI가 자율 진행

## 작업 로그 규칙
모든 작업 완료 시 agent_log.txt에 아래 형식으로 기록:

[날짜 시간] [백엔드/Flutter/Codex] 완료: 작업내용
다음작업: 다음에 할 것

예시:
[2026-06-01 18:00] [백엔드] 완료: PATCH /tasks/{task_id}/complete 구현
다음작업: Flutter에서 완료 API 연결 필요

agent_log.txt 파일이 없으면 새로 만들어서 기록.
