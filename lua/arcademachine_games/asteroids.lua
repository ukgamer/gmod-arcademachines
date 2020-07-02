--[[
    Asteroids ripoff by ukgamer

    Uses sounds from http://www.classicgaming.cc/classics/asteroids/sounds
    Uses marquee image from https://www.wallpaperflare.com/arcade-cabinet-video-game-art-arcade-marquee-asteroids-wallpaper-yhexk

    All trademarks are property of their respective owners
]]

--TESTGAME = function()
local GAME = {}

GAME.Name = "Asteroids"

local yawVector = Vector(0, 0, 1)

local thePlayer = nil

local GAME_STATE_ATTRACT = 0
local GAME_STATE_PLAYING = 1
local GAME_STATE_DYING = 2
local GAME_STATE_WAITINGCOINS = 3

local gameState = GAME_STATE_ATTRACT

local now = RealTime()

local marqueeLoaded = false

local score, extraLifeScore = 0, 0
local lives = 3
local livesPos = Vector(10, 40)
local livesOffset = Vector(10, 0)
local livesAngle = Angle(0, -90, 0)
local nextFire = 0
local respawnAt = 0
local fastBeep = false
local types = {
    {
        name = "small",
        vertices = {
            Vector(-3, 4),
            Vector(-1, 5),
            Vector(0, 2),
            Vector(2, 5),
            Vector(4, 2),
            Vector(4, -2),
            Vector(2, -4),
            Vector(-2, -3),
            Vector(-3, -2)
        },
        collisionVertices = {
            Vector(-3, 4),
            Vector(-1, 5),
            Vector(2, 5),
            Vector(4, 2),
            Vector(4, -2),
            Vector(2, -4),
            Vector(-2, -3),
            Vector(-3, -2)
        }
    },
    {
        name = "medium",
        vertices = {
            Vector(-10, 5),
            Vector(-6, 8),
            Vector(-5, 10),
            Vector(5, 10),
            Vector(10, 8),
            Vector(10, 5),
            Vector(5, 0),
            Vector(10, -5),
            Vector(7, -10),
            Vector(0, -9),
            Vector(-5, -10),
            Vector(-10, -5)
        },
        collisionVertices = {
            Vector(-10, 5),
            Vector(-6, 8),
            Vector(-5, 10),
            Vector(5, 10),
            Vector(10, 8),
            Vector(10, 5),
            Vector(10, -5),
            Vector(7, -10),
            Vector(-5, -10),
            Vector(-10, -5)
        }
    },
    {
        name = "large",
        vertices = {
            Vector(-15, 8),
            Vector(-11, 15),
            Vector(0, 11),
            Vector(11, 15),
            Vector(15, 11),
            Vector(13, 0),
            Vector(15, -11),
            Vector(3, -15),
            Vector(-8, -15),
            Vector(-15, -9)
        },
        collisionVertices = {
            Vector(-15, 8),
            Vector(-11, 15),
            Vector(11, 15),
            Vector(15, 11),
            Vector(15, -11),
            Vector(3, -15),
            Vector(-8, -15),
            Vector(-15, -9)
        }
    }
}
local objects = {
    bullets = {},
    asteroids = {}
}

local highBeep = false
local nextBeepAt = 0

function GAME:Init()
    IMAGE:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/asteroids/images/marquee.jpg", "marquee")

    self:SpawnAsteroids()
end

function GAME:Destroy()
    
end

function GAME:Start()
    lives = 3

    self:SpawnAsteroids()

    self:SpawnPlayer()

    gameState = GAME_STATE_PLAYING
end

function GAME:Stop()
    if objects.player then
        objects.player = nil
    end

    table.Empty(objects.bullets)

    score = 0
    extraLifeScore = 0
    
    gameState = GAME_STATE_ATTRACT

    self:SpawnAsteroids()
end

function GAME:SpawnPlayer()
    objects.player = {
        pos = Vector(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2),
        ang = Angle(),
        vel = Vector(),
        collision = {
            type = COLLISION.types.POLY,
            vertices = {
                Vector(-5, -5),
                Vector(-5, 5),
                Vector(10, 0)
            }
        }
    }
