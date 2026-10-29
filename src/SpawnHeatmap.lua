-- Session observations, NOT guaranteed actual server spawn events.
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local Heatmap={}
Heatmap.__index=Heatmap
local function node(kind,parent,props)
    local v=Instance.new(kind)
    for k,x in pairs(props) do v[k]=x end
    v.Parent=parent
    return v
end
function Heatmap.new(settings,tracker,playerGui)
    local gui=node("ScreenGui",playerGui,{
        Name="IVORY_SpawnObservations",ResetOnSpawn=false,DisplayOrder=995,
    })
    local panel=node("Frame",gui,{
        Size=UDim2.fromOffset(206,232),
        Position=UDim2.new(1,-220,0,146),
        BackgroundColor3=Color3.fromRGB(16,17,24),
        BackgroundTransparency=0.08,Visible=false,
    })
    node("UICorner",panel,{CornerRadius=UDim.new(0,9)})
    local head=node("TextLabel",panel,{
        Position=UDim2.fromOffset(8,4),Size=UDim2.fromOffset(193,25),
        BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=12,
        Text="OBSERVED DHAB AREAS",TextColor3=Color3.new(1,1,1),
        TextXAlignment=Enum.TextXAlignment.Left,
    })
    local cells={}
    for y=1,8 do
        for x=1,8 do
            local cell=node("Frame",panel,{
                Position=UDim2.fromOffset(9+(x-1)*23,34+(y-1)*20),
                Size=UDim2.fromOffset(21,18),BorderSizePixel=0,
                BackgroundColor3=Color3.fromRGB(43,44,54),
            })
            cells[(y-1)*8+x]=cell
        end
    end
    local foot=node("TextLabel",panel,{
        Position=UDim2.fromOffset(7,199),Size=UDim2.fromOffset(194,28),
        BackgroundTransparency=1,Font=Enum.Font.Gotham,
        TextSize=11,TextColor3=Color3.fromRGB(200,202,214),
        Text="No observations yet",TextXAlignment=Enum.TextXAlignment.Left,
    })
    return setmetatable({
        Settings=settings,Tracker=tracker,Gui=gui,Panel=panel,Cells=cells,
        Foot=foot,Seen=setmetatable({}, {__mode="k"}),Counts={},
        Total=0,Accumulator=0,Connection=nil,
    },Heatmap)
end
local function cellKey(position,size)
    local x=math.floor(position.X/size)
    local z=math.floor(position.Z/size)
    return x..":"..z,x,z
end
function Heatmap:Update()
    self.Panel.Visible=self.Settings.HeatmapEnabled==true
    if not self.Panel.Visible then return end
    local size=math.clamp(self.Settings.HeatmapCellSize or 150,50,350)
    for model,category in pairs(self.Tracker.Known) do
        if category=="monster" and self.Tracker:IsDhab(model)
            and model:IsDescendantOf(workspace) and not self.Seen[model] then
            local root=model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart",true)
            if root then
                self.Seen[model]=true
                local key=cellKey(root.Position,size)
                self.Counts[key]=(self.Counts[key] or 0)+1
                self.Total=self.Total+1
            end
        end
    end
    local char=Players.LocalPlayer.Character
    local part=char and char:FindFirstChild("HumanoidRootPart")
    if not part then return end
    local _,cx,cz=cellKey(part.Position,size)
    local maxCount=1
    local raw={}
    for y=1,8 do for x=1,8 do
        local key=(cx+x-4)..":"..(cz+y-4)
        local count=self.Counts[key] or 0
        raw[(y-1)*8+x]=count
        maxCount=math.max(maxCount,count)
    end end
    for i,cell in ipairs(self.Cells) do
        local count=raw[i]
        local ratio=count/maxCount
        cell.BackgroundColor3=count==0 and Color3.fromRGB(43,44,54)
            or Color3.fromRGB(
                math.floor(60+195*ratio),
                math.floor(110-40*ratio),
                math.floor(48+23*ratio))
    end
    self.Foot.Text=("%d unique Dhab observed | %d-stud cells"):format(self.Total,size)
end
function Heatmap:Start()
    if self.Connection then return end
    self.Connection=RunService.Heartbeat:Connect(function(dt)
        self.Accumulator=self.Accumulator+dt
        if self.Accumulator<4 then return end
        self.Accumulator=0
        local ok,err=pcall(self.Update,self)
        if not ok then warn("[7jl Heatmap] "..tostring(err)) end
    end)
end
function Heatmap:Reset()
    self.Seen=setmetatable({}, {__mode="k"})
    table.clear(self.Counts)
    self.Total=0
end
function Heatmap:Destroy()
    if self.Connection then self.Connection:Disconnect() end
    self.Connection=nil
    if self.Gui then self.Gui:Destroy() end
end
return Heatmap