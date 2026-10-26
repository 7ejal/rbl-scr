-- Categorizes targets so plots/vendors are not mistaken for monsters.
-- Monster-only matching uses hostile identifiers or user-registered model names.
local Players = game:GetService("Players")
local Tags = game:GetService("CollectionService")

local Tracker = {}
Tracker.__index = Tracker

local MONSTER_TERMS = {
    "monster", "enemy", "enemies", "hostile", "creature", "boss",
    "wolf", "wolves", "scorpion", "snake", "spider", "bandit",
    "zombie", "mutant", "infected", "hyena", "skeleton", "ghoul",
    "وحش", "وحوش", "عدو", "عقرب", "ذئب", "ذيب", "ضبع", "ثعبان",
}
local IGNORE_TERMS = {
    "plot", "house", "building", "vendor", "seller", "merchant",
    "shop", "stall", "farmer", "herder", "poet", "storyteller",
    "gunsmith", "weaponshop", "decoration", "prop", "market",
}
local HOSTILE_MARKERS = {
    "MonsterId", "MonsterID", "EnemyId", "EnemyID",
    "IsMonster", "IsEnemy", "IsHostile", "Hostile",
    "BossId", "MobId", "CreatureId",
}

local function containsAny(value, words)
    value = string.lower(tostring(value))
    for _, word in ipairs(words) do
        if string.find(value, word, 1, true) then return true end
    end
    return false
end

local function isPlayerCharacter(instance)
    local current = instance
    while current and current ~= workspace do
        if current:IsA("Model") and Players:GetPlayerFromCharacter(current) then
            return true
        end
        current = current.Parent
    end
    return false
end

local function hasMonsterMarker(instance)
    for _, name in ipairs(HOSTILE_MARKERS) do
        local value = instance:GetAttribute(name)
        if value ~= nil and value ~= false then return true end
    end
    for _, tag in ipairs(Tags:GetTags(instance)) do
        if containsAny(tag, MONSTER_TERMS) then return true end
    end
    return false
end

function Tracker.new(onAdd, onRemove, settings)
    return setmetatable({
        OnAdd = onAdd,
        OnRemove = onRemove,
        Settings = settings,
        Known = {}, -- Instance -> "monster" or "other"
        Connections = {},
        Started = false,
    }, Tracker)
end

function Tracker:Classify(instance)
    if not instance:IsDescendantOf(workspace)
        or isPlayerCharacter(instance) then
        return nil
    end
    local isModel = instance:IsA("Model")
    local isPart = instance:IsA("BasePart")
    if not isModel and not isPart then return nil end

    if isPart then
        -- Only independently named/tagged BaseParts can be targets, not rig body parts.
        if instance.Parent and instance.Parent:IsA("Model") then return nil end
        if not hasMonsterMarker(instance)
            and not containsAny(instance.Name, MONSTER_TERMS) then
            return nil
        end
    elseif not instance:FindFirstChildWhichIsA("BasePart", true) then
        return nil
    end

    local lowerName = string.lower(instance.Name)
    local names = self.Settings.MonsterModelNames or {}
    if names[lowerName] or names[instance.Name] then return "monster" end

    if hasMonsterMarker(instance) or containsAny(lowerName, MONSTER_TERMS) then
        return "monster"
    end

    local ancestor = instance.Parent
    while ancestor and ancestor ~= workspace do
        -- Prefer a single ESP record for the outer monster.
        if ancestor:IsA("Model") and
            (containsAny(ancestor.Name, MONSTER_TERMS) or hasMonsterMarker(ancestor)) then
            return nil
        end
        if ancestor:IsA("Folder") and containsAny(ancestor.Name, MONSTER_TERMS) then
            return "monster"
        end
        ancestor = ancestor.Parent
    end

    -- Explicitly named scenery never becomes a target.
    if containsAny(lowerName, IGNORE_TERMS) then return nil end

    if isModel then
        local humanoid = instance:FindFirstChildOfClass("Humanoid")
        if humanoid then return "other" end
        local animation = instance:FindFirstChildOfClass("AnimationController")
        if animation then return "other" end
    end

    return nil
end

function Tracker:IsCandidate(instance)
    return self:Classify(instance) ~= nil
end

function Tracker:IsMonster(instance)
    return self:Classify(instance) == "monster"
end

