-- One NPC/monster visual record. Each rendering concern stays in its own class.
local MonsterESP = {}
MonsterESP.__index = MonsterESP

function MonsterESP.new(model, parent, classes, settings)
    local box = classes.BoxESP.new(parent)
    return setmetatable({
        Model = model,
        Settings = settings,
        Box = box,
        Name = classes.NameESP.new(box.Frame),
        Distance = classes.DistanceESP.new(box.Frame),
        Health = classes.HealthESP.new(box.Frame),
        Highlight = classes.HighlightESP.new(),
        Projection = classes.Projection,
    }, MonsterESP)
end

function MonsterESP:Hide()
    self.Box:Hide()
    self.Highlight:Hide()
end

function MonsterESP:Update(camera, localRoot)
    local model = self.Model
    if not model:IsDescendantOf(workspace) then
        self:Hide()
        return
    end

    local root = model.PrimaryPart
        or model:FindFirstChild("HumanoidRootPart", true)
        or model:FindFirstChildWhichIsA("BasePart", true)
    if not root then
        self:Hide()
        return
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then
        self:Hide()
        return
    end

    local origin = localRoot and localRoot.Position or camera.CFrame.Position
    local distance = (origin - root.Position).Magnitude
    if distance > self.Settings.MaxDistance then
        self:Hide()
        return
    end

    local color = Color3.fromRGB(255, 164, 65)
    if self.Settings.MonsterHighlights then
        self.Highlight:Update(model, color, true)
    else
        self.Highlight:Hide()
    end

    local x, y, width, height = self.Projection.GetRect(camera, model)
    if not x then
        self.Box:Hide()
        return
    end

    self.Box:Update(x, y, width, height, color, self.Settings.MonsterBoxes)

    local name = model:GetAttribute("DisplayName") or model.Name
    self.Name:Update({DisplayName = tostring(name)}, self.Settings.MonsterNames)
    self.Distance:Update(distance, self.Settings.MonsterDistance)

    if humanoid then
        self.Health:Update(humanoid, self.Settings.MonsterHealth)
    else
        local health = model:GetAttribute("Health")
        local maxHealth = model:GetAttribute("MaxHealth")
        if type(health) == "number" and type(maxHealth) == "number" then
            self.Health:Update(
                {Health = health, MaxHealth = maxHealth},
                self.Settings.MonsterHealth
            )
        else
            self.Health.Background.Visible = false
        end
    end
end

function MonsterESP:Destroy()
    self.Highlight:Destroy()
    self.Box:Destroy()
end

return MonsterESP