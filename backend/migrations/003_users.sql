CREATE TABLE IF NOT EXISTS users (
    user_id text PRIMARY KEY,
    fcm_token text,
    updated_at timestamptz DEFAULT now()
);
