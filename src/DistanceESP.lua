-- Stud distance text, anchored under the projected box.
local DistanceESP = {}
DistanceESP.__index = DistanceESP

function DistanceESP.new(parent)
    local label = Instance.new("TextLabel")
    label.Name = "PlayerDistance"
    label.Size = UDim2.new(1, 0, 0, 18)
    label.Position = UDim2.new(0, 0, 1, 3)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.25
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.Parent = parent
    return setmetatable({Label = label}, DistanceESP)
end

function DistanceESP:Update(distance, enabled)
    self.Label.Visible = enabled
    if enabled then
        self.Label.Text = tostring(math.floor(distance)) .. " studs"
    end
end

return DistanceESP