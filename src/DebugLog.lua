-- Bounded event log. Copy/export is explicit; no secrets or user IDs.
local HttpService=game:GetService("HttpService")
local Log={}
Log.__index=Log
function Log.new()
    return setmetatable({Entries={},LastKey="",LastAt=0,Cap=180},Log)
end
function Log:Add(kind,message)
    local now=os.clock()
    local key=tostring(kind)..": "..tostring(message)
    if self.LastKey==key and now-self.LastAt<2 then return end
    self.LastKey=key;self.LastAt=now
    table.insert(self.Entries,("%0.1fs | %s | %s"):format(
        now,tostring(kind):sub(1,20),tostring(message):sub(1,220)))
    while #self.Entries>self.Cap do table.remove(self.Entries,1) end
end
function Log:Export(extra)
    local lines={"=== 7jl DIAGNOSTIC EXPORT ===","local session; no private tokens"}
    for _,entry in ipairs(self.Entries) do table.insert(lines,entry) end
    if extra then table.insert(lines,"=== SNAPSHOT ===")
        table.insert(lines,tostring(extra):sub(1,3600))
    end
    return table.concat(lines,"\n")
end
function Log:Copy(extra)
    local report=self:Export(extra)
    if type(getgenv)=="function" then
        local ok,env=pcall(getgenv)
        if ok and type(env)=="table" then env.IvoryDebugReport=report end
    end
    if type(setclipboard)=="function" then
        local ok=pcall(setclipboard,report)
        return ok,report
    end
    return false,report
end
return Log