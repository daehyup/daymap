# Daymap

## 프로젝트 개요

AI가 일정을 분석해서 하루 할일을 자동으로 짜주고,
푸시 알림 + 보상 시스템으로 실제로 실행하게 만드는 모바일 앱.

## 기술 스택

- 프론트: Flutter
- 백엔드: FastAPI
- DB: Supabase
- AI: Claude API (claude-sonnet-4-6)
- 푸시 알림: Firebase Cloud Messaging
- 배포: Railway

## 폴더 구조

- backend/ : FastAPI 서버
- flutter_app/ : Flutter 앱

## 핵심 기능

1. 일정 텍스트 입력 → AI 자동 배분
2. 푸시 알림으로 실행 유도
3. 완료 시 보상 (스트릭, XP)
4. 미완료 시 페널티 + 자동 재배분

## 개발 원칙

- MVP 우선, 복잡한 기능은 나중에
- Flutter UI는 애니메이션 적극 활용
- 한국어 우선
- backend/는 백엔드 담당 Claude가 작업
- flutter_app/는 Flutter 담당 Claude가 작업
