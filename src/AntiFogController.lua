-- Client-only reversible Roblox fog / atmosphere control.
-- Independent of ESP, FOV, aiming, and other feature toggles.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local AntiFogController = {}
AntiFogController.__index = AntiFogController

local CLEAR_FOG_START = 1000000
local CLEAR_FOG_END = 10000000
local CHECK_INTERVAL = 0.75

function AntiFogController.new()
    return setmetatable({
        Enabled = false,
        Destroyed = false,
        FogSnapshot = nil,
        AtmosphereSnapshots = {},
        Connections = {},
        Accumulator = 0,
    }, AntiFogController)
end

function AntiFogController:RememberAtmosphere(atmosphere)
    if not atmosphere:IsA("Atmosphere") then return end
    if self.AtmosphereSnapshots[atmosphere] then return end

    self.AtmosphereSnapshots[atmosphere] = {
        Density = atmosphere.Density,
        Haze = atmosphere.Haze,
        Glare = atmosphere.Glare,
    }
end

function AntiFogController:Apply()
    if not self.Enabled or self.Destroyed then return end

    -- Classic Lighting distance fog.
    if Lighting.FogStart ~= CLEAR_FOG_START then
        Lighting.FogStart = CLEAR_FOG_START
    end
    if Lighting.FogEnd ~= CLEAR_FOG_END then
        Lighting.FogEnd = CLEAR_FOG_END
    end

    -- Atmosphere replaces classic fog in experiences that use it.
    -- Do not destroy instances or affect skies, clouds, color or brightness.
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("Atmosphere") then
            self:RememberAtmosphere(child)
            if child.Density ~= 0 then child.Density = 0 end
            if child.Haze ~= 0 then child.Haze = 0 end
            if child.Glare ~= 0 then child.Glare = 0 end
        end
    end
end

function AntiFogController:SetEnabled(enabled)
    if self.Destroyed then return end
    enabled = enabled == true
    if self.Enabled == enabled then
        if enabled then self:Apply() end
        return
    end

    self.Enabled = enabled
    if enabled then
        -- Snapshot on each OFF -> ON transition. Disabling restores exactly
        -- these values (later server-driven weather may update again).
        self.FogSnapshot = {
            FogStart = Lighting.FogStart,
            FogEnd = Lighting.FogEnd,
        }
        self.AtmosphereSnapshots = {}
        for _, child in ipairs(Lighting:GetChildren()) do
            self:RememberAtmosphere(child)
        end

        self:Apply()
        table.insert(self.Connections, Lighting.ChildAdded:Connect(function(child)
            if not self.Enabled or not child:IsA("Atmosphere") then return end
            self:RememberAtmosphere(child)
            self:Apply()
        end))
        table.insert(self.Connections, RunService.Heartbeat:Connect(function(dt)
            self.Accumulator = self.Accumulator + dt
            if self.Accumulator >= CHECK_INTERVAL then
                self.Accumulator = 0
                self:Apply()
            end
        end))
    else
        self:Restore()
    end
end

function AntiFogController:Restore()
    for _, connection in ipairs(self.Connections) do
        connection:Disconnect()
    end
    table.clear(self.Connections)
    self.Accumulator = 0

    if self.FogSnapshot then
        Lighting.FogStart = self.FogSnapshot.FogStart
        Lighting.FogEnd = self.FogSnapshot.FogEnd
    end
    self.FogSnapshot = nil

    for atmosphere, values in pairs(self.AtmosphereSnapshots) do
        if atmosphere.Parent == Lighting then
            atmosphere.Density = values.Density
            atmosphere.Haze = values.Haze
            atmosphere.Glare = values.Glare
        end
    end
    table.clear(self.AtmosphereSnapshots)
end

function AntiFogController:Destroy()
    if self.Destroyed then return end
    if self.Enabled then self:SetEnabled(false) end
    self.Destroyed = true
    self:Restore()
end

return AntiFogController