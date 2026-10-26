-- Read-only detection of owned replicated DhabCatches; not a confirmed
-- server-acknowledged capture count. Only count explicit owner attribution.
local Players=game:GetService("Players")
local Watch={}
Watch.__index=Watch
function Watch.new(settings)
    return setmetatable({
        Settings=settings, Observed={}, ObservedCount=0,
        Latest="Not checked", Owned=0, Capacity=nil, Used=nil,
    },Watch)
end
local OWNER_KEYS={"OwnerUserId","OwnerId","PlayerUserId","UserId"}
function Watch:Owner(obj)
    for _,key in ipairs(OWNER_KEYS) do
        local value=obj:GetAttribute(key)
        if tonumber(value)==Players.LocalPlayer.UserId then return true end
    end
    return false
end
local function numericAttr(obj,keys)
    if not obj then return nil end
    for _,key in ipairs(keys) do
        local v=obj:GetAttribute(key)
        if type(v)=="number" then return v end
    end
    return nil
end
function Watch:Update()
    local folder=workspace:FindFirstChild("DhabCatches")
    local owned=0
    local current={}
    if folder then
        for _,obj in ipairs(folder:GetChildren()) do
            if obj:IsA("Model") and self:Owner(obj) then
                owned=owned+1
                local id=obj:GetAttribute("Uid") or obj.Name
                current[tostring(id)]=true
                if not self.Observed[tostring(id)] then
                    self.Observed[tostring(id)]=true
                    self.ObservedCount=self.ObservedCount+1
                end
            end
        end
    end
    self.Owned=owned
    local player=Players.LocalPlayer
    local inventory=player:FindFirstChild("Inventory")
    self.Capacity=numericAttr(inventory,{"Capacity","MaxCapacity","MaxSlots"})
        or numericAttr(player,{"InventoryCapacity","MaxDhabCatches"})
    self.Used=numericAttr(inventory,{"Used","Count","SlotsUsed"})
        or numericAttr(player,{"InventoryUsed","DhabCount"})
    self.Latest=string.format(
        "Owned replicated DhabCatches now: %d\nNew owned IDs observed: %d\n"
        .. "Inventory usage: %s / %s\n"
        .. "Capture validation: not confirmed by server event",
        self.Owned,self.ObservedCount,tostring(self.Used or "unknown"),
        tostring(self.Capacity or "unknown"))
end
function Watch:Describe()
    return self.Latest
end
return Watch