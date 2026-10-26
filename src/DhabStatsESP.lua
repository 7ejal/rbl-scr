-- Displays replicated Dhab Tier, Length and State without inventing rarity.
-- The game's Tier is not assumed to equal numerical Quality or Rarity.
local DhabStatsESP = {}
DhabStatsESP.__index = DhabStatsESP

local function formatNumber(value)
    if type(value) ~= "number" or value ~= value then return nil end
    return string.format("%.2f", value)
end

function DhabStatsESP.new(box, model)
    local statsLabel = Instance.new("TextLabel")
    statsLabel.Name = "DhabTierStats"
    statsLabel.Position = UDim2.new(0, -65, 0, -67)
    statsLabel.Size = UDim2.new(1, 130, 0, 22)
    statsLabel.BackgroundTransparency = 1
    statsLabel.Font = Enum.Font.GothamBold
    statsLabel.TextSize = 12
    statsLabel.TextStrokeTransparency = 0.25
    statsLabel.TextColor3 = Color3.fromRGB(220, 245, 255)
    statsLabel.TextTruncate = Enum.TextTruncate.AtEnd
    statsLabel.Visible = false
    statsLabel.Parent = box.Frame

    return setmetatable({
        Model = model,
        Label = statsLabel,
    }, DhabStatsESP)
end

function DhabStatsESP:Update(enabled)
    local model = self.Model
    if not enabled or not model or not model.Parent then
        self.Label.Visible = false
        return
    end

    local pieces = {}
    local tier = model:GetAttribute("Tier")
    if type(tier) == "string" and tier ~= "" then
        table.insert(pieces, "Tier " .. tier)
    end

    local length = formatNumber(model:GetAttribute("Length"))
    if length then
        table.insert(pieces, "Length " .. length .. " studs")
    end

    local state = model:GetAttribute("State")
    if type(state) == "string" and state ~= "" then
        table.insert(pieces, state)
    end

    self.Label.Text = table.concat(pieces, " | ")
    self.Label.Visible = #pieces > 0
end

return DhabStatsESP