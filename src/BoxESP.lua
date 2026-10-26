-- Frame and outline for one player.
local BoxESP = {}
BoxESP.__index = BoxESP

function BoxESP.new(parent)
    local frame = Instance.new("Frame")
    frame.Name = "PlayerBox"
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = parent

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.5
    stroke.Parent = frame

    return setmetatable({Frame = frame, Stroke = stroke}, BoxESP)
end

function BoxESP:Update(x, y, width, height, color, outlined)
    self.Frame.Position = UDim2.fromOffset(x, y)
    self.Frame.Size = UDim2.fromOffset(width, height)
    self.Stroke.Color = color
    self.Stroke.Enabled = outlined
    self.Frame.Visible = true
end

function BoxESP:Hide()
    self.Frame.Visible = false
end

function BoxESP:Destroy()
    self.Frame:Destroy()
end

return BoxESP