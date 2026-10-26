-- 7jl car learner: user-initiated observation and cautious low-speed input
-- calibration. Reports only measured motion; never guesses game remotes.
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local Learner={}
Learner.__index=Learner
local function horizontal(v) return Vector3.new(v.X,0,v.Z) end
local function speed(part)
    return part and horizontal(part.AssemblyLinearVelocity).Magnitude or 0
end
local function ownedSeat()
    local c=Players.LocalPlayer.Character
    local h=c and c:FindFirstChildOfClass("Humanoid")
    local seat=h and h.SeatPart
    if not seat or not (seat:IsA("Seat") or seat:IsA("VehicleSeat"))
        or seat.Occupant~=h or h.Health<=0 then return nil end
    local folder=workspace:FindFirstChild("PlayersCars")
    local car=seat
    while car and car.Parent~=folder do car=car.Parent end
    if folder and car and car:IsA("Model") and car.Parent==folder then
        return seat,car,h
    end
    return nil
end
local function carType(car)
    for _,name in ipairs({"CarType","VehicleType","ModelName"}) do
        local v=car:GetAttribute(name)
        if type(v)=="string" and #v>0 and #v<=100 then return v end
    end
    return car.Name
end
local function gear(obj)
    if not obj then return nil end
    for _,n in ipairs({"CurrentGear","SelectedGear","Gear","GearPosition","TransmissionGear"}) do
        local value=obj:GetAttribute(n)
        if value~=nil then return n..": "..tostring(value) end
        local child=obj:FindFirstChild(n,true)
        if child and child:IsA("ValueBase") then
            return n..": "..tostring(child.Value)
        end
    end
    return nil
end
function Learner.new(settings,inputClass)
    return setmetatable({
        Settings=settings,Input=inputClass.new(),Running=false,Cancelled=false,
        Status="Idle - observe manual driving or calibrate stationary",
        Report="",OnUpdate=nil,Generation=0,Results={},ActiveSeat=nil,
    },Learner)
end
function Learner:Tell(line)
    self.Status=line
    if self.OnUpdate then pcall(self.OnUpdate,line) end
end
function Learner:Release()
    self.Input:ReleaseAll()
    if self.ActiveSeat and self.ActiveSeat:IsA("VehicleSeat") then
        pcall(function()
            self.ActiveSeat.ThrottleFloat=0
            self.ActiveSeat.SteerFloat=0
        end)
    end
    self.ActiveSeat=nil
end
function Learner:Cancel()
    self.Generation=self.Generation+1
    self.Cancelled=true
    self.Running=false
    self:Release()
    self:Tell("Calibration/observation cancelled; inputs released")
end
function Learner:Describe()
    return self.Status.."\n"..self.Report
end
function Learner:Observe()
    if self.Running then self:Tell("Already observing/calibrating") return end
    local seat,car=ownedSeat()
    if not seat then self:Tell("Enter your own PlayersCars driver seat first") return end
    if self.Settings.AutoHuntEnabled then
        self:Tell("Turn Auto Hunt OFF before manual drive observation") return
    end
    self.Running=true;self.Cancelled=false;self.Generation=self.Generation+1
    local generation=self.Generation
    self:Tell("Observe manually: drive using W/A/S/D for 8 seconds")
    task.spawn(function()
        local initial=seat.Position
        local top=0
        local keyCounts={W=0,A=0,S=0,D=0}
        local seatControls=0
        local samples=0
        for i=1,40 do
            if self.Generation~=generation then return end
            if ownedSeat()~=seat then
                self.Running=false;self:Tell("Driver seat changed; observation stopped")
                return
            end
            for k in pairs(keyCounts) do
                if UIS:IsKeyDown(Enum.KeyCode[k]) then keyCounts[k]=keyCounts[k]+1 end
            end
            top=math.max(top,speed(seat))
            if seat:IsA("VehicleSeat") and math.abs(seat.ThrottleFloat)>0.1 then
                seatControls=seatControls+1
            end
            samples=samples+1
            task.wait(0.2)
        end
        if self.Generation~=generation then return end
        local traveled=horizontal(seat.Position-initial).Magnitude
        self.Report=string.format(
            "Car: %s | Seat: %s\nTravel: %.1f studs | Peak: %.1f km/h\n"
            .. "UIS W/A/S/D samples: %d/%d/%d/%d (of %d)\n"
            .. "VehicleSeat throttle samples: %d\nReplicated gear: %s\n"
            .. "Observation only: no keyboard/seat input injected",
            car.Name,seat.ClassName,traveled,top*1.008,
            keyCounts.W,keyCounts.A,keyCounts.S,keyCounts.D,
            samples,seatControls,gear(seat) or gear(car) or "unknown"
        )
        self.Running=false;self:Tell("Manual driving observation complete")
    end)