end

function GAME:WrapPos(pos)
    if pos.x > SCREEN_WIDTH then
        pos.x = 0
    end
    if pos.x < 0 then
        pos.x = SCREEN_WIDTH
    end

    if pos.y > SCREEN_HEIGHT then
        pos.y = 0
    end
    if pos.y < 0 then
        pos.y = SCREEN_HEIGHT
    end
end

function GAME:GenerateVelocity()
    local velX = math.random(1, 3)
    local velY = math.random(1, 3)

    if math.random(0, 1) == 0 then velX = -velX end
    if math.random(0, 1) == 0 then velY = -velY end

    return Vector(velX, velY)
end

function GAME:SpawnAsteroid(pos, type)
    table.insert(objects.asteroids, {
        pos = pos,
        ang = Angle(0, math.random(0, 90)),
        vel = self:GenerateVelocity(),
        type = type,
        collision = {
            type = COLLISION.types.POLY,
            vertices = type.collisionVertices
        }
    })
end

function GAME:BreakAsteroid(key, obj)
    if obj.type.name ~= "small" then
        for i = 1, 2 do
            local pos = Vector()
            pos:Set(obj.pos)

            local type = obj.type.name == "large" and types[2] or types[1]

            self:SpawnAsteroid(pos, type)
        end
    end

    local snd = "bang" .. obj.type.name

    if IsValid(SOUND.Sounds[snd].sound) then
        SOUND.Sounds[snd].sound:SetTime(0)
        SOUND.Sounds[snd].sound:Play()
    end

    if obj.type.name == "large" then
        score = score + 20
        extraLifeScore = extraLifeScore + 20
    elseif obj.type.name == "medium" then
        score = score + 50
        extraLifeScore = extraLifeScore + 50
    else
        score = score + 100
        extraLifeScore = extraLifeScore + 100
    end

    if extraLifeScore >= 10000 then
        lives = lives + 1
        extraLifeScore = 0

        if IsValid(SOUND.Sounds.extraShip.sound) then
            SOUND.Sounds.extraShip.sound:SetTime(0)
            SOUND.Sounds.extraShip.sound:Play()
        end
    end

    table.remove(objects.asteroids, key)

    if #objects.asteroids == 0 then
        self:SpawnAsteroids()
    else
        for _, v in ipairs(objects.asteroids) do
            if v.type.name ~= "small" then
                fastBeep = false
                return
            end
        end

        fastBeep = true
    end
end

function GAME:SpawnAsteroids()
    table.Empty(objects.asteroids)

    highBeep = false
    nextBeepAt = now
    fastBeep = false

    local count = math.random(4, 6)

    for i = 1, count do
        self:SpawnAsteroid(Vector(math.random(0, SCREEN_WIDTH), 0), types[3])
    end
end

