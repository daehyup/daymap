ALTER TABLE events ADD COLUMN IF NOT EXISTS event_type text DEFAULT 'goal';
ALTER TABLE events ADD COLUMN IF NOT EXISTS color text DEFAULT 'green';
ALTER TABLE events ADD COLUMN IF NOT EXISTS end_date timestamptz;

ALTER TABLE tasks ADD COLUMN IF NOT EXISTS event_color text DEFAULT 'green';

ALTER TABLE streaks ADD COLUMN IF NOT EXISTS last_completed_at timestamptz;
