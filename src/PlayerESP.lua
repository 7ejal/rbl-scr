-- A single player's features; orchestration of individual classes.
local PlayerESP = {}
PlayerESP.__index = PlayerESP

function PlayerESP.new(player, parent, classes, settings, localPlayer)
    local box = classes.BoxESP.new(parent)
    return setmetatable({
        Player = player,
        Settings = settings,
        LocalPlayer = localPlayer,
        Box = box,
        Name = classes.NameESP.new(box.Frame),
        Distance = classes.DistanceESP.new(box.Frame),
        Health = classes.HealthESP.new(box.Frame),
        Highlight = classes.HighlightESP.new(),
        Projection = classes.Projection,
    }, PlayerESP)
end

function PlayerESP:Hide()
    self.Box:Hide()
    self.Highlight:Hide()
end

function PlayerESP:Update(camera, localRoot)
    local settings = self.Settings
    local player = self.Player
    local character = player.Character

    if not character then
        self:Hide()
        return
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then
        self:Hide()
        return
    end

    local origin = localRoot and localRoot.Position or camera.CFrame.Position
    local distance = (origin - root.Position).Magnitude
    if distance > settings.MaxDistance then
        self:Hide()
        return
    end

    local color = Color3.fromRGB(255, 65, 65)
    if settings.TeamColors and player.Team ~= nil
        and player.Team == self.LocalPlayer.Team then
        color = Color3.fromRGB(65, 255, 100)
    end

    if settings.ShowHighlights then
        self.Highlight:Update(character, color, true)
    else
        self.Highlight:Hide()
    end

    -- Keep highlights visible even when the character is off-screen.
    local x, y, width, height = self.Projection.GetRect(camera, character)
    if not x then
        self.Box:Hide()
        return
    end

    self.Box:Update(x, y, width, height, color, settings.ShowBoxes)
    self.Name:Update(player, settings.ShowNames)
    self.Distance:Update(distance, settings.ShowDistance)
    self.Health:Update(humanoid, settings.ShowHealth)
end

function PlayerESP:Destroy()
    self.Highlight:Destroy()
    self.Box:Destroy()
end

return PlayerESP