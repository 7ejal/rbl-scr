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
        Cruising=true, LastSpeedKmh=0, TargetSpeedKmh=120,
        NoResponse=false, NoResponseSince=nil, MotionConfirmed=false,
        LastPulseAt=0, UISRecognizesW=false, GearHint="not replicated",
        LastGearCheck=0,
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
local function gearValue(obj)
    if not obj then return nil end
    for _,name in ipairs({"CurrentGear","SelectedGear","Gear","GearPosition",
        "TransmissionGear","TransmissionMode"}) do
        local attribute=obj:GetAttribute(name)
        if attribute~=nil then return name.."="..tostring(attribute) end
        local value=obj:FindFirstChild(name,true)
        if value and value:IsA("ValueBase") then
            return name.."="..tostring(value.Value)
        end
    end
    return nil
end
function Car:CheckGear()
    self.GearHint=gearValue(self.Seat)
        or gearValue(self.Vehicle) or "not replicated"
end
function Car:RetryInput()
    self.Input:ReleaseAll()
    self.NoResponse=false
    self.NoResponseSince=nil
    self.LastPulseAt=0
    self.MotionConfirmed=false
    self.Recoveries=0
    self.RecoveryUntil=0
    self.LastProgress=os.clock()
    self.LastStatus="Retrying car input; check the gear is in Drive"
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
    self.Cruising=true
    self.NoResponse=false
    self.NoResponseSince=nil
    self.MotionConfirmed=false
    self.UISRecognizesW=false
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
        self.Cruising=true
        self.NoResponse=false
        self.NoResponseSince=nil
        self.GearHint="not replicated"
    end
    self.Vehicle=model;self.Humanoid=h
    self.Target=target;self.Goal=goal;self.LastIntent=os.clock()
    return true
