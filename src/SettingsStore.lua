-- Optional local JSON settings. Never stores tokens, IDs, scripts or credentials.
-- Requires executor readfile/writefile; disabled by default and opt-in only.
local HttpService = game:GetService("HttpService")
local Store = {}
Store.__index = Store

local KEYS = {
    "Enabled", "PlayersEnabled", "OtherNPCEnabled", "MonsterEnabled",
    "MonsterBoxes", "MonsterNames", "MonsterDistance", "MonsterHealth",
    "MonsterHighlights", "CarsEnabled", "CarBoxes", "CarNames",
    "CarDistance", "CarHighlights", "HandCatchEnabled", "HandCatchBoxes",
    "HandCatchNames", "HandCatchDistance", "HandCatchHighlights",
    "DhabQualityEnabled", "DhabStatsEnabled", "HandCatchQuality",
    "AimEnabled", "AimHoldRightMouse", "AimShowCircle", "AimRadius",
    "AimDistance", "AimSmoothness", "AutoShootEnabled",
    "AutoShootInputMode", "AutoShootLineOfSight", "AutoShootRate",
    "AutoShootMaxDistance", "AutoHuntEnabled", "HuntAutoShoot",
    "HuntPauseOnManualMove", "HuntStopDistance", "HuntSearchDistance",
    "HuntShootDistance", "HuntCarEnabled", "HuntCarStopDistance",
    "HuntCarTargetKmh", "HuntCarObstacleBrake",
    "HuntCarInvertSteering",
    "HuntCarInputMode", "HuntCarTurnDeadzone",
    "HuntRouteEnabled", "HuntScoreLength", "HuntScoreSize",
    "HuntScoreDistance", "HuntAvoidRadius",
    "AimPredictionEnabled", "AimLeadSeconds", "PerformanceMode",
    "HuntPriority", "HuntMinLength",
    "HuntTierT1", "HuntTierT2", "HuntTierT3", "HuntTierT4",
    "HuntTierT5", "HuntTierT6", "HuntTierUnknown", "RadarEnabled",
    "RadarRange", "StatsEnabled", "AntiFogEnabled", "MaxDistance",
    "CameraFOV",
    "SaveSettingsEnabled",
}
local function api(name)
    if type(getgenv) == "function" then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" and type(env[name]) == "function" then
            return env[name]
        end
    end
    if name == "readfile" and type(readfile) == "function" then return readfile end
    if name == "writefile" and type(writefile) == "function" then return writefile end
    return nil
end

function Store.new(settings)
    return setmetatable({
        Settings = settings,
        Filename = "ivory_esp_" .. tostring(game.PlaceId) .. "_settings.json",
        Sequence = 0,
        Destroyed = false,
        LastStatus = "Not enabled",
    }, Store)
end

function Store:Supported()
    return api("readfile") ~= nil and api("writefile") ~= nil
end

function Store:Load()
    if not self:Supported() then
        self.LastStatus = "File access unavailable in this executor"
        return false
    end
    local read = api("readfile")
    local ok, contents = pcall(read, self.Filename)
    if not ok or type(contents) ~= "string" then
        self.LastStatus = "No saved preferences"
        return false
    end
    local decoded, data = pcall(HttpService.JSONDecode, HttpService, contents)
    if not decoded or type(data) ~= "table" or data.SaveSettingsEnabled ~= true then
        self.LastStatus = "Saved settings disabled or invalid"
        return false
    end
    local default = self.Settings
    for _, key in ipairs(KEYS) do
        local value = data[key]
        if type(value) == type(default[key]) then
            if type(value) == "number" then
                if value == value and value ~= math.huge
                    and value ~= -math.huge then
                    default[key] = value
                end
            elseif key == "HuntPriority" then
                if value == "Closest" or value == "Longest"
                    or value == "Largest" or value == "Smart" then
                    default[key] = value
                end
            elseif key == "HuntCarInputMode" then
                if value == "Keyboard" or value == "Seat" then
                    default[key] = value
                end
            elseif key == "AutoShootInputMode" then
                if value == "Tool" or value == "Mouse" then
                    default[key] = value
                end
            else
                default[key] = value
            end
        end
    end
    -- Conservative bounds for writable numeric preferences.
    local bounds = {
        MaxDistance = {100, 5000}, AimRadius = {20, 400},
        AimDistance = {25, 1200}, AimSmoothness = {0.01, 1},
        AutoShootRate = {1, 8}, AutoShootMaxDistance = {10, 500},
        HuntStopDistance = {10, 100}, HuntSearchDistance = {100, 2000},
        HuntShootDistance = {10, 500}, HuntMinLength = {0, 12},
        HuntCarStopDistance = {25, 125}, HuntCarTargetKmh = {30, 180},
        RadarRange = {100, 2000}, CameraFOV = {0, 120},
        HuntCarTurnDeadzone = {0.05, 0.5},
        HuntScoreLength = {0, 10}, HuntScoreSize = {0, 10},
        HuntScoreDistance = {0, 0.5}, HuntAvoidRadius = {20, 350},
        AimLeadSeconds = {0, 0.6},
    }
    for key, limits in pairs(bounds) do
        default[key] = math.clamp(default[key], limits[1], limits[2])
    end
    self.LastStatus = "Loaded " .. self.Filename
    return true
end

function Store:SaveNow()
    local write = api("writefile")
    if not write then
        self.LastStatus = "writefile unsupported"
        return false
    end
    local data = {SaveSettingsEnabled = self.Settings.SaveSettingsEnabled == true}
    if data.SaveSettingsEnabled then
        for _, key in ipairs(KEYS) do
            if key ~= "SaveSettingsEnabled" then data[key] = self.Settings[key] end
        end
    end
    local ok, err = pcall(function()
        write(self.Filename, HttpService:JSONEncode(data))
    end)
    self.LastStatus = ok and ("Saved " .. self.Filename)
        or ("Save failed: " .. tostring(err):sub(1, 90))
    return ok
end

function Store:Schedule()
    if self.Destroyed then return end
    self.Sequence = self.Sequence + 1
    local generation = self.Sequence
    task.delay(1.2, function()
        if not self.Destroyed and generation == self.Sequence then
            self:SaveNow()
        end
    end)
end

function Store:OnSettingChanged(key)
    if key == "SaveSettingsEnabled" then
        -- Writes opt-out marker so previous enabled preferences won't reload.
        self:SaveNow()
    elseif self.Settings.SaveSettingsEnabled then
        self:Schedule()
    end
end

function Store:Destroy()
    if self.Destroyed then return end
    self.Sequence = self.Sequence + 1
    if self.Settings.SaveSettingsEnabled then self:SaveNow() end
    self.Destroyed = true
end

return Store