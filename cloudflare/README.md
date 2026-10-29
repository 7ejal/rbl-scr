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
