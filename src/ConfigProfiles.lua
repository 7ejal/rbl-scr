-- Named local configuration profiles, safe allowlist; no arbitrary Lua.
local Profiles={}
Profiles.__index=Profiles
local KEYS={
"AutoHuntEnabled","HuntCarEnabled","HuntAutoShoot",
"HuntCarTargetKmh","HuntCarInputMode","HuntStopDistance",
"HuntCarStopDistance","HuntSearchDistance","HuntPriority",
"HuntTierT1","HuntTierT2","HuntTierT3","HuntTierT4","HuntTierT5","HuntTierT6",
"AutoShootEnabled","AimEnabled","RadarEnabled","PerformanceMode",
"DhabStatsEnabled","DhabTierColorsEnabled","HuntHUDEnabled",
}
local templates={
["Car Hunting"]={AutoHuntEnabled=false,HuntCarEnabled=true,
    HuntCarInputMode="Auto",HuntCarTargetKmh=120,HuntCarStopDistance=65,
    HuntPriority="Closest",PerformanceMode=false},
["On Foot"]={AutoHuntEnabled=false,HuntCarEnabled=false,
    HuntPriority="Closest",HuntStopDistance=28,PerformanceMode=false},
["High Tier"]={AutoHuntEnabled=false,HuntPriority="Smart",
    HuntTierT1=false,HuntTierT2=false,HuntTierT3=true,
    HuntTierT4=true,HuntTierT5=true,HuntTierT6=true},
["Low FPS"]={AutoHuntEnabled=false,PerformanceMode=true,
    RadarEnabled=false,HuntHUDEnabled=false,DhabTierColorsEnabled=false},
}
function Profiles.new(settings)
    return setmetatable({Settings=settings,Last="No profile loaded"},Profiles)
end
function Profiles:ExportCurrent()
    local data={}
    for _,key in ipairs(KEYS) do
        local value=self.Settings[key]
        if type(value)=="boolean" or type(value)=="number"
            or type(value)=="string" then data[key]=value end
    end
    return data
end
function Profiles:Apply(name,settingCallback)
    local stored=self.Settings.ConfigSlots or {}
    local values=templates[name] or stored[name]
    if not values then return false,"Unknown profile" end
    -- Explicitly disable autonomous input BEFORE changing its controls.
    settingCallback("AutoHuntEnabled",false)
    settingCallback("AutoShootEnabled",false)
    for _,key in ipairs(KEYS) do
        local v=values[key]
        if v~=nil and key~="AutoHuntEnabled"
            and key~="AutoShootEnabled" then
            if type(v)==type(self.Settings[key]) then
                settingCallback(key,v)
            end
        end
    end
    -- Autonomous activity never starts simply from selecting a profile.
    self.Last=name.." loaded (Hunt/Shoot OFF; enable manually)"
    return true,self.Last
end
function Profiles:Save(name)
    if name~="Custom A" and name~="Custom B" then
        return false,"Only Custom A/B are writable"
    end
    self.Settings.ConfigSlots=self.Settings.ConfigSlots or {}
    self.Settings.ConfigSlots[name]=self:ExportCurrent()
    self.Last=name.." saved"
    return true,self.Last
end
Profiles.Keys=KEYS
return Profiles