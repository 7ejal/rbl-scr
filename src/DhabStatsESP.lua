-- Displays replicated Dhab Tier, Length and Size (Scale) without inventing rarity.
-- The game's Tier is not assumed to equal numerical Quality or Rarity.
local DhabStatsESP = {}
DhabStatsESP.__index = DhabStatsESP

local function formatNumber(value)
    if type(value) ~= "number" or value ~= value then return nil end
    return string.format("%.2f", value)
end

local TIER_COLORS={
    T1=Color3.fromRGB(196,196,202),
    T2=Color3.fromRGB(83,179,255),
    T3=Color3.fromRGB(191,114,255),
    T4=Color3.fromRGB(250,188,62),
    T5=Color3.fromRGB(245,90,128),
    T6=Color3.fromRGB(255,225,114),
}
function DhabStatsESP.new(box, model, settings)
    local statsLabel = Instance.new("TextLabel")
    statsLabel.Name = "DhabTierStats"
    statsLabel.AnchorPoint = Vector2.new(0.5, 0)
    statsLabel.Position = UDim2.new(0.5, 0, 0, -67)
    statsLabel.Size = UDim2.fromOffset(340, 22)
    statsLabel.TextXAlignment = Enum.TextXAlignment.Center
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
        Settings = settings,
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

    -- The replicated Scale attribute is the creature's size multiplier,
    -- not a physical dimension. Length above is in studs.
    local sizeMultiplier = formatNumber(model:GetAttribute("Scale"))
    if sizeMultiplier then
        table.insert(pieces, "Size " .. sizeMultiplier .. "x")
    end

    local longest=self.Settings and self.Settings.HighlightLongestDhab
        and self.Settings.LongestDhabModel==model
    self.Label.Text = (longest and "LONGEST | " or "")
        .. table.concat(pieces, " | ")
    local color=self.Settings and self.Settings.DhabTierColorsEnabled
        and TIER_COLORS[tier] or nil
    self.Label.TextColor3=longest and Color3.fromRGB(255,227,90)
        or color or Color3.fromRGB(220,245,255)
    self.Label.Visible = #pieces > 0
end

return DhabStatsESP