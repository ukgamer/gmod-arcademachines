-- typical color fading functions --
local function RGBToYCbCr(r, g, b)
    local Y  =  0.299 * r + 0.587 * g + 0.114 * b
    local Cb = -0.169 * r - 0.331 * g + 0.500 * b + 128
    local Cr =  0.500 * r - 0.419 * g - 0.081 * b + 128

    return Y, Cb, Cr
end
local function YCbCrToRGB(Y, Cb, Cr)
    local r = 1 * Y + 0 * (Cb - 128) + 1.4 * (Cr - 128)
    local g = 1 * Y - 0.343 * (Cb - 128) - 0.711 * (Cr - 128)
    local b = 1 * Y + 1.765 * (Cb - 128) + 0 * (Cr - 128)

    return r, g, b
end

local function Intersect(a, b, value)
    return a + (b - a) * value
end

local function IntersectColor(a, b, value)
    local Y1, Cb1, Cr1 = RGBToYCbCr(a.r,a.g,a.b)
    local Y2, Cb2, Cr2 = RGBToYCbCr(b.r,b.g,b.b)

    local r_, g_, b_ = Intersect(Y1, Y2, value), Intersect(Cb1, Cb2, value), Intersect(Cr1, Cr2, value)

    local R, G, B = YCbCrToRGB(r_, g_, b_)
    return Color(math.floor(R), math.floor(G), math.floor(B))
end
-- typical color fading functions --

-- tile class --
local TileMeta = {
    x = 0,
    y = 0,
    value = 2,
    prevPos = {},

    SavePosition = function(self)
        self.prevPos = {x = self.x, y = self.y}
    end,
    UpdatePosition = function(self, pos)
        self.x = pos.x
        self.y = pos.y
    end
}
TileMeta.__index = TileMeta

local function createTile(pos, val)
    local tile = {}
    setmetatable(tile, TileMeta)

    tile.x = pos.x
    tile.y = pos.y
    tile.value = val or 2
    tile.prevPos = {}

    return tile
end
-- tile class --

