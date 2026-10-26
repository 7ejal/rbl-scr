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

function ESPController:AddMonster(model)
    if self.Monsters[model] then return end
    self.Monsters[model] = self.Classes.MonsterESP.new(
        model, self.UI.Gui, self.Classes, self.Settings
    )
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
    local count = 0
    for _ in pairs(self.Monsters) do count = count + 1 end
    if self.UI then self.UI:SetMonsterCount(count) end
end

function ESPController:RescanMonsters()
    if self.MonsterTracker then
        self.MonsterTracker:Scan()
        self:UpdateMonsterCount()
    end
end

function ESPController:SetEnabled(enabled)
    self.Settings.Enabled = enabled
    self.UI:SetESPEnabled(enabled)
    if not enabled then
        for _, record in pairs(self.Records) do record:Hide() end
        for _, record in pairs(self.Monsters) do record:Hide() end
    end
end

function ESPController:SetSetting(key, value)
    if key == "Enabled" then
        self:SetEnabled(value)
        return
    end

    self.Settings[key] = value
    if key == "PlayersEnabled" and not value then
        for _, record in pairs(self.Records) do record:Hide() end
    elseif key == "MonsterEnabled" and not value then
        for _, record in pairs(self.Monsters) do record:Hide() end
    end
    if self.UI then self.UI:Refresh() end
end

function ESPController:Toggle()
    self:SetEnabled(not self.Settings.Enabled)
end

function ESPController:Start()
    if self.Running or self.Destroyed then return end

    self.FOV = self.Classes.FOVController.new(self.Settings)
    self.UI = self.Classes.UIController.new(
        self.LocalPlayer:WaitForChild("PlayerGui"),
        self.Settings,
        self.FOV,
        self.Classes.Janitor
    )

    self.UI.OnToggle = function() self:Toggle() end
    self.UI.OnSettingChanged = function(key, value)
        self:SetSetting(key, value)
    end
    self.UI.OnRescan = function() self:RescanMonsters() end

    self.Keys = self.Classes.KeybindController.new(
        self.Settings.ToggleKey,
        function() self:Toggle() end
    )
    self.Inspector = self.Classes.MonsterInspector.new(
        self.Settings.InspectorKey,
        self.Settings.InspectorScanKey,
        self.Classes.MonsterTracker
    )
    self.UI.OnInspectNearby = function()
        if self.Inspector then self.Inspector:ScanNearby() end
    end

    self.Tracker = self.Classes.PlayerTracker.new(
        self.LocalPlayer,
        function(player) self:AddPlayer(player) end,
        function(player) self:RemovePlayer(player) end
    )
    self.Tracker:Start()

    self.MonsterTracker = self.Classes.MonsterTracker.new(
        function(model) self:AddMonster(model) end,
        function(model) self:RemoveMonster(model) end
    )
    self.MonsterTracker:Start()

    self.Running = true
    table.insert(self.Connections, RunService.RenderStepped:Connect(function(dt)
        if not self.Running then return end
        local camera = workspace.CurrentCamera
        if not camera then return end

        self.FOV:Update(camera)

        -- A periodic rescan accounts for spawned models that receive parts,
        -- humanoids, or tags after they initially enter Workspace.
        self.MonsterScanTimer = self.MonsterScanTimer + dt
        if self.MonsterScanTimer >= 10 then
            self.MonsterScanTimer = 0
            self:RescanMonsters()
        end

        if not self.Settings.Enabled then return end

        self.Accumulator = self.Accumulator + dt
        local interval = 1 / math.max(1, self.Settings.RenderFPS)
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

        if self.Settings.MonsterEnabled then
            for model, record in pairs(self.Monsters) do
                if self.MonsterTracker:IsCandidate(model) then
                    local ok = pcall(record.Update, record, camera, localRoot)
                    if not ok then record:Hide() end
                else
                    record:Hide()
                end
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

    if self.Tracker then self.Tracker:Destroy() end
    if self.MonsterTracker then self.MonsterTracker:Destroy() end
    if self.Keys then self.Keys:Destroy() end
    if self.Inspector then self.Inspector:Destroy() end

    local players = {}
    for player in pairs(self.Records) do table.insert(players, player) end
    for _, player in ipairs(players) do self:RemovePlayer(player) end

    local monsters = {}
    for model in pairs(self.Monsters) do table.insert(monsters, model) end
    for _, model in ipairs(monsters) do self:RemoveMonster(model) end

    if self.UI then self.UI:Destroy() end
    if self.FOV then self.FOV:Destroy() end
end

return ESPController