end
local function checkValid(seat,generation,self)
    return self.Generation==generation and self.Settings.AutoHuntEnabled==false
        and ownedSeat()==seat and not UIS:GetFocusedTextBox()
end
function Learner:Calibrate()
    if self.Running then self:Tell("A car test is already running") return end
    local seat,car=ownedSeat()
    if not seat then self:Tell("Enter your own PlayersCars driver seat") return end
    if self.Settings.AutoHuntEnabled then
        self:Tell("Turn Auto Hunt OFF before calibrating") return end
    if speed(seat)>2 then self:Tell("Stop the car first (under 2 studs/s)") return end
    local gearText=(gear(seat) or gear(car) or "unknown"):lower()
    if gearText:match("=%s*n") or gearText:match(":%s*n")
        or gearText:find("neutral",1,true) then
        self:Tell("Replicated transmission appears Neutral; select Drive first")
        return
    end
    self.Running=true;self.Cancelled=false;self.Generation=self.Generation+1
    local generation=self.Generation
    self.ActiveSeat=seat
    self:Tell("Calibration: low-speed forward input test, F8 to cancel")
    task.spawn(function()
        local summary={}
        local winner
        for _,backend in ipairs({"Keyboard","Seat"}) do
            if self.Generation~=generation then return end
            self.ActiveSeat=seat
            if backend=="Seat" and not seat:IsA("VehicleSeat") then
                table.insert(summary,"Seat: unavailable (regular Seat)")
            else
                local startPos=seat.Position
                local beforeSpeed=speed(seat)
                if backend=="Keyboard" then
                    local ok,err=self.Input:Set({W=true})
                    if not ok then
                        table.insert(summary,"Keyboard: "..tostring(err))
                    end
                else
                    pcall(function()seat.ThrottleFloat=0.45 end)
                end
                local maxSpeed=beforeSpeed
                for n=1,12 do
                    if not checkValid(seat,generation,self) then
                        self:Cancel()
                        self:Tell("Calibration cancelled: control/seat changed")
                        return
                    end
                    task.wait(0.1)
                    if self.Generation~=generation then return end
                    maxSpeed=math.max(maxSpeed,speed(seat))
                    if maxSpeed>14 then break end -- ~14 km/h safety ceiling
                end
                self:Release()
                local moved=horizontal(seat.Position-startPos).Magnitude
                local delta=maxSpeed-beforeSpeed
                local worked=moved>2 or delta>2
                table.insert(summary,string.format(
                    "%s: moved %.1f studs, speed +%.1f studs/s%s",
                    backend,moved,delta,worked and " (response)" or " (no response)"))
                if worked then winner=backend;break end
                task.wait(0.5)
            end
        end
        if self.Generation~=generation then return end
        self.Report=table.concat(summary,"\n")
        self.Running=false
        if winner then
            self.Settings.HuntCarProfiles=self.Settings.HuntCarProfiles or {}
            local key=carType(car)
            self.Settings.HuntCarProfiles[key]=winner
            self:Tell("Calibrated "..key.." = "..winner)
        else
            self:Tell("Neither input method moved this car; check gear/chassis")
        end
    end)
end
function Learner:Destroy()
    self:Cancel()
    self.OnUpdate=nil
    self.Input:Destroy()
end
return Learner