-- One complete car per entry: Workspace.PlayersCars.<car Model>.
-- Nested wheels, tires and body-part models are intentionally ignored.
local CarESP = {}
CarESP.__index = CarESP

function CarESP.new(model, parent, classes, settings)
    local box = classes.BoxESP.new(parent)
    return setmetatable({
        Model = model,
        Category = "car",
        Settings = settings,
        Box = box,
        Name = classes.NameESP.new(box.Frame),
        Distance = classes.DistanceESP.new(box.Frame),
        Highlight = classes.HighlightESP.new(),
        Projection = classes.Projection,
    }, CarESP)
end

function CarESP:Hide()
    self.Box:Hide()
    self.Highlight:Hide()
end

function CarESP:Update(camera, localRoot)
    local model = self.Model
    if not model:IsA("Model") or not model:IsDescendantOf(workspace) then
        self:Hide()
        return
    end

    local root = model.PrimaryPart
        or model:FindFirstChild("VehicleSeat", true)
        or model:FindFirstChildWhichIsA("BasePart", true)
    if not root then self:Hide() return end

    local origin = localRoot and localRoot.Position or camera.CFrame.Position
    local distance = (origin - root.Position).Magnitude
    if distance > self.Settings.MaxDistance then self:Hide() return end

    local color = Color3.fromRGB(169, 133, 255)
    if self.Settings.CarHighlights then
        self.Highlight:Update(model, color, true)
    else
        self.Highlight:Hide()
    end

    local x, y, width, height = self.Projection.GetRect(camera, model)
    if not x then self.Box:Hide() return end
    self.Box:Update(x, y, width, height, color, self.Settings.CarBoxes)

    self.Name:Update({
        DisplayName = "Car: " .. tostring(model:GetAttribute("DisplayName") or model.Name)
    }, self.Settings.CarNames)
    self.Distance:Update(distance, self.Settings.CarDistance)
end

function CarESP:Destroy()
    self.Highlight:Destroy()
    self.Box:Destroy()
end

return CarESP