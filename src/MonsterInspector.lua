-- Press P while hovering a model to discover paths, tags and attributes.
-- Model instances do not necessarily have stable numeric monster IDs.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local MonsterInspector = {}
MonsterInspector.__index = MonsterInspector

function MonsterInspector.new(key)
    local self = setmetatable({Key = key}, MonsterInspector)
    local mouse = Players.LocalPlayer:GetMouse()

    self.Connection = UserInputService.InputBegan:Connect(function(input, processed)
        if processed or UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode ~= self.Key then return end
        local target = mouse.Target
        if not target then
            warn("[IVORY] Point at a monster before pressing P.")
            return
        end
        self:Inspect(target)
    end)

    return self
end

function MonsterInspector:Inspect(target)
    local lines = {
        "=== IVORY MONSTER INSPECTOR ===",
        "Target: " .. target.Name,
        "Class: " .. target.ClassName,
        "Path: " .. target:GetFullName(),
    }

    local current = target
    while current and current ~= workspace do
        if current:IsA("Model") then
            table.insert(lines, "")
            table.insert(lines, "MODEL: " .. current.Name)
            table.insert(lines, "PATH: " .. current:GetFullName())

            local humanoid = current:FindFirstChildOfClass("Humanoid")
            if humanoid then
                table.insert(lines, "Health: " .. tostring(humanoid.Health))
            end

            local tags = CollectionService:GetTags(current)
            table.insert(lines, "Tags: " .. table.concat(tags, ", "))
            for key, value in pairs(current:GetAttributes()) do
                table.insert(lines, "Attribute " .. key .. " = " .. tostring(value))
            end
        end
        current = current.Parent
    end

    local result = table.concat(lines, "\n")
    print(result)
    if type(setclipboard) == "function" then
        local ok = pcall(setclipboard, result)
        if ok then print("[IVORY] Inspector details copied to clipboard.") end
    end
    return result
end

function MonsterInspector:Destroy()
    if self.Connection then self.Connection:Disconnect() end
    self.Connection = nil
end

return MonsterInspector