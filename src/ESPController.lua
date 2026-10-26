-- Application coordinator. Individual features remain separate class modules.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ESPController = {}
ESPController.__index = ESPController

function ESPController.new(classes, settings)
    return setmetatable({
        Classes = classes,
        Settings = settings,
        LocalPlayer = Players.LocalPlayer,
        Records = {},
        Monsters = {},
        Connections = {},
        Running = false,
        Destroyed = false,
        Accumulator = 0,
        MonsterScanTimer = 0,
    }, ESPController)
end

function ESPController:AddPlayer(player)
    if player == self.LocalPlayer or self.Records[player] then return end
    self.Records[player] = self.Classes.PlayerESP.new(
        player, self.UI.Gui, self.Classes, self.Settings, self.LocalPlayer
    )
end

function ESPController:RemovePlayer(player)
    local record = self.Records[player]
    if not record then return end
    record:Destroy()
    self.Records[player] = nil
end

function ESPController:AddMonster(model, category)
    if self.Monsters[model] then return end
    if category == "car" then
        self.Monsters[model] = self.Classes.CarESP.new(
            model, self.UI.Gui, self.Classes, self.Settings
        )
    elseif category == "handcatch" then
        self.Monsters[model] = self.Classes.HandCatchESP.new(
            model, self.UI.Gui, self.Classes, self.Settings
        )
        self.Monsters[model].Category = "handcatch"
    else
        self.Monsters[model] = self.Classes.MonsterESP.new(
            model, self.UI.Gui, self.Classes, self.Settings,
            category, self.MonsterTracker:IsDhab(model)
        )
    end
    self:UpdateMonsterCount()
end

function ESPController:RemoveMonster(model)
    local record = self.Monsters[model]
    if not record then return end
    record:Destroy()
    self.Monsters[model] = nil
    self:UpdateMonsterCount()
end

function ESPController:UpdateMonsterCount()
    local count, handCount, carCount = 0, 0, 0
    for _, record in pairs(self.Monsters) do
        if record.Category == "monster" then
            count = count + 1
        elseif record.Category == "handcatch" then
            handCount = handCount + 1
        elseif record.Category == "car" then
            carCount = carCount + 1
        end
    end
    if self.UI then
        self.UI:SetMonsterCount(count)
        self.UI:SetHandCatchCount(handCount)
        self.UI:SetCarCount(carCount)
    end
end

function ESPController:RescanMonsters()
    if self.MonsterTracker then
        self.MonsterTracker:Scan()
        self:UpdateMonsterCount()
    end
end

function ESPController:SetEnabled(enabled)
    self.Settings.Enabled = enabled
    if self.Store then self.Store:OnSettingChanged("Enabled") end
    self.UI:SetESPEnabled(enabled)
    if not enabled then
        for _, record in pairs(self.Records) do record:Hide() end
        for _, record in pairs(self.Monsters) do record:Hide() end
    end
end

function ESPController:EmergencyStop()
    -- F8 aborts only active autonomous actions and always releases WASD.
    self.Settings.AutoHuntEnabled = false
    self.Settings.AutoShootEnabled = false
    self.Settings.AimEnabled = false
    if self.Hunt then self.Hunt:Reset();self.Hunt:SetStatus("F8 emergency stop") end
    if self.Hunt and self.Hunt.Vehicle then self.Hunt.Vehicle:Stop() end
    if self.AutoShoot then self.AutoShoot:ReleaseMouse()
        self.AutoShoot:SetStatus("F8 emergency stop") end
    if self.Aim then self.Aim:SetHuntTarget(nil) end
    if self.Store then
        for _,key in ipairs({"AutoHuntEnabled","AutoShootEnabled","AimEnabled"}) do
            self.Store:OnSettingChanged(key)
        end
    end
    if self.UI then
        self.UI:Refresh()
        self.UI:SetDiagnosticStatus(self:Diagnostics())
    end
end

