-- IVORY monster diagnostics. P inspects a model under the cursor.
-- O lists nearby replicated NPC candidates, even when aiming at Terrain.
-- Cannot inspect server-only or streamed-out instances.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local MonsterInspector = {}
MonsterInspector.__index = MonsterInspector

local SCAN_RADIUS = 1200
local CURSOR_RADIUS_PX = 175
local MAX_LIST = 25

local function isPlayerOwned(instance)
    local current = instance
    while current and current ~= workspace do
        if current:IsA("Model") and Players:GetPlayerFromCharacter(current) then
            return true
        end
        current = current.Parent
    end
    return false
end

local function modelPosition(model)
    local root = model.PrimaryPart
        or model:FindFirstChild("HumanoidRootPart", true)
        or model:FindFirstChildWhichIsA("BasePart", true)
    return root and root.Position or nil
end

local function attributeLines(model, lines)
    local entries = {}
    for key, value in pairs(model:GetAttributes()) do
        table.insert(entries, {key = tostring(key), value = tostring(value)})
    end
    table.sort(entries, function(a, b) return a.key < b.key end)
    if #entries == 0 then
        table.insert(lines, "Attributes: none")
    else
        for _, entry in ipairs(entries) do
            table.insert(lines, "Attribute " .. entry.key .. " = " .. entry.value)
        end
    end
end

function MonsterInspector.new(key, scanKey, monsterTracker, markKey, qualityClass)
    local self = setmetatable({
        Key = key,
        ScanKey = scanKey or Enum.KeyCode.O,
        MarkKey = markKey or Enum.KeyCode.M,
        OnMarked = nil,
        Tracker = monsterTracker,
        QualityResolver = qualityClass,
        Mouse = Players.LocalPlayer:GetMouse(),
        Connection = nil,
    }, MonsterInspector)

    self.Connection = UIS.InputBegan:Connect(function(input, processed)
        if processed or UIS:GetFocusedTextBox() then return end
        if input.KeyCode == self.Key then
            self:InspectAtCursor()
        elseif input.KeyCode == self.ScanKey then
            self:ScanNearby()
        elseif input.KeyCode == self.MarkKey then
            self:MarkAtCursor()
        end
    end)
    return self
end

function MonsterInspector:IsCandidate(model)
    return self.Tracker:IsCandidate(model)
end

function MonsterInspector:NearestModels()
    local camera = workspace.CurrentCamera
    local character = Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local origin = root and root.Position or (camera and camera.CFrame.Position)
    if not origin then return {}, {} end

    local strong, unknown, catches, cars = {}, {}, {}, {}
    for _, instance in ipairs(workspace:GetDescendants()) do
        if instance:IsA("Model") and not isPlayerOwned(instance) then
            local position = modelPosition(instance)
            if position then
                local distance = (position - origin).Magnitude
                if distance <= SCAN_RADIUS then
                    local entry = {
                        Model = instance,
                        Position = position,
                        Distance = distance,
                    }
                    if self.Tracker:IsMonster(instance) then
                        table.insert(strong, entry)
                    elseif self.Tracker:IsHandCatch(instance) then
                        table.insert(catches, entry)
                    elseif self.Tracker:Classify(instance) == "car" then
                        table.insert(cars, entry)
                    else
                        table.insert(unknown, entry)
                    end
                end
            end
        end
    end

    local sortByDistance = function(a, b)
        return a.Distance < b.Distance
    end
    table.sort(strong, sortByDistance)
    table.sort(unknown, sortByDistance)
    table.sort(catches, sortByDistance)
    table.sort(cars, sortByDistance)
    return strong, unknown, catches, cars
end

function MonsterInspector:RaycastModel()
    local camera = workspace.CurrentCamera
    if not camera then return nil end

    -- This ignores the local character and Terrain, but does not bypass
    -- the rest of the map; candidate search handles blocked sight lines.
    local excluded = {workspace.Terrain}
    local character = Players.LocalPlayer.Character
    if character then table.insert(excluded, character) end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = excluded
    params.IgnoreWater = true

    local cursor = UIS:GetMouseLocation()
    local ray = camera:ViewportPointToRay(cursor.X, cursor.Y)
    local result = workspace:Raycast(ray.Origin, ray.Direction * 1500, params)
    if not result then return nil end
    return result.Instance
