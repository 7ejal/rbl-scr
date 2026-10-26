-- Inject only W/A/S/D using supported executor functions. Never hold keys
-- after emergency stop, reload, seat exit or owner character death.
local Input = {}
Input.__index = Input
local CODES = {W=0x57,A=0x41,S=0x53,D=0x44}
local KEY = {W=Enum.KeyCode.W,A=Enum.KeyCode.A,S=Enum.KeyCode.S,D=Enum.KeyCode.D}

local function callable(name)
    local value
    if type(getgenv) == "function" then
        local ok, env = pcall(getgenv)
        if ok and type(env)=="table" then value=env[name] end
    end
    if type(value)=="function" then return value end
    if name=="keypress" then value=keypress end
    if name=="keyrelease" then value=keyrelease end
    if type(value)=="function" then return value end
    if type(_G)=="table" and type(_G[name])=="function" then
        return _G[name]
    end
    return nil
end

function Input.new()
    return setmetatable({
        Held={}, Method=nil, Error=nil, Vim=nil,
        ChangedAt=os.clock(), Destroyed=false,
        Pulses=0, SwitchedBackend=false,
    },Input)
end

function Input:Detect()
    if self.Method then return true end
    if callable("keypress") and callable("keyrelease") then
        self.Method="executor keypress/keyrelease"
        return true
    end
    local ok, vim=pcall(function()
        return game:GetService("VirtualInputManager")
    end)
    if ok and vim then
        -- The service may exist but reject SendKeyEvent. Dispatch is checked.
        self.Vim=vim
        self.Method="VirtualInputManager"
        return true
    end
    self.Error="Xeno has no keypress/keyrelease or VirtualInputManager"
    return false
end

function Input:Send(name,isDown)
    if self.Method=="executor keypress/keyrelease" then
        local fn=callable(isDown and "keypress" or "keyrelease")
        if not fn then return false,"Keyboard API disappeared" end
        return pcall(fn,CODES[name])
    end
    if self.Method=="VirtualInputManager" then
        return pcall(function()
            self.Vim:SendKeyEvent(isDown,KEY[name],false,nil)
        end)
    end
    return false,"No supported keyboard input"
end

function Input:Set(keys)
    if self.Destroyed then return false,"Input destroyed" end
    if not self:Detect() then return false,self.Error end
    -- Release first, so conflicting A/D and W/S cannot remain held.
    for name in pairs(self.Held) do
        if not keys[name] then
            local ok,err=self:Send(name,false)
            if not ok then
                self.Error="Unable to release "..name..": "..tostring(err)
                self:ReleaseAll()
                return false,self.Error
            end
            self.Held[name]=nil
        end
    end
    for name in pairs(keys) do
        if CODES[name] and not self.Held[name] then
            local ok,err=self:Send(name,true)
            if not ok then
                self.Error="Unable to hold "..name..": "..tostring(err)
                self:ReleaseAll()
                return false,self.Error
            end
            self.Held[name]=true
            self.ChangedAt=os.clock()
        end
    end
    return true
end

-- Some executor keypress implementations generate an event but do not
-- maintain Roblox's down-state. Retry a fresh key-up/key-down pulse only
-- after actual vehicle movement has failed; never pulse every render frame.
function Input:Pulse(name)
    if self.Destroyed or not CODES[name] or not self.Held[name] then
        return false, "Cannot pulse an unheld key"
    end
    local released, releaseErr = self:Send(name,false)
    self.Held[name]=nil
    if not released then
        self.Error="Key release failed: "..tostring(releaseErr)
        self:ReleaseAll()
        return false,self.Error
    end
    local pressed, pressErr = self:Send(name,true)
    if not pressed then
        self.Error="Key re-press failed: "..tostring(pressErr)
        self:ReleaseAll()
        return false,self.Error
    end
    self.Held[name]=true
    self.Pulses=self.Pulses+1
    return true
end

-- Escalate once to Roblox's virtual input service when the original
-- executor press succeeds but the car has remained stationary.
function Input:TryAlternate()
    if self.SwitchedBackend or self.Destroyed then return false end
    self.SwitchedBackend=true
    if self.Method=="VirtualInputManager" then return false end
    local ok,v=pcall(function()
        return game:GetService("VirtualInputManager")
    end)
    if not ok or not v then
        self.Error="Alternate VirtualInputManager unavailable"
        return false
    end
    self:ReleaseAll()
    self.Vim=v
    self.Method="VirtualInputManager"
    self.Error=nil
    return true
end

function Input:Holding(name)
    return self.Held[name]==true
end

function Input:ReleaseAll()
    -- Retry releases even if one fails. Never simply clear keys first.
    for _,name in ipairs({"W","A","S","D"}) do
        if self.Held[name] then
            self:Send(name,false)
            self.Held[name]=nil
        end
    end
end

function Input:Destroy()
    self:ReleaseAll()
    self.Destroyed=true
end

return Input