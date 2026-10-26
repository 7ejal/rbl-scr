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
        OnTargetsRefresh = nil,
        OnTrackMonster = nil,
        ShowScenery = false,
        MonsterCount = 0,
        HandCatchCount = 0,
        CarCount = 0,
        OnQualityScan = nil,
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

    local hideBtn = button(header, "HIDE [CTRL]", 319, 13, 119, 36, COLOR.Sidebar)
    self.Janitor:Add(hideBtn.MouseButton1Click:Connect(function()
        self:ToggleWindow()
    end))
    self.Janitor:Add(UIS.InputBegan:Connect(function(input, processed)
        if processed or UIS:GetFocusedTextBox() then return end
        if input.KeyCode == settings.MenuKey then
            self:ToggleWindow()
        end
    end))

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

    local tabs = {"Home", "ESP", "Auto Aim", "Auto Shoot", "Monsters",
        "HandCatch", "Cars", "Quality", "Targets", "Settings"}
    for index, name in ipairs(tabs) do
        local tab = button(sidebar, name, 10, 10 + (index - 1) * 40, 161, 35, COLOR.Sidebar)
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
    label(welcome, "Monster ESP and camera aim controls", 20, 60, 414, 24, 14)
    local description = label(welcome,
        "I: toggle ESP. P: inspect. O: scan models. M: mark target as monster.",
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
    self:ToggleRow(esp, "Other NPC ESP", "OtherNPCEnabled", 100)
    self:ToggleRow(esp, "Monster ESP", "MonsterEnabled", 150)
    self:ToggleRow(esp, "Player boxes", "ShowBoxes", 200)
    self:ToggleRow(esp, "Player names", "ShowNames", 250)

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
    local inspectTip = label(monsterPanel, "P: inspect   M: mark monster   O: list nearby", 16, 42, 433, 25, 12)
    inspectTip.TextColor3 = COLOR.Muted
    local monsterScan = button(monsterPanel, "Find models", 209, 70, 132, 28, COLOR.Row)
    self.Janitor:Add(monsterScan.MouseButton1Click:Connect(function()
        if self.OnInspectNearby then self.OnInspectNearby() end
    end))
    local monsterRescan = button(monsterPanel, "Rescan", 350, 70, 95, 28, COLOR.Row)
    self.Janitor:Add(monsterRescan.MouseButton1Click:Connect(function()
        if self.OnRescan then self.OnRescan() end
    end))

    -- HandCatch objects remain visible after they are thrown on terrain.
    -- They are classified separately and are never eligible for auto aim.
    local catches = self.Pages.HandCatch
    self:ToggleRow(catches, "Thrown HandCatch ESP", "HandCatchEnabled", 0)
    self:ToggleRow(catches, "HandCatch boxes", "HandCatchBoxes", 50)
    self:ToggleRow(catches, "HandCatch names", "HandCatchNames", 100)
    self:ToggleRow(catches, "HandCatch distance", "HandCatchDistance", 150)
    self:ToggleRow(catches, "HandCatch highlights", "HandCatchHighlights", 200)
    self:ToggleRow(catches, "HandCatch quality label", "HandCatchQuality", 250)
    self:ToggleRow(catches, "Live Dhab quality label", "DhabQualityEnabled", 300)
    local catchPanel = create("Frame", catches, {
        Position = UDim2.fromOffset(0, 356),
        Size = UDim2.fromOffset(461, 56),
        BackgroundColor3 = COLOR.Sidebar,
        BorderSizePixel = 0,
    })
    corner(catchPanel, 8)
    self.HandCatchCountLabel = label(catchPanel,
        "Thrown HandCatch detected: 0", 15, 3, 430, 48, 13)

    -- Cars: direct models in PlayersCars only, no duplicate wheel outlines.
    local cars = self.Pages.Cars
    self:ToggleRow(cars, "Car ESP", "CarsEnabled", 0)
    self:ToggleRow(cars, "Car boxes", "CarBoxes", 50)
    self:ToggleRow(cars, "Car names", "CarNames", 100)
    self:ToggleRow(cars, "Car distance", "CarDistance", 150)
    self:ToggleRow(cars, "Car wall highlights", "CarHighlights", 200)
    local carInfo = create("Frame", cars, {
        Position = UDim2.fromOffset(0, 267),
        Size = UDim2.fromOffset(461, 105),
        BackgroundColor3 = COLOR.Sidebar,
        BorderSizePixel = 0,
    })
    corner(carInfo, 8)
    self.CarCountLabel = label(carInfo,
        "Detected whole cars: 0", 15, 4, 430, 40, 14)
    local carHint = label(carInfo,
        "One outline per vehicle in Workspace.PlayersCars. Tires and wheels are excluded.",
        15, 43, 433, 50, 12)
    carHint.TextWrapped = true
    carHint.TextTruncate = Enum.TextTruncate.None
    carHint.TextColor3 = COLOR.Muted

    -- Per-Dhab quality diagnostic without requiring the F9 console.
    local quality = self.Pages.Quality
    self:ToggleRow(quality, "Show live Dhab quality", "DhabQualityEnabled", 0)
    self:ToggleRow(quality, "Show HandCatch quality", "HandCatchQuality", 50)
    self:ToggleRow(quality, "Show real Dhab Tier / Length / State", "DhabStatsEnabled", 100)
    local qualityScan = button(quality,
        "Inspect nearest Dhab quality", 0, 151, 260, 38, COLOR.Row)
    self.Janitor:Add(qualityScan.MouseButton1Click:Connect(function()
        if self.OnQualityScan then self.OnQualityScan() end
    end))
    local qualityHint = label(quality,
        "Scans this Dhab's metadata and exact-ID-linked client records. Copies the report where supported.",
        6, 190, 450, 39, 12)
    qualityHint.TextWrapped = true
    qualityHint.TextTruncate = Enum.TextTruncate.None
    qualityHint.TextColor3 = COLOR.Muted

    local reportScroll = create("ScrollingFrame", quality, {
        Name = "QualityDiagnostic",
        Position = UDim2.fromOffset(0, 239),
        Size = UDim2.fromOffset(461, 173),
        BackgroundColor3 = COLOR.Sidebar,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromOffset(0, 208),
    })
    corner(reportScroll, 8)
    self.QualityReport = create("TextLabel", reportScroll, {
        Name = "QualityReport",
        Position = UDim2.fromOffset(9, 8),
        Size = UDim2.new(1, -21, 0, 160),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = "Select Inspect nearest Dhab quality. Unknown means no replicated value was found.",
        TextColor3 = COLOR.Text,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    })
    self.QualityReportScroll = reportScroll

    -- Aim tab: the camera rotates toward a live Dhab only.
    local aim = self.Pages["Auto Aim"]
    self:ToggleRow(aim, "Live Dhab auto aim (camera only)", "AimEnabled", 0)
    self:ToggleRow(aim, "Require right mouse button", "AimHoldRightMouse", 50)
    self:ToggleRow(aim, "Show targeting FOV circle", "AimShowCircle", 100)
    local note = label(aim, "Live DhabWild creatures only. HandCatch is excluded.", 10, 150, 445, 26, 12)
    note.TextColor3 = COLOR.Muted

    local function counterPanel(y, heading, key, amount, low, high, unit, digits)
        local panel = create("Frame", aim, {
            Position = UDim2.fromOffset(0, y),
            Size = UDim2.fromOffset(461, 74),
            BackgroundColor3 = COLOR.Sidebar,
            BorderSizePixel = 0,
        })
        corner(panel, 8)
        local valueLabel = label(panel, heading, 15, 3, 435, 29, 14)
        local minus = button(panel, "-" .. tostring(amount) .. unit,
            16, 34, 94, 32, COLOR.Row)
        local plus = button(panel, "+" .. tostring(amount) .. unit,
            119, 34, 94, 32, COLOR.Row)
        self.AimLabels[key] = {Label = valueLabel, Title = heading, Unit = unit, Digits = digits}
        local function change(delta)
            local value = math.clamp(self.Settings[key] + delta, low, high)
            if digits then value = math.floor(value * 100 + 0.5) / 100 end
            self:ChangeSetting(key, value)
        end
        self.Janitor:Add(minus.MouseButton1Click:Connect(function() change(-amount) end))
        self.Janitor:Add(plus.MouseButton1Click:Connect(function() change(amount) end))
    end
    self.AimLabels = {}
    counterPanel(180, "Target FOV radius", "AimRadius", 20, 20, 400, " px")
    counterPanel(261, "Target distance", "AimDistance", 50, 50, 1500, " studs")
    counterPanel(342, "Aim smoothing", "AimSmoothness", 0.05, 0.05, 1, "", true)

    -- Auto Shoot: separate from camera aiming; an equipped Roblox Tool is required.
    -- It never fires at thrown HandCatch or non-Dhab targets.
    local shooter = self.Pages["Auto Shoot"]
    self:ToggleRow(shooter, "Auto Shoot (live Dhab only)", "AutoShootEnabled", 0)
    self:ToggleRow(shooter, "Require clear line of sight", "AutoShootLineOfSight", 50)
    self:ToggleRow(shooter, "Require right mouse button", "AimHoldRightMouse", 100)

    self.ShootModeButton = button(shooter,
        "Fire input: Left Click", 0, 156, 222, 39, COLOR.Row)
    self.Janitor:Add(self.ShootModeButton.MouseButton1Click:Connect(function()
        local mode = self.Settings.AutoShootInputMode == "Mouse" and "Tool" or "Mouse"
        self:ChangeSetting("AutoShootInputMode", mode)
    end))
    local shootInfo = label(shooter,
        "Left Click uses mouse1click. Tool uses Tool:Activate.",
        234, 154, 226, 48, 12)
    shootInfo.TextWrapped = true
    shootInfo.TextTruncate = Enum.TextTruncate.None
    shootInfo.TextYAlignment = Enum.TextYAlignment.Top
    shootInfo.TextColor3 = COLOR.Muted

    local shootPanel = create("Frame", shooter, {
        Position = UDim2.fromOffset(0, 212),
        Size = UDim2.fromOffset(461, 89),
        BackgroundColor3 = COLOR.Sidebar,
        BorderSizePixel = 0,
    })
    corner(shootPanel, 8)
    self.ShootRateLabel = label(shootPanel, "Firing rate", 15, 5, 435, 25, 14)
    local decrease = button(shootPanel, "- 1 shot/sec", 16, 39, 135, 36, COLOR.Row)
    local increase = button(shootPanel, "+ 1 shot/sec", 161, 39, 135, 36, COLOR.Row)
    self.Janitor:Add(decrease.MouseButton1Click:Connect(function()
        self:ChangeSetting("AutoShootRate",
            math.clamp(self.Settings.AutoShootRate - 1, 1, 8))
    end))
    self.Janitor:Add(increase.MouseButton1Click:Connect(function()
        self:ChangeSetting("AutoShootRate",
            math.clamp(self.Settings.AutoShootRate + 1, 1, 8))
    end))

    local statusPanel = create("Frame", shooter, {
        Position = UDim2.fromOffset(0, 310),
        Size = UDim2.fromOffset(461, 103),
        BackgroundColor3 = COLOR.Sidebar,
        BorderSizePixel = 0,
    })
    corner(statusPanel, 8)
    local statusHeading = label(statusPanel, "Auto Shoot status", 15, 7, 430, 27, 14)
    statusHeading.Font = Enum.Font.GothamBold
    self.AutoShootStatusLabel = label(statusPanel, "OFF",
        15, 39, 433, 45, 12)
    self.AutoShootStatusLabel.TextWrapped = true
    self.AutoShootStatusLabel.TextTruncate = Enum.TextTruncate.None
    self.AutoShootStatusLabel.TextColor3 = COLOR.Muted

    -- Targets tab: users can register the real model name without guessing IDs.
    local targets = self.Pages.Targets
    local helper = label(targets,
        "Track a nearby NPC model as a monster. All models with its name follow.",
        8, 2, 445, 43, 12)
    helper.TextWrapped = true
    helper.TextTruncate = Enum.TextTruncate.None
    local refreshTargets = button(targets, "Refresh list", 0, 46, 150, 35, COLOR.Row)
    local allTargets = button(targets, "Show scenery: OFF", 160, 46, 190, 35, COLOR.Row)
    local scroll = create("ScrollingFrame", targets, {
        Name = "TargetList",
        Position = UDim2.fromOffset(0, 91),
        Size = UDim2.fromOffset(461, 317),
        BackgroundColor3 = COLOR.Sidebar,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.fromOffset(0, 0),
    })
    corner(scroll, 9)
    self.TargetList = scroll
    self.Janitor:Add(refreshTargets.MouseButton1Click:Connect(function()
        if self.OnTargetsRefresh then self.OnTargetsRefresh(self.ShowScenery) end
    end))
    self.Janitor:Add(allTargets.MouseButton1Click:Connect(function()
        self.ShowScenery = not self.ShowScenery
        allTargets.Text = self.ShowScenery and "Show scenery: ON" or "Show scenery: OFF"
        if self.OnTargetsRefresh then self.OnTargetsRefresh(self.ShowScenery) end
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
    self:ToggleRow(settingsPage, "Team colors", "TeamColors", 126)
    self:ToggleRow(settingsPage, "Player distance labels", "ShowDistance", 171)
    self:ToggleRow(settingsPage, "Player health bars", "ShowHealth", 216)
    self:ToggleRow(settingsPage, "Player wall highlights", "ShowHighlights", 261)
    self:ToggleRow(settingsPage, "Anti Fog (clear haze)", "AntiFogEnabled", 306)
    local resetFOV = button(settingsPage, "Reset camera FOV", 0, 366, 220, 42, COLOR.Row)
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
    self:ShowPage("Monsters")
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
    self.ToggleButtons[key] = self.ToggleButtons[key] or {}
    table.insert(self.ToggleButtons[key], toggle)
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
    if name == "Targets" and self.OnTargetsRefresh then
        self.OnTargetsRefresh(self.ShowScenery)
    end
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
    for key, toggles in pairs(self.ToggleButtons) do
        local enabled = self.Settings[key] == true
        for _, toggle in ipairs(toggles) do
            toggle.Text = enabled and "ON" or "OFF"
            toggle.BackgroundColor3 = enabled and COLOR.On or COLOR.Off
            toggle.TextColor3 = enabled and COLOR.Text or COLOR.Muted
        end
    end
    self.RangeLabel.Text = "ESP detection distance: "
        .. tostring(self.Settings.MaxDistance) .. " studs"
    if self.ShootModeButton then
        self.ShootModeButton.Text = self.Settings.AutoShootInputMode == "Tool"
            and "Fire input: Tool" or "Fire input: Left Click"
    end
    if self.ShootRateLabel then
        self.ShootRateLabel.Text = "Firing rate: " ..
            tostring(self.Settings.AutoShootRate) .. " shots/sec"
    end
    if self.AimLabels then
        for key, entry in pairs(self.AimLabels) do
            local value = self.Settings[key]
            entry.Label.Text = entry.Title .. ": " .. tostring(value) .. entry.Unit
        end
    end
end

function UIController:SetESPEnabled(enabled)
    self.Settings.Enabled = enabled
    self:Refresh()
end

function UIController:SetAutoShootStatus(status)
    if self.AutoShootStatusLabel then
        self.AutoShootStatusLabel.Text = tostring(status)
    end
end

function UIController:SetCarCount(count)
    self.CarCount = count
    if self.CarCountLabel then
        self.CarCountLabel.Text = "Detected whole cars: " .. tostring(count)
    end
    self:UpdateHomeCounts()
end

function UIController:SetQualityReport(report)
    if not self.QualityReport then return end
    self.QualityReport.Text = tostring(report):sub(1, 8000)
    task.defer(function()
        if self.QualityReport and self.QualityReport.Parent then
            local height = self.QualityReport.TextBounds.Y
            self.QualityReportScroll.CanvasSize = UDim2.fromOffset(
                0, math.max(208, height + 24)
            )
        end
    end)
end

function UIController:UpdateHomeCounts()
    self.HomeStatus.Text = "Live creatures: " .. tostring(self.MonsterCount)
        .. "   |   Thrown HandCatch: " .. tostring(self.HandCatchCount)
        .. "   |   Cars: " .. tostring(self.CarCount)
end

function UIController:SetMonsterCount(count)
    self.MonsterCount = count
    self.MonsterCountLabel.Text = "Detected monsters: " .. tostring(count)
    self:UpdateHomeCounts()
end

function UIController:SetHandCatchCount(count)
    self.HandCatchCount = count
    if self.HandCatchCountLabel then
        self.HandCatchCountLabel.Text =
            "Thrown HandCatch detected: " .. tostring(count)
    end
    self:UpdateHomeCounts()
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

function UIController:ToggleWindow()
    self.Window.Visible = not self.Window.Visible
end

function UIController:RenderTargets(choices)
    if not self.TargetList then return end
    for _, child in ipairs(self.TargetList:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end

    if #choices == 0 then
        label(self.TargetList, "No nearby NPC models. Enable Show scenery or press O.",
            15, 12, 430, 40, 12)
    end

    for i, entry in ipairs(choices) do
        local y = (i - 1) * 49 + 5
        local row = create("Frame", self.TargetList, {
            Name = "Target" .. i,
            Position = UDim2.fromOffset(5, y),
            Size = UDim2.fromOffset(447, 44),
            BackgroundColor3 = COLOR.Row,
            BorderSizePixel = 0,
        })
        corner(row, 6)
        local name = label(row, entry.Name, 10, 2, 288, 24, 12)
        name.Font = Enum.Font.GothamBold
        local detail = label(row, tostring(math.floor(entry.Distance)) ..
            " studs | " .. tostring(entry.Category), 10, 24, 284, 17, 11)
        detail.TextColor3 = COLOR.Muted

        local action = entry.Registered and "UNTRACK" or "TRACK"
        local track = button(row, action, 345, 6, 94, 32, COLOR.Off)
        track.MouseButton1Click:Connect(function()
            if self.OnTrackMonster then
                self.OnTrackMonster(entry.Instance, not entry.Registered)
            end
            if self.OnTargetsRefresh then self.OnTargetsRefresh(self.ShowScenery) end
        end)
    end
    self.TargetList.CanvasSize = UDim2.fromOffset(0,
        math.max(317, #choices * 49 + 10))
end

function UIController:Destroy()
    self.Janitor:Cleanup()
end

return UIController