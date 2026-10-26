-- Project an entire Model or BasePart's corners into 2D screen coordinates.
local Projection = {}

function Projection.GetRect(camera, target)
    local cf, size
    if target:IsA("BasePart") then
        cf, size = target.CFrame, target.Size
    else
        cf, size = target:GetBoundingBox()
    end

    local half = size * 0.5
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge

    for x = -1, 1, 2 do
        for y = -1, 1, 2 do
            for z = -1, 1, 2 do
                local offset = Vector3.new(x * half.X, y * half.Y, z * half.Z)
                local point = camera:WorldToViewportPoint(cf:PointToWorldSpace(offset))
                if point.Z <= 0 then return nil end
                minX, minY = math.min(minX, point.X), math.min(minY, point.Y)
                maxX, maxY = math.max(maxX, point.X), math.max(maxY, point.Y)
            end
        end
    end

    local viewport = camera.ViewportSize
    if maxX < 0 or minX > viewport.X or maxY < 0 or minY > viewport.Y then
        return nil
    end
    local width, height = maxX - minX, maxY - minY
    if width < 2 or height < 2 then return nil end
    return minX, minY, width, height
end

return Projection