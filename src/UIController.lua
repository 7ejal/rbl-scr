-- Screenshot-inspired English dashboard: dark shell, sidebar and toggle rows.
-- All controls are functional. No icon glyphs or emojis are used.
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local UIController = {}
UIController.__index = UIController

local COLOR = {
    Shell = Color3.fromRGB(11, 11, 15),
    Sidebar = Color3.fromRGB(18, 18, 23),
    Row = Color3.fromRGB(31, 31, 38),
    Muted = Color3.fromRGB(169, 169, 180),
    Accent = Color3.fromRGB(241, 241, 244),
    Text = Color3.fromRGB(246, 246, 249),
    On = Color3.fromRGB(55, 55, 63),
    Off = Color3.fromRGB(25, 25, 30),
}

local function create(kind, parent, props)
    local instance = Instance.new(kind)
    for key, value in pairs(props or {}) do
        instance[key] = value
    end
    instance.Parent = parent
    return instance
end

local function corner(instance, radius)
    create("UICorner", instance, {CornerRadius = UDim.new(0, radius)})
end

local function label(parent, value, x, y, width, height, fontSize)
    return create("TextLabel", parent, {
        Name = "Label",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(width, height),
        Text = value,
        TextColor3 = COLOR.Text,
        TextSize = fontSize or 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
end

local function button(parent, text, x, y, width, height, bg)
    local result = create("TextButton", parent, {
        Name = text,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(width, height),
        BackgroundColor3 = bg or COLOR.Row,
        Text = text,
        TextSize = 13,
        TextColor3 = COLOR.Text,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = true,
        BorderSizePixel = 0,
    })
    corner(result, 8)
    return result
end

function UIController.new(playerGui, settings, fov, janitorClass)
    local self = setmetatable({
        Settings = settings,
        FOV = fov,
        Janitor = janitorClass.new(),
        ToggleButtons = {},
        Pages = {},
        Tabs = {},
        OnToggle = nil,
        OnSettingChanged = nil,
        OnRescan = nil,
        MonsterCount = 0,
        ActivePage = "ESP",
        DraggingFOV = false,
        DraggingWindow = false,
    }, UIController)

    self.Gui = create("ScreenGui", playerGui, {
        Name = "IvoryESP",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    self.Janitor:Add(self.Gui)

    local window = create("Frame", self.Gui, {
        Name = "Dashboard",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(680, 500),
        BackgroundColor3 = COLOR.Shell,
        BorderSizePixel = 0,
    })
    corner(window, 21)
    create("UIStroke", window, {
        Color = Color3.fromRGB(105, 105, 112),
        Thickness = 1,
        Transparency = 0.4,
    })
    self.Window = window

    local scale = create("UIScale", window, {Scale = 1})
    local function fitScreen()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        scale.Scale = math.min(1,
            (viewport.X - 24) / 680,
            (viewport.Y - 24) / 500
        )
    end
    fitScreen()
    self.Janitor:Add(RunService.RenderStepped:Connect(fitScreen))

    -- Header
    local header = create("Frame", window, {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 63),
        BackgroundTransparency = 1,
        Active = true,
    })
    local logo = label(header, "D3F", 21, 13, 92, 36, 18)
    logo.Font = Enum.Font.GothamBold
    local subheading = label(header, "ESP CONTROL", 93, 18, 180, 26, 12)
    subheading.TextColor3 = COLOR.Muted

    local fpsBG = create("Frame", header, {
        Position = UDim2.fromOffset(446, 13),
        Size = UDim2.fromOffset(92, 36),
        BackgroundColor3 = COLOR.Sidebar,
        BorderSizePixel = 0,
    })
    corner(fpsBG, 6)
    self.FPSLabel = label(fpsBG, "FPS: --", 10, 0, 78, 36, 12)

    local pingBG = create("Frame", header, {
        Position = UDim2.fromOffset(546, 13),
        Size = UDim2.fromOffset(116, 36),
        BackgroundColor3 = COLOR.Sidebar,
        BorderSizePixel = 0,
    })
    corner(pingBG, 6)
    self.PingLabel = label(pingBG, "Ping: -- ms", 10, 0, 102, 36, 12)

    -- Sidebar
    local sidebar = create("Frame", window, {
        Name = "Sidebar",
        Position = UDim2.fromOffset(12, 68),
        Size = UDim2.fromOffset(181, 420),
        BackgroundColor3 = COLOR.Sidebar,
        BorderSizePixel = 0,
    })
    corner(sidebar, 12)

    local mainArea = create("Frame", window, {
        Name = "Content",
        Position = UDim2.fromOffset(207, 68),
        Size = UDim2.fromOffset(461, 420),
        BackgroundTransparency = 1,
    })

    local tabs = {"Home", "ESP", "Monsters", "Settings"}
    for index, name in ipairs(tabs) do
        local tab = button(sidebar, name, 10, 10 + (index - 1) * 53, 161, 44, COLOR.Sidebar)
        self.Tabs[name] = tab
        self.Janitor:Add(tab.MouseButton1Click:Connect(function()
            self:ShowPage(name)
        end))
        local page = create("Frame", mainArea, {
            Name = name .. "Page",
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Visible = false,
        })
        self.Pages[name] = page
    end

    -- Home page
    local home = self.Pages.Home
    local welcome = create("Frame", home, {
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromOffset(461, 175),
        BackgroundColor3 = COLOR.Row,
        BorderSizePixel = 0,
    })
    corner(welcome, 11)
    local heading = label(welcome, "IVORY ESP", 20, 16, 400, 39, 21)
    heading.Font = Enum.Font.GothamBold
    label(welcome, "Player and monster visual overlays", 20, 60, 414, 24, 14)
    local description = label(welcome,
        "I: toggle ESP. P: inspect aimed monster. O: list nearby monster models.",
        20, 95, 415, 62, 13)
    description.TextWrapped = true
    description.TextTruncate = Enum.TextTruncate.None
    description.TextYAlignment = Enum.TextYAlignment.Top

    local status = create("Frame", home, {
        Position = UDim2.fromOffset(0, 189),
        Size = UDim2.fromOffset(461, 79),
        BackgroundColor3 = COLOR.Sidebar,
        BorderSizePixel = 0,
    })
    corner(status, 10)
    self.HomeStatus = label(status, "Detected monsters: 0", 18, 10, 430, 55, 15)

    local refreshButton = button(home, "Rescan monsters", 0, 281, 210, 43, COLOR.Row)
    self.Janitor:Add(refreshButton.MouseButton1Click:Connect(function()
        if self.OnRescan then self.OnRescan() end
    end))
    local modelScanButton = button(home, "Find monster models", 224, 281, 223, 43, COLOR.Row)
    self.Janitor:Add(modelScanButton.MouseButton1Click:Connect(function()
        if self.OnInspectNearby then self.OnInspectNearby() end
    end))

    -- ESP page: feature flags and detection range.
    local esp = self.Pages.ESP
    self:ToggleRow(esp, "All ESP overlays (I)", "Enabled", 0)
    self:ToggleRow(esp, "Player ESP", "PlayersEnabled", 50)
    self:ToggleRow(esp, "Player boxes", "ShowBoxes", 100)
    self:ToggleRow(esp, "Player names", "ShowNames", 150)
    self:ToggleRow(esp, "Player health bars", "ShowHealth", 200)
    self:ToggleRow(esp, "Player wall highlights", "ShowHighlights", 250)

    local rangePanel = create("Frame", esp, {
        Position = UDim2.fromOffset(0, 310),
        Size = UDim2.fromOffset(461, 104),
        BackgroundColor3 = COLOR.Sidebar,
        BorderSizePixel = 0,
    })
    corner(rangePanel, 10)
    self.RangeLabel = label(rangePanel, "", 16, 7, 425, 28, 14)
    self.RangeLabel.Font = Enum.Font.GothamBold

    local rangeMinus = button(rangePanel, "- 100", 16, 43, 82, 37, COLOR.Row)
    local rangePlus = button(rangePanel, "+ 100", 106, 43, 82, 37, COLOR.Row)
    local function adjustRange(delta)
        local nextValue = math.clamp(self.Settings.MaxDistance + delta, 100, 5000)
        self:ChangeSetting("MaxDistance", nextValue)
    end
    self.Janitor:Add(rangeMinus.MouseButton1Click:Connect(function()
        adjustRange(-100)
    end))
    self.Janitor:Add(rangePlus.MouseButton1Click:Connect(function()
        adjustRange(100)
    end))

    -- Monster tab: each toggle updates a real monster-rendering feature.
    local monsters = self.Pages.Monsters
    self:ToggleRow(monsters, "Monster ESP", "MonsterEnabled", 0)
    self:ToggleRow(monsters, "Monster boxes", "MonsterBoxes", 50)
    self:ToggleRow(monsters, "Monster names", "MonsterNames", 100)
    self:ToggleRow(monsters, "Monster distance", "MonsterDistance", 150)
    self:ToggleRow(monsters, "Monster health bars", "MonsterHealth", 200)
    self:ToggleRow(monsters, "Monster wall highlights", "MonsterHighlights", 250)

    local monsterPanel = create("Frame", monsters, {
        Position = UDim2.fromOffset(0, 310),
        Size = UDim2.fromOffset(461, 104),
        BackgroundColor3 = COLOR.Sidebar,
        BorderSizePixel = 0,
    })
    corner(monsterPanel, 10)
    self.MonsterCountLabel = label(monsterPanel, "Detected monsters: 0", 16, 6, 420, 31, 14)
    self.MonsterCountLabel.Font = Enum.Font.GothamBold
    local inspectTip = label(monsterPanel, "P: inspect target   O: list nearby models", 16, 42, 433, 25, 12)
    inspectTip.TextColor3 = COLOR.Muted
    local monsterScan = button(monsterPanel, "Find models", 209, 70, 132, 28, COLOR.Row)
    self.Janitor:Add(monsterScan.MouseButton1Click:Connect(function()
        if self.OnInspectNearby then self.OnInspectNearby() end
    end))
    local monsterRescan = button(monsterPanel, "Rescan", 350, 70, 95, 28, COLOR.Row)
    self.Janitor:Add(monsterRescan.MouseButton1Click:Connect(function()
        if self.OnRescan then self.OnRescan() end
    end))

    -- Settings tab: functional FOV slider and additional player preferences.
    local settingsPage = self.Pages.Settings
    local fovPanel = create("Frame", settingsPage, {
        Name = "CameraFOV",
        Size = UDim2.fromOffset(461, 120),
        BackgroundColor3 = COLOR.Row,
        BorderSizePixel = 0,
    })
    corner(fovPanel, 10)
    self.FOVLabel = label(fovPanel, "Camera FOV", 18, 9, 410, 32, 15)
    self.FOVLabel.Font = Enum.Font.GothamBold

    self.Slider = create("Frame", fovPanel, {
        Position = UDim2.fromOffset(19, 73),
        Size = UDim2.fromOffset(421, 9),
        BackgroundColor3 = Color3.fromRGB(70, 70, 78),
        BorderSizePixel = 0,
        Active = true,
    })
    corner(self.Slider, 7)
    self.Fill = create("Frame", self.Slider, {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = Color3.fromRGB(220, 220, 225),
        BorderSizePixel = 0,
    })
    corner(self.Fill, 7)
    self.Knob = create("Frame", self.Slider, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(19, 19),
        BackgroundColor3 = COLOR.Text,
        BorderSizePixel = 0,
        Active = true,
        ZIndex = 3,
    })
    corner(self.Knob, 11)
    self:ToggleRow(settingsPage, "Team colors", "TeamColors", 137)
    self:ToggleRow(settingsPage, "Player distance labels", "ShowDistance", 187)
    label(settingsPage, "Overlay toggle: I", 12, 249, 430, 25, 14)
    label(settingsPage, "Inspect target: P   Nearby model list: O", 12, 281, 430, 25, 14)
    local resetFOV = button(settingsPage, "Reset camera FOV", 0, 334, 220, 44, COLOR.Row)
    self.Janitor:Add(resetFOV.MouseButton1Click:Connect(function()
        self.FOV:SetFOV(self.FOV.Original)
        self:DrawFOV()
    end))

    local function startFOV(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            self.DraggingFOV = true
            self.FOVTouch = input.UserInputType == Enum.UserInputType.Touch and input or nil
            self:UpdateFOVFromX(input.Position.X)
        end
    end
    self.Janitor:Add(self.Slider.InputBegan:Connect(startFOV))
    self.Janitor:Add(self.Knob.InputBegan:Connect(startFOV))

    -- Drag the dashboard by the header.
    local startPosition, startPoint, windowTouch
    self.Janitor:Add(header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            self.DraggingWindow = true
            windowTouch = input.UserInputType == Enum.UserInputType.Touch and input or nil
            startPoint = input.Position
            startPosition = window.Position
        end
    end))

    self.Janitor:Add(UIS.InputChanged:Connect(function(input)
        if self.DraggingFOV and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or (self.FOVTouch and input == self.FOVTouch)
        ) then
            self:UpdateFOVFromX(input.Position.X)
        end

        if self.DraggingWindow and startPosition and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or (windowTouch and input == windowTouch)
        ) then
            local delta = (input.Position - startPoint) / math.max(scale.Scale, 0.01)
            window.Position = UDim2.new(
                startPosition.X.Scale, startPosition.X.Offset + delta.X,
                startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
            )
        end
    end))
    self.Janitor:Add(UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or (self.FOVTouch and input == self.FOVTouch) then
            self.DraggingFOV = false
            self.FOVTouch = nil
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or (windowTouch and input == windowTouch) then
            self.DraggingWindow = false
            windowTouch = nil
        end
    end))

    local frames, elapsed = 0, 0
    self.Janitor:Add(RunService.RenderStepped:Connect(function(dt)
        frames = frames + 1
        elapsed = elapsed + dt
        if elapsed < 1 then return end

        local fps = math.floor(frames / math.max(elapsed, 0.001) + 0.5)
        self.FPSLabel.Text = "FPS: " .. tostring(fps)

        local ok, ping = pcall(function()
            return Players.LocalPlayer:GetNetworkPing() * 1000
        end)
        self.PingLabel.Text = ok and
            ("Ping: " .. tostring(math.floor(ping + 0.5)) .. " ms") or
            "Ping: -- ms"

        elapsed = 0
        frames = 0
    end))

    self:DrawFOV()
    self:Refresh()
    self:ShowPage("ESP")
    return self
