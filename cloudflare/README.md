# 7jl ESP hosting on Cloudflare

Live site: https://scripts.7jl.dev/
Lua entry: https://scripts.7jl.dev/main.lua
Health: https://scripts.7jl.dev/health
Cloudflare Worker: 7jl-esp-loader
Source GitHub: 7ejal/rbl-scr, feature/modular-ivory-esp

## Roblox/Xeno loader

Use this one-line loader; it does not point to GitHub:

    loadstring(game:HttpGet("https://scripts.7jl.dev/main.lua?v=" .. tostring(os.time())))()

The live release is 47 files stored in Cloudflare KV namespace 7jl-esp-releases under v1/main.lua, v1/config.lua and v1/src/*.lua. The live Worker never calls GitHub. Updating the source branch alone does NOT update production: updated files must be published to KV. Keep every module from the same release.

## Track individual requests

Each request reaching this Worker triggers an attempted synchronous INSERT into the D1 database 7jl-esp-request-log. Logs include UTC timestamp, request UUID, method, path, HTTP status, country, data center, ASN, truncated User-Agent and Ray ID when available; no IP addresses or full URL query strings are recorded.

Authenticated dashboard: Cloudflare -> Workers & Pages -> D1 -> 7jl-esp-request-log -> Console.

Latest request records:

    SELECT requested_at, path, status, country, colo, asn, user_agent, cf_ray
    FROM request_log ORDER BY requested_at DESC LIMIT 100;

Requests per script over the previous 24 hours:

    SELECT path, COUNT(*) AS requests FROM request_log
    WHERE requested_at >= strftime('%Y-%m-%dT%H:%M:%fZ','now','-1 day')
    GROUP BY path ORDER BY requests DESC;

Total requests in the previous 24 hours:

    SELECT COUNT(*) FROM request_log
    WHERE requested_at >= strftime('%Y-%m-%dT%H:%M:%fZ','now','-1 day');

Responses include X-7jl-Request-Id and X-7jl-Log: ok or failed. WAF-blocked requests do not reach this Worker; view Cloudflare Security Analytics for those. D1 writes can fail, in which case X-7jl-Log is failed and Worker logs contain an error. A 03:00 UTC daily cron deletes records older than 30 days. The D1 data is not publicly available through the script-loader website.

The original 7jl.dev website Worker (7jl-site) was not modified.

## Publishing changes

Push source changes to the feature branch; then upload the verified exact 47 matching Lua files to Cloudflare KV using the account's Cloudflare API or Wrangler. To avoid mixed releases, upload a new version prefix before switching the Worker VERSION constant and test /health and /main.lua. Do not expose Cloudflare API keys or D1 admin endpoints in publicly served Lua.

## v2 anonymous session analytics (2026-10-30)

Official loader:
    loadstring(game:HttpGet("https://scripts.7jl.dev/boot.lua?v=" .. tostring(os.time())))()

boot.lua generates a random UUID for each invocation; the same temporary session ID is supplied with main.lua, config.lua, and every module GET. A new invocation creates a new ID. IDs aren't tied to Roblox usernames, devices, accounts, or IP addresses.

Anonymous boot_start/startup_success/startup_error telemetry is enabled by default and disclosed on the website. The user can set getgenv().IvoryESP_Telemetry=false before loading to disable client events. File access logs remain. Errors are allowlisted stage codes and module paths, not raw Lua error messages.

Car compatibility telemetry is separately opt-in: getgenv().IvoryESP_CarTelemetry=true. The client reports only categorical input-backend/moved vs no_motion outcomes after user-triggered calibration or a real 0 km/h failure. No car name, gear string, device ID, usernames, coordinates or tokens are sent.

Version v2 is stored in a separate 48-key Cloudflare KV prefix; v1 remains intact (47 keys). GitHub changes must be separately published to KV. The Worker defaults to v2.

## Private authenticated analytics dashboard

Open https://scripts.7jl.dev/admin . It is protected by Cloudflare Access using an owner-only email allow policy. /admin/api returns aggregated 7-day dashboard data only through this protected path. There are no publicly exposed D1 credentials.

Dashboard cards include HTTP requests, load sessions (not unique people), startup successes, startup errors, HTTP errors, outdated sessions and opt-in car report count. Tables include release versions, startup outcomes per release, failures per module, HTTP file failures, car compatibility and recent requests.

Cloudflare D1: 7jl-esp-request-log. New request_log columns: session_id, release, bytes. New session_events table: occurred_at, session_id, release, event, module, error_code, car_method, car_result, speed_band. Both tables have 30-day cleanup at 03:00 UTC daily.

SQL to group by version:
    SELECT release, COUNT(DISTINCT session_id) AS sessions, COUNT(*) AS requests
    FROM request_log GROUP BY release;

SQL to review startup failures:
    SELECT release,module,error_code,COUNT(*) AS failures
    FROM session_events WHERE event='startup_error'
    GROUP BY release,module,error_code ORDER BY failures DESC;

SQL to review car compatibility (only opt-in events):
    SELECT car_method,car_result,COUNT(*) AS count
    FROM session_events WHERE event='car_compat'
    GROUP BY car_method,car_result;

Counts of startup outcomes are best-effort because client HTTP APIs can fail, and WAF-blocked requests don't reach the Worker. Cloudflare may process connection IP addresses outside the custom D1 logger.
