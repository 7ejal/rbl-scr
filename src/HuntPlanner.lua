-- Verified client attributes only; plan and avoid unsafe/undesired locations.
local Planner={}
Planner.__index=Planner
function Planner.new(settings)
    return setmetatable({
        Settings=settings, Zones={}, Route={}, RouteUpdated=0,
        LastSelection=nil, LastCandidates=0,
    },Planner)
end
function Planner:AddZone(origin)
    if typeof(origin)~="Vector3" then return false end
    if #self.Zones>=20 then table.remove(self.Zones,1) end
    table.insert(self.Zones,origin)
    self.Route={}
    return true
end
function Planner:ClearZones()
    table.clear(self.Zones);table.clear(self.Route)
end
function Planner:IsBlocked(position)
    local radius=math.clamp(self.Settings.HuntAvoidRadius or 110,20,350)
    for _,zone in ipairs(self.Zones) do
        if (Vector3.new(zone.X,0,zone.Z)
            - Vector3.new(position.X,0,position.Z)).Magnitude<radius then
            return true
        end
    end
    return false
end
function Planner:Score(model,distance)
    local s=self.Settings
    local length=tonumber(model:GetAttribute("Length")) or 0
    local scale=tonumber(model:GetAttribute("Scale")) or 0
    return (length*math.clamp(s.HuntScoreLength or 3,0,10))
        +(scale*math.clamp(s.HuntScoreSize or 3,0,10))
        -distance*math.clamp(s.HuntScoreDistance or 0.08,0,0.5)
end
function Planner:BuildRoute(items,origin)
    local queue={}
    for _,item in ipairs(items) do table.insert(queue,item) end
    local current=origin
    local route={}
    -- Greedy nearest-neighbor walk through 12 best candidate objects.
    while #queue>0 and #route<12 do
        local index=1;local best=math.huge
        for i,item in ipairs(queue) do
            local d=(item.Position-current).Magnitude
            if d<best then best=d;index=i end
        end
        local chosen=table.remove(queue,index)
        table.insert(route,chosen.Model)
        current=chosen.Position
    end
    self.Route=route
    self.RouteUpdated=os.clock()
end
function Planner:Select(origin,known,valid)
    local all={}
    for model,category in pairs(known) do
        if category=="monster" then
            local pos,dist=valid(model,origin)
            if pos and not self:IsBlocked(pos) then
                table.insert(all,{
                    Model=model,Position=pos,Distance=dist,
                    Score=self:Score(model,dist),
                })
            end
        end
    end
    self.LastCandidates=#all
    if #all==0 then
        self.Route={};return nil
    end
    local settings=self.Settings
    local priority=settings.HuntPriority or "Closest"
    table.sort(all,function(a,b)
        if priority=="Smart" then
            if a.Score~=b.Score then return a.Score>b.Score end
        elseif priority=="Longest" then
            local x=tonumber(a.Model:GetAttribute("Length")) or 0
            local y=tonumber(b.Model:GetAttribute("Length")) or 0
            if x~=y then return x>y end
        elseif priority=="Largest" then
            local x=tonumber(a.Model:GetAttribute("Scale")) or 0
            local y=tonumber(b.Model:GetAttribute("Scale")) or 0
            if x~=y then return x>y end
        end
        return a.Distance<b.Distance
    end)
    if not settings.HuntRouteEnabled then
        self.LastSelection=all[1].Model
        return all[1].Model
    end
    -- Prefer a route among the highest-scoring candidates. When reaching
    -- a target or losing it, keep the rest of the route instead of reranking.
    local present={}
    for _,item in ipairs(all) do present[item.Model]=true end
    while #self.Route>0 and not present[self.Route[1]] do
        table.remove(self.Route,1)
    end
    if #self.Route==0 or os.clock()-self.RouteUpdated>40 then
        local shortlist={}
        for i=1,math.min(12,#all) do
            table.insert(shortlist,all[i])
        end
        self:BuildRoute(shortlist,origin)
    end
    self.LastSelection=self.Route[1]
    return self.LastSelection
end
function Planner:Completed(model)
    if self.Route[1]==model then table.remove(self.Route,1) end
end
function Planner:Describe()
    return ("Candidate Dhab: %d | Route: %d | Blocked zones: %d")
        :format(self.LastCandidates,#self.Route,#self.Zones)
end
return Planner