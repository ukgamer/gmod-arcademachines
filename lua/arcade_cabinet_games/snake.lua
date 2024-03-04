
-- gaming
-- https://github.com/ukgamer/gmod-arcademachines
-- Made by Jule

--if not FONT:Exists("Snake32") then
    surface.CreateFont("Snake32", {
        font = "Trebuchet MS",
        size = 32,
        weight = 500,
        antialias = 1,
        additive = 1
    })
--end

--if not FONT:Exists("SnakeTitle") then
    surface.CreateFont("SnakeTitle", {
        font = "Trebuchet MS",
        size = 70,
        italic = true,
        weight = 500,
        antialias = 1,
        additive = 1
    })
--end

local function PlayLoaded(loaded)
    if IsValid(SOUND.Sounds[loaded].sound) then
        SOUND.Sounds[loaded].sound:SetTime(0)
        SOUND.Sounds[loaded].sound:Play()
    end
end

local function StopLoaded(loaded)
    if IsValid(SOUND.Sounds[loaded].sound) then
        SOUND.Sounds[loaded].sound:Pause()
    end
end

local GAME = {
    Name = "Snake",
    Author = "Jule",
    Description = "Get a score as high as possible by eating apples!\nMove the snake with WASD.",
    CabinetArtURL = "https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/snake/images/ms_acabinet_artwork.png",
    Bodygroup = BG_GENERIC_RECESSED_JOYSTICK
}

local STATE_ATTRACT = 0
local STATE_AWAITING = 1
local STATE_PLAYING = 2

local BORDER_X = 20
local BORDER_Y = 60
local BORDER_WIDTH = 470
local BORDER_HEIGHT = 400

local SNAKESIZE = 10

local SNAKE_UP = Vector(0, -SNAKESIZE)
local SNAKE_DOWN = Vector(0, SNAKESIZE)
local SNAKE_RIGHT = Vector(SNAKESIZE, 0)
local SNAKE_LEFT = Vector(-SNAKESIZE, 0)

local GOAL = 10

local COLOR_SNAKE = Color(25, 255, 25)
local COLOR_APPLE_N = Color(255, 25, 25)
local COLOR_APPLE_B = Color(25, 25, 255)
local COLOR_APPLE_G = Color(255, 223, 127)

local state
local pelaaja
local score
local delay

local snakebod
local snakecol
local boosted_at
local golds_eaten
local queue

local apples

function GAME:Init() -- Called when MACHINE:Set(Current)Game( game ) is called.
    state = STATE_ATTRACT
end

function GAME:Start()
    queue       = {SNAKE_DOWN}
    snakecol    = COLOR_SNAKE
    boosted_at  = RealTime() - 11
    state       = STATE_PLAYING
    delay       = 0.1
    golds_eaten = 0
    score       = 0

    snakebod    = {}
    apples      = {}

    for i = 1, 3 do
        snakebod[i] = Vector(BORDER_X + 100, BORDER_Y + 100 - SNAKESIZE * i)
    end

    StopLoaded("intromusic")
end

function GAME:Stop()
    COINS:TakeCoins(1)
    state = STATE_AWAITING
end

-- There is still a 0.025s zone where input isn't taken because
-- KeyPressed runs like 5 times over the course of something a bit less than 0.025s

-- Before it was 0.1s so its still wayy better 

local queue_o
local last_input = RealTime()
function GAME:Input()
    if last_input + 0.025 > RealTime() then return end

    if pelaaja:KeyPressed(IN_FORWARD) and queue_o.x ~= 0 then
        table.insert(queue, SNAKE_UP)
        last_input = RealTime()
    elseif pelaaja:KeyPressed(IN_BACK) and queue_o.x ~= 0 then
        table.insert(queue, SNAKE_DOWN)
        last_input = RealTime()
    elseif pelaaja:KeyPressed(IN_MOVERIGHT) and queue_o.y ~= 0 then
        table.insert(queue, SNAKE_RIGHT)
        last_input = RealTime()
    elseif pelaaja:KeyPressed(IN_MOVELEFT) and queue_o.y ~= 0 then
        table.insert(queue, SNAKE_LEFT)
        last_input = RealTime()
    end
end

