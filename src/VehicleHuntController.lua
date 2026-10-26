-- IVORY vehicle hunt: uses only the local player's occupied VehicleSeat.
-- No teleports, network-ownership changes, vehicle remotes, or forced seat entry.
-- Works with cars whose chassis reads VehicleSeat ThrottleFloat/SteerFloat.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VehicleHuntController = {}
VehicleHuntController.__index = VehicleHuntController

local STEP_INTERVAL = 0.05
local INTENT_TTL = 0.75

local function currentHumanoid()
    local player = Players.LocalPlayer
    local character = player and player.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

function VehicleHuntController.new(settings)
    return setmetatable({
        Settings = settings,
        Running = false,
        Connection = nil,
        Seat = nil,
        Humanoid = nil,
        Car = nil,
        Target = nil,
        Desired = nil,
        StopDistance = 0,
        LastIntent = 0,
        LastStatus = "Waiting for a driver seat",
        Accumulator = 0,
        Error = nil,
        Throttle = 0,
        Steer = 0,
    }, VehicleHuntController)
end

function VehicleHuntController:FindCar(seat, humanoid)
    if not seat or not seat:IsA("VehicleSeat")
        or not humanoid or humanoid.Health <= 0
        or humanoid.SeatPart ~= seat
        or seat.Occupant ~= humanoid then
        return nil
    end
    local root = workspace:FindFirstChild(
        self.Settings.CarsFolderName or "PlayersCars"
    )
    if not root then return nil end
    local car = seat
    while car and car.Parent ~= root do
        car = car.Parent
    end
    if car and car:IsA("Model") and car.Parent == root then
        return car
    end
    return nil
end

function VehicleHuntController:IsDriving()
    local humanoid = currentHumanoid()
    local seat = humanoid and humanoid.SeatPart
    local car = self:FindCar(seat, humanoid)
    return seat and car ~= nil, seat, car, humanoid
end

function VehicleHuntController:Neutralize(seat)
    local humanoid = currentHumanoid()
    if seat and seat.Parent and humanoid and humanoid.SeatPart == seat
        and seat.Occupant == humanoid then
        pcall(function()
            seat.ThrottleFloat = 0
            seat.SteerFloat = 0
        end)
    end
end

function VehicleHuntController:Stop()
    local seat = self.Seat
    self.Target = nil
    self.Desired = nil
    self.Seat = nil
    self.Humanoid = nil
    self.Car = nil
    self.LastIntent = 0
    self.LastStatus = "Vehicle hunt idle"
    self.Throttle, self.Steer = 0, 0
    self:Neutralize(seat)
end

function VehicleHuntController:Drive(seat, car, humanoid, target, destination)
    if not self.Running or not self.Settings.AutoHuntEnabled
        or not self.Settings.HuntCarEnabled then
        self:Stop()
        return false
    end
    if self:FindCar(seat, humanoid) ~= car or not target
        or not target:IsDescendantOf(workspace) then
        self:Stop()
        return false
    end
    if self.Seat and self.Seat ~= seat then self:Neutralize(self.Seat) end
    self.Seat, self.Humanoid, self.Car = seat, humanoid, car
    self.Target = target
    self.Desired = destination
    self.StopDistance = math.clamp(
        self.Settings.HuntCarStopDistance or 48, 25, 125)
    self.LastIntent = os.clock()
    return true
end

function VehicleHuntController:ObstacleAhead(seat, car, range)
    local direction = seat.CFrame.LookVector
    local origin = seat.Position + Vector3.new(0, 1.8, 0)
    local flat = Vector3.new(direction.X, 0, direction.Z)
    if flat.Magnitude < 0.1 then return false end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local character = Players.LocalPlayer.Character
    params.FilterDescendantsInstances = character and {car, character}
        or {car}
    params.IgnoreWater = true

    -- Only use the center ray for emergency detection; distant Dhab
    -- within the configured stopping distance is never chased through.
    local hit = workspace:Raycast(origin, flat.Unit * range, params)
    if not hit then return false end
    return hit.Instance ~= nil
end

