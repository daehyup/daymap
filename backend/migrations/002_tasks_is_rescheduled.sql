ALTER TABLE tasks ADD COLUMN IF NOT EXISTS is_rescheduled boolean DEFAULT false;
