-- UI-only explorer; no game remotes, no inferred rarity.
local Players=game:GetService("Players")
local Explorer={}
Explorer.__index=Explorer
local SORTS={"Distance","Length","Size","Tier"}
local function part(m)
    return m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart",true)
end
function Explorer.new(tracker)
    return setmetatable({Tracker=tracker,Sort="Distance",Tier="All",
        Search="",Rows={},Updated=0},Explorer)
end
function Explorer:NextSort()
    local ix=table.find(SORTS,self.Sort) or 0
    self.Sort=SORTS[ix%#SORTS+1];return self.Sort
end
function Explorer:NextTier()
    local tiers={"All","T1","T2","T3","T4","T5","T6"}
    local ix=table.find(tiers,self.Tier) or 0
    self.Tier=tiers[ix%#tiers+1];return self.Tier
end
function Explorer:Query(maxCount)
    local character=Players.LocalPlayer.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    local camera=workspace.CurrentCamera
    local origin=root and root.Position or camera and camera.CFrame.Position
    if not origin then return {} end
    local out={}
    for m,k in pairs(self.Tracker.Known) do
        if k=="monster" and self.Tracker:IsDhab(m)
            and m:IsDescendantOf(workspace) then
            local p=part(m)
            local tier=m:GetAttribute("Tier")
            local name=m.Name
            if p and (self.Tier=="All" or tier==self.Tier)
                and (self.Search=="" or
                    string.find(name:lower(),self.Search:lower(),1,true)) then
                table.insert(out,{
                    Model=m,Name=name,Tier=tostring(tier or "?"),
                    Distance=(p.Position-origin).Magnitude,
                    Length=tonumber(m:GetAttribute("Length")) or 0,
                    Size=tonumber(m:GetAttribute("Scale")) or 0,
                })
            end
        end
    end
    table.sort(out,function(a,b)
        if self.Sort=="Distance" then return a.Distance<b.Distance end
        if self.Sort=="Length" and a.Length~=b.Length then return a.Length>b.Length end
        if self.Sort=="Size" and a.Size~=b.Size then return a.Size>b.Size end
        if self.Sort=="Tier" and a.Tier~=b.Tier then return a.Tier>b.Tier end
        return a.Distance<b.Distance
    end)
    while #out>(maxCount or 20) do table.remove(out) end
    self.Rows=out;self.Updated=os.clock()
    return out
end
return Explorer