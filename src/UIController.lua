-- On-screen toggle and mouse/touch FOV slider.
local UIS = game:GetService("UserInputService")
local Janitor = nil -- injected through constructor
local UIController = {}
UIController.__index = UIController

local function rounded(parent, px)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, px)
    corner.Parent = parent
end

function UIController.new(playerGui, settings, fov, janitorClass)
    Janitor = janitorClass
    local self = setmetatable({
        Settings = settings,
        FOV = fov,
        Janitor = Janitor.new(),
        Dragging = false,
        TouchInput = nil,
        OnToggle = nil,
    }, UIController)

    local gui = Instance.new("ScreenGui")
    gui.Name = "IvoryESP"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999
    gui.Parent = playerGui
    self.Janitor:Add(gui)
    self.Gui = gui

    local toggle = Instance.new("TextButton")
    toggle.Name = "Toggle"
    toggle.Size = UDim2.fromOffset(210, 38)
    toggle.Position = UDim2.fromOffset(20, 120)
    toggle.BorderSizePixel = 0
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 14
    toggle.TextColor3 = Color3.new(1, 1, 1)
    toggle.Parent = gui
    rounded(toggle, 8)
    self.Toggle = toggle

    local panel = Instance.new("Frame")
    panel.Name = "FOVPanel"
    panel.Position = UDim2.fromOffset(20, 166)
    panel.Size = UDim2.fromOffset(210, 82)
    panel.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    panel.BorderSizePixel = 0
    panel.Parent = gui
    rounded(panel, 8)

    local title = Instance.new("TextLabel")
    title.Name = "Value"
    title.Position = UDim2.fromOffset(10, 5)
    title.Size = UDim2.new(1, -20, 0, 30)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = panel
    self.FOVLabel = title

    local slider = Instance.new("Frame")
    slider.Name = "FOVSlider"
    slider.Position = UDim2.fromOffset(12, 49)
    slider.Size = UDim2.new(1, -24, 0, 8)
    slider.BackgroundColor3 = Color3.fromRGB(65, 65, 75)
    slider.BorderSizePixel = 0
    slider.Active = true
    slider.Parent = panel
    rounded(slider, 8)
    self.Slider = slider

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = Color3.fromRGB(70, 180, 255)
    fill.BorderSizePixel = 0
    fill.Parent = slider
    rounded(fill, 8)
    self.Fill = fill

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Size = UDim2.fromOffset(18, 18)
    knob.Position = UDim2.fromScale(0, 0.5)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Active = true
    knob.ZIndex = 3
    knob.Parent = slider
    rounded(knob, 9)
    self.Knob = knob

    self.Janitor:Add(toggle.MouseButton1Click:Connect(function()
        if self.OnToggle then self.OnToggle() end
    end))

    local function beginDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            self.Dragging = true
            self.TouchInput = input.UserInputType == Enum.UserInputType.Touch
                and input or nil
            self:UpdateFromX(input.Position.X)
        end
    end

    self.Janitor:Add(slider.InputBegan:Connect(beginDrag))
    self.Janitor:Add(knob.InputBegan:Connect(beginDrag))
    self.Janitor:Add(UIS.InputChanged:Connect(function(input)
        if not self.Dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or (self.TouchInput and input == self.TouchInput) then
            self:UpdateFromX(input.Position.X)
        end
    end))
    self.Janitor:Add(UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or (self.TouchInput and input == self.TouchInput) then
            self.Dragging = false
            self.TouchInput = nil
        end
    end))

    self:DrawFOV()
    self:SetESPEnabled(settings.Enabled)
    return self
end

function UIController:UpdateFromX(x)
    local width = self.Slider.AbsoluteSize.X
    if width <= 0 then return end
    local fraction = math.clamp(
        (x - self.Slider.AbsolutePosition.X) / width, 0, 1
    )
    local settings = self.Settings
    self.FOV:SetFOV(
        settings.MinFOV + fraction * (settings.MaxFOV - settings.MinFOV)
    )
    self:DrawFOV()
end

function UIController:DrawFOV()
    local settings = self.Settings
    local value = self.FOV:GetFOV()
    local fraction = (value - settings.MinFOV) /
        (settings.MaxFOV - settings.MinFOV)
    self.Fill.Size = UDim2.fromScale(fraction, 1)
    self.Knob.Position = UDim2.fromScale(fraction, 0.5)
    self.FOVLabel.Text = "Camera FOV: " .. tostring(value)
end

function UIController:SetESPEnabled(enabled)
    self.Toggle.Text = enabled and "IVORY ESP: ON [I]" or "IVORY ESP: OFF [I]"
    self.Toggle.BackgroundColor3 = enabled
        and Color3.fromRGB(25, 90, 45)
        or Color3.fromRGB(110, 35, 35)
end

function UIController:Destroy()
    self.Janitor:Cleanup()
end

return UIController