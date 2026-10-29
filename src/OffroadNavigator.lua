-- Terrain-aware, client-side short waypoint selection for vehicles.
-- Does not teleport or bypass the chassis physics.
local Nav={}
Nav.__index=Nav
local function flat(v) return Vector3.new(v.X,0,v.Z) end
function Nav.new(settings)
    return setmetatable({Settings=settings,LastStatus="Direct",Waypoints=0,
        LastOrigin=nil,LastDestination=nil,LastDecision=nil,LastCheck=0},Nav)
end
local function clearLine(from,to,ignores)
    local p=RaycastParams.new()
    p.FilterType=Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances=ignores
    p.RespectCanCollide=true
    local d=to-from
    if d.Magnitude<1 then return true end
    local result=workspace:Raycast(from,d,p)
    if not result then return true end
    if result.Normal.Y>0.6 and result.Position.Y<from.Y+0.5 then
        return true
    end
    return false
end
local function safeGround(candidate,car,character,target)
    local p=RaycastParams.new()
    p.FilterType=Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances=character and {car,character,target}
        or {car,target}
    p.RespectCanCollide=true
    local hit=workspace:Raycast(candidate+Vector3.new(0,15,0),
        Vector3.new(0,-40,0),p)
    if not hit or hit.Normal.Y<0.66 then return false end
    local h=math.abs(hit.Position.Y-candidate.Y)
    return h<=9
end
function Nav:Approach(seat,car,target,destination)
    if not self.Settings.HuntOffroadEnabled then
        self.LastStatus="Offroad assist OFF";return destination
    end
    local origin=seat.Position
    if self.LastOrigin and self.LastDestination
        and (origin-self.LastOrigin).Magnitude<6
        and (destination-self.LastDestination).Magnitude<10
        and os.clock()-self.LastCheck<0.4 then
        return self.LastDecision
    end
    self.LastOrigin=origin;self.LastDestination=destination
    self.LastCheck=os.clock()
    local toward=flat(destination-origin)
    if toward.Magnitude<4 then return destination end
    local character=game:GetService("Players").LocalPlayer.Character
    local ignores=character and {car,character,target} or {car,target}
    local from=origin+Vector3.new(0,3,0)
    local checkDistance=math.min(85,toward.Magnitude)
    local direct=from+toward.Unit*checkDistance
    if clearLine(from,direct,ignores) then
        self.LastStatus="Direct route clear";self.LastDecision=destination
        return destination
    end
    local right=Vector3.new(-toward.Z,0,toward.X).Unit
    -- Sample short offset approaches; do not drive into steep slopes.
    for _,side in ipairs({1,-1,2,-2}) do
        local candidate=origin+toward.Unit*math.min(42,toward.Magnitude*0.6)
            +right*side*22
        if safeGround(candidate,car,character,target)
            and clearLine(from,candidate+Vector3.new(0,3,0),ignores) then
            self.Waypoints=self.Waypoints+1
            self.LastStatus="Avoiding obstacle via side approach"
            self.LastDecision=candidate
            return candidate
        end
    end
    self.LastStatus="No verified safe approach; stopping"
    self.LastDecision=nil
    return nil
end
return Nav