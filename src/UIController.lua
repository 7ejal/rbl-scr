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
        OnStatsReset = nil,
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
    self.UserScale=math.clamp(settings.GuiScale or 1,0.65,1.25)
    self.MiniButton=create("TextButton",self.Gui,{
        Name="7jlMiniControl",Size=UDim2.fromOffset(126,36),
        Position=UDim2.fromOffset(22,72),
        BackgroundColor3=COLOR.Sidebar,TextColor3=COLOR.Text,
        Font=Enum.Font.GothamBold,TextSize=13,Text="7jl | OPEN",
        BorderSizePixel=0,Visible=false,
    })
    corner(self.MiniButton,8)
    self.Janitor:Add(self.MiniButton.MouseButton1Click:Connect(function()
        self:ToggleWindow()
    end))

    local scale = create("UIScale", window, {Scale = 1})
    local function fitScreen()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        scale.Scale = math.min(self.UserScale,
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
    local logo = label(header, "7jl", 21, 13, 92, 36, 18)
    logo.Font = Enum.Font.GothamBold
    local subheading = label(header, "ESP CONTROL", 93, 18, 180, 26, 12)
    subheading.TextColor3 = COLOR.Muted

    local hideBtn = button(header, "HIDE [CTRL]", 319, 13, 119, 36, COLOR.Sidebar)
    self.Janitor:Add(hideBtn.MouseButton1Click:Connect(function()
        self:ToggleWindow()
    end))
    local smaller=button(header,"-",265,16,24,30,COLOR.Row)
    local bigger=button(header,"+",292,16,24,30,COLOR.Row)
    self.Janitor:Add(smaller.MouseButton1Click:Connect(function()
        self.UserScale=math.clamp(self.UserScale-0.1,0.65,1.25)
        self:ChangeSetting("GuiScale",self.UserScale)
    end))
    self.Janitor:Add(bigger.MouseButton1Click:Connect(function()
        self.UserScale=math.clamp(self.UserScale+0.1,0.65,1.25)
        self:ChangeSetting("GuiScale",self.UserScale)
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
    local sidebar = create("ScrollingFrame", window, {
        Name = "Sidebar",
        Position = UDim2.fromOffset(12, 68),
        Size = UDim2.fromOffset(181, 420),
        BackgroundColor3 = COLOR.Sidebar,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.fromOffset(0, 1100),
    })
    corner(sidebar, 12)
    local sidebarSearch=create("TextBox",sidebar,{
        Name="MenuSearch",Position=UDim2.fromOffset(10,8),
        Size=UDim2.fromOffset(159,33),
        BackgroundColor3=COLOR.Row,TextColor3=COLOR.Text,
        PlaceholderText="Search 7jl pages",
        PlaceholderColor3=COLOR.Muted,ClearTextOnFocus=false,
        Text="",Font=Enum.Font.Gotham,TextSize=12,BorderSizePixel=0,
    })
    corner(sidebarSearch,8)

    local mainArea = create("Frame", window, {
        Name = "Content",
        Position = UDim2.fromOffset(207, 68),
        Size = UDim2.fromOffset(461, 420),
        BackgroundTransparency = 1,
    })

    local tabs = {"Home", "ESP", "Auto Aim", "Auto Shoot", "Auto Hunt",
        "Vehicle Lab", "Car Inspector", "Hunt Tools", "Dhab Explorer",
        "Radar", "Statistics", "Monsters", "HandCatch", "Cars", "Quality",
        "Targets", "Profiles", "Settings", "Advanced", "Diagnostics"}
    for index, name in ipairs(tabs) do
        local tab = button(sidebar, name, 10, 48 + (index - 1) * 37, 161, 32, COLOR.Sidebar)
        self.Tabs[name] = tab
        self.Janitor:Add(tab.MouseButton1Click:Connect(function()
            self:ShowPage(name)
        end))
        local scrollable = name == "Auto Hunt" or name == "Auto Shoot"
            or name == "Advanced" or name == "Statistics"
            or name == "Diagnostics"
            or name == "Vehicle Lab" or name == "Hunt Tools"
            or name == "Car Inspector" or name == "Dhab Explorer"
            or name == "Profiles" or name == "Radar"
        -- ScrollBarThickness/CanvasSize only exist on ScrollingFrame.
        -- Passing ScrollBarThickness = 0 to a regular Frame errors at load.
        local pageProps = {
            Name = name .. "Page",
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Visible = false,
        }
        if scrollable then
            pageProps.ScrollBarThickness = 4
            pageProps.ScrollingDirection = Enum.ScrollingDirection.Y
            pageProps.CanvasSize = UDim2.fromOffset(0,
                name == "Auto Hunt" and 1680
                    or (name == "Advanced" and 1180
                    or (name == "Diagnostics" and 1100
                    or (name == "Vehicle Lab" and 850
                    or (name == "Hunt Tools" and 920
                    or (name == "Car Inspector" and 950
                    or (name == "Dhab Explorer" and 1050
                    or (name == "Profiles" and 1170
                    or (name == "Radar" and 650 or 600)))))))))
        end
        local page = create(scrollable and "ScrollingFrame" or "Frame",
            mainArea, pageProps)
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
    self:ToggleRow(quality, "Show Dhab Tier / Length / Size", "DhabStatsEnabled", 100)
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

    local shootRangePanel = create("Frame", shooter, {
        Position = UDim2.fromOffset(0, 422),
        Size = UDim2.fromOffset(461, 90),
        BackgroundColor3 = COLOR.Sidebar, BorderSizePixel = 0,
    })
    corner(shootRangePanel, 8)
    self.ShootDistanceLabel = label(shootRangePanel,
        "Max shooting distance", 14, 5, 420, 28, 14)
    local lessRange = button(shootRangePanel, "- 10 studs",
        12, 41, 140, 35, COLOR.Row)
    local moreRange = button(shootRangePanel, "+ 10 studs",
        162, 41, 140, 35, COLOR.Row)
    self.Janitor:Add(lessRange.MouseButton1Click:Connect(function()
        self:ChangeSetting("AutoShootMaxDistance", math.clamp(
            self.Settings.AutoShootMaxDistance - 10, 10, 500))
    end))
    self.Janitor:Add(moreRange.MouseButton1Click:Connect(function()
        self:ChangeSetting("AutoShootMaxDistance", math.clamp(
            self.Settings.AutoShootMaxDistance + 10, 10, 500))
    end))

    -- GUI V2: categories and instant page search.
    local groups={
        Core={"Home","Settings","Profiles","Statistics"},
        Hunting={"Auto Aim","Auto Shoot","Auto Hunt","Hunt Tools",
            "Dhab Explorer","Advanced"},
        Tracking={"ESP","Monsters","HandCatch","Cars","Quality","Radar",
            "Targets"},
        Tools={"Vehicle Lab","Car Inspector","Diagnostics"},
    }
    local order={"Core","Hunting","Tracking","Tools"}
    self.GroupOpen={Core=true,Hunting=true,Tracking=true,Tools=true}
    local headers={}
    for _,group in ipairs(order) do
        local btn=button(sidebar,group,10,0,159,23,COLOR.Row)
        headers[group]=btn
        self.Janitor:Add(btn.MouseButton1Click:Connect(function()
            self.GroupOpen[group]=not self.GroupOpen[group]
            if self.ReflowSidebar then self.ReflowSidebar() end
        end))
    end
    local function reflow()
        local term=sidebarSearch.Text:lower()
        local y=48
        for _,group in ipairs(order) do
            headers[group].Position=UDim2.fromOffset(10,y)
            headers[group].Text=(self.GroupOpen[group] and "v " or "> ")..group
            y=y+27
            for _,name in ipairs(groups[group]) do
                local tab=self.Tabs[name]
                local matches=term=="" or name:lower():find(term,1,true)
                local show=matches and (self.GroupOpen[group] or term~="")
                tab.Visible=show
                if show then tab.Position=UDim2.fromOffset(10,y);y=y+36 end
            end
            y=y+5
        end
        sidebar.CanvasSize=UDim2.fromOffset(0,math.max(420,y+8))
    end
    self.ReflowSidebar=reflow
    self.Janitor:Add(sidebarSearch:GetPropertyChangedSignal("Text"):Connect(reflow))
    reflow()

    -- Auto Hunt: pathfinding movement + the existing live-Dhab aim/shoot.
    -- Does not teleport, equip Tools, fire remotes, target cars or collect loot.
    local hunt = self.Pages["Auto Hunt"]
    self:ToggleRow(hunt, "Auto Hunt (follow live Dhab)", "AutoHuntEnabled", 0)
    self:ToggleRow(hunt, "Auto Shoot during hunt", "HuntAutoShoot", 47)
    self:ToggleRow(hunt, "Pause on manual movement", "HuntPauseOnManualMove", 94)
    local huntInfo = label(hunt,
        "Walk to nearest live Dhab via pathfinding. Aims in range. For left-click weapons, hide this menu with Right Ctrl.",
        9, 141, 448, 47, 12)
    huntInfo.TextWrapped = true
    huntInfo.TextTruncate = Enum.TextTruncate.None
    huntInfo.TextYAlignment = Enum.TextYAlignment.Top
    huntInfo.TextColor3 = COLOR.Muted

    local function huntNumberPanel(y, title, key, increment, minValue, maxValue, unit)
        local panel = create("Frame", hunt, {
            Position = UDim2.fromOffset(0, y),
            Size = UDim2.fromOffset(461, 75),
            BackgroundColor3 = COLOR.Sidebar,
            BorderSizePixel = 0,
        })
        corner(panel, 8)
        local display = label(panel, title, 15, 4, 420, 27, 14)
        local decrease = button(panel, "-" .. tostring(increment) .. unit,
            15, 36, 119, 32, COLOR.Row)
        local increase = button(panel, "+" .. tostring(increment) .. unit,
            143, 36, 119, 32, COLOR.Row)
        self.HuntLabels[key] = {Label = display, Title = title, Unit = unit}
        local function change(delta)
            self:ChangeSetting(key, math.clamp(
                self.Settings[key] + delta, minValue, maxValue
            ))
        end
        self.Janitor:Add(decrease.MouseButton1Click:Connect(function()
            change(-increment)
        end))
        self.Janitor:Add(increase.MouseButton1Click:Connect(function()
            change(increment)
        end))
    end
    self.HuntLabels = {}
    huntNumberPanel(185, "Stop distance", "HuntStopDistance", 5, 10, 100, " studs")
    huntNumberPanel(266, "Search radius", "HuntSearchDistance", 100, 100, 2000, " studs")

    local huntStatus = create("Frame", hunt, {
        Position = UDim2.fromOffset(0, 350),
        Size = UDim2.fromOffset(461, 64),
        BackgroundColor3 = COLOR.Sidebar,
        BorderSizePixel = 0,
    })
    corner(huntStatus, 8)
    self.HuntStatusLabel = label(huntStatus, "Auto Hunt: OFF",
        13, 6, 435, 52, 12)
    self.HuntStatusLabel.TextWrapped = true
    self.HuntStatusLabel.TextTruncate = Enum.TextTruncate.None
    self.HuntStatusLabel.TextColor3 = COLOR.Muted

    -- Hunting preferences (scroll the Auto Hunt page for advanced settings).
    self.HuntPriorityBtn = button(hunt,
        "Target priority: Closest", 0, 427, 290, 38, COLOR.Sidebar)
    self.Janitor:Add(self.HuntPriorityBtn.MouseButton1Click:Connect(function()
        local order = {Closest = "Longest", Longest = "Largest",
            Largest = "Smart", Smart = "Closest"}
        self:ChangeSetting("HuntPriority",
            order[self.Settings.HuntPriority] or "Closest")
    end))
    label(hunt, "Allowed Dhab tiers", 10, 470, 340, 25, 14)
    self:ToggleRow(hunt, "Tier T1", "HuntTierT1", 499)
    self:ToggleRow(hunt, "Tier T2", "HuntTierT2", 546)
    self:ToggleRow(hunt, "Tier T3", "HuntTierT3", 593)
    self:ToggleRow(hunt, "Tier T4", "HuntTierT4", 640)
    self:ToggleRow(hunt, "Tier T5", "HuntTierT5", 687)
    self:ToggleRow(hunt, "Tier T6", "HuntTierT6", 734)
    self:ToggleRow(hunt, "Unknown Tier", "HuntTierUnknown", 781)
    huntNumberPanel(836, "Minimum Length", "HuntMinLength", 0.5, 0, 12, " studs")
    huntNumberPanel(919, "Hunt shooting distance", "HuntShootDistance",
        10, 10, 500, " studs")
    local huntFoot = label(hunt,
        "Unreachable targets are skipped temporarily. Size uses the model's actual Scale attribute. No fabricated rarity data.",
        10, 1005, 438, 70, 12)
    huntFoot.TextWrapped = true
    huntFoot.TextTruncate = Enum.TextTruncate.None
    huntFoot.TextYAlignment = Enum.TextYAlignment.Top
    huntFoot.TextColor3 = COLOR.Muted

    -- Vehicle hunting requires an occupied local VehicleSeat in PlayersCars.
    -- It never auto-enters vehicles or controls other drivers' cars.
    self:ToggleRow(hunt, "Auto Hunt in car (driver seat)",
        "HuntCarEnabled", 1080)
    self:ToggleRow(hunt, "Reverse vehicle steering",
        "HuntCarInvertSteering", 1127)
    huntNumberPanel(1184, "Vehicle stopping radius",
        "HuntCarStopDistance", 5, 25, 125, " studs")
    huntNumberPanel(1269, "Vehicle speed target",
        "HuntCarTargetKmh", 10, 30, 180, " km/h")
    local driveInfo = label(hunt,
        "Sit in your car's driver seat and enable Auto Hunt. Keyboard mode keeps W held below the target speed. Standard Roblox speed conversion is used; custom speedometers may differ. F8 stops driving.",
        8, 1360, 442, 94, 12)
    driveInfo.TextWrapped = true
    driveInfo.TextTruncate = Enum.TextTruncate.None
    driveInfo.TextYAlignment = Enum.TextYAlignment.Top
    driveInfo.TextColor3 = COLOR.Muted

    -- Input backend for cars that move from real WASD instead of Seat floats.
    self.CarInputButton = button(hunt,
        "Car input: Keyboard W/A/S/D", 0, 1466, 326, 39, COLOR.Row)
    self.Janitor:Add(self.CarInputButton.MouseButton1Click:Connect(function()
        local nextMode = ({Auto="Keyboard",Keyboard="Seat",
            Seat="ControlsValue",ControlsValue="Auto"})
            [self.Settings.HuntCarInputMode] or "Auto"
        self:ChangeSetting("HuntCarInputMode", nextMode)
    end))

    self:ToggleRow(hunt, "Brake for obstacles",
        "HuntCarObstacleBrake", 1518)

    -- Radar page: nearby live Dhab, highlighted hunt target and distances.
    local radarPage = self.Pages.Radar
    self:ToggleRow(radarPage, "Show Dhab radar overlay", "RadarEnabled", 0)
    local rangePanel = create("Frame", radarPage, {
        Position = UDim2.fromOffset(0, 61),
        Size = UDim2.fromOffset(461, 100),
        BackgroundColor3 = COLOR.Sidebar, BorderSizePixel = 0,
    })
    corner(rangePanel, 8)
    self.RadarRangeLabel = label(rangePanel, "Radar range", 12, 5, 430, 30, 14)
    local radarLess = button(rangePanel, "- 100 studs", 12, 45, 150, 39, COLOR.Row)
    local radarMore = button(rangePanel, "+ 100 studs", 172, 45, 150, 39, COLOR.Row)
    self.Janitor:Add(radarLess.MouseButton1Click:Connect(function()
        self:ChangeSetting("RadarRange", math.clamp(
            self.Settings.RadarRange - 100, 100, 2000))
    end))
    self.Janitor:Add(radarMore.MouseButton1Click:Connect(function()
        self:ChangeSetting("RadarRange", math.clamp(
            self.Settings.RadarRange + 100, 100, 2000))
    end))
    local radarHint = label(radarPage,
        "Orange = nearby Dhab. Green = your selected hunt target. Center = you. Radar rotates with your camera.",
        12, 174, 440, 83, 13)
    radarHint.TextWrapped = true
    radarHint.TextTruncate = Enum.TextTruncate.None
    radarHint.TextYAlignment = Enum.TextYAlignment.Top
    self:ToggleRow(radarPage, "Observed Dhab heatmap", "HeatmapEnabled", 269)
    self:ToggleRow(radarPage, "Real-Tier / long-Dhab alerts",
        "DhabAlertsEnabled", 376)
    local alertTier=button(radarPage,"Alert Tier: T3+",0,431,218,36,COLOR.Row)
    local alertLength=button(radarPage,"Alert Length: 5 studs",
        228,431,226,36,COLOR.Row)
    self.AlertTierButton=alertTier;self.AlertLengthButton=alertLength
    self.Janitor:Add(alertTier.MouseButton1Click:Connect(function()
        self:ChangeSetting("DhabAlertTier",
            self.Settings.DhabAlertTier>=6 and 1
                or self.Settings.DhabAlertTier+1)
    end))
    self.Janitor:Add(alertLength.MouseButton1Click:Connect(function()
        self:ChangeSetting("DhabAlertLength",
            self.Settings.DhabAlertLength>=12 and 0
                or self.Settings.DhabAlertLength+1)
    end))
    self.AlertStatus=label(radarPage,"Alerts OFF",0,479,441,50,12)
    self.AlertStatus.TextWrapped=true
    local heatReset=button(radarPage,"Clear observed locations",
        0,324,235,36,COLOR.Row)
    self.Janitor:Add(heatReset.MouseButton1Click:Connect(function()
        if self.OnClearHeatmap then self.OnClearHeatmap() end
    end))


    -- Dedicated car observation/calibration page: never calibrate on startup.
    local lab=self.Pages["Vehicle Lab"]
    local labHelp=label(lab,
        "Turn Auto Hunt OFF. First manually shift into Drive and test W on open terrain. Manual Observation reads your driving only. Calibration briefly tests W in a stationary car; F8 cancels.",
        5,0,446,98,13)
    labHelp.TextWrapped=true
    labHelp.TextYAlignment=Enum.TextYAlignment.Top
    labHelp.TextColor3=COLOR.Muted
    local observe=button(lab,"Observe manual driving (8s)",
        0,107,280,40,COLOR.Row)
    self.Janitor:Add(observe.MouseButton1Click:Connect(function()
        if self.OnObserveDriving then self.OnObserveDriving() end
    end))
    local calibrate=button(lab,"Calibrate car input (slow test)",
        0,158,280,40,COLOR.Row)
    self.Janitor:Add(calibrate.MouseButton1Click:Connect(function()
        if self.OnCalibrateCar then self.OnCalibrateCar() end
    end))
    local cancel=button(lab,"Cancel and release inputs",
        0,209,280,40,COLOR.Off)
    self.Janitor:Add(cancel.MouseButton1Click:Connect(function()
        if self.OnCancelCalibration then self.OnCancelCalibration() end
    end))
    self.LearnerStatus=label(lab,
        "No observations yet. Calibrated methods are saved per car model name only if Save preferences locally is ON.",
        8,264,444,186,12)
    self.LearnerStatus.TextWrapped=true
    self.LearnerStatus.TextTruncate=Enum.TextTruncate.None
    self.LearnerStatus.TextYAlignment=Enum.TextYAlignment.Top
    self.LearnerStatus.Font=Enum.Font.Code
    self:ToggleRow(lab,"Approach-speed cruise control",
        "HuntCarCruiseEnabled",465)
    self:ToggleRow(lab,"Off-road side-path assist",
        "HuntOffroadEnabled",515)
    local warn=label(lab,
        "Off-road assist uses terrain and obstacle raycasts. It is not a mapped road autopilot. Calibration proves motion only, not that the vehicle can reach 120 km/h.",
        5,573,444,130,12)
    warn.TextWrapped=true
    warn.TextYAlignment=Enum.TextYAlignment.Top
    warn.TextColor3=COLOR.Muted

    -- Hunting shortcuts and ESP appearance.
    local toolsPage=self.Pages["Hunt Tools"]
    self:ToggleRow(toolsPage,"Lock selected Dhab",
        "HuntTargetLockEnabled",0)
    local previous=button(toolsPage,"Previous Dhab",
        0,53,144,37,COLOR.Row)
    local next=button(toolsPage,"Next Dhab",
        153,53,144,37,COLOR.Row)
    local unlock=button(toolsPage,"Unlock",
        306,53,153,37,COLOR.Row)
    self.Janitor:Add(previous.MouseButton1Click:Connect(function()
        if self.OnPreviousTarget then self.OnPreviousTarget() end
    end))
    self.Janitor:Add(next.MouseButton1Click:Connect(function()
        if self.OnNextTarget then self.OnNextTarget() end
    end))
    self.Janitor:Add(unlock.MouseButton1Click:Connect(function()
        if self.OnUnlockTarget then self.OnUnlockTarget() end
    end))
    label(toolsPage,"One-click hunt presets",0,106,430,26,14)
    local presets={"Closest","Biggest","Longest","T3+"}
    for i,name in ipairs(presets) do
        local x=(i-1)%2*232
        local y=138+math.floor((i-1)/2)*47
        local b=button(toolsPage,name,x,y,217,37,COLOR.Row)
        self.Janitor:Add(b.MouseButton1Click:Connect(function()
            if self.OnPreset then self.OnPreset(name) end
        end))
    end
    self:ToggleRow(toolsPage,"Color ESP by real Tier",
        "DhabTierColorsEnabled",241)
    self:ToggleRow(toolsPage,"Highlight longest observed Dhab",
        "HighlightLongestDhab",291)
    self:ToggleRow(toolsPage,"Compact hunting HUD",
        "HuntHUDEnabled",341)
    self:ToggleRow(toolsPage,"Off-screen target arrow",
        "TargetArrowEnabled",391)
    local skipTarget=button(toolsPage,"Skip current Dhab (cooldown)",
        0,568,280,40,COLOR.Row)
    self.Janitor:Add(skipTarget.MouseButton1Click:Connect(function()
        if self.OnSkipDhab then self.OnSkipDhab() end
    end))
    local clearSkips=button(toolsPage,"Clear skipped Dhab",
        0,618,280,40,COLOR.Row)
    self.Janitor:Add(clearSkips.MouseButton1Click:Connect(function()
        if self.OnClearSkips then self.OnClearSkips() end
    end))
    self.SkipDuration=label(toolsPage,"Cooldown: 90 seconds",
        0,671,450,22,13)
    local skipLess=button(toolsPage,"-30s",0,702,138,34,COLOR.Row)
    local skipMore=button(toolsPage,"+30s",145,702,138,34,COLOR.Row)
    self.Janitor:Add(skipLess.MouseButton1Click:Connect(function()
        self:ChangeSetting("HuntManualSkipSeconds",math.clamp(
            self.Settings.HuntManualSkipSeconds-30,15,600))
    end))
    self.Janitor:Add(skipMore.MouseButton1Click:Connect(function()
        self:ChangeSetting("HuntManualSkipSeconds",math.clamp(
            self.Settings.HuntManualSkipSeconds+30,15,600))
    end))
    local toolsHelp=label(toolsPage,
        "Tiers are actual model attributes, not guessed rarity. Arrow appears only with a locked or actively hunted live Dhab. Radar has the observation heatmap toggle.",
        8,447,442,110,12)
    toolsHelp.TextWrapped=true
    toolsHelp.TextYAlignment=Enum.TextYAlignment.Top
    toolsHelp.TextColor3=COLOR.Muted

    -- Session statistics and explicitly opt-in local settings persistence.
    local statsPage = self.Pages.Statistics
    self:ToggleRow(statsPage, "Collect session statistics", "StatsEnabled", 0)
    self:ToggleRow(statsPage, "Save preferences locally", "SaveSettingsEnabled", 50)
    self.StatsLabel = label(statsPage, "No hunt activity yet",
        11, 112, 438, 355, 13)
    self.StatsLabel.TextWrapped = true
    self.StatsLabel.TextTruncate = Enum.TextTruncate.None
    self.StatsLabel.TextYAlignment = Enum.TextYAlignment.Top
    self.ResetStatsButton = button(statsPage, "Reset session stats",
        11, 474, 210, 37, COLOR.Row)
    self.Janitor:Add(self.ResetStatsButton.MouseButton1Click:Connect(function()
        if self.OnStatsReset then self.OnStatsReset() end
    end))
    self.StorageLabel = label(statsPage,
        "Local save requires readfile and writefile in Xeno",
        11, 521, 440, 60, 12)
    self.StorageLabel.TextWrapped = true
    self.StorageLabel.TextTruncate = Enum.TextTruncate.None
    self.StorageLabel.TextColor3 = COLOR.Muted

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


    -- Advanced hunt controls and emergency stop.
    local adv = self.Pages.Advanced
    local emergency = button(adv,
        "EMERGENCY STOP (F8)", 0, 2, 244, 43, COLOR.Off)
    self.Janitor:Add(emergency.MouseButton1Click:Connect(function()
        if self.OnEmergencyStop then self.OnEmergencyStop() end
    end))
    self:ToggleRow(adv, "Multi-Dhab route planning", "HuntRouteEnabled", 58)
    self:ToggleRow(adv, "Predictive Dhab aim", "AimPredictionEnabled", 109)
    self:ToggleRow(adv, "Performance mode (15 FPS overlay)", "PerformanceMode", 160)

    local function advancedValue(y,title,key,step,minVal,maxVal,suffix)
        local panel=create("Frame",adv,{
            Position=UDim2.fromOffset(0,y),
            Size=UDim2.fromOffset(461,77),
            BackgroundColor3=COLOR.Sidebar,BorderSizePixel=0,
        })
        corner(panel,8)
        self.AdvancedLabels[key]=label(panel,title,12,3,426,26,14)
        local less=button(panel,"- "..tostring(step),
            12,36,140,34,COLOR.Row)
        local more=button(panel,"+ "..tostring(step),
            162,36,140,34,COLOR.Row)
        self.AdvancedSuffix[key]=suffix
        self.Janitor:Add(less.MouseButton1Click:Connect(function()
            self:ChangeSetting(key,math.clamp(
                self.Settings[key]-step,minVal,maxVal))
        end))
        self.Janitor:Add(more.MouseButton1Click:Connect(function()
            self:ChangeSetting(key,math.clamp(
                self.Settings[key]+step,minVal,maxVal))
        end))
    end
    self.AdvancedLabels={}
    self.AdvancedSuffix={}
    advancedValue(218,"Length score weight","HuntScoreLength",1,0,10,"")
    advancedValue(304,"Size score weight","HuntScoreSize",1,0,10,"")
    advancedValue(390,"Distance penalty","HuntScoreDistance",0.02,0,0.5,"")
    advancedValue(476,"Aim lead time","AimLeadSeconds",0.05,0,0.6," sec")
    advancedValue(562,"Blacklist zone radius","HuntAvoidRadius",10,20,350," studs")
    local blockButton=button(adv,"Blacklist current location",
        0,655,260,37,COLOR.Row)
    self.Janitor:Add(blockButton.MouseButton1Click:Connect(function()
        if self.OnMarkAvoidZone then self.OnMarkAvoidZone() end
    end))
    local clearButton=button(adv,"Clear blocked zones",
        0,701,260,37,COLOR.Row)
    self.Janitor:Add(clearButton.MouseButton1Click:Connect(function()
        if self.OnClearAvoidZones then self.OnClearAvoidZones() end
    end))
    local hint=label(adv,
        "Smart scoring combines actual Dhab Length, Scale and distance. Route planning visits nearby candidates in a short sequence. Blacklists are session-only.",
        8,749,440,95,12)
    hint.TextWrapped=true
    hint.TextYAlignment=Enum.TextYAlignment.Top
    hint.TextColor3=COLOR.Muted

    local diagnostics=self.Pages.Diagnostics
    local diagRefresh=button(diagnostics,
        "Refresh diagnostics",0,0,220,40,COLOR.Row)
    self.Janitor:Add(diagRefresh.MouseButton1Click:Connect(function()
        if self.OnDiagnose then self.OnDiagnose() end
    end))
    local diagStop=button(diagnostics,
        "Stop all (F8)",237,0,222,40,COLOR.Off)
    self.Janitor:Add(diagStop.MouseButton1Click:Connect(function()
        if self.OnEmergencyStop then self.OnEmergencyStop() end
    end))
    local retryCar=button(diagnostics,
        "Retry car input after shifting into Drive",
        0,49,385,40,COLOR.Row)
    self.Janitor:Add(retryCar.MouseButton1Click:Connect(function()
        if self.OnRetryCarInput then self.OnRetryCarInput() end
    end))
    local exportLog=button(diagnostics,"Copy/export debug log",
        0,807,235,40,COLOR.Row)
    self.Janitor:Add(exportLog.MouseButton1Click:Connect(function()
        if self.OnExportLog then self.OnExportLog() end
    end))
    self.DebugExportStatus=label(diagnostics,
        "No debug log exported",245,807,208,45,12)
    self.DebugExportStatus.TextWrapped=true
    self.DiagnosticLabel=label(diagnostics,
        "Press Refresh diagnostics to inspect the gear and keyboard input.",
        7,105,448,670,12)
    self.DiagnosticLabel.TextWrapped=true
    self.DiagnosticLabel.TextTruncate=Enum.TextTruncate.None
    self.DiagnosticLabel.TextYAlignment=Enum.TextYAlignment.Top
    self.DiagnosticLabel.Font=Enum.Font.Code


    -- Car Inspector: read-only vehicle controls/gear and explicit manual bench.
    local inspection=self.Pages["Car Inspector"]
    local inspect=button(inspection,"Inspect current vehicle",0,0,235,39,COLOR.Row)
    self.Janitor:Add(inspect.MouseButton1Click:Connect(function()
        if self.OnInspectCar then self.OnInspectCar() end
    end))
    local bench=button(inspection,"Manual test bench (10s)",
        0,51,260,39,COLOR.Row)
    self.Janitor:Add(bench.MouseButton1Click:Connect(function()
        if self.OnVehicleBench then self.OnVehicleBench() end
    end))
    self:ToggleRow(inspection,"Enable typed local controls adapter",
        "HuntAdapterEnabled",101)
    local carNote=label(inspection,
        "Adapter supports NumberValue Throttle and Steer inside Controls/Input folders. Only turn on for your own compatible car. No game remotes, no automatic gear changes.",
        9,153,438,89,12)
    carNote.TextWrapped=true;carNote.TextYAlignment=Enum.TextYAlignment.Top
    carNote.TextColor3=COLOR.Muted
    self.CarInspectorLabel=label(inspection,
        "Inspect your occupied car for replicated controls and gear.",
        9,255,442,525,12)
    self.CarInspectorLabel.TextWrapped=true
    self.CarInspectorLabel.TextTruncate=Enum.TextTruncate.None
    self.CarInspectorLabel.TextYAlignment=Enum.TextYAlignment.Top
    self.CarInspectorLabel.Font=Enum.Font.Code

    -- Live sorted Dhab Explorer with direct target selection.
    local explorer=self.Pages["Dhab Explorer"]
    local refresh=button(explorer,"Refresh live Dhab",0,0,145,34,COLOR.Row)
    self.ExplorerSort=button(explorer,"Sort: Distance",153,0,146,34,COLOR.Row)
    self.ExplorerTier=button(explorer,"Tier: All",307,0,151,34,COLOR.Row)
    self.Janitor:Add(refresh.MouseButton1Click:Connect(function()
        if self.OnExplorerRefresh then self.OnExplorerRefresh() end
    end))
    self.Janitor:Add(self.ExplorerSort.MouseButton1Click:Connect(function()
        if self.OnExplorerSort then self.OnExplorerSort() end
    end))
    self.Janitor:Add(self.ExplorerTier.MouseButton1Click:Connect(function()
        if self.OnExplorerTier then self.OnExplorerTier() end
    end))
    self.ExplorerSearch=create("TextBox",explorer,{
        Position=UDim2.fromOffset(0,42),Size=UDim2.fromOffset(457,34),
        BackgroundColor3=COLOR.Row,TextColor3=COLOR.Text,
        PlaceholderText="Filter Dhab name...",Text="",ClearTextOnFocus=false,
        Font=Enum.Font.Gotham,TextSize=13,BorderSizePixel=0,
    })
    corner(self.ExplorerSearch,7)
    self.Janitor:Add(self.ExplorerSearch:GetPropertyChangedSignal("Text"):Connect(function()
        if self.OnExplorerSearch then
            self.OnExplorerSearch(self.ExplorerSearch.Text)
        end
    end))
    self.ExplorerInfo=label(explorer,"Refresh to list live Dhab",
        0,81,446,28,12)
    self.ExplorerList=create("Frame",explorer,{
        Position=UDim2.fromOffset(0,117),
        Size=UDim2.fromOffset(457,850),BackgroundTransparency=1,
    })

    -- Named hunting configurations. Loading a profile never automatically hunts.
    local profilesPage=self.Pages.Profiles
    label(profilesPage,"Switch hunting profiles (auto actions remain OFF)",
        4,3,443,36,13)
    for i,name in ipairs({"Car Hunting","On Foot","High Tier","Low FPS",
        "Custom A","Custom B"}) do
        local y=47+(i-1)*54
        local selectProfile=button(profilesPage,"Load "..name,
            0,y,215,39,COLOR.Row)
        self.Janitor:Add(selectProfile.MouseButton1Click:Connect(function()
            if self.OnConfigLoad then self.OnConfigLoad(name) end
        end))
        if name=="Custom A" or name=="Custom B" then
            local saveProfile=button(profilesPage,"Save "..name,
                226,y,225,39,COLOR.Row)
            self.Janitor:Add(saveProfile.MouseButton1Click:Connect(function()
                if self.OnConfigSave then self.OnConfigSave(name) end
            end))
        end
    end
    self.ProfileStatus=label(profilesPage,
        "Custom profiles persist only when Save preferences locally is ON.",
        4,385,448,72,12)
    self.ProfileStatus.TextWrapped=true
    self.ProfileStatus.TextYAlignment=Enum.TextYAlignment.Top
    self:ToggleRow(profilesPage,"Compact dashboard layout",
        "GuiCompactEnabled",465)
    label(profilesPage,"Custom hotkeys (F8 emergency stop stays fixed)",
        4,523,439,29,13)
    self.HotkeyButtons={}
    for i,action in ipairs({"Hunt","Next","Radar","Menu","Stop"}) do
        local y=563+(i-1)*54
        local btn=button(profilesPage,action.." hotkey",0,y,330,39,COLOR.Row)
        self.HotkeyButtons[action]=btn
        self.Janitor:Add(btn.MouseButton1Click:Connect(function()
            if self.OnHotkeyCycle then self.OnHotkeyCycle(action) end
        end))
    end
    local profileHelp=label(profilesPage,
        "Hotkeys: toggle Hunt, select next Dhab, toggle Radar. Profile saves exclude passwords, remotes and account information.",
        4,862,445,100,12)
    profileHelp.TextWrapped=true
    profileHelp.TextYAlignment=Enum.TextYAlignment.Top
    profileHelp.TextColor3=COLOR.Muted

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
        self:ChangeSetting("CameraFOV", self.FOV:GetFOV())
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
    if name == "Dhab Explorer" and self.OnExplorerRefresh then
        self.OnExplorerRefresh()
    end
    if name == "Car Inspector" and self.OnInspectCar then
        self.OnInspectCar()
    end
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
    if self.ShootDistanceLabel then
        self.ShootDistanceLabel.Text = "Max shooting distance: " ..
            tostring(self.Settings.AutoShootMaxDistance) .. " studs"
    end
    if self.ShootModeButton then
        self.ShootModeButton.Text = self.Settings.AutoShootInputMode == "Tool"
            and "Fire input: Tool" or "Fire input: Left Click"
    end
    if self.ShootRateLabel then
        self.ShootRateLabel.Text = "Firing rate: " ..
            tostring(self.Settings.AutoShootRate) .. " shots/sec"
    end
    if self.AlertTierButton then
        self.AlertTierButton.Text="Alert Tier: T"..
            tostring(self.Settings.DhabAlertTier).."+"
        self.AlertLengthButton.Text="Alert Length: "..
            tostring(self.Settings.DhabAlertLength).." studs"
    end
    if self.SkipDuration then
        self.SkipDuration.Text="Dhab cooldown: "..
            tostring(self.Settings.HuntManualSkipSeconds).." seconds"
    end
    if self.HotkeyButtons then
        for action,btn in pairs(self.HotkeyButtons) do
            local key=({Hunt="HuntHotkey",Next="NextTargetHotkey",
                Radar="RadarHotkey",Menu="MenuHotkey",
                Stop="StopHotkey"})[action]
            btn.Text=action.." hotkey: "..
                tostring(self.Settings[key])
        end
    end
    if self.CarInputButton then
        self.CarInputButton.Text =
            self.Settings.HuntCarInputMode == "Seat" and "Car input: VehicleSeat"
            or (self.Settings.HuntCarInputMode == "ControlsValue"
                and "Car input: Typed controls (opt-in)"
            or (self.Settings.HuntCarInputMode == "Auto"
                and "Car input: Auto (calibrated)" or "Car input: Keyboard W/A/S/D"))
    end
    if self.AdvancedLabels then
        for key,lbl in pairs(self.AdvancedLabels) do
            lbl.Text=key..": "..tostring(
                math.floor(self.Settings[key]*100+0.5)/100)
                ..(self.AdvancedSuffix[key] or "")
        end
    end
    if self.HuntPriorityBtn then
        self.HuntPriorityBtn.Text = "Target priority: " ..
            tostring(self.Settings.HuntPriority)
    end
    if self.RadarRangeLabel then
        self.RadarRangeLabel.Text = "Radar range: " ..
            tostring(self.Settings.RadarRange) .. " studs"
    end
    if self.HuntLabels then
        for key, entry in pairs(self.HuntLabels) do
            entry.Label.Text = entry.Title .. ": " ..
                tostring(self.Settings[key]) .. entry.Unit
        end
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

function UIController:SetStatistics(summary)
    if self.StatsLabel then
        self.StatsLabel.Text = self.Settings.StatsEnabled
            and tostring(summary) or "Session statistics disabled"
    end
end

function UIController:SetStorageStatus(status)
    if self.StorageLabel then self.StorageLabel.Text = tostring(status) end
end

function UIController:SetLearnerStatus(report)
    if self.LearnerStatus then
        self.LearnerStatus.Text=tostring(report):sub(1,1600)
    end
end

function UIController:SetExplorerRows(rows,sort,tier)
    if not self.ExplorerList then return end
    for _,child in ipairs(self.ExplorerList:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
    self.ExplorerSort.Text="Sort: "..tostring(sort)
    self.ExplorerTier.Text="Tier: "..tostring(tier)
    self.ExplorerInfo.Text=("%d live Dhab matched | tap a row to lock"):format(#rows)
    for i,entry in ipairs(rows) do
        local y=(i-1)*48
        local title=("%s  | %s | L %.2f | S %.2fx | %.0f studs"):format(
            entry.Name,entry.Tier,entry.Length,entry.Size,entry.Distance)
        local btn=button(self.ExplorerList,title,0,y,454,43,COLOR.Row)
        btn.TextSize=11
        btn.TextXAlignment=Enum.TextXAlignment.Left
        btn.MouseButton1Click:Connect(function()
            if self.OnExplorerSelect then self.OnExplorerSelect(entry.Model) end
        end)
    end
end
function UIController:SetAlertStatus(value)
    if self.AlertStatus then
        self.AlertStatus.Text=tostring(value):sub(1,180)
    end
end
function UIController:SetProfileStatus(value)
    if self.ProfileStatus then self.ProfileStatus.Text=tostring(value) end
end
function UIController:SetCarInspection(value)
    if self.CarInspectorLabel then
        self.CarInspectorLabel.Text=tostring(value):sub(1,4200)
    end
end
function UIController:SetExportStatus(value)
    if self.DebugExportStatus then self.DebugExportStatus.Text=tostring(value) end
end

function UIController:SetDiagnosticStatus(report)
    if self.DiagnosticLabel then self.DiagnosticLabel.Text=tostring(report) end
end

function UIController:SetAutoHuntStatus(status)
    if self.HuntStatusLabel then
        self.HuntStatusLabel.Text = tostring(status)
    end
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
    self:ChangeSetting("CameraFOV", self.FOV:GetFOV())
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
    if self.MiniButton then
        self.MiniButton.Visible=not self.Window.Visible
    end
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