function ESPController:Diagnostics()
    local vehicle = self.Hunt and self.Hunt.Vehicle
    local report = {
        "=== IVORY DIAGNOSTICS ===",
        "Auto Hunt: " .. tostring(self.Settings.AutoHuntEnabled),
        "Hunt status: " .. tostring(self.Hunt and self.Hunt.Status or "not initialized"),
        "Vehicle mode: " .. tostring(self.Settings.HuntCarInputMode),
        "Car status: " .. tostring(vehicle and vehicle.LastStatus or "not initialized"),
        "Key API: " .. tostring(vehicle and vehicle.Input.Method or "not probed"),
        "Key error: " .. tostring(vehicle and vehicle.Input.Error or "none"),
        "Auto Shoot: " .. tostring(self.AutoShoot and self.AutoShoot.Status or "not initialized"),
        "Radar: " .. tostring(self.Settings.RadarEnabled),
        "Performance mode: " .. tostring(self.Settings.PerformanceMode),
        "Planner: " .. tostring(self.Planner and self.Planner:Describe() or "not initialized"),
        "F8 stops Hunt / Shoot / Aim and releases WASD",
    }
    return table.concat(report, "\n")
end

function ESPController:MarkAvoidZone()
    local c = self.LocalPlayer.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if root and self.Planner then
        self.Planner:AddZone(root.Position)
        if self.Hunt then self.Hunt:Reset() end
    end
    if self.UI then self.UI:SetDiagnosticStatus(self:Diagnostics()) end
end

function ESPController:ClearAvoidZones()
    if self.Planner then self.Planner:ClearZones() end
    if self.Hunt then self.Hunt:Reset() end
    if self.UI then self.UI:SetDiagnosticStatus(self:Diagnostics()) end
end

function ESPController:SetSetting(key, value)
    if key == "Enabled" then
        self:SetEnabled(value)
        return
    end

    self.Settings[key] = value
    if key == "CameraFOV" and self.FOV then
        self.FOV:SetFOV(value)
    end
    if key:match("^HuntTier") or key == "HuntPriority"
        or key == "HuntMinLength" or key == "HuntSearchDistance"
        or key == "HuntRouteEnabled" then
        if self.Hunt then self.Hunt:Reset() end
    end
    if self.Store then
        self.Store:OnSettingChanged(key)
        if self.UI then self.UI:SetStorageStatus(self.Store.LastStatus) end
    end
    if key == "AntiFogEnabled" and self.AntiFog then
        self.AntiFog:SetEnabled(value)
    end
    if key == "HuntCarInputMode" and self.Hunt and self.Hunt.Vehicle then
        self.Hunt.Vehicle:Stop()
    end
    if key == "AutoHuntEnabled" and not value and self.Hunt then
        self.Hunt:Reset()
        self.Hunt:SetStatus("OFF")
    end
    -- Auto Shoot depends on camera aim; activating shooting enables aim too.
    if key == "AutoShootEnabled" and value then
        self.Settings.AimEnabled = true
    end
    if key == "PlayersEnabled" and not value then
        for _, record in pairs(self.Records) do record:Hide() end
    elseif key == "MonsterEnabled" and not value then
        for _, record in pairs(self.Monsters) do
            if record.Category == "monster" then record:Hide() end
        end
    elseif key == "OtherNPCEnabled" and not value then
        for _, record in pairs(self.Monsters) do
            if record.Category == "other" then record:Hide() end
        end
    elseif key == "HandCatchEnabled" and not value then
        for _, record in pairs(self.Monsters) do
            if record.Category == "handcatch" then record:Hide() end
        end
    elseif key == "CarsEnabled" and not value then
        for _, record in pairs(self.Monsters) do
            if record.Category == "car" then record:Hide() end
        end
    end
    if self.UI then self.UI:Refresh() end
end

function ESPController:Toggle()
    self:SetEnabled(not self.Settings.Enabled)
end

function ESPController:InspectNearestDhabQuality()
    if not self.MonsterTracker then return end
    local camera = workspace.CurrentCamera
    local character = self.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local origin = root and root.Position or
        (camera and camera.CFrame.Position)
    if not origin then
        self.UI:SetQualityReport("No player or camera position available")
        return
    end

    local nearest, nearestDist = nil, math.huge
    for model, _ in pairs(self.MonsterTracker.Known) do
        if self.MonsterTracker:IsDhab(model) then
            local part = model.PrimaryPart
                or model:FindFirstChild("HumanoidRootPart", true)
                or model:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local distance = (part.Position - origin).Magnitude
                if distance < nearestDist then
                    nearest, nearestDist = model, distance
                end
            end
        end
    end

    if not nearest then
        self.UI:SetQualityReport(
            "No replicated live Dhab found. Enter an area with wildlife and rescan."
        )
        return
    end

    local report = self.Classes.QualityResolver.Diagnose(nearest)
    self.UI:SetQualityReport(report)
    local env = _G
    pcall(function()
        if type(getgenv) == "function" then env = getgenv() end
    end)
    env.IvoryQualityReport = report
    if type(setclipboard) == "function" then
        pcall(setclipboard, report)
    end
    print(report)
