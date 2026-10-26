-- Driver-only Dhab car autopilot using real WASD input where supported.
-- Supports Seat and VehicleSeat, but only when occupied by LocalPlayer.
-- Never teleports, forces seat ownership, or fires remote events.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local Car={}
Car.__index=Car
local BIND="IVORY_VehicleHuntInput"

local function human()
    local c=Players.LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function flat(v)
    return Vector3.new(v.X,0,v.Z)
end
function Car.new(settings,inputClass)
    return setmetatable({
        Settings=settings, Input=inputClass.new(),
        Running=false, Seat=nil, Vehicle=nil, Humanoid=nil, Target=nil,
        Goal=nil, LastIntent=0, LastStatus="Waiting for car",
        LastProgress=os.clock(), LastPos=nil, RecoveryUntil=0,
        Recoveries=0, Commands={}, UnreachableSignal=false,
    },Car)
end
function Car:FindCar(seat,h)
    if not seat or not (seat:IsA("Seat") or seat:IsA("VehicleSeat"))
        or not h or h.Health<=0
        or h.SeatPart~=seat or seat.Occupant~=h then return nil end
    local root=workspace:FindFirstChild(self.Settings.CarsFolderName or "PlayersCars")
    if not root then return nil end
    local model=seat
    while model and model.Parent~=root do model=model.Parent end
    if model and model:IsA("Model") and model.Parent==root then return model end
    return nil
end
function Car:IsDriving()
    local h=human()
    local seat=h and h.SeatPart
    local model=self:FindCar(seat,h)
    return model~=nil,seat,model,h
end
function Car:Neutralize(seat)
    if seat and seat.Parent and seat:IsA("VehicleSeat") then
        pcall(function() seat.ThrottleFloat=0;seat.SteerFloat=0 end)
    end
end
function Car:InputReleaseManual()
    self.Input:ReleaseAll()
    self:Neutralize(self.Seat)
end
function Car:Stop()
    self.Input:ReleaseAll()
    self:Neutralize(self.Seat)
    self.Seat=nil;self.Vehicle=nil;self.Humanoid=nil
    self.Target=nil;self.Goal=nil;self.LastIntent=0
    self.Commands={};self.LastPos=nil
    self.LastStatus="Vehicle stopped; controls released"
end
function Car:Drive(seat,model,h,target,goal)
    if not self.Running or not self.Settings.AutoHuntEnabled
        or not self.Settings.HuntCarEnabled or self:FindCar(seat,h)~=model
        or not target or not target:IsDescendantOf(workspace) then
        self:Stop();return false
    end
    if self.Seat~=seat then
        self:Stop();self.Seat=seat
        self.LastProgress=os.clock();self.Recoveries=0
    end
    self.Vehicle=model;self.Humanoid=h
    self.Target=target;self.Goal=goal;self.LastIntent=os.clock()
    return true
end
function Car:ObstacleAhead(seat,model,speed)
    local direction=flat(seat.CFrame.LookVector)
    if direction.Magnitude<0.01 then return true end
    local range=math.clamp(speed*1.4+12,18,54)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    local c=Players.LocalPlayer.Character
    params.FilterDescendantsInstances=c and {model,c} or {model}
    params.IgnoreWater=true
    local origin=seat.Position+Vector3.new(0,2.2,0)
    -- Front, left, and right safety rays.
    local vectors={
        direction.Unit,
        (direction.Unit+flat(seat.CFrame.RightVector)*0.36).Unit,
        (direction.Unit-flat(seat.CFrame.RightVector)*0.36).Unit,
    }
    for _,unit in ipairs(vectors) do
        local result=workspace:Raycast(origin,unit*range,params)
        if result then
            -- Terrain at ground height is expected. Ignore it only if
            -- clearly below the vehicle body; never ignore walls/objects.
            if not (result.Instance==workspace.Terrain
                and result.Position.Y<seat.Position.Y-1.8) then
                return true
            end
        end
    end
    return false
end
function Car:ManualInput()
    if UIS:GetFocusedTextBox() then return true end
    if not self.Settings.HuntPauseOnManualMove then return false end
    -- Keypress-generated states may appear in IsKeyDown; discount only keys
    -- the controller knows it owns. F8 always overrides regardless.
    for _,k in ipairs({"W","A","S","D"}) do
        if UIS:IsKeyDown(Enum.KeyCode[k]) and not self.Input:Holding(k) then
            return true
        end
    end
    for _,k in ipairs({Enum.KeyCode.Up,Enum.KeyCode.Down,
        Enum.KeyCode.Left,Enum.KeyCode.Right}) do
        if UIS:IsKeyDown(k) then return true end
    end
    return false
