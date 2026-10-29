-- Read-only local gear and transmission inspection. Never auto-shifts.
local Gear={}
Gear.__index=Gear
local KEYS={"CurrentGear","SelectedGear","Gear","GearPosition","TransmissionGear",
"TransmissionMode","ShiftMode","PRND","GearIndex","GearState"}
local function collect(obj,label,lines)
    if not obj then return end
    for _,key in ipairs(KEYS) do
        local attribute=obj:GetAttribute(key)
        if attribute~=nil then
            table.insert(lines,label.." attribute "..key.." = "..tostring(attribute))
        end
        local v=obj:FindFirstChild(key,true)
        if v and v:IsA("ValueBase") then
            table.insert(lines,label.." ValueBase "..key.." = "..tostring(v.Value))
        end
    end
end
function Gear.new() return setmetatable({Last="Not inspected"},Gear) end
function Gear:Inspect(car,seat)
    local lines={"7jl GEAR / TRANSMISSION","Gear state is read-only"}
    collect(seat,"Seat",lines)
    collect(car,"Car",lines)
    if #lines==2 then
        table.insert(lines,"No replicated gear state found")
        table.insert(lines,"HUD 'N' may mean Neutral; verify manually")
    end
    if seat and seat:IsA("VehicleSeat") then
        table.insert(lines,string.format(
            "VehicleSeat ThrottleFloat %.2f, SteerFloat %.2f",
            seat.ThrottleFloat,seat.SteerFloat))
    end
    self.Last=table.concat(lines,"\n")
    return self.Last
end
return Gear