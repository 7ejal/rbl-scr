-- Auto Shoot (client Tool activation only).
-- Strictly uses AimController's live DhabWild target, never HandCatch / players.
-- No RemoteEvent calls, no simulated damage, and no tool swapping.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local AutoShootController = {}
AutoShootController.__index = AutoShootController

function AutoShootController.new(settings, aimController, monsterTracker, onStatus)
    return setmetatable({
        Settings = settings,
        Aim = aimController,
        Tracker = monsterTracker,
        OnStatus = onStatus,
        Status = "",
        Running = false,
        Connection = nil,
        Elapsed = 0,
        LastShot = -math.huge,
        LastTool = nil,
    }, AutoShootController)
end

function AutoShootController:SetStatus(value)
    if self.Status == value then return end
    self.Status = value
    if self.OnStatus then
        pcall(self.OnStatus, value)
    end
end

function AutoShootController:GetEquippedTool()
    local character = Players.LocalPlayer.Character
    if not character then return nil end

    -- Tool:Activate works only with a Tool equipped on the character.
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") and child.Enabled then
            return child
        end
    end
    return nil
end

function AutoShootController:ClearShot(camera, target, position)
    local direction = position - camera.CFrame.Position
    if direction.Magnitude < 0.05 then return true end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local character = Players.LocalPlayer.Character
    params.FilterDescendantsInstances = character and {character} or {}
    params.IgnoreWater = true

    local result = workspace:Raycast(camera.CFrame.Position, direction, params)
    if not result then return true end

    local hit = result.Instance
    return hit == target or hit:IsDescendantOf(target)
end

function AutoShootController:Update()
    local settings = self.Settings
    if not settings.AutoShootEnabled then
        self:SetStatus("OFF")
        return
    end
    if not settings.AimEnabled then
        self:SetStatus("Enable Auto Aim first")
        return
    end
    if settings.AimHoldRightMouse and not UIS:IsMouseButtonPressed(
        Enum.UserInputType.MouseButton2) then
        self:SetStatus("Hold right mouse to aim and shoot")
        return
    end
    if UIS:GetFocusedTextBox() then
        self:SetStatus("Paused while typing")
        return
    end

    local camera = workspace.CurrentCamera
    if not camera then
        self:SetStatus("Waiting for camera")
        return
    end

    -- BestTarget returns (position, model) from the strict DhabWild allowlist.
    local position, target = self.Aim:BestTarget(camera)
    if not position or not target or not self.Tracker:IsDhab(target) then
        self:SetStatus("Waiting for live Dhab in target FOV")
        return
    end

    -- Wait until the aim controller has centered the camera before firing.
    local projected, visible = camera:WorldToViewportPoint(position)
    local center = camera.ViewportSize * 0.5
    local offset = Vector2.new(projected.X - center.X, projected.Y - center.Y)
    if not visible or projected.Z <= 0 or offset.Magnitude > 16 then
        self:SetStatus("Centering on Dhab")
        return
    end

    if settings.AutoShootLineOfSight
        and not self:ClearShot(camera, target, position) then
        self:SetStatus("Dhab blocked by terrain or objects")
        return
    end

    local tool = self:GetEquippedTool()
    if not tool then
        self:SetStatus("Equip a Roblox Tool to shoot")
        return
    end

    local now = os.clock()
    local shotsPerSecond = math.clamp(settings.AutoShootRate or 3, 1, 8)
    if now - self.LastShot < 1 / shotsPerSecond then
        self:SetStatus("Auto shooting: " .. tool.Name)
        return
    end

    -- Validate the selected target one final time before tool activation.
    if not target:IsDescendantOf(workspace)
        or not self.Tracker:IsDhab(target) or not tool.Enabled then
        self:SetStatus("Target or Tool unavailable")
        return
    end

    self.LastShot = now
    local success, err = pcall(function()
        tool:Activate()
    end)
    if not success then
        self:SetStatus("Tool activation failed: " ..
            tostring(err):sub(1, 65))
        return
    end

    self.LastTool = tool
    self:SetStatus("Auto shooting: " .. tool.Name)

    -- Release the activation so semi-automatic Tools can react again.
    task.delay(0.075, function()
        local character = Players.LocalPlayer.Character
        if tool.Parent == character and tool.Enabled then
            pcall(function() tool:Deactivate() end)
        end
        if self.LastTool == tool then self.LastTool = nil end
    end)
end

function AutoShootController:Start()
    if self.Running then return end
    self.Running = true
    self:SetStatus("OFF")
    self.Connection = RunService.Heartbeat:Connect(function(dt)
        if not self.Running then return end
        self.Elapsed = self.Elapsed + dt
        if self.Elapsed < 0.08 then return end
        self.Elapsed = 0

        local ok, err = pcall(self.Update, self)
        if not ok then
            self:SetStatus("Auto Shoot error: " .. tostring(err):sub(1, 65))
        end
    end)
end

function AutoShootController:Destroy()
    self.Running = false
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    if self.LastTool and self.LastTool.Parent then
        pcall(function() self.LastTool:Deactivate() end)
    end
    self.LastTool = nil
    self:SetStatus("Stopped")
end

return AutoShootController