end
function Car:Step()
    local s=self.Settings
    if not self.Running or not s.AutoHuntEnabled or not s.HuntCarEnabled
        or not self.Seat or not self.Goal or not self.Target
        or os.clock()-self.LastIntent>0.9 then
        if self.Seat then self:Stop() end
        return
    end
    local h=human()
    if h~=self.Humanoid or self:FindCar(self.Seat,h)~=self.Vehicle
        or not self.Target:IsDescendantOf(workspace) then
        self:Stop();return
    end
    if self:ManualInput() then
        self.Input:ReleaseAll()
        self:Neutralize(self.Seat)
        self.LastStatus="Manual driving; autopilot paused"
        return
    end
    local seat=self.Seat
    local delta=flat(self.Goal-seat.Position)
    local dist=delta.Magnitude
    local velocity=flat(seat.AssemblyLinearVelocity)
    local speed=velocity.Magnitude
    local cap=math.clamp(s.HuntCarMaxSpeed or 32,8,90)
    local stopDist=math.clamp(s.HuntCarStopDistance or 48,25,125)
    local buffer=math.clamp(speed*1.35,8,65)
    local keys={}
    local mode=s.HuntCarInputMode or "Keyboard"
    if mode~="Keyboard" and mode~="Seat" then mode="Keyboard" end

    if dist<=stopDist+buffer then
        self.LastStatus="Braking near Dhab"
    elseif dist>0.1 then
        local f=flat(seat.CFrame.LookVector)
        local right=flat(seat.CFrame.RightVector)
        if f.Magnitude>0.1 and right.Magnitude>0.1 then
            local dir=delta.Unit
            local angle=math.atan2(dir:Dot(right.Unit),dir:Dot(f.Unit))
            if s.HuntCarInvertSteering then angle=-angle end
            local turn=math.clamp(s.HuntCarTurnDeadzone or 0.13,0.05,0.5)
            if angle>turn then keys.D=true
            elseif angle < -turn then keys.A=true end
            local desiredSpeed=cap*math.clamp(1-math.abs(angle)/math.pi,0.25,1)
            if speed<desiredSpeed then keys.W=true end
            local blocked=self:ObstacleAhead(seat,self.Vehicle,speed)
            if blocked then
                keys.W=nil
                self.LastStatus="Obstacle ahead: slowing"
            else
                self.LastStatus="Car hunting via "..mode
            end
        end
    end
    if self.LastPos and (flat(seat.Position-self.LastPos)).Magnitude>=5 then
        self.LastPos=seat.Position;self.LastProgress=os.clock()
        self.Recoveries=0
    elseif not self.LastPos then
        self.LastPos=seat.Position;self.LastProgress=os.clock()
    elseif os.clock()-self.LastProgress>5 and dist>stopDist+buffer then
        self.LastProgress=os.clock()
        self.Recoveries=self.Recoveries+1
        if self.Recoveries>2 then
            self.UnreachableSignal=true
            self:Stop()
            self.LastStatus="Car stuck repeatedly; skip target"
            return
        end
        self.RecoveryUntil=os.clock()+0.65
    end
    if os.clock()<self.RecoveryUntil then
        keys={S=true}
        self.LastStatus="Short reverse to unstick"
    end
    if mode=="Seat" then
        self.Input:ReleaseAll()
        if not seat:IsA("VehicleSeat") then
            self.LastStatus="Seat mode requires VehicleSeat; select Keyboard"
            return
        end
        local steer=(keys.D and 1 or 0)-(keys.A and 1 or 0)
        local throttle=(keys.W and 1 or 0)-(keys.S and 1 or 0)
        pcall(function()seat.SteerFloat=steer;seat.ThrottleFloat=throttle end)
    else
        self:Neutralize(seat)
        local ok,err=self.Input:Set(keys)
        if not ok then
            self.LastStatus="WASD unavailable: "..tostring(err)
            self.Input:ReleaseAll()
        end
    end
end
function Car:Start()
    if self.Running then return end
    self.Running=true
    RunService:BindToRenderStep(BIND,
        Enum.RenderPriority.Camera.Value+2,function()
            local ok,err=pcall(self.Step,self)
            if not ok then
                self:Stop()
                self.LastStatus="Car input error: "..tostring(err):sub(1,90)
            end
        end)
end
function Car:Destroy()
    self.Running=false
    RunService:UnbindFromRenderStep(BIND)
    self:Stop()
    self.Input:Destroy()
end
return Car