end

function ESPController:Start()
    if self.Running or self.Destroyed then return end

    self.Store = self.Classes.SettingsStore.new(self.Settings)
    self.Store:Load()

    self.Stats = self.Classes.HuntStats.new(self.Settings)
    self.Planner = self.Classes.HuntPlanner.new(self.Settings)
    self.Catches = self.Classes.CatchTracker.new(self.Settings)
    self.FOV = self.Classes.FOVController.new(self.Settings)
    self.AntiFog = self.Classes.AntiFogController.new()
    self.UI = self.Classes.UIController.new(
        self.LocalPlayer:WaitForChild("PlayerGui"),
        self.Settings,
        self.FOV,
        self.Classes.Janitor
    )

    self.AntiFog:SetEnabled(self.Settings.AntiFogEnabled)
    self.UI:SetStorageStatus(self.Store.LastStatus)
    self.UI:SetStatistics(self.Stats:GetSummary())
    self.UI.OnEmergencyStop = function() self:EmergencyStop() end
    self.UI.OnMarkAvoidZone = function() self:MarkAvoidZone() end
    self.UI.OnClearAvoidZones = function() self:ClearAvoidZones() end
    self.UI.OnDiagnose = function()
        self.UI:SetDiagnosticStatus(self:Diagnostics())
    end
    self.UI.OnStatsReset = function()
        if self.Stats then self.Stats:Reset() end
    end
    self.Stats.OnChange = function(summary)
        if self.UI then self.UI:SetStatistics(summary) end
    end
    self.UI.OnToggle = function() self:Toggle() end
    self.UI.OnSettingChanged = function(key, value)
        self:SetSetting(key, value)
    end
    self.UI.OnRescan = function() self:RescanMonsters() end
    self.UI.OnQualityScan = function() self:InspectNearestDhabQuality() end
    self.UI.OnTargetsRefresh = function(showScenery)
        if self.MonsterTracker then
            self.UI:RenderTargets(
                self.MonsterTracker:GetChoices(40, showScenery)
            )
        end
    end
    self.UI.OnTrackMonster = function(instance, enabled)
        if not self.MonsterTracker then return end
        if enabled then
            self.MonsterTracker:TrackName(instance)
        else
            self.MonsterTracker:UntrackName(instance)
        end
        self:UpdateMonsterCount()
    end

    self.Keys = self.Classes.KeybindController.new(
        self.Settings.ToggleKey,
        function() self:Toggle() end
    )
    self.Emergency = self.Classes.EmergencyStop.new(
        self.Settings.EmergencyKey,
        function() self:EmergencyStop() end
    )
    -- Create the tracker before the inspector so its target lookup is valid.
    self.MonsterTracker = self.Classes.MonsterTracker.new(
        function(model, category) self:AddMonster(model, category) end,
        function(model) self:RemoveMonster(model) end,
        self.Settings
    )
    self.MonsterTracker:Start()

    self.Inspector = self.Classes.MonsterInspector.new(
        self.Settings.InspectorKey,
        self.Settings.InspectorScanKey,
        self.MonsterTracker,
        self.Settings.MarkMonsterKey,
        self.Classes.QualityResolver
    )
    self.Inspector.OnMarked = function()
        self:UpdateMonsterCount()
        if self.UI.ActivePage == "Targets" then
            self.UI.OnTargetsRefresh(self.UI.ShowScenery)
        end
    end
    self.UI.OnInspectNearby = function()
        if self.Inspector then self.Inspector:ScanNearby() end
    end

    self.Tracker = self.Classes.PlayerTracker.new(
        self.LocalPlayer,
        function(player) self:AddPlayer(player) end,
        function(player) self:RemovePlayer(player) end
    )
    self.Tracker:Start()

    self.Aim = self.Classes.AimController.new(
        self.Settings, self.MonsterTracker, self.UI.Gui
    )
    self.Aim:Start()

    self.AutoShoot = self.Classes.AutoShootController.new(
        self.Settings,
        self.Aim,
        self.MonsterTracker,
        function(status)
            if self.UI then self.UI:SetAutoShootStatus(status) end
        end
    )
    self.AutoShoot.UI = self.UI
    self.AutoShoot.Stats = self.Stats
    self.AutoShoot:Start()

    self.Hunt = self.Classes.AutoHuntController.new(
        self.Settings,
        self.MonsterTracker,
        self.Aim,
        function(status)
            if self.UI then self.UI:SetAutoHuntStatus(status) end
        end
    )
    self.Hunt.UI = self.UI
    self.Hunt.Vehicle = self.Classes.VehicleHuntController.new(
        self.Settings, self.Classes.VehicleKeyInput
    )
    self.Hunt.Planner = self.Planner
    self.Hunt.Stats = self.Stats
    self.Hunt:Start()

    self.Radar = self.Classes.DhabRadar.new(
        self.Settings, self.MonsterTracker,
        self.LocalPlayer:WaitForChild("PlayerGui"),
        function() return self.Hunt and self.Hunt.Target or nil end
    )
    self.Radar:Start()
    self.StatsRefresh = 0

    self.Running = true
    table.insert(self.Connections, RunService.RenderStepped:Connect(function(dt)
        if not self.Running then return end
        local camera = workspace.CurrentCamera
        if not camera then return end

        self.FOV:Update(camera)
        self.StatsRefresh = self.StatsRefresh + dt
        if self.StatsRefresh >= 1 then
            self.StatsRefresh = 0
            if self.UI and self.Stats then
                if self.Catches then self.Catches:Update() end
                self.UI:SetStatistics(self.Stats:GetSummary() ..
                    "\n" .. (self.Catches and self.Catches:Describe() or ""))
                if self.Store then self.UI:SetStorageStatus(self.Store.LastStatus) end
            end
        end

        -- A periodic rescan accounts for spawned models that receive parts,
        -- humanoids, or tags after they initially enter Workspace.
        self.MonsterScanTimer = self.MonsterScanTimer + dt
        if self.MonsterScanTimer >=
            (self.Settings.PerformanceMode and 25 or 10) then
            self.MonsterScanTimer = 0
            self:RescanMonsters()
        end

        if not self.Settings.Enabled then return end

        self.Accumulator = self.Accumulator + dt
        local interval = 1 / math.max(1,
            self.Settings.PerformanceMode
                and math.min(15, self.Settings.RenderFPS)
                or self.Settings.RenderFPS)
        if self.Accumulator < interval then return end
        self.Accumulator = 0

        local character = self.LocalPlayer.Character
        local localRoot = character and character:FindFirstChild("HumanoidRootPart")

        if self.Settings.PlayersEnabled then
            for _, record in pairs(self.Records) do
                local ok = pcall(record.Update, record, camera, localRoot)
                if not ok then record:Hide() end
            end
        end

        for model, record in pairs(self.Monsters) do
            local category = self.MonsterTracker.Known[model]
            local visible = category == "monster" and self.Settings.MonsterEnabled
                or (category == "other" and self.Settings.OtherNPCEnabled)
                or (category == "handcatch" and self.Settings.HandCatchEnabled)
                or (category == "car" and self.Settings.CarsEnabled)
            if visible then
                local ok = pcall(record.Update, record, camera, localRoot)
                if not ok then record:Hide() end
            else
                record:Hide()
            end
        end
    end))
end

function ESPController:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self.Running = false

    for _, connection in ipairs(self.Connections) do
        connection:Disconnect()
    end
    table.clear(self.Connections)

    if self.Hunt then self.Hunt:Destroy() end
    if self.Radar then self.Radar:Destroy() end
    if self.AutoShoot then self.AutoShoot:Destroy() end
    if self.Aim then self.Aim:Destroy() end
    if self.Tracker then self.Tracker:Destroy() end
    if self.MonsterTracker then self.MonsterTracker:Destroy() end
    if self.Keys then self.Keys:Destroy() end
    if self.Emergency then self.Emergency:Destroy() end
    if self.Inspector then self.Inspector:Destroy() end

    local players = {}
    for player in pairs(self.Records) do table.insert(players, player) end
    for _, player in ipairs(players) do self:RemovePlayer(player) end

    local monsters = {}
    for model in pairs(self.Monsters) do table.insert(monsters, model) end
    for _, model in ipairs(monsters) do self:RemoveMonster(model) end

    if self.Store then self.Store:Destroy() end
    if self.AntiFog then self.AntiFog:Destroy() end
    if self.UI then self.UI:Destroy() end
    if self.FOV then self.FOV:Destroy() end
end

return ESPController