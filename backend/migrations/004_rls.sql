-- 백엔드는 service_role 또는 secret key로 접근하므로 RLS 활성화 후에도 bypass됩니다.
-- anon/authenticated role의 직접 테이블 접근은 별도 허용 정책을 만들지 않아 차단합니다.

ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE streaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
