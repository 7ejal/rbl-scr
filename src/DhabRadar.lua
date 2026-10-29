-- Lightweight 2D local radar (live Dhab only), not a world map.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Radar = {}
Radar.__index = Radar

local function new(kind, parent, props)
    local obj = Instance.new(kind)
    for key, value in pairs(props) do obj[key] = value end
    obj.Parent = parent
    return obj
end

function Radar.new(settings, tracker, playerGui, getTarget)
    local gui = new("ScreenGui", playerGui, {
        Name = "IVORY_DhabRadar", ResetOnSpawn = false,
        DisplayOrder = 997, IgnoreGuiInset = false,
    })
    local frame = new("Frame", gui, {
        Name = "RadarPanel", Size = UDim2.fromOffset(202, 236),
        Position = UDim2.fromOffset(20, 155),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(13, 14, 19),
        Visible = false,
    })
    new("UICorner", frame, {CornerRadius = UDim.new(0, 10)})
    new("UIStroke", frame, {
        Color = Color3.fromRGB(100, 103, 120), Thickness = 1,
    })
    new("TextLabel", frame, {
        Name = "Title", Position = UDim2.fromOffset(9, 5),
        Size = UDim2.fromOffset(184, 25), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 13,
        Text = "DHAB RADAR", TextColor3 = Color3.fromRGB(250, 250, 250),
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local field = new("Frame", frame, {
        Name = "Map", Position = UDim2.fromOffset(10, 33),
        Size = UDim2.fromOffset(182, 182), BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(28, 29, 38),
        ClipsDescendants = true,
    })
    new("UICorner", field, {CornerRadius = UDim.new(1, 0)})
    new("UIStroke", field, {
        Color = Color3.fromRGB(65, 67, 85), Thickness = 1,
    })
    local center = new("Frame", field, {
        Name = "You", AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(8, 8),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
    })
    new("UICorner", center, {CornerRadius = UDim.new(1, 0)})
    local footer = new("TextLabel", frame, {
        Name = "Info", Position = UDim2.fromOffset(9, 214),
        Size = UDim2.fromOffset(186, 18), BackgroundTransparency = 1,
        Text = "", TextColor3 = Color3.fromRGB(194, 198, 211),
        TextSize = 11, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    return setmetatable({
        Settings = settings, Tracker = tracker, Gui = gui,
        Frame = frame, Field = field, Footer = footer,
        Dots = {}, Target = getTarget, Accumulator = 0,
        Connection = nil,
    }, Radar)
end

function Radar:Update()
    local enabled = self.Settings.RadarEnabled == true
    self.Frame.Visible = enabled
    if not enabled then return end

    local camera = workspace.CurrentCamera
    local character = Players.LocalPlayer.Character
    local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not camera or not playerRoot then
        self.Footer.Text = "Waiting for character"
        for _, dot in ipairs(self.Dots) do dot.Visible = false end
        return
    end

    local origin = playerRoot.Position
    local range = math.clamp(self.Settings.RadarRange or 400, 100, 2000)
    local forward = camera.CFrame.LookVector
    local flat = Vector3.new(forward.X, 0, forward.Z)
    if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
    flat = flat.Unit
    local right = Vector3.new(-flat.Z, 0, flat.X)

    local nearby = {}
    for model, category in pairs(self.Tracker.Known) do
        if category == "monster" and self.Tracker:IsDhab(model)
            and model:IsDescendantOf(workspace) then
            local part = model.PrimaryPart
                or model:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local delta = part.Position - origin
                local distance = Vector3.new(delta.X, 0, delta.Z).Magnitude
                if distance <= range then
                    table.insert(nearby, {Model = model, Delta = delta, Distance = distance})
                end
            end
        end
    end
    table.sort(nearby, function(a, b) return a.Distance < b.Distance end)

    local target = self.Target and self.Target() or nil
    for index = 1, math.min(30, #nearby) do
        local item = nearby[index]
        local dot = self.Dots[index]
        if not dot then
            dot = new("Frame", self.Field, {
                Name = "DhabPin", AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.fromOffset(7, 7), BorderSizePixel = 0,
                BackgroundColor3 = Color3.fromRGB(255, 166, 75),
            })
            new("UICorner", dot, {CornerRadius = UDim.new(1, 0)})
            self.Dots[index] = dot
        end
        local dx = item.Delta:Dot(right) / range
        local dy = -item.Delta:Dot(flat) / range
        dot.Position = UDim2.fromScale(0.5 + dx * 0.46, 0.5 + dy * 0.46)
        dot.BackgroundColor3 = item.Model == target
            and Color3.fromRGB(100, 240, 180)
            or Color3.fromRGB(255, 166, 75)
        dot.Size = UDim2.fromOffset(item.Model == target and 11 or 7,
            item.Model == target and 11 or 7)
        dot.Visible = true
    end
    for index = math.min(30, #nearby) + 1, #self.Dots do
        self.Dots[index].Visible = false
    end
    self.Footer.Text = tostring(#nearby) .. " Dhab | " .. tostring(range) .. " studs"
end

function Radar:Start()
    if self.Connection then return end
    self.Connection = RunService.Heartbeat:Connect(function(dt)
        self.Accumulator = self.Accumulator + dt
        if self.Accumulator < (self.Settings.PerformanceMode and 0.75 or 0.25) then return end
        self.Accumulator = 0
        local ok, err = pcall(self.Update, self)
        if not ok then warn("[IVORY RADAR] " .. tostring(err)) end
    end)
end

function Radar:Destroy()
    if self.Connection then self.Connection:Disconnect() end
    self.Connection = nil
    if self.Gui then self.Gui:Destroy() end
    table.clear(self.Dots)
end

return Radar