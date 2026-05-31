"""Manual API smoke tests for POST /events/."""

import json
import os
from typing import Any

import requests


BASE_URL = os.getenv("DAYMAP_API_URL", "http://127.0.0.1:8000")
EVENTS_URL = f"{BASE_URL.rstrip('/')}/events/"
TEST_USER_ID = os.getenv("DAYMAP_TEST_USER_ID", "test-user")

TEST_CASES = [
    {
        "name": "1. Normal input",
        "payload": {
            "user_id": TEST_USER_ID,
            "raw_text": "정보처리기사 실기 7월 20일, 기말고사 6월 25일",
        },
        "expect_error": False,
    },
    {
        "name": "2. Single event",
        "payload": {
            "user_id": TEST_USER_ID,
            "raw_text": "결혼식 6월 14일",
        },
        "expect_error": False,
    },
    {
        "name": "3. Empty input",
        "payload": {
            "user_id": TEST_USER_ID,
            "raw_text": "",
        },
        "expect_error": True,
    },
]


def format_response_body(response: requests.Response) -> str:
    try:
        body: Any = response.json()
    except ValueError:
        return response.text

    return json.dumps(body, ensure_ascii=False, indent=2)


def run_test_case(test_case: dict[str, Any]) -> bool:
    print("=" * 72)
    print(test_case["name"])
    print(f"POST {EVENTS_URL}")
    print("Request:")
    print(json.dumps(test_case["payload"], ensure_ascii=False, indent=2))

    try:
        response = requests.post(EVENTS_URL, json=test_case["payload"], timeout=60)
    except requests.RequestException as exc:
        print("Result: REQUEST FAILED")
        print(f"Error: {exc}")
        return False

    is_error = response.status_code >= 400
    passed = is_error if test_case["expect_error"] else not is_error

    print(f"Status: {response.status_code}")
    print(f"Expected: {'error' if test_case['expect_error'] else 'success'}")
    print(f"Result: {'PASS' if passed else 'FAIL'}")
    print("Response:")
    print(format_response_body(response))
    return passed


def main() -> int:
    print("Daymap POST /events/ API smoke test")
    print(f"Base URL: {BASE_URL}")

    passed_count = sum(run_test_case(test_case) for test_case in TEST_CASES)
    total_count = len(TEST_CASES)
    print("=" * 72)
    print(f"Summary: {passed_count}/{total_count} passed")

    return 0 if passed_count == total_count else 1


if __name__ == "__main__":
    raise SystemExit(main())