end
function Car:ObstacleAhead(seat,model,speed)
    if not self.Settings.HuntCarObstacleBrake then return false end
    local forward=flat(seat.CFrame.LookVector)
    local right=flat(seat.CFrame.RightVector)
    if forward.Magnitude<0.01 or right.Magnitude<0.01 then return false end

    -- Exclude own car/character and Dhab target: chasing the target itself
    -- must never be misdiagnosed as a wall.
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.RespectCanCollide=true
    local ignore={model}
    local c=Players.LocalPlayer.Character
    if c then table.insert(ignore,c) end
    if self.Target then table.insert(ignore,self.Target) end
    params.FilterDescendantsInstances=ignore
    params.IgnoreWater=true

    local length=math.clamp(speed*0.65+15,22,85)
    local origin=seat.Position+Vector3.new(0,2.2,0)
    for _,factor in ipairs({0,0.23,-0.23}) do
        local ray=(forward.Unit+right.Unit*factor).Unit
        local result=workspace:Raycast(origin,ray*length,params)
        if result then
            local height=result.Position.Y-seat.Position.Y
            local slope=result.Normal.Y
            -- Driving over slopes and low ground is normal, not an
            -- obstacle. Ignore low, upward-facing road/terrain hits.
            local traversable=(slope>0.55 and height<2.5)
            if not traversable then return true end
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
        or os.clock()-self.LastIntent>2.0 then
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
    -- Roblox's nominal scale is 0.28 metres per stud, so a 120 km/h
    -- target corresponds to approximately 119 studs/second.
    local speedKmh=speed*0.28*3.6
    local now=os.clock()
    if now-self.LastGearCheck>1.2 then
        self.LastGearCheck=now
        self:CheckGear()
    end
    local targetKmh=math.clamp(s.HuntCarTargetKmh or 120,30,180)
    self.LastSpeedKmh=speedKmh
    self.TargetSpeedKmh=targetKmh
    local stopDist=math.clamp(s.HuntCarStopDistance or 48,25,125)
    -- Leave room to decelerate as speed increases, instead of waiting
    -- until the car is already inside the animal's collision area.
    local buffer=math.clamp(speed*0.65+7,10,85)
    local keys={}
    local mode=s.HuntCarInputMode or "Keyboard"
    if mode~="Keyboard" and mode~="Seat" then mode="Keyboard" end

    if dist<=stopDist+buffer then
        self.Cruising=false
        self.LastStatus=("Near Dhab; coasting at %.0f km/h"):format(speedKmh)
    elseif dist>0.1 then
        local forward=flat(seat.CFrame.LookVector)
        local right=flat(seat.CFrame.RightVector)
        if forward.Magnitude>0.1 and right.Magnitude>0.1 then
            local dir=delta.Unit
            local angle=math.atan2(dir:Dot(right.Unit),dir:Dot(forward.Unit))
            if s.HuntCarInvertSteering then angle=-angle end
            local deadzone=math.clamp(s.HuntCarTurnDeadzone or 0.13,0.05,0.5)
            if angle>deadzone then keys.D=true
            elseif angle < -deadzone then keys.A=true end

            -- A/D can remain held while W stays down; gradual reduction
            -- for sharp turns instead of cutting acceleration to 25%.
            local cornerFactor=math.clamp(
                1-math.abs(angle)/math.pi*0.45,0.55,1)
            local cruiseTarget=targetKmh*cornerFactor

            -- 11 km/h hysteresis prevents rapid W press/release pulsing.
            if self.Cruising then
                if speedKmh>=cruiseTarget+3 then self.Cruising=false end
            elseif speedKmh<=cruiseTarget-8 then
                self.Cruising=true
            end

            local blocked=self:ObstacleAhead(seat,self.Vehicle,speed)
            if blocked then
                keys.W=nil
                self.LastStatus=("Obstacle ahead | %.0f km/h"):format(speedKmh)
            else
                if self.Cruising then keys.W=true end
                self.LastStatus=("%s | %.0f/%.0f km/h%s"):format(
                    mode, speedKmh, targetKmh,
                    keys.W and " | W held" or " | cruising")
            end
        else
            self.LastStatus="Waiting for vehicle heading"
        end
    end

    -- Never interpret a successful pcall(keypress) as proof that the car
    -- received the input. Observe real speed, try pulse and then alternate
    -- backend once, and stop retrying if nothing moves.
    self.UISRecognizesW=UIS:IsKeyDown(Enum.KeyCode.W)
    if mode=="Keyboard" and keys.W then
        if speedKmh>3 then
            self.MotionConfirmed=true
            self.NoResponseSince=nil
            self.NoResponse=false
        elseif not self.MotionConfirmed then
            self.NoResponseSince=self.NoResponseSince or now
            local elapsed=now-self.NoResponseSince
            if elapsed>=9 then
                self.NoResponse=true
                self.Input:ReleaseAll()
                self.LastStatus="No drive response (0 km/h); check gear N / Drive"
                return
            end
        end
    else
        self.NoResponseSince=nil
    end
    if self.NoResponse then
        self.Input:ReleaseAll()
        self.LastStatus="Car not responding: shift into Drive; retry input"
        return
    end

    -- Only perform reverse unstick maneuvers once the car has previously
    -- demonstrated that the selected input backend can actually move it.
    -- Never reverse a stationary car with an unknown gearbox state.
    if not self.MotionConfirmed then
        self.LastProgress=now
        self.Recoveries=0
        self.RecoveryUntil=0
    end
    -- Stuck recovery applies only while we are actively trying to
    -- accelerate; an obstacle pause or coasting is not being stuck.
    if self.LastPos and flat(seat.Position-self.LastPos).Magnitude>=5 then
        self.LastPos=seat.Position
        self.LastProgress=os.clock()
        self.Recoveries=0
    elseif not self.LastPos then
        self.LastPos=seat.Position
        self.LastProgress=os.clock()
    elseif not keys.W then
        self.LastProgress=os.clock()
    elseif self.MotionConfirmed and os.clock()-self.LastProgress>6 then
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
        -- IMPORTANT: do not force VehicleSeat.ThrottleFloat = 0 while W
        -- is injected. The game's keyboard-based chassis may read the
        -- seat's throttle and the previous neutralization cancelled W.
        local ok,err=self.Input:Set(keys)
        if not ok then
            self.LastStatus="WASD unavailable: "..tostring(err)
            self.Input:ReleaseAll()
        elseif keys.W and self.NoResponseSince
            and not self.MotionConfirmed then
            local elapsed=now-self.NoResponseSince
            if elapsed>5 and not self.Input.SwitchedBackend then
                local switched=self.Input:TryAlternate()
                self.LastStatus=switched
                    and "Trying alternate input; waiting for movement"
                    or "No movement: input/gear check needed"
            elseif elapsed>2 and now-self.LastPulseAt>=0.45 then
                self.LastPulseAt=now
                local pulseOk,pulseErr=self.Input:Pulse("W")
                self.LastStatus=pulseOk
                    and ("W re-press probe | %.1fs, 0 km/h"):format(elapsed)
                    or ("Input pulse failed: "..tostring(pulseErr))
            elseif elapsed>1 then
                self.LastStatus=("W sent, no motion for %.1fs | Gear: %s")
                    :format(elapsed,self.GearHint)
            end
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