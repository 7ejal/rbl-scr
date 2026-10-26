-- Discover replicated monster/NPC Models by humanoid, tags, attributes,
-- common monster names, or placement in a monster/NPC folder.
-- Specific games may need additional matching once their model paths are known.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local MonsterTracker = {}
MonsterTracker.__index = MonsterTracker

local KEYWORDS = {
    "monster", "enemy", "npc", "zombie", "creature", "mob",
    "boss", "infected", "spider", "mutant", "t5", "t6",
}

local MARKER_ATTRIBUTES = {
    "MonsterId", "MonsterID", "NPCId", "NPCID",
    "EnemyId", "IsMonster", "IsEnemy", "IsNPC",
}

local function containsKeyword(value)
    value = string.lower(tostring(value))
    for _, keyword in ipairs(KEYWORDS) do
        if string.find(value, keyword, 1, true) then return true end
    end
    return false
end

function MonsterTracker.new(onAdd, onRemove)
    return setmetatable({
        OnAdd = onAdd,
        OnRemove = onRemove,
        Known = {},
        Connections = {},
        Started = false,
    }, MonsterTracker)
end

function MonsterTracker:IsCandidate(model)
    if not model:IsA("Model") or not model:IsDescendantOf(workspace) then
        return false
    end

    -- Never treat an avatar, or any nested model inside an avatar, as an NPC.
    local ancestor = model
    while ancestor and ancestor ~= workspace do
        if Players:GetPlayerFromCharacter(ancestor) then return false end
        ancestor = ancestor.Parent
    end

    if not model:FindFirstChildWhichIsA("BasePart", true) then return false end
    if model:FindFirstChildOfClass("Humanoid") then return true end

    for _, name in ipairs(MARKER_ATTRIBUTES) do
        local value = model:GetAttribute(name)
        if value ~= nil and value ~= false then return true end
    end

    for _, tag in ipairs(CollectionService:GetTags(model)) do
        if containsKeyword(tag) then return true end
    end

    if containsKeyword(model.Name) then return true end

    ancestor = model.Parent
    while ancestor and ancestor ~= workspace do
        if ancestor:IsA("Folder") and containsKeyword(ancestor.Name) then
            return true
        end
        ancestor = ancestor.Parent
    end
    return false
end

function MonsterTracker:Check(model)
    if self:IsCandidate(model) then
        if not self.Known[model] then
            self.Known[model] = true
            self.OnAdd(model)
        end
    elseif self.Known[model] then
        self.Known[model] = nil
        self.OnRemove(model)
    end
end

function MonsterTracker:Scan()
    local seen = {}
    for _, instance in ipairs(workspace:GetDescendants()) do
        if instance:IsA("Model") then
            seen[instance] = true
            self:Check(instance)
        end
    end
    for model in pairs(self.Known) do
        if not seen[model] or not self:IsCandidate(model) then
            self.Known[model] = nil
            self.OnRemove(model)
        end
    end
end

function MonsterTracker:Start()
    if self.Started then return end
    self.Started = true

    table.insert(self.Connections, workspace.DescendantAdded:Connect(function(instance)
        if instance:IsA("Model") then
            self:Check(instance)
        elseif instance:IsA("Humanoid") or instance:IsA("BasePart") then
            local parent = instance.Parent
            if parent and parent:IsA("Model") then self:Check(parent) end
        end
    end))

    table.insert(self.Connections, workspace.DescendantRemoving:Connect(function(instance)
        if instance:IsA("Model") and self.Known[instance] then
            self.Known[instance] = nil
            self.OnRemove(instance)
        end
    end))

    self:Scan()
end

function MonsterTracker:Destroy()
    for _, connection in ipairs(self.Connections) do
        connection:Disconnect()
    end
    table.clear(self.Connections)
    table.clear(self.Known)
    self.Started = false
end

return MonsterTracker