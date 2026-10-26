-- Tracks join and leave events without per-player frame connections.
local Players = game:GetService("Players")
local PlayerTracker = {}
PlayerTracker.__index = PlayerTracker

function PlayerTracker.new(localPlayer, onAdd, onRemove)
    return setmetatable({
        LocalPlayer = localPlayer,
        OnAdd = onAdd,
        OnRemove = onRemove,
        Connections = {},
        Started = false,
    }, PlayerTracker)
end

function PlayerTracker:Start()
    if self.Started then return end
    self.Started = true

    table.insert(self.Connections, Players.PlayerAdded:Connect(function(player)
        if player ~= self.LocalPlayer then self.OnAdd(player) end
    end))
    table.insert(self.Connections, Players.PlayerRemoving:Connect(function(player)
        if player ~= self.LocalPlayer then self.OnRemove(player) end
    end))

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= self.LocalPlayer then self.OnAdd(player) end
    end
end

function PlayerTracker:Destroy()
    for _, connection in ipairs(self.Connections) do
        connection:Disconnect()
    end
    table.clear(self.Connections)
    self.Started = false
end

return PlayerTracker