function GAME:SnakeMove(head)
    if not queue[1] then queue[1] = queue_o end
    local newp = Vector(head.x, head.y)

    for key, part in ipairs(snakebod) do
        if key == 1 then
            for _, queued in ipairs(queue) do
                head.x, head.y = head.x + queued.x, head.y + queued.y
            end
        else
            local x, y = part.x, part.y
            part.x, part.y = newp.x, newp.y
            newp.x, newp.y = x, y
        end
    end

    queue_o = queue[#queue]
    queue = {}

    SOUND:EmitSound("garrysmod/ui_hover.wav")
end

function GAME:CheckForDeath(head)
    local dead

    dead = head.x > BORDER_X + BORDER_WIDTH - SNAKESIZE and true or
           head.y > BORDER_Y + BORDER_HEIGHT - SNAKESIZE and true or
           head.x < BORDER_X and true or
           head.y < BORDER_Y and true or false
    for key, part in ipairs(snakebod) do
        dead = dead == true and true or
               key == 1 and 0 or
               part.x ~= head.x and 0 or
               part.y ~= head.y and 0 or true
    end

    return dead
end

function GAME:CreateApple()
    local x = math.Round(math.random(BORDER_X + 30, BORDER_WIDTH - 30), -1)
    local y = math.Round(math.random(BORDER_Y + 30, BORDER_HEIGHT - 30), -1)

    -- Prevent spawning on top of other apples or the snake
    for _, part in ipairs(snakebod) do
        if part.x == x and part.y == y then return end
    end

    for _, apple in ipairs(apples) do
        if apple[1].x == x and apple[1].y == y then return end
    end

    local a_type = math.random(0, 15)
    a_type = a_type > 2 and 0 or a_type

    local a_color = a_type == 0 and COLOR_APPLE_N or
                    a_type == 1 and COLOR_APPLE_B or
                    a_type == 2 and COLOR_APPLE_G

    table.insert(apples, {Vector(x, y), a_color, a_type})
end

function GAME:EatApple(apple)
    local head = snakebod[1]
    local apple_type = apple[3]
    table.RemoveByValue(apples, apple)

    table.insert(snakebod, Vector(head.x, head.y))

    if apple_type == 0 then
        PlayLoaded("eatnormal")
    elseif apple_type == 1 then
        PlayLoaded("eatboost")
        boosted_at = RealTime()
    elseif apple_type == 2 then
        SOUND:EmitSound("garrysmod/save_load3.wav")
        golds_eaten = golds_eaten + 1
        score = score + 50

        if golds_eaten == GOAL then
            PlayLoaded("goalreached")
        end

        return
    end

    score = score + 20
end

local last_move = RealTime()
function GAME:Update()
    if state < STATE_PLAYING or not IsValid(pelaaja) then return end

    GAME:Input()

    -- Snake tick
    if last_move + delay < RealTime() then
        last_move = RealTime()

        if #apples < 8 then
            self:CreateApple()
        end

        local head = snakebod[1]

        for _, apple in ipairs(apples) do
            if head.x == apple[1].x and head.y == apple[1].y then
                self:EatApple(apple)
            end
        end

        self:SnakeMove(head)

        -- Effects for eating boost apples and reaching 10 gold apples
        snakecol = boosted_at + 10 < RealTime() and
                (golds_eaten >= GOAL and COLOR_APPLE_G or COLOR_SNAKE)
                or COLOR_APPLE_B

        delay = boosted_at + 10 < RealTime() and 0.1 or 0.05

        local dead = self:CheckForDeath(head)
        if tobool(dead) then
            PlayLoaded("death")
            PlayLoaded("gameover")
            self:Stop()

            return
        end
    end
end

function GAME:Draw()
    draw.SimpleText(COINS:GetCoins() .. " COIN(S)", "Trebuchet18", 25, 25, color_white)

    if state < STATE_PLAYING then
        draw.SimpleText(
            "INSERT COINS",
            "Snake32",
            SCREEN_WIDTH / 2,
            SCREEN_HEIGHT - 100,
            Color(255, 255, 255, RealTime() % 1 > .5 and 255 or 0),
            TEXT_ALIGN_CENTER
        )

        surface.SetDrawColor(COLOR_SNAKE)
        if RealTime() % .45 > .225 then
            surface.DrawRect(SCREEN_WIDTH / 2 - 45, SCREEN_HEIGHT / 2, 90, 10)
        else
            surface.DrawRect(SCREEN_WIDTH / 2 - 45, SCREEN_HEIGHT / 2, 30, 10)
            surface.DrawRect(SCREEN_WIDTH / 2 - 15, SCREEN_HEIGHT / 2, 30, 10)
            surface.DrawRect(SCREEN_WIDTH / 2 - 30, SCREEN_HEIGHT / 2 - 7, 30, 10)
        end

        surface.SetDrawColor(COLOR_APPLE_N)
        surface.DrawRect(SCREEN_WIDTH / 2 - 120, SCREEN_HEIGHT / 2, 10, 10)

        return
    end

    draw.SimpleText("Score: " .. score, "Snake32", SCREEN_WIDTH / 2, 25, color_white, TEXT_ALIGN_CENTER)

    -- Either display x/10 of golden apples eaten or the amount of time left for a boost in seconds
    draw.SimpleText(boosted_at + 10 < RealTime() and
        math.min(golds_eaten, GOAL) .. "/" .. tostring(GOAL) or
        "0:" .. ((10 - math.Round(RealTime() - boosted_at) < 10) and
        "0" .. 10 - math.Round(RealTime() - boosted_at) or
        10 - math.Round(RealTime() - boosted_at)),
        "Trebuchet24", SCREEN_WIDTH - 75, 25, color_white)

    -- Draw an apple beside the counter with gold/blue color
    surface.SetDrawColor(boosted_at + 10 < RealTime() and
        COLOR_APPLE_G or
        COLOR_APPLE_B)

    surface.DrawRect(SCREEN_WIDTH - 90, 30, SNAKESIZE, SNAKESIZE)

    -- Apples, borders and snake
    for _, apple in ipairs(apples) do
        surface.SetDrawColor(apple[2])
        surface.DrawRect(apple[1].x, apple[1].y, SNAKESIZE, SNAKESIZE)
    end

    surface.SetDrawColor(snakecol)
    surface.DrawOutlinedRect(BORDER_X, BORDER_Y, BORDER_WIDTH, BORDER_HEIGHT)
    for key, part in ipairs(snakebod) do
        local col = Color(snakecol.r, snakecol.g, snakecol.b)
        col.a = math.max(col.a - key * 10, 20)
        surface.SetDrawColor(col)
        surface.DrawRect(part.x, part.y, SNAKESIZE, SNAKESIZE)
    end
end

function GAME:OnStartPlaying(ply) -- Called when the arcade machine is entered
    if ply == LocalPlayer() then
        SOUND:LoadFromURL( "https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/snake/sounds/song.ogg", "intromusic", function(snd)
            snd:EnableLooping(true)
            if state ~= STATE_PLAYING then
                PlayLoaded("intromusic")
            end
        end )

        SOUND:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/snake/sounds/eat_normal.ogg","eatnormal")
        SOUND:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/snake/sounds/eat_boost.ogg","eatboost")
        -- Golden apples use a GMod sound when eaten.
        SOUND:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/snake/sounds/goalreached.ogg", "goalreached")
        SOUND:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/snake/sounds/death.ogg", "death")
        SOUND:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/snake/sounds/gameover.ogg", "gameover")

        pelaaja = ply
    else return end

    state = STATE_AWAITING
end

function GAME:OnStopPlaying(ply) -- ^^ upon exit.
    if ply == pelaaja and ply == LocalPlayer() then
        pelaaja = nil
    else return end

    self:Stop()

    state = STATE_ATTRACT
    StopLoaded("intromusic")
end

function GAME:OnCoinsInserted(ply, old, new)
    if ply ~= LocalPlayer() then return end

    if new > 0 and state == STATE_AWAITING then
        self:Start()
    end
end

function GAME:OnCoinsLost(ply, old, new)
    if ply ~= LocalPlayer() then return end

    if new <= 0 then
        self:Stop()
    elseif new > 0 then
        self:Start()
    end
end

function GAME:DrawMarquee()
    -- Title text
    draw.SimpleText("SNAKE", "SnakeTitle", MARQUEE_WIDTH / 2 - 140, MARQUEE_HEIGHT / 2 - 25, color_white)

    -- Snake
    surface.SetDrawColor(COLOR_SNAKE)
    surface.DrawRect(MARQUEE_WIDTH / 2 + 20, 40, 120, 20)
    surface.DrawRect(MARQUEE_WIDTH / 2 + 140, 40, 20, 40)

    -- Apple
    surface.SetDrawColor(COLOR_APPLE_N)
    surface.DrawRect(MARQUEE_WIDTH / 2 + 140, 100, 20, 20)
end

return GAME