-- IVORY ESP modular loader. Requires game:HttpGet and loadstring.
-- Review the repository before executing remote code.

local env = _G
pcall(function()
    if type(getgenv) == "function" then
        local value = getgenv()
        if type(value) == "table" then env = value end
    end
end)

assert(type(loadstring) == "function", "IVORY ESP requires loadstring support")

local ref = env.IvoryESP_Ref or "main"
assert(type(ref) == "string" and ref:match("^[%w%._/%-]+$"),
    "Invalid IvoryESP_Ref")

local base = "https://raw.githubusercontent.com/7ejal/rbl-scr/" .. ref .. "/"
local function load(path)
    local url = base .. path
    local success, body = pcall(function()
        return game:HttpGet(url .. "?v=" .. tostring(os.time()))
    end)
    if not success then
        error("IVORY ESP: could not load " .. path .. ": " .. tostring(body))
    end
    local chunk, err = loadstring(body)
    if not chunk then error("IVORY ESP: invalid module " .. path .. ": " .. tostring(err)) end
    return chunk()
end

local settings = load("config.lua")
local classes = {}
local names = {
    "Janitor",
    "Projection",
    "BoxESP",
    "NameESP",
    "DistanceESP",
    "HealthESP",
    "HighlightESP",
    "PlayerESP",
    "PlayerTracker",
    "MonsterESP",
    "MonsterTracker",
    "MonsterInspector",
    "FOVController",
    "UIController",
    "KeybindController",
    "ESPController",
}
for _, name in ipairs(names) do
    classes[name] = load("src/" .. name .. ".lua")
end

-- Fetch every module successfully before replacing a running instance.
-- Clean up the older standalone inspector if it was executed before this loader.
if _G.IvoryInspectorConnection then
    pcall(function() _G.IvoryInspectorConnection:Disconnect() end)
    _G.IvoryInspectorConnection = nil
end
if type(env.IvoryESP_Stop) == "function" then
    pcall(env.IvoryESP_Stop)
end

local controller = classes.ESPController.new(classes, settings)
local ok, err = pcall(function() controller:Start() end)
if not ok then
    controller:Destroy()
    error("IVORY ESP: failed to initialize: " .. tostring(err))
end

local function stop()
    controller:Destroy()
    if env.IvoryESP_Stop == stop then env.IvoryESP_Stop = nil end
end

env.IvoryESP_Stop = stop
print("[IVORY ESP] Dashboard ready | I: toggle | P: inspect | O: list nearby models")
return controller