function GAME:Update()
    if not marqueeLoaded and IMAGE.Images.marquee and IMAGE.Images.marquee.status == IMAGE.STATUS_LOADED then
        marqueeLoaded = true
        MACHINE:UpdateMarquee()
    end

    now = RealTime()

    for _, v in ipairs(objects.asteroids) do
        v.pos:Add(v.vel * 25 * FrameTime())
        v.ang:RotateAroundAxis(yawVector, FrameTime() * 10)
        self:WrapPos(v.pos)
    end

    if gameState == GAME_STATE_ATTRACT then return end
    if not IsValid(thePlayer) then
        self:Stop()
        return
    end

    if gameState == GAME_STATE_DYING and now >= respawnAt then
        lives = lives - 1

        if lives == 0 then
            MACHINE:TakeCoins(1)
            gameState = GAME_STATE_WAITINGCOINS
            return
        else
            self:SpawnPlayer()
            gameState = GAME_STATE_PLAYING
        end
    end

    if gameState == GAME_STATE_PLAYING then
        if now >= nextBeepAt then
            local snd = highBeep and "beat2" or "beat1"
            if IsValid(SOUND.Sounds[snd].sound) then
                SOUND.Sounds[snd].sound:SetTime(0)
                SOUND.Sounds[snd].sound:Play()
            end

            local t = fastBeep and 0.3 or 0.8

            highBeep = not highBeep
            nextBeepAt = now + t
        end

        if thePlayer:KeyDown(IN_MOVELEFT) then
            objects.player.ang:RotateAroundAxis(yawVector, -(150 * FrameTime()))
        end

        if thePlayer:KeyDown(IN_MOVERIGHT) then
            objects.player.ang:RotateAroundAxis(yawVector, 150 * FrameTime())
        end

        if thePlayer:KeyDown(IN_FORWARD) then
            objects.player.vel:Add(objects.player.ang:Forward() * 10 * FrameTime())
            
            if IsValid(SOUND.Sounds.thrust.sound) then
                SOUND.Sounds.thrust.sound:Play()
            end
        else
            if IsValid(SOUND.Sounds.thrust.sound) then
                SOUND.Sounds.thrust.sound:Pause()
            end
        end

        if thePlayer:KeyDown(IN_JUMP) then
            if now >= nextFire and #objects.bullets < 4 then
                if IsValid(SOUND.Sounds.fire.sound) then
                    SOUND.Sounds.fire.sound:SetTime(0)
                    SOUND.Sounds.fire.sound:Play()
                end

                local pos = Vector()
                pos:Set(objects.player.pos)
                local ang = Angle()
                ang:Set(objects.player.ang)

                table.insert(objects.bullets, {
                    pos = pos,
                    ang = ang,
                    vel = objects.player.vel + objects.player.ang:Forward() * 15,
                    size = 2,
                    dieTime = now + 3,
                    collision = {
                        type = COLLISION.types.CIRCLE,
                        radius = 2
                    }
                })

                nextFire = now + 0.2
            end
        end

        objects.player.pos:Add(objects.player.vel * 25 * FrameTime())

        self:WrapPos(objects.player.pos)

        objects.player.vel.x = math.Approach(objects.player.vel.x, 0, 3 * FrameTime())
        objects.player.vel.y = math.Approach(objects.player.vel.y, 0, 3 * FrameTime())

        for ak, av in ipairs(objects.asteroids) do
            if COLLISION:IsColliding(av, objects.player) then
                if IsValid(SOUND.Sounds.bangsmall.sound) then
                    SOUND.Sounds.bangsmall.sound:Play()
                end

                if IsValid(SOUND.Sounds.thrust.sound) then
                    SOUND.Sounds.thrust.sound:Pause()
                end
                objects.player = nil

                gameState = GAME_STATE_DYING
                respawnAt = now + 2
                return
            end
        end
    end

    for k, v in ipairs(objects.bullets) do
        if now >= v.dieTime then
            table.remove(objects.bullets, k)
            continue
        end

        v.pos:Add(v.vel * 25 * FrameTime())
        self:WrapPos(v.pos)

        for ak, av in ipairs(objects.asteroids) do
            if not COLLISION:IsColliding(v, av) then continue end
            table.remove(objects.bullets, k)
            self:BreakAsteroid(ak, av)
        end
    end
end

function GAME:DrawMarquee()
    surface.SetDrawColor(0, 0, 0, 255)
    surface.DrawRect(0, 0, MARQUEE_WIDTH, MARQUEE_HEIGHT)

    if marqueeLoaded then
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(IMAGE.Images.marquee.mat)
        surface.DrawTexturedRect(0, 0, MARQUEE_WIDTH, MARQUEE_HEIGHT)
    end
end

function GAME:DrawPlayerTriangle(pos, ang, thrusting)
    if not ang then ang = Angle() end
    local mat = Matrix()
    mat:Translate(pos)
    mat:Rotate(ang)
    mat:Translate(-pos)
    cam.PushModelMatrix(mat)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawLine(pos.x - 5, pos.y + 5, pos.x + 10, pos.y)
        surface.DrawLine(pos.x + 10, pos.y, pos.x - 5, pos.y - 5)
        surface.DrawLine(pos.x - 3, pos.y - 4, pos.x - 3, pos.y + 4) -- back of the ship
        if thrusting then
            surface.DrawLine(pos.x - 3, pos.y - 2, pos.x - 8, pos.y)
            surface.DrawLine(pos.x - 8, pos.y, pos.x - 3, pos.y + 2)
        end
    cam.PopModelMatrix()
