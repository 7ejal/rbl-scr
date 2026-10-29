-- 7jl D1 request log (created 2026-10-30).
CREATE TABLE IF NOT EXISTS request_log (
 id TEXT PRIMARY KEY,
 requested_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
 method TEXT NOT NULL, path TEXT NOT NULL, status INTEGER NOT NULL,
 country TEXT, colo TEXT, asn INTEGER, user_agent TEXT, cf_ray TEXT,
 duration_ms INTEGER
);
CREATE INDEX IF NOT EXISTS idx_log_requested ON request_log(requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_log_path ON request_log(path,requested_at DESC);
