-- Per-creature quality metadata reader; never invents a quality value.
-- Supports attributes, ValueBase instances and displayed quality text.
local QualityResolver = {}
QualityResolver.__index = QualityResolver

local QUALITY_KEYS = {
    "DhabQuality", "DhabQualityPercent", "DhabQualityPercentage",
    "Quality", "QualityPercent", "QualityPercentage", "QualityValue",
    "QualityLevel", "quality", "dhabQuality", "qualityPercent",
    "Grade", "Rarity",
}
local NORMALIZED = {}
for index, key in ipairs(QUALITY_KEYS) do
    local normal = string.lower(key):gsub("[^%w]", "")
    NORMALIZED[normal] = {rank = index, key = key}
end

local function format(value)
    local valueType = typeof(value)
    if valueType == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return nil
        end
        if value % 1 == 0 then return tostring(math.floor(value)) end
        return string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
    end
    if valueType == "string" and value ~= "" then
        return value:sub(1, 70)
    end
    if valueType == "boolean" then return tostring(value) end
    return nil
end

local function qualityName(key)
    local normalized = string.lower(key):gsub("[^%w]", "")
    return NORMALIZED[normalized]
end

local function tryValue(value, key)
    local text = format(value)
    if not text then return nil end
    local meta = qualityName(key)
    if not meta then return nil end
    local label = (meta.key == "Rarity") and "Rarity"
        or (meta.key == "Grade" and "Grade" or "Quality")
    if label == "Quality" and (string.find(string.lower(key), "percent", 1, true)) then
        if text:sub(-1) ~= "%" then text = text .. "%" end
    end
    return {Text = label .. ": " .. text, Rank = meta.rank, Source = key}
end

local function readOnce(model)
    if not model or not model.Parent then
        return {Text = "Quality: Unknown", Source = "unavailable"}
    end

    local best
    local function consider(value, key, source)
        local entry = tryValue(value, key)
        if entry and (not best or entry.Rank < best.Rank) then
            entry.Source = source .. "." .. key
            best = entry
        end
    end

    -- Prefer per-model attributes, followed by descendant metadata.
    local function attributes(instance, source)
        for key, value in pairs(instance:GetAttributes()) do
            consider(value, key, source)
        end
    end

    attributes(model, model.Name)
    -- Direct children often contain Stats, Data or Configuration values.
    -- Bounded descendant traversal limits overhead on detailed rigs.
    local descendants = model:GetDescendants()
    for index = 1, math.min(200, #descendants) do
        local item = descendants[index]
        if item:IsA("StringValue")
            or item:IsA("NumberValue")
            or item:IsA("IntValue") then
            consider(item.Value, item.Name, item:GetFullName())
        end
        if item:IsA("TextLabel") then
            local value = item.Text
            if type(value) == "string" then
                -- Only text that explicitly names quality/rarity.
                if string.find(string.lower(value), "quality", 1, true)
                    or string.find(value, "جودة", 1, true) then
                    local val = value:match(":%s*(.+)$")
                    if val and val ~= "" and (not best) then
                        best = {
                            Text = "Quality: " .. val:sub(1, 70),
                            Source = item:GetFullName() .. ".Text",
                            Rank = 100,
                        }
                    end
                end
            end
        end
        attributes(item, item.Name)
    end

    if best then return best end
    return {Text = "Quality: Unknown", Source = "no replicated quality field"}
end

function QualityResolver.Read(model)
    return readOnce(model)
end

function QualityResolver.new(model)
    return setmetatable({
        Model = model,
        LastCheck = -math.huge,
        LastResult = {Text = "Quality: Unknown", Source = "not checked"},
    }, QualityResolver)
end

function QualityResolver:Get()
    local now = os.clock()
    if now - self.LastCheck >= 1 then
        self.LastCheck = now
        self.LastResult = readOnce(self.Model)
    end
    return self.LastResult
end

return QualityResolver