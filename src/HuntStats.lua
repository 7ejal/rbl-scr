-- Session-only Hunt Statistics. No unsupported capture claims.
local Stats = {}
Stats.__index = Stats

function Stats.new(settings)
    return setmetatable({
        Settings = settings,
        StartedAt = os.clock(),
        TargetsVisited = 0,
        SkippedUnreachable = 0,
        ShotAttempts = 0,
        InputDispatched = 0,
        TargetNames = {},
        OnChange = nil,
    }, Stats)
end

function Stats:Notify()
    if self.OnChange then pcall(self.OnChange, self:GetSummary()) end
end

function Stats:RecordTarget()
    if self.Settings and not self.Settings.StatsEnabled then return end
    self.TargetsVisited = self.TargetsVisited + 1
    self:Notify()
end

function Stats:RecordSkipped()
    if self.Settings and not self.Settings.StatsEnabled then return end
    self.SkippedUnreachable = self.SkippedUnreachable + 1
    self:Notify()
end

function Stats:RecordShotAttempt()
    if self.Settings and not self.Settings.StatsEnabled then return end
    self.ShotAttempts = self.ShotAttempts + 1
    self:Notify()
end

function Stats:RecordShotDispatched()
    if self.Settings and not self.Settings.StatsEnabled then return end
    self.InputDispatched = self.InputDispatched + 1
    self:Notify()
end

function Stats:GetSummary()
    local elapsed = math.max(0, math.floor(os.clock() - self.StartedAt))
    return string.format(
        "Session: %02d:%02d:%02d\nTargets selected: %d\nUnreachable skipped: %d\n"
            .. "Shot attempts: %d\nInput dispatched: %d\n"
            .. "Confirmed hits/catches: unavailable (no verified game event)",
        math.floor(elapsed / 3600), math.floor(elapsed / 60) % 60,
        elapsed % 60, self.TargetsVisited, self.SkippedUnreachable,
        self.ShotAttempts, self.InputDispatched
    )
end

function Stats:Reset()
    self.StartedAt = os.clock()
    self.TargetsVisited = 0
    self.SkippedUnreachable = 0
    self.ShotAttempts = 0
    self.InputDispatched = 0
    self:Notify()
end

return Stats