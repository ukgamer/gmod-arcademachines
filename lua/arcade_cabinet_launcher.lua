local GAME = {}

local thePlayer = nil
local gameList = {}
local curIndex = 1
local selectedCol = Color(255, 100, 100)
local lastInput = 0
local selectionTri = {
    { x = 0, y = 0 },
    { x = 0, y = 0 },
    { x = 0, y = 0 }
}
local bgBarW = 20

function GAME:Init()
    gameList = {}

    for k, v in ipairs(file.Find("arcade_cabinet_games/*.lua", "LUA")) do
        gameList[k] = v:gsub(".lua", "")
    end

    curIndex = 1
end

function GAME:Update()
    if not IsValid(thePlayer) or #gameList == 0 or RealTime() - lastInput < 0.2 then return end

    if thePlayer:KeyDown(IN_FORWARD) then
        if curIndex == 1 then
            curIndex = #gameList
        else
            curIndex = curIndex - 1
        end

        lastInput = RealTime()
    end

    if thePlayer:KeyDown(IN_BACK) then
        if curIndex == #gameList then
            curIndex = 1
        else
            curIndex = curIndex + 1
        end

        lastInput = RealTime()
    end

    if thePlayer:KeyDown(IN_JUMP) then
        LAUNCHER:LaunchGame(gameList[curIndex])

        lastInput = RealTime()
    end
end

function GAME:DrawBackground()
    local h = 20 + math.sin(RealTime() * 0.25) * 10

    for i = 0, math.ceil(SCREEN_WIDTH / bgBarW) do
        local val = math.sin((i * 0.1) + (RealTime() * 0.5))
        surface.SetDrawColor(0, 0, 50 + math.abs(val) * 50)
        surface.DrawRect(i * bgBarW, SCREEN_HEIGHT * 0.5 + val * h, bgBarW, h)

        surface.SetDrawColor(0, 0, 50 + math.abs(-val) * 50)
        surface.DrawRect(i * bgBarW, SCREEN_HEIGHT * 0.5 + -val * h, bgBarW, h)
    end
end

function GAME:Draw()
    self:DrawBackground()

    surface.SetFont("DermaLarge")
    local tw, th = surface.GetTextSize("Select a Game")
    surface.SetTextColor(color_white)
    surface.SetTextPos((SCREEN_WIDTH * 0.5) - (tw * 0.5), SCREEN_HEIGHT * 0.1)
    surface.DrawText("Select a Game")

    surface.SetFont("DermaDefault")
    for k, v in pairs(gameList) do
        tw, th = surface.GetTextSize(v)
        local x, y = (SCREEN_WIDTH * 0.5) - (tw * 0.5), (SCREEN_HEIGHT * 0.2) + ((k - 1) * th)

        surface.SetTextColor(curIndex == k and selectedCol or color_white)
        surface.SetTextPos(x, y)
        surface.DrawText(v)

        if curIndex == k then
            x = x - 10
            y = y + 2

            selectionTri[1].x = x
            selectionTri[1].y = y
            selectionTri[2].x = x + 5
            selectionTri[2].y = y + 5
            selectionTri[3].x = x
            selectionTri[3].y = y + 10

            surface.SetDrawColor(selectedCol)
            draw.NoTexture()
            surface.DrawPoly(selectionTri)
        end
    end

    local text = "[" .. string.upper(input.LookupBinding("+forward") or "w") ..
        "/" .. string.upper(input.LookupBinding("+back") or "s") .. "] Up/Down " ..
        "[" .. string.upper(input.LookupBinding("+jump") or "space") .. "] Start Game"
    tw, th = surface.GetTextSize(text)
    surface.SetTextColor(color_white)
    surface.SetTextPos((SCREEN_WIDTH * 0.5) - (tw * 0.5), SCREEN_HEIGHT - (th * 2))
    surface.DrawText(text)
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