end

function GAME:DrawAsteroid(asteroid)
    local mat = Matrix()
    mat:Translate(asteroid.pos)
    mat:Rotate(asteroid.ang)
    cam.PushModelMatrix(mat)
        surface.SetDrawColor(255, 255, 255, 255)
        for i = 1, #asteroid.type.vertices do
            local s = asteroid.type.vertices[i]
            local e = asteroid.type.vertices[i + 1 == #asteroid.type.vertices + 1 and 1 or i + 1]
            surface.DrawLine(s.x, s.y, e.x, e.y)
        end
    cam.PopModelMatrix()
end

function GAME:DrawObjects()
    for _, v in ipairs(objects.asteroids) do
        self:DrawAsteroid(v)
    end

    for _, v in ipairs(objects.bullets) do
        surface.DrawCircle(v.pos.x, v.pos.y, v.size, 255, 255, 255)
    end

    if objects.player then
        self:DrawPlayerTriangle(objects.player.pos, objects.player.ang, thePlayer:KeyDown(IN_FORWARD))
    end
end

function GAME:Draw()
    self:DrawObjects()

    if gameState ~= GAME_STATE_ATTRACT then
        surface.SetFont("DermaLarge")
        local tw, th = surface.GetTextSize(score)
        surface.SetTextColor(255, 255, 255, 255)
        surface.SetTextPos(10, 0)
        surface.DrawText(score)

        livesOffset.x = 10
        for i = 1, lives do
            self:DrawPlayerTriangle(livesPos + livesOffset, livesAngle)
            livesOffset.x = livesOffset.x + 15
        end

        surface.SetFont("DermaDefault")
        local tw, th = surface.GetTextSize(MACHINE:GetCoins() .. " COIN(S)")
        surface.SetTextColor(255, 255, 255, 255)
        surface.SetTextPos(10, SCREEN_HEIGHT - (th * 2))
        surface.DrawText(MACHINE:GetCoins() .. " COIN(S)")
    else
        surface.SetFont("DermaLarge")
        local tw, th = surface.GetTextSize("INSERT COIN")
        surface.SetTextColor(255, 255, 255, now % 1 > 0.5 and 255 or 0)
        surface.SetTextPos((SCREEN_WIDTH / 2) - (tw / 2), SCREEN_HEIGHT - (th * 2))
        surface.DrawText("INSERT COIN")
    end
end

function GAME:OnStartPlaying(ply)
    if ply == LocalPlayer() then
        thePlayer = ply

        SOUND:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/asteroids/sounds/fire.ogg", "fire")
        SOUND:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/asteroids/sounds/bangSmall.ogg", "bangsmall")
        SOUND:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/asteroids/sounds/bangMedium.ogg", "bangmedium")
        SOUND:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/asteroids/sounds/bangLarge.ogg", "banglarge")
        SOUND:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/asteroids/sounds/extraShip.ogg", "extraShip")
        SOUND:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/asteroids/sounds/thrust.ogg", "thrust", function(snd)
            snd:EnableLooping(true)
        end)
        SOUND:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/asteroids/sounds/beat1.ogg", "beat1")
        SOUND:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/asteroids/sounds/beat2.ogg", "beat2")
    end
end

function GAME:OnStopPlaying(ply)
    if ply == thePlayer then
        thePlayer = nil
    end
end

function GAME:OnCoinsInserted(ply, old, new)
    MACHINE:EmitSound("garrysmod/content_downloaded.wav", 50)

    if ply ~= LocalPlayer() then return end

    if old == 0 and new > 0 then
        self:Start()
    end
end

function GAME:OnCoinsLost(ply, old, new)
    if ply ~= LocalPlayer() then return end

    if new == 0 then
        self:Stop()
    end

    if new > 0 then
        self:Start()
    end
end

return GAME
--end