-- Halt autonomous input on Roblox focus loss; never auto-resume on focus regain.
local UIS=game:GetService("UserInputService")
local Guard={}
Guard.__index=Guard
function Guard.new(onFocusLost)
    local self=setmetatable({
        Connections={},Supported=false,Focused=true,LastEvent="none",
    },Guard)
    local ok=pcall(function()
        table.insert(self.Connections,UIS.WindowFocusReleased:Connect(function()
            self.Focused=false
            self.LastEvent="window lost focus"
            if onFocusLost then pcall(onFocusLost) end
        end))
        table.insert(self.Connections,UIS.WindowFocused:Connect(function()
            self.Focused=true
            self.LastEvent="window focus returned (manual restart required)"
        end))
    end)
    self.Supported=ok
    return self
end
function Guard:Destroy()
    for _,c in ipairs(self.Connections) do c:Disconnect() end
    table.clear(self.Connections)
end
return Guard