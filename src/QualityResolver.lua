-- Resolves actual replicated per-Dhab quality; never guesses from the model name.
-- Sources: own attributes, descendant ValueObjects, displayed quality labels;
-- then exact ID-linked metadata in ReplicatedStorage / PlayerGui.
-- External lookups are bounded, shared, and cached; never assume an unrelated
-- vehicle/NPC/other Dhab's quality applies to this model.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Resolver = {}
Resolver.__index = Resolver

local QUALITY_KEYS = {
    "DhabQuality", "DhabQualityPercent", "DhabQualityPercentage",
    "Quality", "QualityPercent", "QualityPercentage",
    "QualityValue", "QualityLevel", "QualityGrade",
    "QualityScore", "QualityPct", "Qlt",
    "جودة", "درجةالجودة", "نسبةالجودة",
}
local RARITY_KEYS = {"Rarity", "Grade", "ندرة", "درجة"}
local INDEX = {}
local LAST_INDEX = -math.huge
local INDEX_ITEMS = 0
local INDEX_LIMIT = 12000

local function compact(key)
    return tostring(key):lower():gsub("[%s_%-%.]", "")
end

local function kind(key)
    local normalized = compact(key)
    for i, candidate in ipairs(QUALITY_KEYS) do
        if normalized == compact(candidate) then return "Quality", i end
    end
    for i, candidate in ipairs(RARITY_KEYS) do
        if normalized == compact(candidate) then return
            candidate == "Grade" and "Grade" or "Rarity", 100 + i
        end
    end
    return nil
end

local function format(value)
    if type(value) == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return nil
        end
        if value % 1 == 0 then return tostring(math.floor(value)) end
        return string.format("%.3f", value):gsub("0+$", ""):gsub("%.$", "")
    end
    if type(value) == "string" then
        local s = value:match("^%s*(.-)%s*$")
        if s ~= "" then return s:sub(1, 70) end
    end
    return nil
end

local function candidate(key, value, source, depth, external)
    local label, keyRank = kind(key)
    local txt = format(value)
    if not label or not txt then return nil end
    local k = compact(key)
    if label == "Quality" and
        (k:find("percent", 1, true) or k:find("pct", 1, true)
            or k:find("نسبة", 1, true)) and not txt:find("%%") then
        txt = txt .. "%"
    end
    local scopePenalty = external and 1000 or 0
    local rank = scopePenalty + keyRank + depth * 2
    return {
        Text = label .. ": " .. txt,
        Source = source,
        Rank = rank,
        IsQuality = label == "Quality",
    }
end

