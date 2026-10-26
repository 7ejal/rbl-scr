-- IVORY ESP remote entry. In-game loading, success and error notifications
-- appear independently of the main dashboard. Requires HttpGet + loadstring.
local Players = game:GetService("Players")

local env = _G
pcall(function()
    if type(getgenv) == "function" then
        local value = getgenv()
        if type(value) == "table" then env = value end
    end
end)

-- Independent lightweight status UI: failure in the ESP GUI does not hide errors.
local noticeGui, noticeTitle, noticeBody
local noticeSequence = 0
local function createNotice()
    local player = Players.LocalPlayer
    if not player then return end
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
        or player:WaitForChild("PlayerGui", 10)
    if not playerGui then return end

    local old = playerGui:FindFirstChild("IvoryLoaderNotice")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "IvoryLoaderNotice"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = false
    gui.DisplayOrder = 10000
    gui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Name = "Notification"
    frame.AnchorPoint = Vector2.new(1, 0)
    frame.Position = UDim2.new(1, -18, 0, 52)
    frame.Size = UDim2.fromOffset(325, 78)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 23)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 9)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = Color3.fromRGB(85, 85, 94)
    stroke.Parent = frame

    local heading = Instance.new("TextLabel")
    heading.Name = "Title"
    heading.Position = UDim2.fromOffset(14, 7)
    heading.Size = UDim2.new(1, -28, 0, 23)
    heading.BackgroundTransparency = 1
    heading.Font = Enum.Font.GothamBold
    heading.TextSize = 15
    heading.TextXAlignment = Enum.TextXAlignment.Left
    heading.TextColor3 = Color3.fromRGB(250, 250, 250)
    heading.Text = "IVORY ESP"
    heading.Parent = frame

    local body = Instance.new("TextLabel")
    body.Name = "Details"
    body.Position = UDim2.fromOffset(14, 31)
    body.Size = UDim2.new(1, -28, 0, 40)
    body.BackgroundTransparency = 1
    body.Font = Enum.Font.Gotham
    body.TextSize = 12
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.TextColor3 = Color3.fromRGB(205, 205, 215)
    body.TextWrapped = true
    body.Text = "Starting..."
    body.Parent = frame

    noticeGui, noticeTitle, noticeBody = gui, heading, body
end

local okNotice, noticeError = pcall(createNotice)
if not okNotice then warn("[IVORY] Notification UI unavailable:", noticeError) end

local function notify(title, message, status, seconds)
    local prefix = "[IVORY " .. tostring(status or "STATUS") .. "]"
    print(prefix, tostring(title), tostring(message))

    noticeSequence = noticeSequence + 1
    local sequence = noticeSequence
    if noticeGui and noticeGui.Parent and noticeTitle and noticeBody then
        noticeTitle.Text = tostring(title)
        noticeBody.Text = tostring(message)
        noticeTitle.TextColor3 = status == "ERROR"
            and Color3.fromRGB(255, 130, 130)
            or (status == "SUCCESS" and Color3.fromRGB(105, 230, 145)
                or Color3.fromRGB(240, 240, 240))
        if seconds and seconds > 0 then
            task.delay(seconds, function()
                if sequence == noticeSequence and noticeGui
                    and noticeGui.Parent then
                    noticeGui:Destroy()
                    noticeGui = nil
                end
            end)
        end
    end
end

notify("IVORY ESP - Loading", "Preparing Lua modules...", "LOADING")

local activeController
local ok, response = pcall(function()
    assert(type(loadstring) == "function", "Xeno must support loadstring")
    -- HttpGet is supplied by the executor; test it in load() below.

    local ref = env.IvoryESP_Ref or "main"
    assert(type(ref) == "string" and ref:match("^[%w%._/%-]+$"),
        "Invalid IvoryESP_Ref")
    local base = "https://raw.githubusercontent.com/7ejal/rbl-scr/" .. ref .. "/"

    local function load(path)
        local url = base .. path
        local lastError
        for attempt = 1, 3 do
            local success, body = pcall(function()
                return game:HttpGet(url .. "?ivory_cache=" .. tostring(os.time()))
            end)
            if success and type(body) == "string" and #body > 0 then
                local chunk, compileError = loadstring(body)
                if not chunk then
                    error("Syntax error in " .. path .. ": " ..
                        tostring(compileError))
                end
                local worked, result = pcall(chunk)
                if not worked then
                    error("Module error in " .. path .. ": " ..
                        tostring(result))
                end
                if result == nil then
                    error("Module " .. path .. " returned nil")
                end
                return result
            end
            lastError = tostring(body)
            if attempt < 3 then task.wait(0.35 * attempt) end
        end
        error("Could not download " .. path .. ": " .. tostring(lastError))
    end

    local settings = load("config.lua")
    if type(env.IvoryMonsterNames) == "table" then
        settings.MonsterModelNames = env.IvoryMonsterNames
    else
        env.IvoryMonsterNames = settings.MonsterModelNames
    end

    local classes = {}
    local names = {
        "Janitor", "Projection", "BoxESP", "NameESP", "DistanceESP",
        "HealthESP", "HighlightESP", "PlayerESP", "PlayerTracker",
        "MonsterESP", "MonsterTracker", "MonsterInspector",
        "QualityResolver", "QualityESP", "DhabStatsESP", "HandCatchESP", "CarESP",
        "AimController", "AutoShootController", "AutoHuntController",
        "VehicleKeyInput", "VehicleHuntController",
        "HuntPlanner", "CatchTracker", "EmergencyStop", "SafetyGuard",
        "VehicleControlLearner", "OffroadNavigator",
        "SpawnHeatmap", "HuntHUD",
        "DhabRadar", "HuntStats",
        "SettingsStore", "FOVController",
        "AntiFogController", "UIController",
        "KeybindController", "ESPController",
    }

    for i, name in ipairs(names) do
        notify("IVORY ESP - Loading",
            "Loading " .. name .. " (" .. i .. "/" .. #names .. ")...",
            "LOADING")
        classes[name] = load("src/" .. name .. ".lua")
    end

    -- Replace an old instance only after all new files have downloaded.
    if _G.IvoryInspectorConnection then
        pcall(function() _G.IvoryInspectorConnection:Disconnect() end)
        _G.IvoryInspectorConnection = nil
    end
    if type(env.IvoryESP_Stop) == "function" then
        pcall(env.IvoryESP_Stop)
    end

    local controller = classes.ESPController.new(classes, settings)
    activeController = controller

    notify("IVORY ESP - Loading", "Building dashboard...", "LOADING")
    controller:Start()

    local function stop()
        controller:Destroy()
        if env.IvoryESP_Stop == stop then env.IvoryESP_Stop = nil end
    end

    env.IvoryESP_Stop = stop
    return controller
end)

if not ok then
    if activeController then
        pcall(function() activeController:Destroy() end)
    end
    local fullError = tostring(response)
    warn("[IVORY ESP LOAD FAILED] " .. fullError)
    notify("IVORY ESP - Load failed",
        string.sub(fullError, 1, 160) .. " | Open F9 for details.",
        "ERROR", 20)
    return nil
end

notify("IVORY ESP - Loaded",
    "Successfully loaded. Press Right Ctrl for menu; I for ESP.",
    "SUCCESS", 8)
return response