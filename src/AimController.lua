-- Live-Dhab-only camera aim. Auto Shoot is a separate class.
-- Runs after the standard camera update so Roblox does not overwrite rotation.
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")

local AimController = {}
AimController.__index = AimController
local RENDER_NAME = "IvoryMonsterAim"

local function focusPosition(target)
    if target:IsA("BasePart") then return target.Position end
    local head = target:FindFirstChild("Head", true)
    if head and head:IsA("BasePart") then return head.Position end
    local root = target.PrimaryPart
        or target:FindFirstChild("HumanoidRootPart", true)
        or target:FindFirstChildWhichIsA("BasePart", true)
    return root and root.Position or nil
end

function AimController.new(settings, tracker, playerGui)
    local self = setmetatable({
        Settings = settings,
        Tracker = tracker,
        Running = false,
        Circle = nil,
    }, AimController)

    local circle = Instance.new("Frame")
    circle.Name = "MonsterAimFOV"
    circle.AnchorPoint = Vector2.new(0.5, 0.5)
    circle.BackgroundTransparency = 1
    circle.BorderSizePixel = 0
    circle.ZIndex = 3
    circle.Parent = playerGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = circle

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.2
    stroke.Parent = circle
    self.Circle = circle

    return self
end

function AimController:Focus(model)
    local center = focusPosition(model)
    if not center or not self.Settings.AimPredictionEnabled then return center end
    local part = model.PrimaryPart
        or model:FindFirstChild("HumanoidRootPart", true)
        or model:FindFirstChildWhichIsA("BasePart", true)
    if not part then return center end
    local lead = math.clamp(self.Settings.AimLeadSeconds or 0.15, 0, 0.6)
    local velocity = part.AssemblyLinearVelocity
    if velocity.Magnitude > 120 then return center end
    return center + velocity * lead
end

function AimController:SetHuntTarget(model)
    self.HuntTarget = model
end

function AimController:BestTarget(camera)
    local settings = self.Settings
    local center = camera.ViewportSize / 2
    local character = Players.LocalPlayer.Character
    local ownRoot = character and character:FindFirstChild("HumanoidRootPart")
    local origin = ownRoot and ownRoot.Position or camera.CFrame.Position

    -- Hunt mode uses the selected live Dhab, even if it is initially
    -- outside the reticle. Aim starts after walking into AimDistance.
    -- Never select a second model while the hunter is following one.
    if settings.AutoHuntEnabled then
        local hunted = self.HuntTarget
        if hunted and hunted:IsDescendantOf(workspace)
            and self.Tracker:IsDhab(hunted)
            and self.Tracker.Known[hunted] == "monster" then
            local humanoid = hunted:FindFirstChildOfClass("Humanoid")
            local health = hunted:GetAttribute("Health")
            local state = hunted:GetAttribute("State")
            local active = (not humanoid or humanoid.Health > 0)
                and (type(health) ~= "number" or health > 0)
                and state ~= "dead" and state ~= "death"
            if active then
                local focus = self:Focus(hunted)
                if focus and (focus - origin).Magnitude <= settings.AimDistance then
                    return focus, hunted
                end
            end
        end
        return nil, nil
    end

    local bestTarget, bestModel = nil, nil
    local bestScore = math.huge

    for target, category in pairs(self.Tracker.Known) do
        -- Strict allowlist: live Dhab models only. HandCatch objects,
        -- vendor NPCs and other generic monsters must never be aim targets.
        if category == "monster" and self.Tracker:IsDhab(target)
            and target:IsDescendantOf(workspace) then
            local humanoid = target:FindFirstChildOfClass("Humanoid")
            local health = target:GetAttribute("Health")
            local alive = (not humanoid or humanoid.Health > 0)
                and (type(health) ~= "number" or health > 0)

            if alive then
                local position = self:Focus(target)
                if position then
                    local distance = (position - origin).Magnitude
                    if distance <= settings.AimDistance then
                        local projected, onScreen = camera:WorldToViewportPoint(position)
                        if onScreen and projected.Z > 0 then
                            local delta = Vector2.new(projected.X, projected.Y) - center
                            local pixels = delta.Magnitude
                            if pixels <= settings.AimRadius then
                                -- Prefer targets closest to the reticle; distance breaks ties.
                                local score = pixels + distance * 0.015
                                if score < bestScore then
                                    bestScore = score
                                    bestTarget = position
                                    bestModel = target
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return bestTarget, bestModel
end

function AimController:Update(dt)
    local settings = self.Settings
    local camera = workspace.CurrentCamera
    if not camera then
        self.Circle.Visible = false
        return
    end

    local radius = math.clamp(settings.AimRadius, 20, 400)
    self.Circle.Size = UDim2.fromOffset(radius * 2, radius * 2)
    self.Circle.Position = UDim2.fromOffset(
        camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2
    )
    self.Circle.Visible = (settings.AimEnabled or settings.AutoHuntEnabled)
        and settings.AimShowCircle

    if not settings.AimEnabled and not settings.AutoHuntEnabled then return end
    if not settings.AutoHuntEnabled
        and settings.AimHoldRightMouse
        and not UIS:IsMouseButtonPressed(
        Enum.UserInputType.MouseButton2) then
        return
    end
    if UIS:GetFocusedTextBox() then return end

    local targetPosition = self:BestTarget(camera)
    if not targetPosition then return end

    local difference = targetPosition - camera.CFrame.Position
    if difference.Magnitude < 0.05 then return end
    local desired = CFrame.lookAt(camera.CFrame.Position, targetPosition)
    local alpha = 1 - math.pow(1 - math.clamp(settings.AimSmoothness, 0.01, 1),
        math.clamp(dt, 0, 0.25) * 60)
    camera.CFrame = camera.CFrame:Lerp(desired, alpha)
end

function AimController:Start()
    if self.Running then return end
    self.Running = true
    RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1,
        function(dt)
            if self.Running then self:Update(dt) end
        end)
end

function AimController:Destroy()
    if self.Running then
        self.Running = false
        RunService:UnbindFromRenderStep(RENDER_NAME)
    end
    if self.Circle then self.Circle:Destroy() end
    self.Circle = nil
end

return AimController