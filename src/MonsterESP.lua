-- Monster and optional other-NPC overlay; supports Models and tagged BaseParts.
local MonsterESP = {}
MonsterESP.__index = MonsterESP

function MonsterESP.new(instance, parent, classes, settings, category, isDhab)
    local box = classes.BoxESP.new(parent)
    return setmetatable({
        Model = instance,
        Category = category,
        Settings = settings,
        Box = box,
        Name = classes.NameESP.new(box.Frame),
        Distance = classes.DistanceESP.new(box.Frame),
        Health = classes.HealthESP.new(box.Frame),
        Highlight = classes.HighlightESP.new(),
        Projection = classes.Projection,
        IsDhab = isDhab == true,
        Quality = classes.QualityESP.new(box, instance, classes.QualityResolver),
        DhabStats = classes.DhabStatsESP.new(box, instance, settings),
    }, MonsterESP)
end

function MonsterESP:Hide()
    self.Box:Hide()
    self.Highlight:Hide()
end

function MonsterESP:Update(camera, localRoot)
    local target = self.Model
    if not target:IsDescendantOf(workspace) then
        self:Hide()
        return
    end

    local root
    if target:IsA("BasePart") then
        root = target
    else
        root = target.PrimaryPart
            or target:FindFirstChild("HumanoidRootPart", true)
            or target:FindFirstChildWhichIsA("BasePart", true)
    end
    if not root then self:Hide() return end

    local humanoid = target:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then self:Hide() return end
    if not humanoid and type(target:GetAttribute("Health")) == "number"
        and target:GetAttribute("Health") <= 0 then
        self:Hide()
        return
    end

    local origin = localRoot and localRoot.Position or camera.CFrame.Position
    local distance = (origin - root.Position).Magnitude
    if distance > self.Settings.MaxDistance then self:Hide() return end

    local isMonster = self.Category == "monster"
    local color = isMonster and Color3.fromRGB(255, 164, 65)
        or Color3.fromRGB(80, 180, 255)
    if self.IsDhab and self.Settings.DhabTierColorsEnabled then
        local colors={
            T1=Color3.fromRGB(196,196,202),
            T2=Color3.fromRGB(83,179,255),
            T3=Color3.fromRGB(191,114,255),
            T4=Color3.fromRGB(250,188,62),
            T5=Color3.fromRGB(245,90,128),
            T6=Color3.fromRGB(255,225,114),
        }
        color=colors[target:GetAttribute("Tier")] or color
    end
    if self.IsDhab and self.Settings.HighlightLongestDhab
        and self.Settings.LongestDhabModel==target then
        color=Color3.fromRGB(255,227,90)
    end
    local showHighlight = isMonster and self.Settings.MonsterHighlights
        or (not isMonster and self.Settings.ShowHighlights)

    if showHighlight then
        self.Highlight:Update(target, color, true)
    else
        self.Highlight:Hide()
    end

    local x, y, width, height = self.Projection.GetRect(camera, target)
    if not x then
        self.Box:Hide()
        return
    end

    local showBoxes = isMonster and self.Settings.MonsterBoxes or
        (not isMonster and self.Settings.ShowBoxes)
    self.Box:Update(x, y, width, height, color, showBoxes)

    local value = target:GetAttribute("DisplayName") or target.Name
    local showNames = isMonster and self.Settings.MonsterNames or
        (not isMonster and self.Settings.ShowNames)
    local longest=self.IsDhab and self.Settings.HighlightLongestDhab
        and self.Settings.LongestDhabModel==target
    self.Name:Update({DisplayName = tostring(value)
        .. (longest and " [LONGEST]" or "")}, showNames)

    self.Distance:Update(distance,
        isMonster and self.Settings.MonsterDistance
            or (not isMonster and self.Settings.ShowDistance))
    self.Quality:Update(self.IsDhab and self.Settings.DhabQualityEnabled)
    self.DhabStats:Update(self.IsDhab and self.Settings.DhabStatsEnabled)

    local showHealth = isMonster and self.Settings.MonsterHealth
        or (not isMonster and self.Settings.ShowHealth)
    if humanoid then
        self.Health:Update(humanoid, showHealth)
    else
        local health = target:GetAttribute("Health")
        local maxHealth = target:GetAttribute("MaxHealth")
        if type(health) == "number" and type(maxHealth) == "number" then
            self.Health:Update({Health = health, MaxHealth = maxHealth}, showHealth)
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