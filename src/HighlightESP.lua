-- Depth-independent Roblox Highlight; each player owns its own instance.
local HighlightESP = {}
HighlightESP.__index = HighlightESP

function HighlightESP.new()
    return setmetatable({Character = nil, Instance = nil}, HighlightESP)
end

function HighlightESP:Bind(character)
    if self.Character == character and self.Instance then return end
    self:Destroy()

    local highlight = Instance.new("Highlight")
    highlight.Name = "IvoryESPHighlight"
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0.8
    highlight.OutlineTransparency = 0
    highlight.Parent = character

    self.Character = character
    self.Instance = highlight
end

function HighlightESP:Update(character, color, enabled)
    self:Bind(character)
    self.Instance.FillColor = color
    self.Instance.OutlineColor = color
    self.Instance.Enabled = enabled
end

function HighlightESP:Hide()
    if self.Instance then self.Instance.Enabled = false end
end

function HighlightESP:Destroy()
    if self.Instance then self.Instance:Destroy() end
    self.Instance = nil
    self.Character = nil
end

return HighlightESP