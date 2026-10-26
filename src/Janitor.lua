-- Owns RBXScriptConnections and Instances; cleanup is idempotent.
local Janitor = {}
Janitor.__index = Janitor

function Janitor.new()
    return setmetatable({items = {}, cleaned = false}, Janitor)
end

function Janitor:Add(item)
    if self.cleaned then
        if typeof(item) == "RBXScriptConnection" then
            item:Disconnect()
        elseif typeof(item) == "Instance" then
            item:Destroy()
        end
        return item
    end
    table.insert(self.items, item)
    return item
end

function Janitor:Cleanup()
    if self.cleaned then return end
    self.cleaned = true

    for i = #self.items, 1, -1 do
        local item = self.items[i]
        if typeof(item) == "RBXScriptConnection" then
            item:Disconnect()
        elseif typeof(item) == "Instance" then
            item:Destroy()
        end
        self.items[i] = nil
    end
end

return Janitor