// 7jl Lua distribution from Cloudflare KV with individual D1 request records.
const VERSION = "v1";
const ALLOWED = /^\/(?:main\.lua|config\.lua|src\/[A-Za-z][A-Za-z0-9_]*\.lua)$/;
const HEADERS = {
  "access-control-allow-origin": "*",
  "cache-control": "no-store, max-age=0",
  "x-content-type-options": "nosniff",
};
function landing() {
  return [
    '<!doctype html><html lang="en"><head><meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width,initial-scale=1">',
    '<title>7jl Script Loader</title><style>',
    'body{margin:0;min-height:100vh;background:#10131b;color:#edf0f8;',
    'font:15px system-ui;display:grid;place-items:center}',
    'main{padding:32px;border:1px solid #31384b;border-radius:16px;',
    'max-width:690px;width:calc(100% - 84px);background:#191f2c}',
    'h1{margin:0 0 8px;color:#c5caff}p{line-height:1.6;color:#bfc7d6}',
    'pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#0d1119;',
    'padding:18px;border-radius:10px;color:#c0f8b9}',
    'a{color:#a7c4ff}.muted{font-size:13px}',
    '</style></head><body><main><h1>7jl Script Loader</h1>',
    '<p>Script delivery for 7jl IVORY ESP, directly from Cloudflare.',
    'Each request reaching this service is logged for its owner,',
    'without storing your IP address.</p>',
    '<pre>loadstring(game:HttpGet("https://scripts.7jl.dev/main.lua?v=" .. tostring(os.time())))()</pre>',
    '<p><a href="/main.lua">View Lua entry point</a> · ',
    '<a href="/health">Service health</a></p>',
    '<p class="muted">Individual request records are private in the',
    'Cloudflare D1 database dashboard.</p></main></body></html>'
  ].join(" ");
}
export default {
  async fetch(request, env) {
    const started = Date.now();
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method.toUpperCase();
    const id = crypto.randomUUID();
    let status = 200;
    let contentType = "text/plain; charset=utf-8";
    let output = "";
    if (method !== "GET" && method !== "HEAD") {
      status = 405;
      output = "Method not allowed";
    } else if (path === "/") {
      contentType = "text/html; charset=utf-8";
      output = landing();
    } else if (path === "/health") {
      contentType = "application/json; charset=utf-8";
      output = JSON.stringify({service:"7jl-script-loader",release:VERSION,
        origin:"Cloudflare KV",logs:"Cloudflare D1"});
    } else if (ALLOWED.test(path)) {
      try {
        const value = await env.RELEASE_FILES.get(VERSION + path);
        if (typeof value === "string") {
          output = value;
        } else {
          status = 404;
          output = "Script not published";
        }
      } catch (error) {
        console.error("KV fetch failure", String(error));
        status = 503;
        output = "Script storage temporarily unavailable";
      }
    } else {
      status = 404;
      output = "Not found";
    }
    // Log every Worker-handled request. IP, query, cookies and tokens omitted.
    // Requests blocked by Cloudflare WAF do not reach this Worker.
    let logStatus = "ok";
    try {
      await env.REQUEST_LOGS.prepare(
        "INSERT INTO request_log(id,method,path,status,country,colo,asn,user_agent,cf_ray,duration_ms) " +
        "VALUES(?,?,?,?,?,?,?,?,?,?)"
      ).bind(
        id, method, path.slice(0, 180), status,
        String(request.cf?.country || "unknown").slice(0, 5),
        String(request.cf?.colo || "unknown").slice(0, 10),
        Number(request.cf?.asn || 0),
        String(request.headers.get("user-agent") || "").slice(0, 160),
        String(request.headers.get("cf-ray") || "").slice(0, 60),
        Math.max(0, Date.now() - started)
      ).run();
    } catch (error) {
      logStatus = "failed";
      console.error("D1 log write failed", String(error));
    }
    const headers = new Headers(HEADERS);
    headers.set("content-type", contentType);
    headers.set("x-7jl-request-id", id);
    headers.set("x-7jl-log", logStatus);
    headers.set("x-7jl-release", VERSION);
    if (status === 405) headers.set("allow", "GET, HEAD");
    return new Response(method === "HEAD" ? null : output, {status, headers});
  },
  async scheduled(_event, env) {
    await env.REQUEST_LOGS.prepare(
      "DELETE FROM request_log WHERE requested_at < " +
      "strftime('%Y-%m-%dT%H:%M:%fZ','now','-30 days')"
    ).run();
  },
};