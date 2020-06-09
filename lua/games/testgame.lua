-- You can call machine:SetGame(GAME) on the client to test your game

GAME = {}

-- REQUIRED
GAME.Name = "Test Game"

local theMachine = nil
local thePlayer = nil
local x, y, w, h = 0, 0, 0, 0
local mw, mh = 0, 0
local isPlaying = false
local now = RealTime()
local gameOverAt = 0
local gameState = 0

-- REQUIRED
function GAME:Init(ent, screenWidth, screenHeight, marqueeWidth, marqueeHeight)
    theMachine = ent

    w = screenWidth
    h = screenHeight

    mw = marqueeWidth
    mh = marqueeHeight
end

function GAME:Destroy()
    
end

-- Custom function
function GAME:Start()
    x, y = w / 2, h / 2
    gameOverAt = now + 10
    gameState = 1
end

-- REQUIRED
-- Called every frame while the local player is nearby
-- WALK key is "reserved" for coin insert
function GAME:Update()
    now = RealTime()

    isPlaying = IsValid(thePlayer) and theMachine:GetCoins() > 0

    if not isPlaying then return end

    if now >= gameOverAt and gameState == 1 then
        theMachine:TakeCoins(1)
        gameState = 0
        return
    end

    if thePlayer:KeyDown(IN_MOVELEFT) then
        x = x > 5 and x - 1 or x
    end

    if thePlayer:KeyDown(IN_MOVERIGHT) then
        x = x < w - 5 and x + 1 or x
    end

    if thePlayer:KeyDown(IN_BACK) then
        y = y < h - 5 and y + 1 or y
    end

    if thePlayer:KeyDown(IN_FORWARD) then
        y = y > 5 and y - 1 or y
    end
end

-- Called once on init
function GAME:DrawMarquee()
    surface.SetDrawColor(0, 0, 255, 255)
    surface.DrawRect(0, 0, mw, mh)

    surface.SetFont("DermaLarge")
    local tw, th = surface.GetTextSize("Test Game!")
    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos((mw / 2) - (tw / 2), (mh / 2) - (th / 2))
    surface.DrawText("Test Game!")
end

-- REQUIRED
-- Called every frame while the local player is nearby
-- The screen is cleared to black for you
function GAME:Draw()
    if not isPlaying then
        surface.SetDrawColor(HSVToColor(now * 50 % 360, 1, 0.5))
        surface.DrawRect(0, 0, w, h)

        surface.SetFont("DermaLarge")
        local tw, th = surface.GetTextSize("INSERT COIN")
        surface.SetTextColor(255, 255, 255, math.sin(now * 5) * 255)
        surface.SetTextPos((w / 2) - (tw / 2), h - (th * 2))
        surface.DrawText("INSERT COIN")
        return
    end

    surface.SetDrawColor(255, 0, 0, 255)
    surface.DrawRect(x - 10, y - 10, 20, 20)

    local txt = "GAME OVER IN " .. math.floor(gameOverAt - now)

    surface.SetFont("DermaLarge")
    local tw, th = surface.GetTextSize(txt)
    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos((w / 2) - tw / 2, (th * 2))
    surface.DrawText(txt)

    surface.SetFont("DermaDefault")
    local tw, th = surface.GetTextSize(theMachine:GetCoins() .. " COIN(S)")
    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos(10, h - (th * 2))
    surface.DrawText(theMachine:GetCoins() .. " COIN(S)")
end

-- REQUIRED
-- Called when someone sits in the seat
function GAME:OnStartPlaying(ply)
    if ply == LocalPlayer() then
        thePlayer = ply
    end
end

-- REQUIRED
-- Called when someone leaves the seat
function GAME:OnStopPlaying(ply)
    if ply == thePlayer then
        thePlayer = nil
    end
end

function GAME:OnCoinsInserted(ply, old, new)
    theMachine:EmitSound("garrysmod/content_downloaded.wav", 50)

    if ply ~= LocalPlayer() then return end

    if old == 0 and new > 0 then
        self:Start()
    end
end

function GAME:OnCoinsLost(ply, old, new)
    if ply ~= LocalPlayer() then return end

    if new > 0 then
        self:Start()
    end
end

return GAME