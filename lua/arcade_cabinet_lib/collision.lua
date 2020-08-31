local COLLISION = {
    types = {
        BOX = 0,
        CIRCLE = 1,
        POLY = 2
    }
}

local axisRotateAng = Angle(0, 90, 0)

function COLLISION:RotateAndTranslateVerts(poly)
    if not poly.collision.actualVertices then
        poly.collision.actualVertices = {}
    end

    for i = 1, #poly.collision.vertices do
        local rotated = poly.collision.actualVertices[i] or Vector()
        rotated:Set(poly.collision.vertices[i])
        rotated:Rotate(poly.ang)

        poly.collision.actualVertices[i] = poly.pos + rotated
    end
end

function COLLISION:GetAxes(poly, includeFaces)
    local axes = {}
    local faces = {}

    if not poly.collision.axes then
        poly.collision.axes = {}
    end

    for i = 1, #poly.collision.actualVertices do
        local v1 = poly.collision.actualVertices[i]
        local v2 = poly.collision.actualVertices[i + 1 == #poly.collision.actualVertices + 1 and 1 or i + 1]

        local normal = v2 - v1
        normal:Normalize()

        local axis = poly.collision.axes[i] or Vector()
        axis:Set(normal)
        axis:Rotate(axisRotateAng)

        table.insert(axes, axis)
        table.insert(faces, { v1, v2 })
    end

    if includeFaces then
        return axes, faces
    end

    return axes
end

function COLLISION:GetNearestVertex(circle, poly)
    local min = circle.pos:DistToSqr(poly.collision.actualVertices[1])
    local d = 0
    local index = 1

    for i = 2, #poly.collision.actualVertices do
        d = circle.pos:DistToSqr(poly.collision.actualVertices[i])
        if d < min then
            min = d
            index = i
        end
    end

    return poly.collision.actualVertices[index]
end

function COLLISION:Projection(obj, axis)
    local min, max = 0, 0
    if obj.collision.type == self.types.CIRCLE then
        local circlePro = obj.pos:Dot(axis)
        min = circlePro - obj.collision.radius
        max = circlePro + obj.collision.radius
        return min, max
    end

    min = obj.collision.actualVertices[1]:Dot(axis)
    max = obj.collision.actualVertices[1]:Dot(axis)
    local pro = nil

    for i = 2, #obj.collision.actualVertices do
        pro = obj.collision.actualVertices[i]:Dot(axis)
        if pro < min then
            min = pro
        elseif pro > max then
            max = pro
        end
    end

    return min, max
end

function COLLISION:LineOverlap(aMin, aMax, bMin, bMax)
    return math.max(0, math.floor(math.min(aMax, bMax) - math.max(aMin, bMin)))
end

function COLLISION:CirclePolyCollision(objA, objB)
    local poly = {}
    local circle = {}

    if objA.collision.type == self.types.CIRCLE then
        circle = objA
        poly = objB
    else
        circle = objB
        poly = objA
    end

    self:RotateAndTranslateVerts(poly)

    local axes = self:GetAxes(poly)
    local vertex = self:GetNearestVertex(circle, poly)
    local lastAxis = vertex - circle.pos
    lastAxis:Normalize()
    table.insert(axes, lastAxis)

    local overlap, minOverlap = 0, 0

    local mtvAxisIndex = 1

    for i = 1, #axes do
        local minA, maxA = self:Projection(circle, axes[i])
        local minB, maxB = self:Projection(poly, axes[i])
        overlap = self:LineOverlap(minA, maxA, minB, maxB)

        if overlap == 0 then
            return false
        end

        if i == 1 then
            minOverlap = overlap
            mtvAxisIndex = i
        else
            if overlap < minOverlap then
                minOverlap = overlap
                mtvAxisIndex = i
            end
        end
    end

    local ptp = objA.pos - objB.pos
    local mtvAxis = axes[mtvAxisIndex]
    if ptp:Dot(mtvAxis) <= 0 then
        mtvAxis:Mul(-1)
    end

    local normal = poly.pos - circle.pos
    normal:Normalize()
    local scalarProjection = normal * circle.collision.radius
    local pointOfCollision = circle.pos + scalarProjection
    return true, mtvAxis, minOverlap, pointOfCollision
end

function COLLISION:PolyPolyCollision(objA, objB)
    self:RotateAndTranslateVerts(objA)
    self:RotateAndTranslateVerts(objB)

    local axes, faces = self:GetAxes(objA, true)
    local axesB, facesB = self:GetAxes(objB, true)
    for i = 1, #axesB do
        table.insert(axes, axesB[i])
        table.insert(faces, facesB[i])
    end

    local overlap, minOverlap = 0, 0

    local mtvAxisIndex = 1

    for i = 1, #axes do
        local minA, maxA = self:Projection(objA, axes[i])
        local minB, maxB = self:Projection(objB, axes[i])

        overlap = self:LineOverlap(minA, maxA, minB, maxB)

        if overlap == 0 then
            return false
        end

        if i == 1 then
            minOverlap = overlap
        else
            if overlap <= minOverlap then
                minOverlap = overlap
                mtvAxisIndex = i
            end
        end
    end

    local ptp = objA.pos - objB.pos
    local mtvAxis = axes[mtvAxisIndex]

    if ptp:Dot(axes[mtvAxisIndex]) <= 0 then
        mtvAxis:Mul(-1)
    end

    return true, mtvAxis, minOverlap
end

function COLLISION:BoxCollision(objA, objB)
    return objA.pos.x < objB.pos.x + objB.collision.width and
        objA.pos.x + objA.collision.width > objB.pos.x and
        objA.pos.y < objB.pos.y + objB.collision.height and
        objA.pos.y + objA.collision.height > objB.pos.y
end

function COLLISION:CircleCollision(objA, objB)
    local rad = objA.collision.radius + objB.collision.radius
    return objA.pos:DistToSqr(objB.pos) < rad * rad
end

function COLLISION:IsColliding(objA, objB)
    if objA.collision.type == self.types.BOX and objB.collision.type == self.types.BOX then
        return self:BoxCollision(objA, objB)
    end

    if objA.collision.type == self.types.CIRCLE and objB.collision.type == self.types.CIRCLE then
        return self:CircleCollision(objA, objB)
    end

    if objA.collision.type == self.types.POLY and objB.collision.type == self.types.POLY then
        return self:PolyPolyCollision(objA, objB)
    end

    if
        objA.collision.type == self.types.CIRCLE and objB.collision.type == self.types.POLY or
        objA.collision.type == self.types.POLY and objB.collision.type == self.types.CIRCLE
    then
        return self:CirclePolyCollision(objA, objB)
    end

    error(
        "Unsupported collision type combination: "
        .. table.KeyFromValue(self.types, objA.collision.type) .. " "
        .. table.KeyFromValue(self.types, objB.collision.type)
    )

    return false
end

return COLLISION