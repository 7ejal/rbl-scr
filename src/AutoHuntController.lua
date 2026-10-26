-- IVORY Auto Hunt: client-side humanoid navigation to live DhabWild models.
-- No teleporting, vehicle control, interaction remotes or forced server damage.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")

local AutoHuntController = {}
AutoHuntController.__index = AutoHuntController

local UPDATE_INTERVAL = 0.3
local PATH_REBUILD_SECONDS = 2
local PATH_REBUILD_DISTANCE = 12
local WAYPOINT_RADIUS = 6

local function positionOf(model)
    local root = model.PrimaryPart
        or model:FindFirstChild("HumanoidRootPart", true)
        or model:FindFirstChildWhichIsA("BasePart", true)
    return root and root.Position or nil
end

local function alive(model)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then return false end
    local health = model:GetAttribute("Health")
    if type(health) == "number" and health <= 0 then return false end
    local state = model:GetAttribute("State")
    if type(state) == "string" then
        state = state:lower()
        if state == "dead" or state == "death" then return false end
    end
    return true
end

function AutoHuntController.new(settings, tracker, aimController, onStatus)
    return setmetatable({
        Settings = settings,
        Tracker = tracker,
        Aim = aimController,
        OnStatus = onStatus,
        Status = "",
        Target = nil,
        Running = false,
        Connections = {},
        Accumulator = 0,
        LastRoute = -math.huge,
        LastDestination = nil,
        Waypoints = nil,
        WaypointIndex = 1,
        Computing = false,
        Generation = 0,
        Moving = false,
        LastPosition = nil,
        LastMovedAt = os.clock(),
        UI = nil,
        Stats = nil,
        Unreachable = setmetatable({}, {__mode = "k"}),
        FailedRoutes = setmetatable({}, {__mode = "k"}),
        StuckAttempts = 0,
        LastPathTarget = nil,
    }, AutoHuntController)
end

function AutoHuntController:SetStatus(value)
    if self.Status == value then return end
    self.Status = value
    if self.OnStatus then
        pcall(self.OnStatus, value)
    end
end

function AutoHuntController:Character()
    local character = Players.LocalPlayer.Character
    if not character then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 then return nil end
    if humanoid.Sit or humanoid.SeatPart then return nil end
    return humanoid, root
end

function AutoHuntController:AllowedTier(model)
    local tier = model:GetAttribute("Tier")
    local key = type(tier) == "string" and ("HuntTier" .. tier) or "HuntTierUnknown"
    local allowed = self.Settings[key]
    if allowed ~= true then return false end
    local minLength = math.max(0, self.Settings.HuntMinLength or 0)
    if minLength > 0 then
        local length = model:GetAttribute("Length")
        if type(length) ~= "number" or length < minLength then
            return false
        end
    end
    return true
end

function AutoHuntController:ValidTarget(model, origin)
    if not model or not model:IsDescendantOf(workspace)
        or not self.Tracker:IsDhab(model)
        or self.Tracker.Known[model] ~= "monster"
        or not alive(model)
        or not self:AllowedTier(model)
        or (self.Unreachable[model] or 0) > os.clock() then
        return nil
    end
    local location = positionOf(model)
    if not location then return nil end
    local distance = (location - origin).Magnitude
    if distance > math.max(100, self.Settings.HuntSearchDistance or 700) then
        return nil
    end
    return location, distance
end

function AutoHuntController:ClosestDhab(origin)
    local best, bestScore, bestDistance = nil, -math.huge, math.huge
    local priority = self.Settings.HuntPriority or "Closest"
    for model, category in pairs(self.Tracker.Known) do
        if category == "monster" and self.Tracker:IsDhab(model) then
            local location, distance = self:ValidTarget(model, origin)
            if location then
                local score = -distance
                if priority == "Longest" then
                    score = (tonumber(model:GetAttribute("Length")) or -1) * 10000
                elseif priority == "Largest" then
                    score = (tonumber(model:GetAttribute("Scale")) or -1) * 10000
                end
                if score > bestScore or (score == bestScore
                    and distance < bestDistance) then
                    best, bestScore, bestDistance = model, score, distance
                end
            end
        end
    end
    return best
end

function AutoHuntController:ClearPath()
    self.Generation = self.Generation + 1
    self.Waypoints = nil
    self.WaypointIndex = 1
    self.LastDestination = nil
    self.Computing = false
end

function AutoHuntController:SkipUnreachable(reason)
    local model = self.Target
    if model then
        self.Unreachable[model] = os.clock() + 35
        self.FailedRoutes[model] = nil
        if self.Stats then self.Stats:RecordSkipped() end
    end
    self:Reset()
    self:SetStatus(reason or "Target unreachable; trying another Dhab")
end

