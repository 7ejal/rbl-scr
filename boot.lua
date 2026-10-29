-- 7jl session bootloader. Per-launch random ID, not a Roblox identity.
local http = game:GetService("HttpService")
local env=_G
pcall(function()
    if type(getgenv)=="function" then
        local v=getgenv()
        if type(v)=="table" then env=v end
    end
end)
local sid=http:GenerateGUID(false)
local release="v2"
env.IvoryESP_Session=sid
env.IvoryESP_Release=release
-- Anonymous startup outcome reporting is enabled by default.
-- Set getgenv().IvoryESP_Telemetry=false BEFORE loading to opt out.
-- Detailed vehicle compatibility telemetry is separately opt-in:
-- getgenv().IvoryESP_CarTelemetry=true
local function report(kind,code)
    if env.IvoryESP_Telemetry==false then return end
    task.spawn(function()
        pcall(function()
            local u="https://scripts.7jl.dev/event?session="..sid
                .."&release="..release.."&event="..kind
            if code then u=u.."&code="..code end
            game:HttpGet(u)
        end)
    end)
end
env.IvoryESP_Report=report
report("boot_start")
local startUrl="https://scripts.7jl.dev/main.lua?session="..sid
    .."&release="..release.."&v="..tostring(os.time())
local ok,result=pcall(function()
    return loadstring(game:HttpGet(startUrl))()
end)
if not ok then
    report("startup_error","boot_failure")
    warn("[7jl] Could not load main.lua: "..tostring(result))
    return nil
end
return result
