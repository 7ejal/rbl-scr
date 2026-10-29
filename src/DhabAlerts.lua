-- Live Dhab only; bounded notifications, actual Tier and Length attributes.
local Alert={}
Alert.__index=Alert
function Alert.new(settings,tracker,onAlert)
    return setmetatable({
        Settings=settings,Tracker=tracker,OnAlert=onAlert,
        Seen=setmetatable({}, {__mode="k"}),Messages={},Last="No alerts",
        Acc=0,
    },Alert)
end
function Alert:Update(dt)
    self.Acc=self.Acc+(dt or 0)
    if self.Acc<2 then return end
    self.Acc=0
    if not self.Settings.DhabAlertsEnabled then return end
    local count=0
    for model,category in pairs(self.Tracker.Known) do
        if category=="monster" and self.Tracker:IsDhab(model)
            and model:IsDescendantOf(workspace) and not self.Seen[model] then
            self.Seen[model]=true
            local tier=model:GetAttribute("Tier")
            local number=type(tier)=="string" and tonumber(tier:match("^T(%d+)$")) or nil
            local length=model:GetAttribute("Length")
            local threshold=math.clamp(self.Settings.DhabAlertTier or 3,1,6)
            local minimum=math.clamp(self.Settings.DhabAlertLength or 5,0,15)
            if (number and number>=threshold)
                or (type(length)=="number" and length>=minimum) then
                local message=("%s | Tier %s | Length %s studs"):format(
                    model.Name,tostring(tier or "?"),
                    type(length)=="number" and string.format("%.2f",length) or "?")
                self.Last=message
                table.insert(self.Messages,message)
                while #self.Messages>15 do table.remove(self.Messages,1) end
                if self.OnAlert then pcall(self.OnAlert,message) end
                count=count+1
                if count>=3 then break end -- avoid notification flood
            end
        end
    end
end
function Alert:Report()
    return "Recent live-Dhab alerts:\n"..table.concat(self.Messages,"\n")
end
return Alert