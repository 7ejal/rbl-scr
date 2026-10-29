-- 7jl D1 schema (new database). For existing deployments use the migration below.
CREATE TABLE IF NOT EXISTS request_log (
  id TEXT PRIMARY KEY,
  requested_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  method TEXT NOT NULL, path TEXT NOT NULL, status INTEGER NOT NULL,
  country TEXT, colo TEXT, asn INTEGER, user_agent TEXT, cf_ray TEXT,
  duration_ms INTEGER, session_id TEXT, release TEXT, bytes INTEGER
);
CREATE INDEX IF NOT EXISTS idx_log_requested ON request_log(requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_log_path ON request_log(path, requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_req_session ON request_log(session_id, requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_req_release ON request_log(release, requested_at DESC);
CREATE TABLE IF NOT EXISTS session_events (
  id TEXT PRIMARY KEY,
  occurred_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  session_id TEXT NOT NULL, release TEXT NOT NULL,
  event TEXT NOT NULL, module TEXT, error_code TEXT,
  car_method TEXT, car_result TEXT, speed_band TEXT
);
CREATE INDEX IF NOT EXISTS idx_event_session ON session_events(session_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_event_time ON session_events(occurred_at DESC);

-- ONE-TIME MIGRATION ONLY for an existing v1 database:
-- ALTER TABLE request_log ADD COLUMN session_id TEXT;
-- ALTER TABLE request_log ADD COLUMN release TEXT;
-- ALTER TABLE request_log ADD COLUMN bytes INTEGER;
-- Then execute the CREATE INDEX / CREATE TABLE statements above.
-- These ALTER TABLE statements have already been applied in production.
