-- Player display name, anchored above the projected box.
local NameESP = {}
NameESP.__index = NameESP

function NameESP.new(parent)
    local label = Instance.new("TextLabel")
    label.Name = "PlayerName"
    label.Size = UDim2.new(1, 0, 0, 18)
    label.Position = UDim2.new(0, 0, 0, -21)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.25
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.Parent = parent
    return setmetatable({Label = label}, NameESP)
end

function NameESP:Update(player, enabled)
    self.Label.Visible = enabled
    if enabled then self.Label.Text = player.DisplayName end
end

return NameESP