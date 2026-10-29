-- Vertical player health indicator.
local HealthESP = {}
HealthESP.__index = HealthESP

function HealthESP.new(parent)
    local background = Instance.new("Frame")
    background.Name = "HealthBar"
    background.Size = UDim2.new(0, 4, 1, 0)
    background.Position = UDim2.fromOffset(-9, 0)
    background.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    background.BorderSizePixel = 0
    background.Parent = parent

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.AnchorPoint = Vector2.new(0, 1)
    fill.Position = UDim2.new(0, 0, 1, 0)
    fill.Size = UDim2.fromScale(1, 1)
    fill.BorderSizePixel = 0
    fill.Parent = background

    return setmetatable({Background = background, Fill = fill}, HealthESP)
end

function HealthESP:Update(humanoid, enabled)
    self.Background.Visible = enabled
    if not enabled then return end

    local fraction = math.clamp(
        humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1
    )
    self.Fill.Size = UDim2.fromScale(1, fraction)
    self.Fill.BackgroundColor3 = Color3.fromRGB(
        math.floor(255 * (1 - fraction)), math.floor(255 * fraction), 50
    )
end

return HealthESP