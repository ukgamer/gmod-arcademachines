local GAME = {}

GAME.Name = "Collision Test"

local thePlayer = nil
local now = RealTime()

local objects = {
    {
        id = 1,
        pos = Vector(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2),
        ang = Angle(),
        collision = {
            type = COLLISION.TYPE_POLY,
            vertices = {
                Vector(-10, 10),
                Vector(10, 10),
                Vector(10, -10),
                Vector(-10, -10)
            }
        }
    },
    {
        id = 2,
        pos = Vector(SCREEN_WIDTH - 115, 300),
        ang = Angle(),
        collision = {
            type = COLLISION.TYPE_CIRCLE,
            radius = 10
        }
    },
    {
        id = 3,
        pos = Vector(SCREEN_WIDTH - 100, SCREEN_HEIGHT - 100),
        ang = Angle(),
        collision = {
            type = COLLISION.TYPE_POLY,
            vertices = {
                Vector(-10, 10),
                Vector(10, 10),
                Vector(10, -10),
                Vector(-10, -10)
            }
        }
    }
}

-- Called every frame while the local player is nearby
-- WALK key is "reserved" for coin insert
function GAME:Update()
    now = RealTime()

    if not IsValid(thePlayer) then
        return
    end

    if thePlayer:KeyDown(IN_MOVELEFT) then
        objects[1].pos.x = objects[1].pos.x > 5 and objects[1].pos.x - (100 * FrameTime()) or objects[1].pos.x
    end

    if thePlayer:KeyDown(IN_MOVERIGHT) then
        objects[1].pos.x = objects[1].pos.x < SCREEN_WIDTH - 5 and objects[1].pos.x + (100 * FrameTime()) or objects[1].pos.x
    end

    if thePlayer:KeyDown(IN_BACK) then
        objects[1].pos.y = objects[1].pos.y < SCREEN_HEIGHT - 5 and objects[1].pos.y + (100 * FrameTime()) or objects[1].pos.y
    end

    if thePlayer:KeyDown(IN_FORWARD) then
        objects[1].pos.y = objects[1].pos.y > 5 and objects[1].pos.y - (100 * FrameTime()) or objects[1].pos.y
    end

    objects[1].ang:RotateAroundAxis(Vector(0, 0, 1), 25 * FrameTime())
    objects[2].pos.y = 300 + math.abs(math.sin(now) * 100)

    for k, v in pairs(objects) do
        v.colliding = false

        for k2, v2 in pairs(objects) do
            if v.id == v2.id then continue end

            if COLLISION:IsColliding(v, v2) then
                v.colliding = true
                v2.colliding = true
            end
        end
    end
end

function GAME:Draw()
    for k, v in pairs(objects) do
        local c = v.colliding and Color(255, 0, 0, 255) or Color(255, 255, 255)
        surface.SetDrawColor(c)

        if v.collision.type == COLLISION.TYPE_BOX then
            surface.DrawRect(v.pos.x, v.pos.y, v.collision.width, v.collision.height)
        end

        if v.collision.type == COLLISION.TYPE_CIRCLE then
            surface.DrawCircle(v.pos.x, v.pos.y, v.collision.radius, c)
        end

        if v.collision.type == COLLISION.TYPE_POLY then
            if not v.collision.actualVertices then continue end
            for i = 1, #v.collision.actualVertices do
                local s = v.collision.actualVertices[i]
                local e = v.collision.actualVertices[i + 1 == #v.collision.actualVertices + 1 and 1 or i + 1]
                surface.DrawLine(s.x, s.y, e.x, e.y)
            end
        end
    end
end

function GAME:OnStartPlaying(ply)
    if ply == LocalPlayer() then
        thePlayer = ply
    end
end

function GAME:OnStopPlaying(ply)
    if ply == thePlayer then
        thePlayer = nil
    end
end

return GAME