end

function UIController:ToggleRow(parent, text, key, y)
    local row = create("Frame", parent, {
        Name = key .. "Row",
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.fromOffset(461, 44),
        BackgroundColor3 = COLOR.Row,
        BorderSizePixel = 0,
    })
    corner(row, 8)

    local stripe = create("Frame", row, {
        Position = UDim2.fromOffset(5, 9),
        Size = UDim2.fromOffset(5, 26),
        BackgroundColor3 = COLOR.Accent,
        BorderSizePixel = 0,
    })
    corner(stripe, 5)

    label(row, text, 19, 1, 350, 42, 13)
    local toggle = button(row, "OFF", 389, 5, 62, 34, COLOR.Off)
    self.ToggleButtons[key] = toggle
    self.Janitor:Add(toggle.MouseButton1Click:Connect(function()
        self:ChangeSetting(key, not self.Settings[key])
    end))
end

function UIController:ChangeSetting(key, value)
    if self.OnSettingChanged then
        self.OnSettingChanged(key, value)
    else
        self.Settings[key] = value
    end
    self:Refresh()
end

function UIController:ShowPage(name)
    self.ActivePage = name
    for pageName, page in pairs(self.Pages) do
        page.Visible = pageName == name
    end
    for tabName, tab in pairs(self.Tabs) do
        local selected = tabName == name
        tab.BackgroundColor3 = selected and COLOR.Accent or COLOR.Sidebar
        tab.TextColor3 = selected and COLOR.Shell or COLOR.Muted
    end