function VehicleHuntController:Step()
    if not self.Running or not self.Settings.AutoHuntEnabled
        or not self.Settings.HuntCarEnabled then
        if self.Seat then self:Stop() end
        return
    end

    local seat = self.Seat
    if not seat then return end
    local humanoid = currentHumanoid()
    local car = self:FindCar(seat, humanoid)
    if not car or car ~= self.Car or humanoid ~= self.Humanoid
        or not self.Desired or not self.Target
        or not self.Target:IsDescendantOf(workspace)
        or os.clock() - self.LastIntent > INTENT_TTL then
        self:Stop()
        return
    end

    local goal = self.Desired - seat.Position
    local flat = Vector3.new(goal.X, 0, goal.Z)
    local distance = flat.Magnitude
    local velocity = seat.AssemblyLinearVelocity
    local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

    local throttle, steer = 0, 0
    local stopDistance = self.StopDistance
    local maxSpeed = math.clamp(self.Settings.HuntCarMaxSpeed or 32, 8, 90)
    local brakeBuffer = math.clamp(speed * 0.9, 6, 55)

    if distance <= stopDistance + brakeBuffer then
        -- Coast into the stopping radius. Reverse is not forced because
        -- custom chassis may interpret a reverse input as acceleration.
        self.LastStatus = "Braking near Dhab"
    else
        local desired = flat.Unit
        local forward = seat.CFrame.LookVector
        local right = seat.CFrame.RightVector
        local f = Vector3.new(forward.X, 0, forward.Z)
        local r = Vector3.new(right.X, 0, right.Z)
        if f.Magnitude > 0.01 and r.Magnitude > 0.01 then
            local angle = math.atan2(desired:Dot(r.Unit), desired:Dot(f.Unit))
            steer = math.clamp(angle * 1.8, -1, 1)
            if self.Settings.HuntCarInvertSteering then steer = -steer end
            -- Reduce throttle on sharp turns; cap forward speed.
            local turnFactor = math.clamp(1 - math.abs(angle) / math.pi,
                0.20, 1)
            throttle = speed < maxSpeed and turnFactor or 0
            local obstacleRange = math.clamp(speed * 1.2 + 10, 16, 45)
            if self:ObstacleAhead(seat, car, obstacleRange) then
                throttle = 0
                self.LastStatus = "Obstacle ahead: vehicle slowing"
            else
                self.LastStatus = "Driving to Dhab"
            end
        end
    end

    self.Throttle, self.Steer = throttle, steer
    local ok, err = pcall(function()
        seat.SteerFloat = self.Steer
        seat.ThrottleFloat = self.Throttle
    end)
    if not ok then
        self.Error = tostring(err):sub(1, 90)
        self:Stop()
        self.LastStatus = "VehicleSeat controls unavailable: " .. self.Error
    end
end

function VehicleHuntController:Start()
    if self.Running then return end
    self.Running = true
    -- Bind AFTER default PlayerModule input updates. The core vehicle
    -- controller can overwrite seat floats every rendered frame.
    RunService:BindToRenderStep("IVORY_VehicleHuntInput",
        Enum.RenderPriority.Camera.Value + 2, function(dt)
            self.Accumulator = self.Accumulator + dt
            if self.Accumulator >= STEP_INTERVAL then
                self.Accumulator = 0
                local ok, err = pcall(self.Step, self)
                if not ok then
                    self.Error = tostring(err)
                    self:Stop()
                    self.LastStatus = "Vehicle hunt error: " ..
                        tostring(err):sub(1, 75)
                end
            end
            local seat = self.Seat
            if seat then
                local humanoid = currentHumanoid()
                if humanoid and self:FindCar(seat, humanoid) == self.Car
                    and humanoid == self.Humanoid
                    and os.clock() - self.LastIntent <= INTENT_TTL then
                    pcall(function()
                        seat.SteerFloat = self.Steer
                        seat.ThrottleFloat = self.Throttle
                    end)
                else
                    self:Stop()
                end
            end
        end)
end

function VehicleHuntController:Destroy()
    self.Running = false
    RunService:UnbindFromRenderStep("IVORY_VehicleHuntInput")
    self.Connection = nil
    self:Stop()
end

return VehicleHuntController