local function readLocal(model, external)
    local best = nil
    local function choose(value)
        if not value then return end
        if not best or (value.IsQuality and not best.IsQuality)
            or (value.IsQuality == best.IsQuality and value.Rank < best.Rank) then
            best = value
        end
    end
    local function attributes(item, depth)
        for key, value in pairs(item:GetAttributes()) do
            choose(candidate(key, value,
                item:GetFullName() .. ".Attribute." .. key, depth, external))
        end
    end
    attributes(model, 0)
    local children = model:GetDescendants()
    for i = 1, math.min(#children, 250) do
        local item = children[i]
        local depth = 1
        local parent = item.Parent
        while parent and parent ~= model and depth < 8 do
            depth = depth + 1
            parent = parent.Parent
        end
        attributes(item, depth)
        if item:IsA("StringValue") or item:IsA("NumberValue")
            or item:IsA("IntValue") then
            choose(candidate(item.Name, item.Value, item:GetFullName(),
                depth, external))
        elseif item:IsA("TextLabel") then
            local textValue = item.Text
            if type(textValue) == "string" then
                -- A UI label with both an explicit quality word and a value.
                local number = textValue:match("[Qq]uality%s*[:：%-]%s*(%S+)")
                    or textValue:match("جودة%s*[:：%-]%s*(%S+)")
                if number then
                    choose(candidate("Quality", number,
                        item:GetFullName() .. ".Text", depth + 40, external))
                end
            end
        end
    end
    return best
end

local function modelIds(model)
    local ids = {}
    local modelName = model.Name:lower()
    if modelName:match("^dhab_[%w%-]+$") then
        ids[modelName] = true
        ids[modelName:sub(6)] = true
    end
    -- Only a token explicitly attached to this model, not a random nearby ID.
    for _, key in ipairs({"DhabId", "DhabID", "CreatureId", "CreatureID"}) do
        local value = model:GetAttribute(key)
        if type(value) == "string" and #value >= 4 and #value < 80 then
            ids[value:lower()] = true
        end
    end
    return ids
end

local function addIndex(item)
    local name = item.Name:lower()
    local id = name:match("^dhab_([%w%-]+)$")
    if id then
        INDEX[id] = INDEX[id] or {}
        table.insert(INDEX[id], item)
        INDEX[name] = INDEX[name] or {}
        table.insert(INDEX[name], item)
    end
    -- Explicitly stored identity fields only; never match partial strings.
    for _, key in ipairs({"DhabId", "DhabID", "CreatureId", "CreatureID"}) do
        local value = item:GetAttribute(key)
        if type(value) == "string" and #value >= 4 and #value < 80 then
            local lowered = value:lower()
            INDEX[lowered] = INDEX[lowered] or {}
            table.insert(INDEX[lowered], item)
        end
    end
end

local function refreshIndex()
    local now = os.clock()
    if now - LAST_INDEX < 20 then return end
    LAST_INDEX = now
    INDEX = {}
    INDEX_ITEMS = 0
    local roots = {ReplicatedStorage}
    local player = Players.LocalPlayer
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
    if playerGui then table.insert(roots, playerGui) end

    for _, root in ipairs(roots) do
        local descendants = root:GetDescendants()
        for i = 1, #descendants do
            INDEX_ITEMS = INDEX_ITEMS + 1
            if INDEX_ITEMS > INDEX_LIMIT then return end
            local item = descendants[i]
            -- Only folders/models/configuration/value containers can hold
            -- metadata associated with a precise Dhab ID.
            if item:IsA("Folder") or item:IsA("Model")
                or item:IsA("Configuration") or item:IsA("ValueBase") then
                addIndex(item)
            end
        end
    end
end

local function resolve(model)
    if not model or not model.Parent then
        return {Text = "Quality: Unknown", Source = "object unavailable"}
    end
    local result = readLocal(model, false)
    if result and result.IsQuality then return result end

    local ids = modelIds(model)
    if next(ids) then
        refreshIndex()
        local visited = {}
        for id in pairs(ids) do
            for _, external in ipairs(INDEX[id] or {}) do
                if external ~= model and external.Parent and not visited[external] then
                    visited[external] = true
                    local found = readLocal(external, true)
                    if found and ((not result)
                        or (found.IsQuality and not result.IsQuality)
                        or (found.IsQuality == result.IsQuality
                            and found.Rank < result.Rank)) then
                        result = found
                    end
                end
            end
        end
    end
    return result or {
        Text = "Quality: Unknown",
        Source = "No per-Dhab replicated quality value found",
    }
end

function Resolver.Read(model)
    return resolve(model)
end

function Resolver.Diagnose(model)
    if not model then return "No Dhab model selected" end
    local result = resolve(model)
    local lines = {
        "=== IVORY DHAB QUALITY DIAGNOSTIC ===",
        "Model: " .. model:GetFullName(),
        result.Text,
        "Resolved source: " .. tostring(result.Source),
        "Model attributes:",
    }
    local attrs = model:GetAttributes()
    local attrCount = 0
    for key, value in pairs(attrs) do
        attrCount = attrCount + 1
        if attrCount <= 70 then
            table.insert(lines, "  " .. key .. " = " .. tostring(value):sub(1, 70))
        end
    end
    if attrCount == 0 then table.insert(lines, "  none") end

    local ids = modelIds(model)
    local idText = {}
    for id in pairs(ids) do table.insert(idText, id) end
    table.sort(idText)
    table.insert(lines, "Exact model IDs: " .. table.concat(idText, ", "))
    table.insert(lines, "External index items inspected: " .. tostring(INDEX_ITEMS))
    table.insert(lines, "Possible quality metadata objects:")
    local matches = 0
    for _, item in ipairs(model:GetDescendants()) do
        if matches >= 40 then break end
        local label = kind(item.Name)
        local values = item:IsA("ValueBase") and tostring(item.Value)
            or (item:IsA("TextLabel") and item.Text) or nil
        if label or values and
            (values:lower():find("quality", 1, true)
                or values:find("جودة", 1, true)) then
            matches = matches + 1
            table.insert(lines, "  " .. item:GetFullName()
                .. (values and (" = " .. values:sub(1, 80)) or ""))
        end
    end
    if matches == 0 then table.insert(lines, "  none") end
    if result.Text == "Quality: Unknown" then
        table.insert(lines,
            "Unknown means the client may not receive a quality value for this Dhab.")
        table.insert(lines,
            "Use an official server script or game's data model to expose Quality.")
    end
    return table.concat(lines, "\n")
end

function Resolver.new(model)
    return setmetatable({
        Model = model,
        LastCheck = -math.huge,
        LastResult = {Text = "Quality: Unknown", Source = "unchecked"},
    }, Resolver)
end

function Resolver:Get()
    if os.clock() - self.LastCheck >= 1 then
        self.LastCheck = os.clock()
        self.LastResult = resolve(self.Model)
    end
    return self.LastResult
end

return Resolver