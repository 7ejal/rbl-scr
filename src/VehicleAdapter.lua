-- 7jl vehicle adapters: inspect replicated/local control values, no remote calls.
-- "Value" backend is opt-in and only writes typed local NumberValue controls.
local VehicleAdapter={}
VehicleAdapter.__index=VehicleAdapter
local function profile(car)
    for _,name in ipairs({"CarType","VehicleType","ModelName"}) do
        local v=car:GetAttribute(name)
        if type(v)=="string" and #v>0 and #v<=100 then return v end
    end
    return car.Name
end
local function find(car,name)
    local folder=car:FindFirstChild("Controls",true) or car:FindFirstChild("Input",true)
    if not folder then return nil end
    local value=folder:FindFirstChild(name)
    return value and value:IsA("NumberValue") and value or nil
end
function VehicleAdapter.new()
    return setmetatable({Car=nil,Throttle=nil,Steer=nil,Mode="None",Last="No adapter selected"},VehicleAdapter)
end
function VehicleAdapter:Inspect(car,seat)
    if not car then return "No owned car" end
    local lines={"Car: "..car.Name, "Type: "..profile(car),
        "Seat: "..tostring(seat and seat.ClassName or "none")}
    for _,n in ipairs({"A-Chassis Tune","A-Chassis Interface","Drive","Controls","Input","Transmission"}) do
        local found=car:FindFirstChild(n,true)
        if found then table.insert(lines,n..": "..found.ClassName) end
    end
    local t,st=find(car,"Throttle"),find(car,"Steer")
    if t and st then
        table.insert(lines,"Local typed Controls: NumberValue Throttle + Steer")
    else
        table.insert(lines,"Local typed Controls: not found; no custom adapter enabled")
    end
    table.insert(lines,"Adapters: Keyboard, VehicleSeat and opt-in typed Controls")
    table.insert(lines,"Script source and server remotes are not inspected/executed")
    return table.concat(lines,"\n")
end
function VehicleAdapter:Available(car)
    local throttle,steer=find(car,"Throttle"),find(car,"Steer")
    return throttle~=nil and steer~=nil
end
function VehicleAdapter:Apply(car,seat,throttle,steer)
    local Players=game:GetService("Players")
    local char=Players.LocalPlayer.Character
    local human=char and char:FindFirstChildOfClass("Humanoid")
    if not seat or not human or human.SeatPart~=seat or seat.Occupant~=human
        or not car or not seat:IsDescendantOf(car) then
        self:Stop()
        return false,"Driver seat invalid"
    end
    local t,st=find(car,"Throttle"),find(car,"Steer")
    if not t or not st then return false,"Controls NumberValues not present" end
    self.Car=car;self.Throttle=t;self.Steer=st
    local ok,err=pcall(function()
        t.Value=math.clamp(throttle,-1,1)
        st.Value=math.clamp(steer,-1,1)
    end)
    self.Mode="ControlsValue"
    self.Last=ok and "Typed local controls written (motion unverified)" or tostring(err)
    if not ok then self:Stop() end
    return ok,self.Last
end
function VehicleAdapter:Stop()
    if self.Throttle and self.Throttle.Parent then
        pcall(function()self.Throttle.Value=0 end)
    end
    if self.Steer and self.Steer.Parent then
        pcall(function()self.Steer.Value=0 end)
    end
    self.Car=nil;self.Throttle=nil;self.Steer=nil
end
return VehicleAdapter