end

function UIController:Refresh()
    for key, toggle in pairs(self.ToggleButtons) do
        local enabled = self.Settings[key] == true
        toggle.Text = enabled and "ON" or "OFF"
        toggle.BackgroundColor3 = enabled and COLOR.On or COLOR.Off
        toggle.TextColor3 = enabled and COLOR.Text or COLOR.Muted
    end
    self.RangeLabel.Text = "ESP detection distance: "
        .. tostring(self.Settings.MaxDistance) .. " studs"
end

function UIController:SetESPEnabled(enabled)
    self.Settings.Enabled = enabled
    self:Refresh()
end

function UIController:SetMonsterCount(count)
    self.MonsterCount = count
    local message = "Detected monsters: " .. tostring(count)
    self.MonsterCountLabel.Text = message
    self.HomeStatus.Text = message
end

function UIController:UpdateFOVFromX(x)
    local width = self.Slider.AbsoluteSize.X
    if width <= 0 then return end
    local fraction = math.clamp(
        (x - self.Slider.AbsolutePosition.X) / width, 0, 1
    )
    self.FOV:SetFOV(
        self.Settings.MinFOV + fraction *
            (self.Settings.MaxFOV - self.Settings.MinFOV)
    )
    self:DrawFOV()
end

function UIController:DrawFOV()
    local value = self.FOV:GetFOV()
    local fraction = (value - self.Settings.MinFOV) /
        (self.Settings.MaxFOV - self.Settings.MinFOV)
    self.Fill.Size = UDim2.fromScale(fraction, 1)
    self.Knob.Position = UDim2.fromScale(fraction, 0.5)
    self.FOVLabel.Text = "Camera FOV: " .. tostring(value)
end

function UIController:Destroy()
    self.Janitor:Cleanup()
end

return UIController