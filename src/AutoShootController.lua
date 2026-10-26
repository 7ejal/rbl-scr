-- Auto Shoot: real left-mouse input when available, or Roblox Tool activation.
-- Strictly uses AimController's live DhabWild target, never HandCatch / players.
-- No RemoteEvent calls, simulated damage or tool swapping.
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
        MouseRelease = nil,
        UI = nil,
    }, AutoShootController)
end

function AutoShootController:SetStatus(value)
    if self.Status == value then return end
    self.Status = value
    if self.OnStatus then
        pcall(self.OnStatus, value)
    end
end

-- Executors expose input functions either as globals or inside getgenv().
-- Never assume Xeno implements a particular function; check dynamically.
local function inputFunction(name)
    local direct = nil
    if name == "mouse1click" then direct = mouse1click
    elseif name == "mouse1press" then direct = mouse1press
    elseif name == "mouse1release" then direct = mouse1release
    end
    if type(direct) == "function" then return direct end

    if type(getgenv) == "function" then
        local ok, value = pcall(getgenv)
        if ok and type(value) == "table" and type(value[name]) == "function" then
            return value[name]
        end
    end
    if type(_G) == "table" and type(_G[name]) == "function" then
        return _G[name]
    end
    return nil
end

function AutoShootController:ReleaseMouse()
    if self.MouseRelease then
        local release = self.MouseRelease
        self.MouseRelease = nil
        pcall(release)
    end
end

function AutoShootController:FireMouse()
    local click = inputFunction("mouse1click")
    if click then
        local ok, err = pcall(click)
        if ok then return true end
        return false, "Left click failed: " .. tostring(err):sub(1, 90)
    end

    local press = inputFunction("mouse1press")
    local release = inputFunction("mouse1release")
    if press and release then
        self:ReleaseMouse()
        local ok, err = pcall(press)
        if not ok then
            return false, "Left press failed: " .. tostring(err):sub(1, 90)
        end

        self.MouseRelease = release
        task.delay(0.06, function()
            self:ReleaseMouse()
        end)
        return true
    end
    return false, "Xeno does not expose mouse1click (or mouse1press/release)"
end

function AutoShootController:FireTool(tool)
    if not tool then return false, "Equip a Roblox Tool to fire" end
    local ok, err = pcall(function() tool:Activate() end)
    if not ok then
        return false, "Tool activation failed: " .. tostring(err):sub(1, 90)
    end

    self.LastTool = tool
    task.delay(0.075, function()
        if tool.Parent == Players.LocalPlayer.Character and tool.Enabled then
            pcall(function() tool:Deactivate() end)
        end
        if self.LastTool == tool then self.LastTool = nil end
    end)
    return true
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
    -- Auto Hunt can use the existing shooter without changing the
    -- independent Auto Shoot toggle. Turning Hunt off stops hunt-only fire.
    local huntFire = settings.AutoHuntEnabled and settings.HuntAutoShoot
    if not settings.AutoShootEnabled and not huntFire then
        self:ReleaseMouse()
        self:SetStatus("OFF")
        return
    end
    if not settings.AimEnabled and not settings.AutoHuntEnabled then
        self:ReleaseMouse()
        self:SetStatus("Enable Auto Aim first")
        return
    end
    if settings.AimHoldRightMouse and not huntFire
        and not UIS:IsMouseButtonPressed(
            Enum.UserInputType.MouseButton2) then
        self:ReleaseMouse()
        self:SetStatus("Hold right mouse to aim and shoot")
        return
    end
    if UIS:GetFocusedTextBox() then
        self:ReleaseMouse()
        self:SetStatus("Paused while typing")
        return
    end
    -- Real simulated clicks interact with visible GUI buttons. Do not send a
    -- click if the cursor is over our own dashboard.
    if (settings.AutoShootInputMode or "Mouse") == "Mouse" and self.UI
        and self.UI.Window and self.UI.Window.Visible then
        local panel = self.UI.Window
        local cursor = UIS:GetMouseLocation()
        local position = panel.AbsolutePosition
        local size = panel.AbsoluteSize
        if cursor.X >= position.X and cursor.X <= position.X + size.X
            and cursor.Y >= position.Y and cursor.Y <= position.Y + size.Y then
            self:SetStatus("Move cursor off menu or press Right Ctrl")
            return
        end
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

    local inputMode = settings.AutoShootInputMode or "Mouse"
    local tool = self:GetEquippedTool()
    if inputMode == "Tool" and not tool then
        self:SetStatus("Equip a Tool to use Tool mode")
        return
    end

    local now = os.clock()
    local shotsPerSecond = math.clamp(settings.AutoShootRate or 3, 1, 8)
    if now - self.LastShot < 1 / shotsPerSecond then
        self:SetStatus(inputMode == "Mouse" and
            "Auto shooting: left click" or "Auto shooting: Tool")
        return
    end

    -- Revalidate the exact live DhabWild target, never HandCatch/car/player.
    if not target:IsDescendantOf(workspace)
        or not self.Tracker:IsDhab(target) then
        self:SetStatus("Dhab target unavailable")
        return
    end

    self.LastShot = now
    local success, err
    if inputMode == "Mouse" then
        success, err = self:FireMouse()
    elseif inputMode == "Tool" then
        success, err = self:FireTool(tool)
    else
        success, err = false, "Unknown input mode " .. tostring(inputMode)
    end

    if not success then
        self:SetStatus(err or "Input method unavailable")
        return
    end
    self:SetStatus(inputMode == "Mouse" and
        "Auto shooting: left click" or ("Auto shooting: Tool " .. tool.Name))
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
    self:ReleaseMouse()
    self:SetStatus("Stopped")
end

return AutoShootController