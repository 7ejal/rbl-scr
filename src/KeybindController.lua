-- Keybind isolated from the GUI and ESP features.
local UIS = game:GetService("UserInputService")
local KeybindController = {}
KeybindController.__index = KeybindController

function KeybindController.new(key, onToggle)
    local self = setmetatable({}, KeybindController)
    self.Connection = UIS.InputBegan:Connect(function(input, processed)
        if processed or UIS:GetFocusedTextBox() then return end
        if input.KeyCode == key then onToggle() end
    end)
    return self
end

function KeybindController:Destroy()
    if self.Connection then self.Connection:Disconnect() end
    self.Connection = nil
end

return KeybindController