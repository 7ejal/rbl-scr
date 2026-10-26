-- An independently toggled overlay for thrown HandCatch objects.
-- Does not participate in target acquisition or camera aim.
local HandCatchESP = {}
HandCatchESP.__index = HandCatchESP

function HandCatchESP.new(model, parent, classes, settings)
    local box = classes.BoxESP.new(parent)
    return setmetatable({
        Model = model,
        Settings = settings,
        Box = box,
        Name = classes.NameESP.new(box.Frame),
        Distance = classes.DistanceESP.new(box.Frame),
        Highlight = classes.HighlightESP.new(),
        Quality = classes.QualityESP.new(box, model, classes.QualityResolver),
        Projection = classes.Projection,
    }, HandCatchESP)
end

function HandCatchESP:Hide()
    self.Box:Hide()
    self.Highlight:Hide()
end

function HandCatchESP:Update(camera, localRoot)
    local target = self.Model
    if not target:IsDescendantOf(workspace) then self:Hide() return end

    local root
    if target:IsA("BasePart") then
        root = target
    else
        root = target.PrimaryPart
            or target:FindFirstChild("HumanoidRootPart", true)
            or target:FindFirstChildWhichIsA("BasePart", true)
    end
    if not root then self:Hide() return end

    local origin = localRoot and localRoot.Position or camera.CFrame.Position
    local distance = (origin - root.Position).Magnitude
    if distance > self.Settings.MaxDistance then self:Hide() return end

    local color = Color3.fromRGB(74, 202, 255)
    if self.Settings.HandCatchHighlights then
        self.Highlight:Update(target, color, true)
    else
        self.Highlight:Hide()
    end

    local x, y, width, height = self.Projection.GetRect(camera, target)
    if not x then self.Box:Hide() return end

    self.Box:Update(x, y, width, height, color, self.Settings.HandCatchBoxes)
    self.Name:Update({
        DisplayName = "HandCatch: " .. tostring(
            target:GetAttribute("DisplayName") or target.Name
        ),
    }, self.Settings.HandCatchNames)
    self.Distance:Update(distance, self.Settings.HandCatchDistance)
    self.Quality:Update(self.Settings.HandCatchQuality)
end

function HandCatchESP:Destroy()
    self.Highlight:Destroy()
    self.Box:Destroy()
end

return HandCatchESP