end

function MonsterInspector:ModelFromPart(part)
    if not part or part == workspace.Terrain or isPlayerOwned(part) then
        return nil
    end

    local model = part
    local fallback
    while model and model ~= workspace do
        if model:IsA("Model") then
            if not fallback then fallback = model end
            if self:IsCandidate(model) then return model end
        end
        model = model.Parent
    end
    -- This could be scenery; only use if no real candidate is under the cursor.
    return fallback
end

function MonsterInspector:ClosestToCursor(strong)
    local camera = workspace.CurrentCamera
    if not camera then return nil end

    local mouse = UIS:GetMouseLocation()
    local best, score = nil, math.huge

    for _, entry in ipairs(strong) do
        local projected, visible = camera:WorldToViewportPoint(entry.Position)
        if projected.Z > 0 and visible then
            local dx, dy = projected.X - mouse.X, projected.Y - mouse.Y
            local pixels = math.sqrt(dx * dx + dy * dy)
            if pixels <= CURSOR_RADIUS_PX then
                local rank = pixels + entry.Distance * 0.015
                if rank < score then
                    best = entry.Model
                    score = rank
                end
            end
        end
    end
    return best
end

function MonsterInspector:FormatModel(model, note)
    local lines = {
        "=== IVORY MONSTER INSPECTOR ===",
        "Selection: " .. (note or "Cursor"),
        "MODEL: " .. model.Name,
        "Class: " .. model.ClassName,
        "PATH: " .. model:GetFullName(),
        "Recognized category: " .. tostring(
            self.Tracker:Classify(model) or "unknown"
        ),
    }

    local position = modelPosition(model)
    if position then
        table.insert(lines, "Position: " .. tostring(position))
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        table.insert(lines, "Health: " .. tostring(humanoid.Health)
            .. " / " .. tostring(humanoid.MaxHealth))
    else
        table.insert(lines, "Humanoid: none")
    end

    local tags = CollectionService:GetTags(model)
    table.sort(tags)
    table.insert(lines, "Tags: " .. (#tags > 0 and table.concat(tags, ", ") or "none"))
    attributeLines(model, lines)
    if self.QualityResolver then
        local quality = self.QualityResolver.Read(model)
        table.insert(lines, quality.Text .. " (source: " ..
            tostring(quality.Source) .. ")")
        if self.Tracker:IsDhab(model) then
            table.insert(lines, "--- QUALITY DETAILS ---")
            table.insert(lines, self.QualityResolver.Diagnose(model))
        end
    end

    local parent = model.Parent
    if parent and parent ~= workspace then
        table.insert(lines, "Parent: " .. parent:GetFullName())
    end

    table.insert(lines, "Note: a model name/path may be its identifier; numeric IDs are optional.")
    return table.concat(lines, "\n")
end

function MonsterInspector:PrintAndCopy(report)
    print(report)
    if type(setclipboard) == "function" then
        local ok = pcall(setclipboard, report)
        if ok then
            print("[IVORY] Inspection report copied to clipboard.")
        end
    end
end

function MonsterInspector:InspectAtCursor()
    local rawTarget = self.Mouse.Target
    local rayTarget = self:RaycastModel()

    local targeted = self:ModelFromPart(rawTarget)
    if targeted and self:IsCandidate(targeted) then
        self:PrintAndCopy(self:FormatModel(targeted, "Cursor target"))
        return
    end

    local fromRay = self:ModelFromPart(rayTarget)
    if fromRay and self:IsCandidate(fromRay) then
        self:PrintAndCopy(self:FormatModel(fromRay, "Raycast (Terrain excluded)"))
        return
    end

    -- Both mouse and ray can hit Terrain or scenery instead of a creature.
    local strong, unknown, catches, cars = self:NearestModels()
    local nearCursor = self:ClosestToCursor(strong)
    if nearCursor then
        self:PrintAndCopy(self:FormatModel(nearCursor, "Nearest NPC on screen"))
    elseif targeted or fromRay then
        local model = targeted or fromRay
        self:PrintAndCopy(self:FormatModel(model, "Unclassified model under cursor")
            .. "\nHint: Press O to list potential monster models nearby.")
    else
        self:PrintAndCopy(self:BuildList(strong, unknown,
            "No monster model under cursor (Terrain or empty space).",
            catches, cars))
    end
end

function MonsterInspector:BuildList(strong, unknown, reason, catches, cars)
    catches = catches or {}
    cars = cars or {}
    local lines = {
        "=== IVORY NEARBY MODEL SCAN ===",
        reason or "Nearby replicated Workspace models",
        "Recognized monster models: " .. tostring(#strong),
        "Thrown HandCatch models: " .. tostring(#catches),
        "Whole car models: " .. tostring(#cars),
        "Other nearby models: " .. tostring(#unknown),
        "Radius: " .. tostring(SCAN_RADIUS) .. " studs",
        "Only the first " .. tostring(MAX_LIST) .. " models from each group are listed.",
        "",
        "RECOGNIZED MONSTERS:",
    }

    if #strong == 0 then table.insert(lines, "  none detected") end
    for index = 1, math.min(#strong, MAX_LIST) do
        local item = strong[index]
        local quality = self.QualityResolver
            and self.QualityResolver.Read(item.Model)
        local tier = item.Model:GetAttribute("Tier")
        local state = item.Model:GetAttribute("State")
        table.insert(lines, string.format("%d. %s | %.0f studs | Tier %s | %s | %s | %s",
            index, item.Model.Name, item.Distance,
            tostring(tier or "Unknown"),
            tostring(state or "Unknown"),
            quality and quality.Text or "Quality: Unknown",
            item.Model:GetFullName()))
    end

    table.insert(lines, "")
    table.insert(lines, "THROWN HANDCATCH OBJECTS:")
    if #catches == 0 then table.insert(lines, "  none detected") end
    for index = 1, math.min(#catches, MAX_LIST) do
        local item = catches[index]
        table.insert(lines, string.format("%d. %s | %.0f studs | %s",
            index, item.Model.Name, item.Distance, item.Model:GetFullName()))
    end

    table.insert(lines, "")
    table.insert(lines, "WHOLE CARS:")
    if #cars == 0 then table.insert(lines, "  none detected") end
    for index = 1, math.min(#cars, MAX_LIST) do
        local item = cars[index]
        table.insert(lines, string.format("%d. %s | %.0f studs | %s",
            index, item.Model.Name, item.Distance, item.Model:GetFullName()))
    end

    table.insert(lines, "")
    table.insert(lines, "OTHER MODELS (NPCs or scenery):")
    if #unknown == 0 then table.insert(lines, "  none in range") end
    for index = 1, math.min(#unknown, MAX_LIST) do
        local item = unknown[index]
        table.insert(lines, string.format("%d. %s | %.0f studs | %s",
            index, item.Model.Name, item.Distance, item.Model:GetFullName()))
    end

    table.insert(lines, "")
    table.insert(lines, "Wildlife source: Workspace.DhabWild (when present).")
    table.insert(lines, "Point at a monster and press P for full attributes/tags.")
    table.insert(lines, "Close the F9 console before aiming.")
    table.insert(lines, "Server-only and streamed-out models cannot be inspected.")
    return table.concat(lines, "\n")
end

function MonsterInspector:ScanNearby()
    local strong, unknown, catches, cars = self:NearestModels()
    self:PrintAndCopy(self:BuildList(strong, unknown, nil, catches, cars))
end

function MonsterInspector:MarkAtCursor()
    local raw = self:ModelFromPart(self.Mouse.Target)
    local ray = self:ModelFromPart(self:RaycastModel())
    local strong = self:NearestModels()
    local candidate = nil

    -- Prefer a precise cursor selection. If terrain blocked it, search
    -- only among recognizable nearby NPCs; never mark Terrain.
    if raw then
        candidate = raw
    elseif ray then
        candidate = ray
    else
        candidate = self:ClosestToCursor(strong)
    end

    if not candidate then
        warn("[IVORY] Could not select a model. Use Targets > Show scenery and TRACK.")
        return
    end

    if self.Tracker:TrackName(candidate) then
        self:PrintAndCopy(self:FormatModel(candidate, "Registered monster (M)"))
        if self.OnMarked then self.OnMarked(candidate) end
    end
end

function MonsterInspector:Destroy()
    if self.Connection then self.Connection:Disconnect() end
    self.Connection = nil
end

return MonsterInspector