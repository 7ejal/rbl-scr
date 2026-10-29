-- A quality label displayed above a live Dhab or thrown HandCatch model.
local QualityESP = {}
QualityESP.__index = QualityESP

function QualityESP.new(box, model, resolverClass)
    local label = Instance.new("TextLabel")
    label.Name = "CreatureQuality"
    label.Position = UDim2.new(0, -30, 0, -43)
    label.Size = UDim2.new(1, 60, 0, 19)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 231, 143)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextStrokeTransparency = 0.25
    label.Visible = false
    label.Parent = box.Frame
    return setmetatable({
        Label = label,
        Resolver = resolverClass.new(model),
    }, QualityESP)
end

function QualityESP:Update(enabled)
    self.Label.Visible = enabled
    if enabled then
        self.Label.Text = self.Resolver:Get().Text
    end
end

return QualityESP