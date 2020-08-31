--TESTGAME = function() -- For testing
local GAME = {}

GAME.Name = "Test Game"
GAME.Description = "Here's a test game. WASD to move the box!"

local thePlayer = nil
local x, y = 0, 0
local now = RealTime()
local gameOverAt = 0
local gameState = 0 -- 0 = Attract mode 1 = Playing 2 = Waiting for coins update

function GAME:Init()

end

function GAME:Destroy()

end

function GAME:Start()
    x, y = SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2
    gameOverAt = now + 10
    gameState = 1
end

function GAME:Stop()
    gameState = 0
end

-- Called every frame while the local player is nearby
-- WALK key is "reserved" for coin insert
function GAME:Update()
    now = RealTime()

    if gameState == 0 then return end
    if not IsValid(thePlayer) then
        self:Stop()
        return
    end

    if now >= gameOverAt and gameState ~= 2 then
        -- Taking coins takes time to be processed by the server and for
        -- OnCoinsLost to be called, so wait until the coin amount has changed
        -- to know whether to end the game/lose a life/etc.
        COINS:TakeCoins(1)
        gameState = 2
        return
    end

    if thePlayer:KeyDown(IN_MOVELEFT) then
        x = x > 5 and x - (100 * FrameTime()) or x
    end

    if thePlayer:KeyDown(IN_MOVERIGHT) then
        x = x < SCREEN_WIDTH - 5 and x + (100 * FrameTime()) or x
    end

    if thePlayer:KeyDown(IN_BACK) then
        y = y < SCREEN_HEIGHT - 5 and y + (100 * FrameTime()) or y
    end

    if thePlayer:KeyDown(IN_FORWARD) then
        y = y > 5 and y - (100 * FrameTime()) or y
    end
end

-- Called once on init
function GAME:DrawMarquee()
    surface.SetDrawColor(0, 0, 255, 255)
    surface.DrawRect(0, 0, MARQUEE_WIDTH, MARQUEE_HEIGHT)

    surface.SetFont("DermaLarge")
    local tw, th = surface.GetTextSize("Test Game!")
    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos((MARQUEE_WIDTH / 2) - (tw / 2), (MARQUEE_HEIGHT / 2) - (th / 2))
    surface.DrawText("Test Game!")
end

-- Called every frame while the local player is nearby
-- The screen is cleared to black for you
function GAME:Draw()
    if gameState == 0 then
        surface.SetDrawColor(HSVToColor(now * 50 % 360, 1, 0.5))
        surface.DrawRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

        surface.SetFont("DermaLarge")
        local tw, th = surface.GetTextSize("INSERT COIN")
        surface.SetTextColor(255, 255, 255, math.sin(now * 5) * 255)
        surface.SetTextPos((SCREEN_WIDTH / 2) - (tw / 2), SCREEN_HEIGHT - (th * 2))
        surface.DrawText("INSERT COIN")
        return
    end

    surface.SetDrawColor(255, 0, 0, 255)
    surface.DrawRect(x - 10, y - 10, 20, 20)

    local txt = "GAME OVER IN " .. math.max(0, math.floor(gameOverAt - now))

    surface.SetFont("DermaLarge")
    local tw, th = surface.GetTextSize(txt)
    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos((SCREEN_WIDTH / 2) - tw / 2, th * 2)
    surface.DrawText(txt)

    surface.SetFont("DermaDefault")
    tw, th = surface.GetTextSize(COINS:GetCoins() .. " COIN(S)")
    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos(10, SCREEN_HEIGHT - (th * 2))
    surface.DrawText(COINS:GetCoins() .. " COIN(S)")
end

-- Called when someone sits in the seat
function GAME:OnStartPlaying(ply)
    if ply == LocalPlayer() then
        thePlayer = ply
    end
end

-- Called when someone leaves the seat
function GAME:OnStopPlaying(ply)
    if ply == thePlayer then
        thePlayer = nil
    end
end

function GAME:OnCoinsInserted(ply, old, new)
    if ply ~= LocalPlayer() then return end

    -- If a fullupdate occurs then the game will be reset, so when the player inserts a coin again
    -- old will not be 0 so we can't use that - instead check your if game state has reset to attract mode
    if new > 0 and gameState == 0 then
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
--end -- For testing