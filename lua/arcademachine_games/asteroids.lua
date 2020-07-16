--[[
    Asteroids ripoff by ukgamer

    Uses sounds from http://www.classicgaming.cc/classics/asteroids/sounds
    Uses marquee image from https://www.wallpaperflare.com/arcade-cabinet-video-game-art-arcade-marquee-asteroids-wallpaper-yhexk

    All trademarks are property of their respective owners
]]

--TESTGAME = function()
local GAME = {}

GAME.Name = "Asteroids"
GAME.Description = [[Blast the asteroids for points! Watch out for UFOs and be careful with your velocity.

Press W to move your ship forward, and A/D to turn. Press SPACE to fire.]]

local function map(s, a1, a2, b1, b2)
    return b1 + (s - a1) * (b2 - b1) / (a2 - a1)
end

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
local nextUfo = 0
local fastBeep = false
local asteroidTypes = {
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
local ufoTypes = {
    {
        name = "small",
        vertices = {
            Vector(-5, 0),
            Vector(-2, 2),
            Vector(-1, 4),
            Vector(1, 4),
            Vector(2, 2),
            Vector(5, 0),
            Vector(3, -2),
            Vector(-2, -2)
        },
        collisionVertices = {
            Vector(-5, 0),
            Vector(-2, 2),
            Vector(-1, 4),
            Vector(1, 4),
            Vector(2, 2),
            Vector(5, 0),
            Vector(3, -2),
            Vector(-2, -2)
        }
    },
    {
        name = "large",
        vertices = {
            Vector(-10, 0),
            Vector(-4, 4),
            Vector(-2, 8),
            Vector(2, 8),
            Vector(4, 4),
            Vector(10, 0),
            Vector(6, -4),
            Vector(-4, -4)
        },
        collisionVertices = {
            Vector(-10, 0),
            Vector(-4, 4),
            Vector(-2, 8),
            Vector(2, 8),
            Vector(4, 4),
            Vector(10, 0),
            Vector(6, -4),
            Vector(-4, -4)
        }
    }
}
local objects = {
    bullets = {},
    asteroids = {},
    explosions = {},
    ufos = {},
    lasers = {}
}

local levelStartedAt = 0
local highBeep = false
local nextBeepAt = 0

-- Optimise rendering by reusing matrix
local mat = Matrix()
local zeroVec = Vector()
local zeroAng = Angle()
local scaleVec = Vector(1, 1, 1)

local yawVec = Vector(0, 0, 1)

function GAME:Init()
    IMAGE:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/asteroids/images/marquee.jpg", "marquee")

    self:SpawnAsteroids()
end

function GAME:Destroy()
    
end

function GAME:PlaySound(snd, looping)
    if SOUND.Sounds[snd] and IsValid(SOUND.Sounds[snd].sound) then
        if not looping then
            SOUND.Sounds[snd].sound:SetTime(0)
        end
        SOUND.Sounds[snd].sound:Play()
    end
end

function GAME:PauseSound(snd)
    if SOUND.Sounds[snd] and IsValid(SOUND.Sounds[snd].sound) then
        SOUND.Sounds[snd].sound:Pause()
    end
end

function GAME:Start()
    lives = 3

    self:SpawnAsteroids()

    self:SpawnPlayer()

    gameState = GAME_STATE_PLAYING

    self:PauseSound("saucerSmall")
    self:PauseSound("saucerBig")

    table.Empty(objects.explosions)
    table.Empty(objects.ufos)
    table.Empty(objects.lasers)

    nextUfo = now + math.random(10, 20)
end

function GAME:Stop()
    if objects.player then
        objects.player = nil
    end

    self:PauseSound("saucerSmall")
    self:PauseSound("saucerBig")

    table.Empty(objects.bullets)
    table.Empty(objects.explosions)
    table.Empty(objects.ufos)
    table.Empty(objects.lasers)

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

function GAME:SpawnBullet()
    self:PlaySound("fire")

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

function GAME:DestroyPlayer()
    self:SpawnExplosion(objects.player.pos, "bangsmall")

    self:PauseSound("thrust")
    objects.player = nil

    gameState = GAME_STATE_DYING
    respawnAt = now + 2
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

function GAME:SpawnExplosion(pos, sound)
    local p = Vector()
    p:Set(pos)

    table.insert(objects.explosions, {
        pos = p,
        dieTime = now + 1
    })

    if gameState ~= GAME_STATE_ATTRACT and sound then
        self:PlaySound(sound)
    end
end

function GAME:SpawnAsteroid(pos, type)
    local p = Vector()
    p:Set(pos)

    table.insert(objects.asteroids, {
        pos = p,
        ang = Angle(0, math.random(90)),
        vel = self:GenerateVelocity(),
        type = type,
        collision = {
            type = COLLISION.types.POLY,
            vertices = type.collisionVertices
        }
    })
end

function GAME:SpawnUfo()
    local type = ufoTypes[2]
    if score >= 40000 then
        type = ufoTypes[1]
    elseif (gameState == GAME_STATE_ATTRACT or score >= 10000) and math.random() > 0.75 then
        type = ufoTypes[1]
    end

    local velX = 3

    if math.random(0, 1) == 0 then velX = -velX end

    table.insert(objects.ufos, {
        pos = Vector(0, math.random(30, SCREEN_HEIGHT - 30)),
        ang = Angle(0, 180),
        vel = Vector(velX, 0),
        type = type,
        collision = {
            type = COLLISION.types.POLY,
            vertices = type.collisionVertices
        },
        nextShot = now + 0.8
    })

    if gameState ~= GAME_STATE_ATTRACT then
        self:PlaySound(type.name == "small" and "saucerSmall" or "saucerBig", true)
    end
end

function GAME:UfoFire(ufo)
    local p = Vector()
    p:Set(ufo.pos)

    local ang = nil

    if objects.player and ufo.type.name == "small" then
        ang = (objects.player.pos - p):Angle()
        local variance = math.Clamp(map(score, 10000, 60000, 30, 0), 0, 30)
        ang.y = ang.y + math.random(-variance, variance)
    else
        ang = Angle(0, math.random(-180, 180))
    end

    table.insert(objects.lasers, {
        pos = p,
        ang = ang,
        vel = ang:Forward() * 15,
        collision = {
            type = COLLISION.types.POLY,
            vertices = { -- Thin "box" collision for a line
                Vector(0, 0),
                Vector(5, 0),
                Vector(5, 1),
                Vector(0, 1)
            }
        }
    })

    -- TODO: Find a good quality recording of the UFO fire sound
    self:PlaySound("fire")

    ufo.nextShot = now + 0.8
end

function GAME:BreakAsteroid(key, obj)
    self:SpawnExplosion(obj.pos, "bang" .. obj.type.name)

    if obj.type.name ~= "small" then
        for i = 1, 2 do
            local type = obj.type.name == "large" and asteroidTypes[2] or asteroidTypes[1]

            self:SpawnAsteroid(obj.pos, type)
        end
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

    table.remove(objects.asteroids, key)
end

function GAME:DestroyUfo(key, obj, byPlayer)
    if byPlayer then
        local points = obj.type.name == "small" and 1000 or 200
        score = score + points
        extraLifeScore = extraLifeScore + points
    end
    
    self:SpawnExplosion(obj.pos, "bangsmall")
    table.remove(objects.ufos, key)

    local snd = obj.type.name == "small" and "saucerSmall" or "saucerBig"
    self:PauseSound(snd)
end

function GAME:SpawnAsteroids()
    table.Empty(objects.asteroids)

    levelStartedAt = RealTime()
    highBeep = false
    nextBeepAt = now

    local max = math.Clamp(math.floor(map(score, 0, 30000, 4, 10)), 4, 10)

    for i = 1, max do
        self:SpawnAsteroid(Vector(math.random(0, SCREEN_WIDTH), 0), asteroidTypes[3])
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
        v.ang:RotateAroundAxis(yawVec, FrameTime() * 10)
        self:WrapPos(v.pos)
    end

    for _, v in ipairs(objects.ufos) do
        v.pos:Add(v.vel * 25 * FrameTime())
        self:WrapPos(v.pos)

        if objects.player and COLLISION:IsColliding(v, objects.player) then
            self:DestroyPlayer()
        end
    end

    if now >= nextUfo then
        if #objects.ufos == 0 then
            self:SpawnUfo()
        end

        nextUfo = now + math.random(10, 20)
    end

    if gameState ~= GAME_STATE_ATTRACT and not IsValid(thePlayer) then
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
        if #objects.asteroids == 0 and #objects.ufos == 0 then
            self:SpawnAsteroids()
        end

        if extraLifeScore >= 10000 then
            lives = lives + 1
            extraLifeScore = 0

            self:PlaySound("extraShip")
        end

        if now >= nextBeepAt then
            self:PlaySound(highBeep and "beat2" or "beat1")

            local t = math.Clamp(map(now - levelStartedAt, 0, 40, 0.8, 0.2), 0.2, 0.8)

            highBeep = not highBeep
            nextBeepAt = now + t
        end

        if thePlayer:KeyDown(IN_MOVELEFT) then
            objects.player.ang:RotateAroundAxis(yawVec, -(200 * FrameTime()))
        end

        if thePlayer:KeyDown(IN_MOVERIGHT) then
            objects.player.ang:RotateAroundAxis(yawVec, 200 * FrameTime())
        end

        if thePlayer:KeyDown(IN_FORWARD) then
            objects.player.vel:Add(objects.player.ang:Forward() * 10 * FrameTime())
            
            self:PlaySound("thrust", true)
        else
            self:PauseSound("thrust")
        end

        if thePlayer:KeyDown(IN_JUMP) then
            if now >= nextFire and #objects.bullets < 4 then
                self:SpawnBullet()
            end
        end

        objects.player.pos:Add(objects.player.vel * 25 * FrameTime())

        self:WrapPos(objects.player.pos)

        objects.player.vel.x = math.Approach(objects.player.vel.x, 0, 2 * FrameTime())
        objects.player.vel.y = math.Approach(objects.player.vel.y, 0, 2 * FrameTime())
    end

    for uk, uv in ipairs(objects.ufos) do
        if now >= uv.nextShot then
            self:UfoFire(uv)
        end
    end

    for lk, lv in ipairs(objects.lasers) do
        lv.pos:Add(lv.vel * 25 * FrameTime())

        if
            lv.pos.x > SCREEN_WIDTH or
            lv.pos.x < 0 or
            lv.pos.y > SCREEN_HEIGHT or
            lv.pos.y < 0
        then
            table.remove(objects.lasers, lk)
            continue
        end

        if gameState == GAME_STATE_PLAYING and COLLISION:IsColliding(lv, objects.player) then
            self:DestroyPlayer()
            table.remove(objects.lasers, lk)
        end
    end

    for ak, av in ipairs(objects.asteroids) do
        for uk, uv in ipairs(objects.ufos) do
            if COLLISION:IsColliding(av, uv) then
                self:DestroyUfo(uk, uv)
            end
        end

        if gameState == GAME_STATE_PLAYING and COLLISION:IsColliding(av, objects.player) then
            self:DestroyPlayer()
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

        for uk, uv in ipairs(objects.ufos) do
            if not COLLISION:IsColliding(v, uv) then continue end
            table.remove(objects.bullets, k)
            self:DestroyUfo(uk, uv, true)
        end
    end

    for k, v in ipairs(objects.explosions) do
        if now >= v.dieTime then
            table.remove(objects.explosions, k)
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

    mat:SetTranslation(zeroVec)
    mat:SetAngles(zeroAng)
    mat:SetScale(scaleVec)

    mat:Translate(pos)
    mat:Rotate(ang)
    mat:Translate(-pos)
    cam.PushModelMatrix(mat)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawLine(pos.x - 5, pos.y + 5, pos.x + 10, pos.y)
        surface.DrawLine(pos.x + 10, pos.y, pos.x - 5, pos.y - 5)
        surface.DrawLine(pos.x - 3, pos.y - 4, pos.x - 3, pos.y + 4) -- back of the ship
        if thrusting and now % 0.1 > 0.05 then
            surface.DrawLine(pos.x - 3, pos.y - 2, pos.x - 8, pos.y)
            surface.DrawLine(pos.x - 8, pos.y, pos.x - 3, pos.y + 2)
        end
    cam.PopModelMatrix()
end

function GAME:DrawAsteroid(asteroid)
    mat:SetTranslation(zeroVec)
    mat:SetAngles(zeroAng)
    mat:SetScale(scaleVec)

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

function GAME:DrawUfo(ufo)
    mat:SetTranslation(zeroVec)
    mat:SetAngles(zeroAng)
    mat:SetScale(scaleVec)

    mat:Translate(ufo.pos)
    mat:Rotate(ufo.ang)
    cam.PushModelMatrix(mat)
        surface.SetDrawColor(255, 255, 255, 255)
        for i = 1, #ufo.type.vertices do
            local s = ufo.type.vertices[i]
            local e = ufo.type.vertices[i + 1 == #ufo.type.vertices + 1 and 1 or i + 1]
            surface.DrawLine(s.x, s.y, e.x, e.y)
            -- Top "glass"
            surface.DrawLine(ufo.type.vertices[2].x, ufo.type.vertices[2].y, ufo.type.vertices[5].x, ufo.type.vertices[5].y)
            -- Body "middle"
            surface.DrawLine(ufo.type.vertices[1].x, ufo.type.vertices[1].y, ufo.type.vertices[6].x, ufo.type.vertices[6].y)
        end
    cam.PopModelMatrix()
end

function GAME:DrawLaser(laser)
    mat:SetTranslation(zeroVec)
    mat:SetAngles(zeroAng)
    mat:SetScale(scaleVec)

    mat:Translate(laser.pos)
    mat:Rotate(laser.ang)
    mat:Translate(-laser.pos)
    cam.PushModelMatrix(mat)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawLine(laser.pos.x - 2.5, laser.pos.y, laser.pos.x + 2.5, laser.pos.y)
    cam.PopModelMatrix()
end

function GAME:DrawObjects()
    for _, v in ipairs(objects.lasers) do
        self:DrawLaser(v)
    end

    for _, v in ipairs(objects.asteroids) do
        self:DrawAsteroid(v)
    end

    for _, v in ipairs(objects.ufos) do
        self:DrawUfo(v)
    end

    for _, v in ipairs(objects.bullets) do
        surface.DrawCircle(v.pos.x, v.pos.y, v.size, 255, 255, 255)
    end

    for _, v in ipairs(objects.explosions) do
        local timeLeft = (1 - (v.dieTime - now)) * 15

        for i = 1, 10 do
            surface.DrawCircle(
                v.pos.x + (math.cos(math.rad(i * (360 / 10))) * timeLeft),
                v.pos.y + (math.sin(math.rad(i * (360 / 10))) * timeLeft),
                1,
                255,
                255,
                255
            )
        end
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
        SOUND:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/asteroids/sounds/saucerSmall.ogg", "saucerSmall", function(snd)
            snd:EnableLooping(true)
        end)
        SOUND:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/asteroids/sounds/saucerBig.ogg", "saucerBig", function(snd)
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
    if ply ~= LocalPlayer() then return end

    if new > 0 and gameState == GAME_STATE_ATTRACT then
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