function AutoHuntController:StopMovement()
    if self.Moving then
        self.Moving = false
        local humanoid, root = self:Character()
        if humanoid and root then
            pcall(function() humanoid:MoveTo(root.Position) end)
        end
    end
end

function AutoHuntController:Reset()
    self:StopMovement()
    if self.Vehicle then self.Vehicle:Stop() end
    self:ClearPath()
    self.Target = nil
    self.StuckAttempts = 0
    if self.Aim then self.Aim:SetHuntTarget(nil) end
    self.LastPosition = nil
    self.LastMovedAt = os.clock()
end

function AutoHuntController:ManualOverride()
    if not self.Settings.HuntPauseOnManualMove then return false end
    if UserInputService:GetFocusedTextBox() then return true end
    for _, key in ipairs({
        Enum.KeyCode.W, Enum.KeyCode.A,
        Enum.KeyCode.S, Enum.KeyCode.D,
        Enum.KeyCode.Up, Enum.KeyCode.Down,
        Enum.KeyCode.Left, Enum.KeyCode.Right,
    }) do
        if UserInputService:IsKeyDown(key) then
            return true
        end
    end
    return false
end

function AutoHuntController:RequestPath(origin, destination)
    if self.Computing then return end
    local now = os.clock()
    if now - self.LastRoute < PATH_REBUILD_SECONDS then return end
    if self.LastDestination
        and (self.LastDestination - destination).Magnitude < PATH_REBUILD_DISTANCE
        and self.Waypoints and #self.Waypoints > 0 then
        return
    end

    self.LastRoute = now
    self.LastDestination = destination
    self.Generation = self.Generation + 1
    local generation = self.Generation
    self.Computing = true

    -- ComputeAsync yields. Keep it off the render loop so the GUI stays responsive.
    task.spawn(function()
        -- CreatePath itself may throw on unsupported or transitioning worlds.
        -- Ensure Computing is always cleared for the active generation.
        local path
        local ok = pcall(function()
            path = PathfindingService:CreatePath({
                AgentRadius = 2,
                AgentHeight = 5,
                AgentCanJump = true,
                WaypointSpacing = 6,
            })
            path:ComputeAsync(origin, destination)
        end)

        if self.Generation ~= generation or not self.Running
            or not self.Settings.AutoHuntEnabled then
            return
        end
        self.Computing = false

        if ok and path.Status == Enum.PathStatus.Success then
            self.Waypoints = path:GetWaypoints()
            self.WaypointIndex = math.min(2, #self.Waypoints)
            if self.Target then self.FailedRoutes[self.Target] = 0 end
        else
            self.Waypoints = nil
            self.WaypointIndex = 1
            if self.Target then
                local failures = (self.FailedRoutes[self.Target] or 0) + 1
                self.FailedRoutes[self.Target] = failures
                if failures >= 3 then
                    self:SkipUnreachable("No navigable route; skipping target")
                end
            end
        end
    end)
end

function AutoHuntController:Update()
    if not self.Settings.AutoHuntEnabled then
        self:Reset()
        self:SetStatus("OFF")
        return
    end


    -- Vehicle mode: only drive the local player's occupied driver VehicleSeat
    -- within Workspace.PlayersCars. Do NOT MoveTo a seated humanoid.
    local character = Players.LocalPlayer.Character
    local living = character and character:FindFirstChildOfClass("Humanoid")
    if living and living.Health > 0 and living.SeatPart then
        self:StopMovement()
        local vehicle = self.Vehicle
        if not vehicle or not self.Settings.HuntCarEnabled then
            if vehicle then vehicle:Stop() end
            self:SetStatus("Seated: enable Auto Hunt in Car or exit the seat")
            return
        end

        local driving, seat, car = vehicle:IsDriving()
        if not driving then
            vehicle:Stop()
            self:SetStatus("Car requires your occupied VehicleSeat in PlayersCars")
            return
        end
        if self:ManualOverride() then
            vehicle:Stop()
            self:SetStatus("Vehicle paused: manual controls / typing")
            return
        end

        local location, distance = self:ValidTarget(self.Target, seat.Position)
        if not location then
            self:Reset()
            self.Target = self:ClosestDhab(seat.Position)
            if self.Target and self.Stats then self.Stats:RecordTarget() end
            location, distance = self:ValidTarget(self.Target, seat.Position)
        end
        if not location then
            vehicle:Stop()
            self:SetStatus("Car hunt: no eligible live Dhab")
            return
        end

        self.Aim:SetHuntTarget(self.Target)
        local stopDistance = math.clamp(
            self.Settings.HuntCarStopDistance or 48, 25, 125)
        if distance <= stopDistance then
            vehicle:Stop()
            self:SetStatus(("Car in range: %s (%d studs)")
                :format(self.Target.Name, math.floor(distance + 0.5)))
            return
        end

        local now = os.clock()
        if not self.LastPosition or
            (seat.Position - self.LastPosition).Magnitude >= 4 then
            self.LastPosition = seat.Position
            self.LastMovedAt = now
            self.StuckAttempts = 0
        elseif now - self.LastMovedAt >= 7 then
            self.StuckAttempts = self.StuckAttempts + 1
            self.LastMovedAt = now
            if self.StuckAttempts >= 3 then
                self:SkipUnreachable("Car stuck; skipping Dhab for 35s")
                return
            end
        end

        if not vehicle:Drive(seat, car, living, self.Target, location) then
            vehicle:Stop()
            self:SetStatus("Cannot control this car seat")
            return
        end
        self:SetStatus(("Car hunting %s | %d studs | %s"):format(
            self.Target.Name, math.floor(distance + 0.5),
            vehicle.LastStatus
        ))
        return
    end

    if self.Vehicle and self.Vehicle.Seat then self.Vehicle:Stop() end
    local humanoid, root = self:Character()
    if not humanoid then
        self:Reset()
        self:SetStatus("Waiting for living, unseated character")
        return
    end
    if self:ManualOverride() then
        self:StopMovement()
        self:SetStatus("Paused: manual movement / text input")
        return
    end

    local location, distance = self:ValidTarget(self.Target, root.Position)
    if not location then
        self:Reset()
        self.Target = self:ClosestDhab(root.Position)
        if self.Target and self.Stats then self.Stats:RecordTarget() end
        location, distance = self:ValidTarget(self.Target, root.Position)
    end
    if not location then
        self:SetStatus("No live Dhab in hunt radius")
        return
    end

    -- Share the selected Dhab with camera aim, never other monsters or catches.
    self.Aim:SetHuntTarget(self.Target)

    local stopDistance = math.clamp(self.Settings.HuntStopDistance or 28, 10, 100)
    if distance <= stopDistance then
        self:StopMovement()
        self:ClearPath()
        self:SetStatus(("In range: %s (%d studs)")
            :format(self.Target.Name, math.floor(distance + 0.5)))
        return
    end

    local now = os.clock()
    if not self.LastPosition
        or (root.Position - self.LastPosition).Magnitude >= 3 then
        self.LastPosition = root.Position
        self.LastMovedAt = now
        self.StuckAttempts = 0
    elseif now - self.LastMovedAt > 5 then
        self.StuckAttempts = self.StuckAttempts + 1
        if self.StuckAttempts >= 3 then
            self:SkipUnreachable("Stuck three times; skipping Dhab")
            return
        end
        self:ClearPath()
        if humanoid.FloorMaterial ~= Enum.Material.Air then
            humanoid.Jump = true
        end
        self.LastMovedAt = now
        self:SetStatus("Replanning blocked path")
    end

    self:RequestPath(root.Position, location)

    local waypoint
    if self.Waypoints then
        while self.WaypointIndex <= #self.Waypoints do
            local step = self.Waypoints[self.WaypointIndex]
            if (step.Position - root.Position).Magnitude > WAYPOINT_RADIUS then
                waypoint = step
                break
            end
            self.WaypointIndex = self.WaypointIndex + 1
        end
    end

    local destination = waypoint and waypoint.Position or location
    if waypoint and waypoint.Action == Enum.PathWaypointAction.Jump then
        humanoid.Jump = true
    end

    humanoid:MoveTo(destination)
    self.Moving = true
    self:SetStatus(("Hunting %s | %d studs | %s"):format(
        self.Target.Name, math.floor(distance + 0.5),
        waypoint and "pathfinding" or "direct movement"
    ))
end

function AutoHuntController:Start()
    if self.Running then return end
    self.Running = true
    if self.Vehicle then self.Vehicle:Start() end
    table.insert(self.Connections, Players.LocalPlayer.CharacterAdded:Connect(
        function()
            self:Reset()
        end
    ))
    table.insert(self.Connections, RunService.Heartbeat:Connect(function(dt)
        if not self.Running then return end
        self.Accumulator = self.Accumulator + dt
        if self.Accumulator < UPDATE_INTERVAL then return end
        self.Accumulator = 0
        local ok, err = pcall(self.Update, self)
        if not ok then
            self:Reset()
            self:SetStatus("Auto Hunt error: " .. tostring(err):sub(1, 85))
        end
    end))
    self:SetStatus("OFF")
end

function AutoHuntController:Destroy()
    if not self.Running then return end
    self.Running = false
    for _, connection in ipairs(self.Connections) do connection:Disconnect() end
    table.clear(self.Connections)
    self:Reset()
    if self.Vehicle then self.Vehicle:Destroy() end
    self:SetStatus("Stopped")
end

return AutoHuntController