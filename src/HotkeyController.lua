-- Rebindable hotkeys without replacing the safety-only F8 emergency key.
local UIS=game:GetService("UserInputService")
local Keys={}
Keys.__index=Keys
local choices={"H","J","K","L","B","N","R","T","Y","U","F6","F7","F9","F10"}
function Keys.new(settings,callbacks)
    local self=setmetatable({Settings=settings,Callbacks=callbacks,Map={
        Hunt="HuntHotkey",Next="NextTargetHotkey",Radar="RadarHotkey",
        Menu="MenuHotkey",Stop="StopHotkey",
    }},Keys)
    self.Connection=UIS.InputBegan:Connect(function(input,processed)
        if processed or UIS:GetFocusedTextBox() then return end
        local key=input.KeyCode
        if key==Enum.KeyCode.F8 or key==settings.MenuKey
            or key==settings.ToggleKey then return end
        for action,setting in pairs(self.Map) do
            local name=settings[setting]
            if type(name)=="string" and Enum.KeyCode[name]==key then
                local cb=self.Callbacks[action]
                if cb then pcall(cb) end
                return
            end
        end
    end)
    return self
end
function Keys:Cycle(action)
    local setting=self.Map[action]
    if not setting then return nil end
    local selected=self.Settings[setting]
    local i=table.find(choices,selected) or 0
    for offset=1,#choices do
        local nextName=choices[(i+offset-1)%#choices+1]
        if nextName~=self.Settings.MenuKey.Name
            and nextName~=self.Settings.ToggleKey.Name
            and nextName~="F8"
            and nextName~=self.Settings.HuntHotkey
            and nextName~=self.Settings.NextTargetHotkey
            and nextName~=self.Settings.RadarHotkey
            and nextName~=self.Settings.MenuHotkey
            and nextName~=self.Settings.StopHotkey then
            self.Settings[setting]=nextName;return nextName
        end
    end
    return selected
end
function Keys:Destroy()
    if self.Connection then self.Connection:Disconnect() end
    self.Connection=nil
end
return Keys