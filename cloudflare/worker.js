// 7jl script CDN v2: anonymous per-launch analytics with private Access dashboard.
const VERSION="v2";
const FILE=/^\/(?:boot\.lua|main\.lua|config\.lua|src\/[A-Za-z][A-Za-z0-9_]*\.lua)$/;
const UUID=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
const CODES=new Set(["initialization","module_fetch","module_compile","module_runtime",
  "controller_start","boot_failure","calibration","no_response","none"]);
const EVENTS=new Set(["boot_start","startup_success","startup_error","car_compat"]);
const METHODS=new Set(["Keyboard","Seat","ControlsValue","Auto","none","unknown"]);
const RESULTS=new Set(["moved","no_motion","unavailable","unknown"]);
const BANDS=new Set(["zero","slow","moving","fast","unknown"]);
const fmt=(v,max=120)=>String(v||"").slice(0,max);
const age7="strftime('%Y-%m-%dT%H:%M:%fZ','now','-7 days')";
const age30="strftime('%Y-%m-%dT%H:%M:%fZ','now','-30 days')";
function baseHeaders(type="text/plain; charset=utf-8"){
  return {"content-type":type,"cache-control":"no-store","x-content-type-options":"nosniff",
    "referrer-policy":"no-referrer","x-frame-options":"DENY"};
}
function landing(){
  return ['<!doctype html><html lang="en"><meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width,initial-scale=1">',
    '<title>7jl Script Loader</title><style>',
    'body{margin:0;min-height:100vh;background:#10131b;color:#edf0f8;',
    'font:15px system-ui;display:grid;place-items:center}',
    'main{padding:30px;border:1px solid #31384b;border-radius:16px;',
    'max-width:710px;background:#191f2c;width:calc(100% - 80px)}',
    'pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#0d1119;',
    'padding:16px;border-radius:9px;color:#c0f8b9}',
    'p{color:#bfc7d6;line-height:1.55}a{color:#a7c4ff}</style>',
    '<main><h1>7jl Script Loader</h1><p>Lua releases served from Cloudflare.',
    'Each launch receives a temporary random ID to group file downloads.',
    'Anonymous startup success/failure categories are reported automatically;',
    'set <code>getgenv().IvoryESP_Telemetry=false</code> before loading to',
    'disable client events. Car diagnostics require separate opt-in via',
    '<code>getgenv().IvoryESP_CarTelemetry=true</code>.</p>',
    '<pre>loadstring(game:HttpGet("https://scripts.7jl.dev/boot.lua?v=" .. tostring(os.time())))()</pre>',
    '<p>No Roblox usernames, raw IP addresses, hardware IDs, game coordinates,',
    'or raw Lua errors are stored in the custom analytics database.',
    'Logs are retained for 30 days.</p>',
    '<a href="/health">Service health</a></main></html>'].join(" ");
}
function dashboard(){
  return ['<!doctype html><html lang="en"><meta charset="utf-8">',
  '<meta name="viewport" content="width=device-width,initial-scale=1">',
  '<title>7jl Analytics</title><style>',
  'body{font:14px system-ui;margin:0;background:#0c0e16;color:#eef0f8}',
  'main{max-width:1190px;margin:auto;padding:28px}',
  'h1{font-size:25px;margin:0 0 6px}small{color:#a9b0c2}',
  '.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:12px;margin:22px 0}',
  '.card{padding:18px;border:1px solid #31394c;background:#191e2b;border-radius:12px}',
  '.num{font-size:29px;font-weight:750;display:block;margin-top:5px}',
  'section{margin:22px 0;border:1px solid #30394c;border-radius:12px;padding:18px;background:#151a26}',
  'table{width:100%;border-collapse:collapse;font-size:12px}',
  'th,td{text-align:left;padding:9px;border-bottom:1px solid #30394c;overflow-wrap:anywhere}',
  'th{color:#aab7d1}button{background:#3c64d3;color:white;border:0;border-radius:8px;padding:10px;cursor:pointer}',
  'a{color:#9eafff}p{color:#b6bfd3}</style><main>',
  '<h1>7jl / Private Analytics</h1><small>Last 7 days · Cloudflare Access protected · Anonymous sessions</small>',
  '<p><button id="refresh">Refresh</button> <span id="status"></span></p>',
  '<div id="cards" class="cards"></div><div id="tables"></div>',
  '<p>Sessions are temporary IDs generated per load, not unique people.',
  'Startup outcomes require client event requests to succeed.',
  'Car diagnostics are optional. WAF-blocked requests never reach this Worker.</p>',
  '<script>',
  'function el(tag,text){const e=document.createElement(tag);if(text!=null)e.textContent=String(text);return e}',
  'function card(title,value){const c=el("div");c.className="card";c.append(el("span",title));const n=el("span",value);n.className="num";c.append(n);return c}',
  'function section(title,rows){const s=el("section");s.append(el("h2",title));',
  'if(!rows||!rows.length){s.append(el("p","No data yet"));return s}',
  'const t=el("table"),h=el("tr");Object.keys(rows[0]).forEach(k=>h.append(el("th",k)));t.append(h);',
  'rows.forEach(r=>{const tr=el("tr");Object.keys(rows[0]).forEach(k=>tr.append(el("td",r[k]??"")));t.append(tr)});s.append(t);return s}',
  'async function refresh(){const status=document.getElementById("status");status.textContent="Loading...";',
  'try{const res=await fetch("/admin/api",{credentials:"same-origin",cache:"no-store"});',
  'if(!res.ok)throw Error("HTTP "+res.status);const d=await res.json();',
  'const c=document.getElementById("cards");c.replaceChildren();',
  'for(const [k,v] of Object.entries(d.metrics||{}))c.append(card(k,v));',
  'const ts=document.getElementById("tables");ts.replaceChildren();',
  'for(const [k,rows] of Object.entries(d.tables||{}))ts.append(section(k,rows));',
  'status.textContent="Updated "+new Date().toLocaleString()}',
  'catch(e){status.textContent="Dashboard unavailable: "+e.message}}',
  'document.getElementById("refresh").addEventListener("click",refresh);refresh();',
  '</script></main></html>'].join(" ");
}
async function metrics(env){
  const db=env.REQUEST_LOGS;
  const query=async sql=>(await db.prepare(sql).all()).results||[];
  const [r,e,v,fail,car,recent,code,failedModules,stale]=await Promise.all([
    query("SELECT COUNT(*) requests, COUNT(DISTINCT session_id) sessions,"+
      "SUM(CASE WHEN status>=400 THEN 1 ELSE 0 END) errors "+
      "FROM request_log WHERE requested_at >= "+age7),
    query("SELECT event,COUNT(*) count FROM session_events WHERE occurred_at >= "+age7+
      " GROUP BY event ORDER BY count DESC"),
    query("SELECT COALESCE(release,'legacy') release,COUNT(*) requests,"+
      "COUNT(DISTINCT session_id) sessions FROM request_log WHERE requested_at >= "+age7+
      " GROUP BY release ORDER BY requests DESC"),
    query("SELECT COALESCE(module,'(unknown)') module,error_code,COUNT(*) count"+
      " FROM session_events WHERE event='startup_error' AND occurred_at >= "+age7+
      " GROUP BY module,error_code ORDER BY count DESC LIMIT 15"),
    query("SELECT car_method,car_result,COUNT(*) count FROM session_events"+
      " WHERE event='car_compat' AND occurred_at >= "+age7+
      " GROUP BY car_method,car_result ORDER BY count DESC"),
    query("SELECT requested_at,path,status,release,country FROM request_log"+
      " ORDER BY requested_at DESC LIMIT 50"),
    query("SELECT release,event,COUNT(*) count FROM session_events"+
      " WHERE occurred_at >= "+age7+" GROUP BY release,event ORDER BY count DESC"),
    query("SELECT path,status,COUNT(*) count FROM request_log WHERE status>=400"+
      " AND requested_at >= "+age7+" GROUP BY path,status ORDER BY count DESC LIMIT 20"),
    query("SELECT COUNT(DISTINCT session_id) AS count FROM request_log"+
      " WHERE release IS NOT NULL AND release!='v2' AND session_id IS NOT NULL"+
      " AND requested_at >= "+age7)
  ]);
  const eventCount=k=>(e.find(x=>x.event===k)||{}).count||0;
  return {metrics:{"HTTP requests":r[0]?.requests||0,
      "Load sessions":r[0]?.sessions||0,
      "Startup successes":eventCount("startup_success"),
      "Startup errors":eventCount("startup_error"),
      "HTTP errors":r[0]?.errors||0,
      "Outdated sessions":stale[0]?.count||0,
      "Car reports (opt-in)":eventCount("car_compat")},
    tables:{"Release versions":v,"Startup outcomes by version":code,
      "Startup failures by module":fail,"Failed file requests":failedModules,
      "Car input compatibility":car,"Recent file requests":recent}};
}
export default {
  async fetch(request,env){
    const start=Date.now(), url=new URL(request.url);
    const path=url.pathname, method=request.method.toUpperCase();
    const id=crypto.randomUUID();
    const sid=UUID.test(url.searchParams.get("session")||"")
      ?url.searchParams.get("session").toLowerCase():null;
    const requestedRelease=url.searchParams.get("release");
    const release=/^v[1-9][0-9]{0,2}$/.test(requestedRelease||"")
      ?requestedRelease:VERSION;
    let status=200,contentType="text/plain; charset=utf-8",body="";
    if(path==="/admin"||path.startsWith("/admin/")){
      // Cloudflare Access additionally blocks unauthenticated requests to
      // scripts.7jl.dev/admin (separate owner-only allow policy).
      if(!request.headers.get("Cf-Access-Jwt-Assertion")){
        return new Response("Cloudflare Access required",
          {status:403,headers:baseHeaders()});
      }
      try{
        if(path==="/admin/api"&&method==="GET"){
          contentType="application/json; charset=utf-8";
          body=JSON.stringify(await metrics(env));
        }else if((path==="/admin"||path==="/admin/")&&method==="GET"){
          contentType="text/html; charset=utf-8";body=dashboard();
        }else{status=404;body="Not found"}
      }catch(error){console.error("Dashboard D1 query failed",String(error));
        status=503;body="Analytics unavailable"}
      return new Response(body,{status,headers:baseHeaders(contentType)});
    }
    if(method!=="GET"&&method!=="HEAD"){
      status=405;body="Method not allowed";
    }else if(path==="/"){
      contentType="text/html; charset=utf-8";body=landing();
    }else if(path==="/health"){
      contentType="application/json; charset=utf-8";
      body=JSON.stringify({service:"7jl-script-loader",release:VERSION,
        files:"Cloudflare KV",events:"D1",admin:"Cloudflare Access"});
    }else if(path==="/event"){
      const event=fmt(url.searchParams.get("event"),32);
      const code=fmt(url.searchParams.get("code"),40);
      const module=fmt(url.searchParams.get("module"),110);
      const input=fmt(url.searchParams.get("method"),25);
      const result=fmt(url.searchParams.get("result"),25);
      const speed=fmt(url.searchParams.get("speed"),20);
      if(!sid||!EVENTS.has(event)||!/^v[1-9][0-9]{0,2}$/.test(release)){
        status=400;body="Invalid anonymous event";
      }else{
        try{
          await env.REQUEST_LOGS.prepare(
            "INSERT INTO session_events(id,session_id,release,event,module,error_code,"+
            "car_method,car_result,speed_band) VALUES(?,?,?,?,?,?,?,?,?)"
          ).bind(id,sid,release,event,
            module&&/^(?:main\.lua|config\.lua|src\/[A-Za-z0-9_]+\.lua)$/.test(module)
              ?module:null,
            CODES.has(code)?code:null,
            event==="car_compat"&&METHODS.has(input)?input:null,
            event==="car_compat"&&RESULTS.has(result)?result:null,
            event==="car_compat"&&BANDS.has(speed)?speed:null
          ).run();
          body="ok";
        }catch(error){status=503;body="Telemetry temporarily unavailable";
          console.error("D1 event failure",String(error))}
      }
    }else if(FILE.test(path)){
      try{
        const data=await env.RELEASE_FILES.get(release+path);
        if(typeof data==="string")body=data;
        else {status=404;body="Script not published"}
      }catch(error){status=503;body="File storage unavailable";
        console.error("KV unavailable",String(error))}
    }else{status=404;body="Not found"}
    let logStatus="ok";
    try{
      await env.REQUEST_LOGS.prepare(
        "INSERT INTO request_log(id,method,path,status,country,colo,asn,user_agent,"+
        "cf_ray,duration_ms,session_id,release,bytes) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)"
      ).bind(id,method,path.slice(0,180),status,
        fmt(request.cf?.country,5)||"unknown",fmt(request.cf?.colo,10)||"unknown",
        Number(request.cf?.asn||0),fmt(request.headers.get("user-agent"),160),
        fmt(request.headers.get("cf-ray"),60),Date.now()-start,sid,release,
        new TextEncoder().encode(body).length
      ).run();
    }catch(error){logStatus="failed";console.error("D1 log failure",String(error))}
    const headers=baseHeaders(contentType);
    headers["x-7jl-request-id"]=id;
    headers["x-7jl-log"]=logStatus;
    headers["x-7jl-release"]=release;
    if(status===405)headers["allow"]="GET, HEAD";
    return new Response(method==="HEAD"?null:body,{status,headers});
  },
  async scheduled(_event,env){
    await env.REQUEST_LOGS.prepare("DELETE FROM request_log WHERE requested_at < "+age30).run();
    await env.REQUEST_LOGS.prepare("DELETE FROM session_events WHERE occurred_at < "+age30).run();
  }
};