local UIS=game:GetService("UserInputService")
local Stop={}
Stop.__index=Stop
function Stop.new(key,onStop)
    local self=setmetatable({OnStop=onStop,Key=key or Enum.KeyCode.F8},Stop)
    self.Connection=UIS.InputBegan:Connect(function(input,processed)
        -- F8 must work even while the dashboard has keyboard focus.
        if input.KeyCode==self.Key then
            pcall(self.OnStop)
        end
    end)
    return self
end
function Stop:Destroy()
    if self.Connection then self.Connection:Disconnect() end
    self.Connection=nil
end
return Stop