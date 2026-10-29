-- Small live hunt readout and off-screen target arrow, independent of menu.
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local HUD={}
HUD.__index=HUD
local function new(kind,parent,props)
    local v=Instance.new(kind)
    for k,x in pairs(props) do v[k]=x end
    v.Parent=parent;return v
end
function HUD.new(settings,guiParent,getHunt)
    local gui=new("ScreenGui",guiParent,{
        Name="IVORY_HuntHUD",ResetOnSpawn=false,DisplayOrder=996,
        IgnoreGuiInset=false,
    })
    local panel=new("Frame",gui,{
        Name="CompactHuntHUD",
        Size=UDim2.fromOffset(292,104),
        Position=UDim2.new(0.5,-146,0,6),
        BackgroundColor3=Color3.fromRGB(17,17,22),
        BackgroundTransparency=0.15,BorderSizePixel=0,Visible=false,
    })
    new("UICorner",panel,{CornerRadius=UDim.new(0,8)})
    local text=new("TextLabel",panel,{
        Position=UDim2.fromOffset(9,5),
        Size=UDim2.fromOffset(274,93),
        BackgroundTransparency=1,TextColor3=Color3.fromRGB(236,238,247),
        TextSize=12,Font=Enum.Font.Code,
        TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Top,Text="7jl | Hunt off",
    })
    local arrow=new("TextLabel",gui,{
        Name="OffscreenDhabPointer",
        BackgroundColor3=Color3.fromRGB(29,29,40),
        BackgroundTransparency=0.15,
        Size=UDim2.fromOffset(145,28),
        AnchorPoint=Vector2.new(0.5,0.5),Visible=false,
        Font=Enum.Font.GothamBold,TextSize=12,
        TextColor3=Color3.fromRGB(255,190,91),
        Text="DHAB",TextTruncate=Enum.TextTruncate.AtEnd,
    })
    new("UICorner",arrow,{CornerRadius=UDim.new(0,7)})
    return setmetatable({
        Settings=settings,Gui=gui,Panel=panel,Label=text,
        Arrow=arrow,GetHunt=getHunt,Connection=nil,Timer=0,
    },HUD)
end
function HUD:Update()
    local settings=self.Settings
    self.Panel.Visible=settings.HuntHUDEnabled==true
    local hunt=self.GetHunt and self.GetHunt() or nil
    local target=hunt and hunt.Target or nil
    self.Arrow.Visible=false
    local camera=workspace.CurrentCamera
    if not camera then return end
    if not target or not target:IsDescendantOf(workspace) then
        if self.Panel.Visible then
            self.Label.Text="7jl HUNT\n"..tostring(hunt and hunt.Status or "OFF")
        end
        return
    end
    local root=target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart",true)
    if not root then return end
    local c=Players.LocalPlayer.Character
    local playerRoot=c and c:FindFirstChild("HumanoidRootPart")
    local origin=playerRoot and playerRoot.Position or camera.CFrame.Position
    local distance=(root.Position-origin).Magnitude
    local vehicle=hunt.Vehicle
    if self.Panel.Visible then
        local tier=target:GetAttribute("Tier") or "?"
        local length=target:GetAttribute("Length")
        local scale=target:GetAttribute("Scale")
        local meters=(vehicle and vehicle.Seat)
            and string.format("%.0f km/h",vehicle.LastSpeedKmh or 0)
            or "on foot"
        self.Label.Text=string.format(
            "7jl | %s\nTier %s | Length %s | Size %s\n"
                .. "%.0f studs | %s\n%s",
            target.Name,tostring(tier),
            type(length)=="number" and string.format("%.2f",length) or "?",
            type(scale)=="number" and string.format("%.2fx",scale) or "?",
            distance,meters,tostring(hunt.Status):sub(1,52))
    end

    if not settings.TargetArrowEnabled then return end
    local projected,onScreen=camera:WorldToViewportPoint(root.Position)
    local width,height=camera.ViewportSize.X,camera.ViewportSize.Y
    if width<200 or height<200 then return end
    local inside=onScreen and projected.Z>0
        and projected.X>90 and projected.X<width-90
        and projected.Y>70 and projected.Y<height-70
    if inside then return end
    local center=Vector2.new(width/2,height/2)
    local delta=Vector2.new(projected.X-center.X,projected.Y-center.Y)
    if projected.Z<=0 then delta=-delta end
    if delta.Magnitude<0.001 then delta=Vector2.new(0,-1) end
    local direction=delta.Unit
    local dx=direction.X~=0 and (width/2-90)/math.abs(direction.X) or math.huge
    local dy=direction.Y~=0 and (height/2-65)/math.abs(direction.Y) or math.huge
    local p=center+direction*math.min(dx,dy)
    local angle=math.atan2(direction.Y,direction.X)
    local glyph=math.abs(direction.X)>math.abs(direction.Y)
        and (direction.X>0 and ">" or "<")
        or (direction.Y>0 and "v" or "^")
    self.Arrow.Position=UDim2.fromOffset(p.X,p.Y)
    self.Arrow.Text=("%s %s | %.0f"):format(glyph,tostring(target:GetAttribute("Tier") or "Dhab"),distance)
    self.Arrow.Visible=true
end
function HUD:Start()
    if self.Connection then return end
    self.Connection=RunService.Heartbeat:Connect(function(dt)
        self.Timer=self.Timer+dt
        if self.Timer<(self.Settings.PerformanceMode and 0.5 or 0.2) then return end
        self.Timer=0
        local ok,err=pcall(self.Update,self)
        if not ok then warn("[7jl HUD] "..tostring(err)) end
    end)
end
function HUD:Destroy()
    if self.Connection then self.Connection:Disconnect() end
    self.Connection=nil
    if self.Gui then self.Gui:Destroy() end
end
return HUD