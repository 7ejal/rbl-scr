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
    "HuntAdapterEnabled", "HuntManualSkipSeconds",
    "HuntCarCruiseEnabled", "HuntOffroadEnabled",
    "HuntRouteEnabled", "HuntTargetLockEnabled",
    "DhabTierColorsEnabled", "HighlightLongestDhab",
    "HuntHUDEnabled", "TargetArrowEnabled",
    "HeatmapEnabled", "HeatmapCellSize",
    "DhabAlertsEnabled", "DhabAlertTier", "DhabAlertLength",
    "HuntHotkey", "NextTargetHotkey", "RadarHotkey",
    "MenuHotkey", "StopHotkey",
    "GuiCompactEnabled", "GuiScale",
    "HuntScoreLength", "HuntScoreSize",
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
                if value == "Keyboard" or value == "Seat"
                    or value == "Auto" or value == "ControlsValue" then
                    default[key] = value
                end
            elseif key == "HuntHotkey" or key == "NextTargetHotkey"
                or key == "RadarHotkey" or key == "MenuHotkey"
                or key == "StopHotkey" then
                local valid={H=true,J=true,K=true,L=true,B=true,
                    N=true,R=true,T=true,Y=true,U=true,
                    F6=true,F7=true,F9=true,F10=true}
                if valid[value] then default[key]=value end
            elseif key == "AutoShootInputMode" then
                if value == "Tool" or value == "Mouse" then
                    default[key] = value
                end
            else
                default[key] = value
            end
        end
    end
    -- Explicit named user slots with a constrained key list and type checks.
    if type(data.ConfigSlots)=="table" then
        local slots={}
        local allowed={
            "AutoHuntEnabled","HuntCarEnabled","HuntAutoShoot",
            "HuntCarTargetKmh","HuntCarInputMode","HuntStopDistance",
            "HuntCarStopDistance","HuntSearchDistance","HuntPriority",
            "HuntTierT1","HuntTierT2","HuntTierT3","HuntTierT4",
            "HuntTierT5","HuntTierT6","AutoShootEnabled","AimEnabled",
            "RadarEnabled","PerformanceMode","DhabStatsEnabled",
            "DhabTierColorsEnabled","HuntHUDEnabled",
        }
        for _,name in ipairs({"Custom A","Custom B"}) do
            local entry=data.ConfigSlots[name]
            if type(entry)=="table" then
                local slot={}
                for _,key in ipairs(allowed) do
                    local value=entry[key]
                    if type(value)==type(self.Settings[key]) then
                        if type(value)=="number" then
                            if value==value and math.abs(value)<5000 then
                                slot[key]=value
                            end
                        elseif type(value)=="string" then
                            if #value<=30 then slot[key]=value end
                        else
                            slot[key]=value
                        end
                    end
                end
                slots[name]=slot
            end
        end
        self.Settings.ConfigSlots=slots
    end
    -- Car-name input profiles have separate validation; no arbitrary table
    -- loading into runtime settings and no trusted code in profile values.
    if type(data.HuntCarProfiles) == "table" then
        local profiles = {}
        local count = 0
        for name, mode in pairs(data.HuntCarProfiles) do
            if type(name) == "string" and #name <= 100
                and (mode == "Keyboard" or mode == "Seat")
                and count < 25 then
                profiles[name] = mode
                count = count + 1
            end
        end
        self.Settings.HuntCarProfiles = profiles
    end
    -- Conservative bounds for writable numeric preferences.
    local bounds = {
        MaxDistance = {100, 5000}, AimRadius = {20, 400},
        AimDistance = {25, 1200}, AimSmoothness = {0.01, 1},
        AutoShootRate = {1, 8}, AutoShootMaxDistance = {10, 500},
        HuntStopDistance = {10, 100}, HuntSearchDistance = {100, 2000},
        HuntShootDistance = {10, 500}, HuntMinLength = {0, 12},
        HuntCarStopDistance = {25, 125}, HuntCarTargetKmh = {30, 180},
        GuiScale = {0.65, 1.25},
        HuntManualSkipSeconds = {15, 600}, DhabAlertTier = {1, 6},
        DhabAlertLength = {0, 15},
        RadarRange = {100, 2000}, CameraFOV = {0, 120},
        HeatmapCellSize = {50, 350},
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
        local profiles = {}
        local count = 0
        for name, mode in pairs(self.Settings.HuntCarProfiles or {}) do
            if type(name) == "string" and #name <= 100
                and (mode == "Keyboard" or mode == "Seat")
                and count < 25 then
                profiles[name] = mode
                count = count + 1
            end
        end
        data.HuntCarProfiles = profiles
        data.ConfigSlots = self.Settings.ConfigSlots or {}
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