function Tracker:Check(instance)
    local category = self:Classify(instance)
    local previous = self.Known[instance]
    if previous == category then return end

    if previous then
        self.Known[instance] = nil
        self.OnRemove(instance)
    end
    if category then
        self.Known[instance] = category
        self.OnAdd(instance, category)
    end
end

function Tracker:Scan()
    local seen = {}
    for _, instance in ipairs(workspace:GetDescendants()) do
        if instance:IsA("Model") then
            seen[instance] = true
            self:Check(instance)
        elseif instance:IsA("BasePart") then
            -- Avoid per-part classification for generic terrain/decorative parts.
            local registered = self.Settings.MonsterModelNames[
                string.lower(instance.Name)] == true
            if registered or containsAny(instance.Name, MONSTER_TERMS)
                or next(instance:GetAttributes()) ~= nil
                or #Tags:GetTags(instance) > 0 then
                seen[instance] = true
                self:Check(instance)
            end
        end
    end
    for instance in pairs(self.Known) do
        if not seen[instance] then
            self.Known[instance] = nil
            self.OnRemove(instance)
        end
    end
end

function Tracker:TrackName(instance)
    if not instance or not (instance:IsA("Model") or instance:IsA("BasePart"))
        or isPlayerCharacter(instance) then
        return false
    end
    local name = string.lower(instance.Name)
    self.Settings.MonsterModelNames[name] = true
    self:Scan()
    print("[IVORY] Registered monster model name:", instance.Name)
    return true
end

function Tracker:UntrackName(instance)
    if not instance then return false end
    self.Settings.MonsterModelNames[string.lower(instance.Name)] = nil
    self:Scan()
    return true
end

function Tracker:GetChoices(maxResults, includeScenery)
    local camera = workspace.CurrentCamera
    local localCharacter = Players.LocalPlayer.Character
    local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    local origin = localRoot and localRoot.Position or
        (camera and camera.CFrame.Position)
    if not origin then return {} end

    local choices = {}
    for _, instance in ipairs(workspace:GetDescendants()) do
        if instance:IsA("Model") and not isPlayerCharacter(instance) then
            local root = instance.PrimaryPart
                or instance:FindFirstChild("HumanoidRootPart", true)
                or instance:FindFirstChildWhichIsA("BasePart", true)
            if root then
                local distance = (root.Position - origin).Magnitude
                if distance < 1800 then
                    local category = self:Classify(instance)
                    local eligible = category ~= nil
                        or instance:FindFirstChildOfClass("Humanoid") ~= nil
                        or instance:FindFirstChildOfClass("AnimationController") ~= nil
                    if includeScenery or eligible then
                        table.insert(choices, {
                            Instance = instance,
                            Name = instance.Name,
                            Distance = distance,
                            Category = category or "unknown",
                            Registered = self.Settings.MonsterModelNames[
                                string.lower(instance.Name)] == true,
                        })
                    end
                end
            end
        end
    end
    table.sort(choices, function(a, b)
        if a.Registered ~= b.Registered then return a.Registered end
        if a.Category == "monster" and b.Category ~= "monster" then return true end
        if a.Category ~= "monster" and b.Category == "monster" then return false end
        return a.Distance < b.Distance
    end)
    while #choices > (maxResults or 30) do table.remove(choices) end
    return choices
end

function Tracker:Start()
    if self.Started then return end
    self.Started = true
    table.insert(self.Connections, workspace.DescendantAdded:Connect(function(instance)
        if instance:IsA("Model") then
            self:Check(instance)
        elseif instance:IsA("BasePart") then
            if containsAny(instance.Name, MONSTER_TERMS) or
                next(instance:GetAttributes()) ~= nil or
                #Tags:GetTags(instance) > 0 then
                self:Check(instance)
            end
        elseif instance:IsA("Humanoid") or instance:IsA("AnimationController") then
            local parent = instance.Parent
            if parent and parent:IsA("Model") then self:Check(parent) end
        end
    end))
    table.insert(self.Connections, workspace.DescendantRemoving:Connect(function(instance)
        if self.Known[instance] then
            self.Known[instance] = nil
            self.OnRemove(instance)
        end
    end))
    self:Scan()
end

function Tracker:Destroy()
    for _, connection in ipairs(self.Connections) do
        connection:Disconnect()
    end
    table.clear(self.Connections)
    table.clear(self.Known)
    self.Started = false
end

return Tracker