-- grid class --
local GridMeta = {
    size = 4,
    cells = {},

    Empty = function(self)
        self.cells = {}
        for x = 1, self.size do
            local row = {}
            self.cells[x] = row

            for y = 1, self.size do
                row[y] = NULL
            end
        end

        return self.cells
    end,
    WithinBounds = function(self, pos)
        return pos.x >= 1 and pos.x <= self.size and pos.y >= 1 and pos.y <= self.size
    end,
    EachCell = function(self, cb)
        for x = 1, self.size do
            for y = 1, self.size do
                cb(x, y, self.cells[x][y])
            end
        end
    end,
    AvailableCells = function(self)
        local cells = {}
        self:EachCell(function(x, y, tile)
            if tile == NULL then
                cells[#cells + 1] = {x = x, y = y}
            end
        end)

        return cells
    end,
    CellsAvailable = function(self)
        return #self:AvailableCells() > 0
    end,
    RandomAvailableCell = function(self)
        local cells = self:AvailableCells()
        if #cells > 0 then
            return table.Random(cells)
        end
    end,
    AddRandomTile = function(self)
        local rand = self:RandomAvailableCell()
        self.cells[rand.x][rand.y] = createTile(rand, math.Rand(0, 1) < 0.9 and 2 or 4)

        return self.cells[rand.x][rand.y]
    end,
    CellContent = function(self, cell)
        if self:WithinBounds(cell) then
            return self.cells[cell.x][cell.y]
        else
            return NULL
        end
    end,
    CellOccupied = function(self, cell)
        return self:CellContent(cell) ~= NULL
    end,
    CellAvailable = function(self, cell)
        return not self:CellOccupied(cell)
    end,
    InsertTile = function(self, tile)
        self.cells[tile.x][tile.y] = tile
    end,
    RemoveTile = function(self, tile)
        self.cells[tile.x][tile.y] = NULL
    end
}
GridMeta.__index = GridMeta

local function createGrid()
    local grid = {}
    setmetatable(grid, GridMeta)

    grid:Empty()

    return grid
end
-- grid class --

local background_color = Color(250, 248, 239)
local text_color = Color(119, 110, 101)
local bright_text_color = Color(249, 246, 242)

local grid_background = Color(187, 173, 160)
local grid_color = Color(205, 193, 180)

local tile_color = Color(238, 228, 218)
local tile_gold_color = Color(237, 194, 46)

local tile_colors = {}
local special_colors = {
    [8] = Color(247, 142, 72),
    [16] = Color(252, 94, 46),
    [32] = Color(255, 51, 51),
    [64] = Color(255, 0, 0)
}

for i = 1, 11 do
    local power = math.pow(2, i)
    local gold_percent = (i - 1) / 10

    local mixed_background = IntersectColor(tile_color, tile_gold_color, gold_percent)

    local special_background = special_colors[power]
    if special_background then
        mixed_background = IntersectColor(mixed_background, special_background, 0.55)
    end

    local tile_text = text_color
    if power > 4 then
        tile_text = bright_text_color
    end

    tile_colors[power] = {
        fg = tile_text,
        bg = mixed_background
    }
end

if not FONT:Exists("2048_title") then
    surface.CreateFont("2048_title", {
        size = 80,
        weight = 800,
        font = "Roboto"
    })

    surface.CreateFont("2048_text", {
        size = 36,
        weight = 800,
        font = "Roboto"
    })

    surface.CreateFont("2048_label", {
        size = 24,
        weight = 800,
        font = "Roboto"
    })
end

local GAME = {}

GAME.Name = "2048"
GAME.Author = "Cynthia"
GAME.Description = "Combine tiles to get to 2048. Use WASD to move tiles around."
GAME.CabinetArtURL = "https://ukgamer.github.io/gmod-arcademachines-assets/2048/images/ms_acabinet_artwork.png"

local thePlayer = nil
local now = RealTime()
local gameOverAt = 0
local gameState = 0 -- 0 = Attract mode 1 = Playing 2 = Waiting for coins update

local score = 0
local topScore = 0
local won = false
local over = false

local endAlpha = 0
local endTextAlpha = 0

local nextMove = now

local last_created
local last_created_size = 0

local grid = createGrid()

local grid_size = 384
local tile_size = (grid_size - (8 * (grid.size + 1))) / grid.size

function GAME:PrepareTiles()
    grid:EachCell(function(x, y, tile)
        if tile ~= NULL then
            tile.mergedFrom = nil
            tile.mergeRatio = 0
            tile:SavePosition()
        end
    end)
end

function GAME:ResetBoard()
    grid:Empty()
    for i = 1, 2 do
        last_created = grid:AddRandomTile()
        last_created_size = 0
    end
end

function GAME:Init()
    self:ResetBoard()
end

function GAME:Destroy()

end

function GAME:Start()
    gameState = 1

    score = 0
    won = false
    over = false
    endAlpha = 0
    endTextAlpha = 0

    self:ResetBoard()

    nextMove = now
end

function GAME:Stop()
    gameState = 0

    score = 0
    won = false
    over = false
    endAlpha = 0
    endTextAlpha = 0

    self:ResetBoard()

    nextMove = now
end

local dir_map = {
    [0] = {x = 0 , y = 1 },
    [1] = {x = 1 , y = 0 },
    [2] = {x = 0 , y = -1},
    [3] = {x = -1, y = 0 },
}
function GAME:GetVector(direction)
    return dir_map[direction] or {x = 0, y = 0}
end

function GAME:MoveTile(tile, cell)
    grid.cells[tile.x][tile.y] = NULL
    grid.cells[cell.x][cell.y] = tile
    tile:UpdatePosition(cell)
end

function GAME:FindFarthestPosition(cell, vector)
    local prev

    repeat
        prev = table.Copy(cell)
        cell = {x = prev.x + vector.x, y = prev.y + vector.y}
    until not (grid:WithinBounds(cell) and grid:CellAvailable(cell))

    return {
        far = prev,
        next = cell
    }
end

function GAME:PositionsEqual(first, second)
    return first.x == second.x and first.y == second.y
end

function GAME:TileMatchesAvailable()
    local tile

    for x = 1, grid.size do
        for y = 1, grid.size do
            tile = grid:CellContent({x = x, y = y})

            if tile ~= NULL then
                for dir = 0, 3 do
                    local vec = self:GetVector(dir)
                    local cell = {x = x + vec.x, y = y + vec.y}

                    local other = grid:CellContent(cell)
                    if other ~= NULL and other.value == tile.value then
                        return true
                    end
                end
            end
        end
    end

    return false
end

function GAME:MovesAvailable()
    return grid:CellsAvailable() or self:TileMatchesAvailable()
end

function GAME:BuildTraversals(vec)
    local traversals = {x = {}, y = {}}

    for pos = 1, grid.size do
        table.insert(traversals.x, pos)
        table.insert(traversals.y, pos)
    end

    if vec.x == 1 then
        traversals.x = table.Reverse(traversals.x)
    end
    if vec.y == 1 then
        traversals.y = table.Reverse(traversals.y)
    end

    return traversals
end

-- 0: up, 1: right, 2: down, 3: left
function GAME:Move(direction)
    if over or won then return end

    local cell, tile

    local vec = self:GetVector(direction)
    local traversals = self:BuildTraversals(vec)
    local moved = false

    self:PrepareTiles()

    for _, x in pairs(traversals.x) do
        for _, y in pairs(traversals.x) do
            cell = {x = x, y = y}
            tile = grid:CellContent(cell)

            if tile ~= NULL then
                local pos = self:FindFarthestPosition(cell, vec)
                local next = grid:CellContent(pos.next)

                if next ~= NULL and next.value == tile.value and not next.mergedFrom then
                    local merged = createTile(pos.next, tile.value * 2)
                    merged.mergedFrom = {tile, next}
                    merged.mergeRatio = 0

                    local gx, gy = SCREEN_WIDTH / 2 - grid_size / 2, SCREEN_HEIGHT / 2 - grid_size / 2
                    merged.prevPos = {x = tile.x, y = tile.y}
                    merged.renderPos = {x = gx + ((8 * tile.x) + ((tile.x - 1) * tile_size)), y = gy + ((8 * tile.y) + ((tile.y - 1) * tile_size))}

                    grid:InsertTile(merged)
                    grid:RemoveTile(tile)

                    tile:UpdatePosition(pos.next)

                    score = score + merged.value
                    if score > topScore then
                        topScore = score
                    end

                    if merged.value == 2048 then
                        won = true
                        gameOverAt = now + 5
                    end
                else
                    self:MoveTile(tile, pos.far)
                end
            end

            if not self:PositionsEqual(cell, tile) then
                moved = true
            end
        end
    end

    if moved then
        last_created = grid:AddRandomTile()
        last_created_size = 0

        if not self:MovesAvailable() then
            over = true
            gameOverAt = now + 5
        end
    end
end

function GAME:MoveDemo(direction)
    local cell, tile

    local vec = self:GetVector(direction)
    local traversals = self:BuildTraversals(vec)
    local moved = false

    self:PrepareTiles()

    for _, x in pairs(traversals.x) do
        for _, y in pairs(traversals.x) do
            cell = {x = x, y = y}
            tile = grid:CellContent(cell)

            if tile ~= NULL then
                local pos = self:FindFarthestPosition(cell, vec)
                local next = grid:CellContent(pos.next)

                if next ~= NULL and next.value == tile.value and not next.mergedFrom then
                    local merged = createTile(pos.next, tile.value * 2)
                    merged.mergedFrom = {tile, next}
                    merged.mergeRatio = 0

                    local gx, gy = SCREEN_WIDTH / 2 - grid_size / 2, SCREEN_HEIGHT / 2 - grid_size / 2
                    merged.prevPos = {x = tile.x, y = tile.y}
                    merged.renderPos = {x = gx + ((8 * tile.x) + ((tile.x - 1) * tile_size)), y = gy + ((8 * tile.y) + ((tile.y - 1) * tile_size))}

                    grid:InsertTile(merged)
                    grid:RemoveTile(tile)

                    tile:UpdatePosition(pos.next)

                    if merged.value == 2048 then
                        self:ResetBoard()
                    end
                else
                    self:MoveTile(tile, pos.far)
                end
            end

            if not self:PositionsEqual(cell, tile) then
                moved = true
            end
        end
    end

    if moved then
        last_created = grid:AddRandomTile()
        last_created_size = 0

        if not self:MovesAvailable() then
            self:ResetBoard()
        end
    end
end

-- Called every frame while the local player is nearby
-- WALK key is "reserved" for coin insert
function GAME:Update()
    now = RealTime()

    if gameState == 0 then
        if now > nextMove then
            self:MoveDemo(math.random(0, 3))
            nextMove = now + 1
        end
        return
    end
    if not IsValid(thePlayer) then
        self:Stop()
        return
    end

    if over and now >= gameOverAt and gameState ~= 2 then
        -- Taking coins takes time to be processed by the server and for
        -- OnCoinsLost to be called, so wait until the coin amount has changed
        -- to know whether to end the game/lose a life/etc.
        COINS:TakeCoins(1)
        gameState = 2
        return
    end

    if not over and not self:MovesAvailable() then
        over = true
        gameOverAt = now + 5
    end

    if now > nextMove then
        if thePlayer:KeyDown(IN_FORWARD) then
            self:Move(2)
            nextMove = now + 0.25
        elseif thePlayer:KeyDown(IN_MOVERIGHT) then
            self:Move(1)
            nextMove = now + 0.25
        elseif thePlayer:KeyDown(IN_BACK) then
            self:Move(0)
            nextMove = now + 0.25
        elseif thePlayer:KeyDown(IN_MOVELEFT) then
            self:Move(3)
            nextMove = now + 0.25
        end
    end
end

-- Called once on init
function GAME:DrawMarquee()
    surface.SetDrawColor(background_color)
    surface.DrawRect(0, 0, MARQUEE_WIDTH, MARQUEE_HEIGHT)

    surface.SetFont("2048_title")
    local tw, th = surface.GetTextSize("2048")
    surface.SetTextColor(text_color)
    surface.SetTextPos((MARQUEE_WIDTH / 2) - (tw / 2), (MARQUEE_HEIGHT / 2) - (th / 2))
    surface.DrawText("2048")
end

-- Called every frame while the local player is nearby
-- The screen is cleared to black for you
function GAME:DrawTiles()
    local gx, gy = SCREEN_WIDTH / 2 - grid_size / 2, SCREEN_HEIGHT / 2 - grid_size / 2

    draw.RoundedBox(4, SCREEN_WIDTH / 2 - grid_size / 2, SCREEN_HEIGHT / 2 - grid_size / 2, grid_size, grid_size, grid_background)

    for x = 1, grid.size do
        for y = 1, grid.size do
            local bx, by = gx + ((8 * x) + ((x - 1) * tile_size)), gy + ((8 * y) + ((y - 1) * tile_size))
            draw.RoundedBox(4, bx, by, tile_size, tile_size, grid_color)
        end
    end

    for x = 1, grid.size do
        for y = 1, grid.size do
            local tile = grid:CellContent({x = x, y = y})

            local tcol = tile ~= NULL and table.Copy(tile_colors[tile.value]) or {fg = text_color, bg = grid_color}
            if tile ~= NULL and tile.mergedFrom then
                tile.mergeRatio = Lerp(RealFrameTime() * 8, tile.mergeRatio, 1)

                local from = tile.mergedFrom[1].value
                local to = tile.value

                local col_from, col_to = table.Copy(tile_colors[from]), table.Copy(tile_colors[to])

                local bg1 = col_from.bg
                local bg2 = col_to.bg
                local fg1 = col_from.fg
                local fg2 = col_to.fg

                local out_bg = IntersectColor(bg1, bg2, tile.mergeRatio)
                local out_fg = IntersectColor(fg1, fg2, tile.mergeRatio)

                tcol.bg = table.Copy(out_bg)
                tcol.fg = table.Copy(out_fg)
            end

            if tile ~= NULL then
                tile.renderPos = tile.renderPos or {x = gx + ((8 * x) + ((x - 1) * tile_size)), y = gy + ((8 * y) + ((y - 1) * tile_size))}
            end
            local tx, ty = tile.renderPos and tile.renderPos.x or gx + ((8 * x) + ((x - 1) * tile_size)), tile.renderPos and tile.renderPos.y or gy + ((8 * y) + ((y - 1) * tile_size))

            if tile ~= NULL then
                if tile.prevPos and tile.prevPos.x and tile.prevPos.y then
                    local nx, ny = gx + ((8 * tile.x) + ((tile.x - 1) * tile_size)), gy + ((8 * tile.y) + ((tile.y - 1) * tile_size))
                    tile.renderPos.x = Lerp(RealFrameTime() * 8, tile.renderPos.x, nx)
                    tile.renderPos.y = Lerp(RealFrameTime() * 8, tile.renderPos.y, ny)
                    tx = tile.renderPos.x
                    ty = tile.renderPos.y
                elseif tile.x == last_created.x and tile.y == last_created.y then
                    last_created_size = Lerp(RealFrameTime() * 16, last_created_size, tile_size)
                    tx = tx + tile_size / 2 - last_created_size / 2
                    ty = ty + tile_size / 2 - last_created_size / 2
                end
            end

            local size = (tile ~= NULL and (tile.x == last_created.x and tile.y == last_created.y)) and last_created_size or tile_size

            if tile ~= NULL then
                draw.RoundedBox(4, tx, ty, size, size, tcol.bg)

                surface.SetFont("2048_text")
                local tw, th = surface.GetTextSize(tile.value)
                surface.SetTextColor(tcol.fg)
                surface.SetTextPos(tx + (size / 2) - tw / 2, ty + (size / 2) - th / 2)
                surface.DrawText(tile.value)
            end
        end
    end
end

local best_max = 0
function GAME:Draw()
    surface.SetDrawColor(background_color)
    surface.DrawRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    if gameState == 0 then
        surface.SetFont("2048_title")
        local tw = surface.GetTextSize("2048")
        surface.SetTextColor(text_color)
        surface.SetTextPos((SCREEN_WIDTH / 2) - (tw / 2), -8)
        surface.DrawText("2048")

        if now % 1 < now % 2 then
            surface.SetFont("2048_text")
            local iw, ih = surface.GetTextSize("INSERT COIN")
            surface.SetTextColor(text_color)
            surface.SetTextPos((SCREEN_WIDTH / 2) - (iw / 2), SCREEN_HEIGHT - (ih * 1.25))
            surface.DrawText("INSERT COIN")
        end

        self:DrawTiles()

        return
    end

    surface.SetFont("2048_label")
    local cw, ch = surface.GetTextSize("COINS")
    draw.RoundedBox(4, SCREEN_WIDTH / 2 - cw / 2 - 4, 12, cw + 8, ch * 2, grid_background)
    surface.SetTextColor(tile_color)
    surface.SetTextPos(SCREEN_WIDTH / 2 - cw / 2, 14)
    surface.DrawText("COINS")

    local cvw = surface.GetTextSize(COINS:GetCoins())
    surface.SetTextColor(255, 255, 255)
    surface.SetTextPos(SCREEN_WIDTH / 2 - cvw / 2, 12 + ch)
    surface.DrawText(COINS:GetCoins())

    local pw, ph = surface.GetTextSize("SCORE")
    draw.RoundedBox(4, 12, 12, pw + 8, ph * 2, grid_background)
    surface.SetTextColor(tile_color)
    surface.SetTextPos(16, 14)
    surface.DrawText("SCORE")

    local pvw = surface.GetTextSize(score)
    surface.SetTextColor(255, 255, 255)
    surface.SetTextPos(16 + pw / 2 - pvw / 2, 12 + ph)
    surface.DrawText(score)

    local bw, bh = surface.GetTextSize("BEST")
    if bw > best_max then
        best_max = bw
    end
    draw.RoundedBox(4, SCREEN_WIDTH - 12 - best_max - 8, 12, best_max + 8, bh * 2, grid_background)
    surface.SetTextColor(tile_color)
    surface.SetTextPos(SCREEN_WIDTH - 12 - best_max - 4, 14)
    surface.DrawText("BEST")

    local bvw = surface.GetTextSize(topScore)
    if bvw > best_max then
        best_max = bw
    end
    surface.SetTextColor(255, 255, 255)
    surface.SetTextPos(SCREEN_WIDTH - 12 - best_max / 2 - 4 - bvw / 2, 12 + bh)
    surface.DrawText(topScore)

    self:DrawTiles()

    if won then
        endAlpha = Lerp(RealFrameTime() / 2, endAlpha, 128)
        endTextAlpha = Lerp(RealFrameTime() / 2, endTextAlpha, 255)

        surface.SetDrawColor(tile_gold_color.r, tile_gold_color.g, tile_gold_color.b, endAlpha)
        surface.DrawRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

        surface.SetFont("2048_text")
        local tw, th = surface.GetTextSize("You Win!")
        surface.SetTextColor(text_color.r, text_color.g, text_color.b, endTextAlpha)
        surface.SetTextPos((SCREEN_WIDTH / 2) - (tw / 2), (SCREEN_HEIGHT / 2) - (th / 2))
        surface.DrawText("You Win!")
    elseif over then
        endAlpha = Lerp(RealFrameTime() / 2, endAlpha, 128)
        endTextAlpha = Lerp(RealFrameTime() / 2, endTextAlpha, 255)

        surface.SetDrawColor(background_color.r, background_color.g, background_color.b, endAlpha)
        surface.DrawRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

        surface.SetFont("2048_text")
        local tw, th = surface.GetTextSize("Game Over!")
        surface.SetTextColor(text_color.r, text_color.g, text_color.b, endTextAlpha)
        surface.SetTextPos((SCREEN_WIDTH / 2) - (tw / 2), (SCREEN_HEIGHT / 2) - (th / 2))
        surface.DrawText("Game Over!")
    end
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
