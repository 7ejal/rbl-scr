-- Owns camera field of view; independent from ESP on/off.
local FOVController = {}
FOVController.__index = FOVController

function FOVController.new(settings)
    local camera = workspace.CurrentCamera
    local original = camera and camera.FieldOfView or 70
    return setmetatable({
        Settings = settings,
        Original = original,
        Value = math.clamp(
            math.round((settings.CameraFOV or 0) > 0
                and settings.CameraFOV or original),
            settings.MinFOV, settings.MaxFOV
        ),
        Active = true,
    }, FOVController)
end

function FOVController:GetFOV()
    return self.Value
end

function FOVController:SetFOV(value)
    self.Value = math.clamp(
        math.round(value), self.Settings.MinFOV, self.Settings.MaxFOV
    )
    self:Update(workspace.CurrentCamera)
end

function FOVController:Update(camera)
    if self.Active and camera and math.abs(camera.FieldOfView - self.Value) > 0.01 then
        camera.FieldOfView = self.Value
    end
end

function FOVController:Destroy()
    self.Active = false
    local camera = workspace.CurrentCamera
    if camera then camera.FieldOfView = self.Original end
end

return FOVController