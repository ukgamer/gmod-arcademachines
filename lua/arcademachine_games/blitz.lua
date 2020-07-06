
-- gmod-arcademachine version of Blitz(VIC-20)
-- Made by simlzx / :d
--
--  ________  ___       ___  _________  ________     
--  |\   __  \|\  \     |\  \|\___   ___\\_____  \    
--  \ \  \|\ /\ \  \    \ \  \|___ \  \_|\|___/  /|   
--   \ \   __  \ \  \    \ \  \   \ \  \     /  / /   
--    \ \  \|\  \ \  \____\ \  \   \ \  \   /  /_/__  
--     \ \_______\ \_______\ \__\   \ \__\ |\________\
--      \|_______|\|_______|\|__|    \|__|  \|_______|

--<Controls>
    --   Space: drop bomb
    --   W: menu select up
    --   S: menu select down
--</Controls>

--MYGAME = function() -- For testing
local GAME = {}

GAME.Name = "Blitz"

local thePlayer = nil
local x, y = 0, 0
local now = RealTime()
local gameOverAt = 0
local gameState = 0 

-- 0 = Attract mode
-- 1 = Playing 
-- 2 = Waiting for coins update

--<variables>
    local state = 0
    local game_tick = 0
    local can_drop_bomb = 0

    local menu_move_time = 0
    local menu_time = 0
    local menu_selected = 0

    local buildings = {}
    local building_parts = {}

    local collapsing = {0,0,0,0,0,0,0,0,0,0,0,0}
    local building_spot={0,0,0,0,0,0,0,0,0,0,0,0}
    local building_index = 0
    local generate_building_time = 0
    local generate_building_interval = 0

	local debug_text = ""
    local level_start = 1
    local level = 1
    local points = 0

	local button = {
		w = 0,
		h = 0
	}

    local plane = {
        x = 0,
        y = 0,
        speed = 0
    }

    local bomb = {
        x = 0,
        y = 0,
        alive = 0,
        speed = 3
    }

    local bomb_explode_particles = {}
    local bomb_explode_time = 0

    local bomb_trail_time = 0
    local bomb_trail = {}
    local bomb_trail_select = 0

    local clouds = {}

--</variables>

-- some functions awadasdawhdjawkdhaskfjsahdkjsh
    function SetColor(r,g,b)
        surface.SetDrawColor(r,g,b,255)
    end

    function DrawRect(xr,yr,w,h)
        surface.DrawRect(xr, yr, w, h)
    end

    function SetFont(font)
        surface.SetFont(font)
    end

    function DrawText(xt,yt,txt,r,g,b)
        surface.SetTextColor(Color(r,g,b,255))
        surface.SetTextPos(xt, yt)
        surface.DrawText(txt)
    end

	function DebugLog(txt)
		debug_text = txt .. "\n" .. debug_text
	end

	function ShowDebug()
		DrawText(11,11,debug_text,0,0,0)
		DrawText(10,10,debug_text,0,255,0)
    end

--<game functions>

    local function GameReset()
         state = 0
         game_tick = 0
         can_drop_bomb = 1
    
         menu_move_time = 0
         menu_time = 80
         menu_selected = 1
    
         buildings = {}
         building_parts = {}
    
         collapsing = {0,0,0,0,0,0,0,0,0,0,0,0}
         building_spot={0,0,0,0,0,0,0,0,0,0,0,0}
         building_index = 0
         generate_building_time = 0
         generate_building_interval = 20
    
         debug_text = ""
         level_start = 1
         level = 1
         points = 0

        bomb_explode_particles = {}
        bomb_explode_time = 0
     
        bomb_trail_time = 0
        bomb_trail = {}
        bomb_trail_select = 0

        clouds = {}

         button = {
            w = 200,
            h = 50
        }
    
         plane = {
            x = -10,
            y = 80,
            speed = 8
        }
    
         bomb = {
            x = 0,
            y = 0,
            alive = 0,
            speed = 12
        }

        for i = 1,3 do
            bomb_trail[i] = {
                x = 0,
                y = 0
            }
        end

        for i = 1, 12 do
            bomb_explode_particles[i] = {
                x = 0,
                y = 0,
                x_change = 0,
                y_change = 0,
                downvel = 0
            }
        end

        for i = 1,7 do
            clouds[i] = {
                x = math.random(400)+20,
                y = math.random(320)+20
            }
        end

    end


    local function NextLevel()
        local temp_points = points
        local temp_level = level
        GameReset()
        points = temp_points
        level = temp_level + 1
    end

    local function Gameover()
        state = 1
        MACHINE:EmitSound("ambient/explosions/exp3.wav", 100)
    end

    local function CheckCollision(x_1, y_1, x_2, y_2, w, h)
        return 
            (x_1 > x_2 and 
             x_1 < x_2 + (w/2) and
             y_1 > y_2 and 
             y_1 < y_2 + (h/2) )
    end

    local function CheckPlaneCollision()
        for i = 1 , #building_parts do
            if CheckCollision(plane.x+72,plane.y,building_parts[i].x,building_parts[i].y,building_parts[i].w+20,building_parts[i].h+20) then
                Gameover()
            end
        end
    end

    local function UpdatePlane()
        CheckPlaneCollision()

        plane.x = plane.x + (plane.speed+level)

        if plane.x > SCREEN_WIDTH then
            plane.y = plane.y + 40
            plane.x = -60
            if plane.y > (SCREEN_HEIGHT - 20) then
                Gameover()
            end
        end
    end

    local function DrawPlane()
        --plane base
        SetColor(220,220,220)
        DrawRect(plane.x, plane.y, 80, 20)

         --plane base front
         SetColor(220,220,220)
         DrawRect(plane.x+72, plane.y+3, 15, 15)
 
        --wing
        SetColor(120,120,120)
        DrawRect(plane.x+20, plane.y+8, 40, 7)

        --wing tail 1
        SetColor(220,220,220)
        DrawRect(plane.x, plane.y-9, 20, 10)

        --wing tail 2
        SetColor(220,220,220)
        DrawRect(plane.x+10, plane.y-4, 20, 10)
           
        --glass
        SetColor(0,115,55)
        DrawRect(plane.x+62, plane.y+2, 20, 7)

    end

    local function DrawBomb()
		SetColor(195,0,0)
		DrawRect(bomb.x,bomb.y,10,10)
    end

    local function DropBomb()
        bomb.alive = 1
        bomb.x = plane.x + 17
        bomb.y = plane.y
    end

    local function ExplodeParticles()
        bomb_explode_time = bomb_explode_time - 1
        for i = 1, #bomb_explode_particles do
            bomb_explode_particles[i].downvel = bomb_explode_particles[i].downvel + 0.03
            bomb_explode_particles[i].x = bomb_explode_particles[i].x + bomb_explode_particles[i].x_change
            bomb_explode_particles[i].y = bomb_explode_particles[i].y + bomb_explode_particles[i].y_change + bomb_explode_particles[i].downvel
        end
    end

    local function DrawExplodeParticles()
        for i = 1, #bomb_explode_particles do
            SetColor(255,255,0)
            DrawRect(bomb_explode_particles[i].x,bomb_explode_particles[i].y,5,5)
        end
    end

    local function BombExplode()
        bomb.alive = 0
        for i = 1, #bomb_explode_particles do
            bomb_explode_particles[i].x = bomb.x
            bomb_explode_particles[i].y = bomb.y
            bomb_explode_particles[i].x_change = math.sin(math.random(360)) * 2
            bomb_explode_particles[i].y_change = math.cos(math.random(360)) * 2
            bomb_explode_particles[i].downvel = 0
        end
        bomb_explode_time = 30
        local random_sound = math.random(2)
        if random_sound == 1 then
            MACHINE:EmitSound("ambient/explosions/exp4.wav", 50)
        else
            MACHINE:EmitSound("ambient/explosions/exp2.wav", 50)
        end

    end

    local function UpdateBomb()
		if bomb.alive == 1 then
            
            bomb.y = bomb.y + (bomb.speed +(level/10))
            bomb.x = bomb.x + 2
            
            if bomb.y > SCREEN_HEIGHT - 40 then
                BombExplode()
            end

            for i = 1 , #building_parts do
                if CheckCollision(bomb.x,bomb.y,building_parts[i].x,building_parts[i].y,building_parts[i].w+20,building_parts[i].h+20) then
                    for j = 1 , #building_parts do
                        if building_parts[j].index == building_parts[i].index then
                            building_parts[j].collapsing = 1
                        end
                    end
                    BombExplode()
                    return
                end
            end
		end
    end

    local function UpdateBombTrail()
        if bomb_trail_time == 0 then
            bomb_trail_time = 2
            bomb_trail_select = bomb_trail_select + 1
            if bomb_trail_select > 3 then 
                bomb_trail_select = 1
            end
            if bomb.alive == 1 then
                bomb_trail[bomb_trail_select].x = bomb.x
                bomb_trail[bomb_trail_select].y = bomb.y
            else
                bomb_trail[bomb_trail_select].x = -111
                bomb_trail[bomb_trail_select].y = -111
            end

        end
        if bomb_trail_time > 0 then
            bomb_trail_time = bomb_trail_time - 1
        end
    end

    local function DrawBombTrail()
        for i = 1,3 do
            SetColor(70,0,0)
            DrawRect(bomb_trail[i].x,bomb_trail[i].y,9,9)
        end
    end

    local function UpdateBuildingParts()
        for i = 1 , #building_parts do
            if building_parts[i].collapsing == 1 then
                building_parts[i].y = building_parts[i].y + 5
                if building_parts[i].y > SCREEN_HEIGHT - 55 then
                    building_parts[i].x = building_parts[i].x + math.random(14) - 7
                    building_parts[i].y = building_parts[i].y + math.random(5) - 2.5
                    building_parts[i].collapsing = 0
                    if building_parts[i].collapsed == 0 then
                        building_parts[i].collapsed = 1
                        points = points + 100
                    end
                end
            end
        end
    end

    local function DrawBuildingParts()
        for i = 1 , #building_parts do
            local shake_x = 0
            local shake_y = 0
            local shake_amount = 2
            if building_parts[i].collapsing == 1 then
                shake_x = math.random(shake_amount)-(shake_amount/2)
                shake_y = math.random(shake_amount)-(shake_amount/2)
            end
            SetColor(120,120,120)
            DrawRect(building_parts[i].x + shake_x ,building_parts[i].y + shake_y ,building_parts[i].w,building_parts[i].h)
        end
    end
    

    local function GenerateBuildingPart(ind)
        local random_x = math.random(6)+1
        while building_spot[random_x] == 1 do
            random_x = math.random(8)+1
        end
        building_spot[random_x] = 1

		local random_part_num = math.random(5)+2
		local part_temp_y = SCREEN_HEIGHT - 30
        for i = 1 , random_part_num do
            local part = {}
            building_index = building_index + 1
			part_temp_y = part_temp_y - 20
			part.x = (random_x * 50)
            part.y = part_temp_y
            part.w = 40
            part.h = 20
            part.index = ind
            part.collapsing = 0
            part.collapsed = 0
            building_parts[building_index] = part
        end
	end

    local function GenerateBuildingParts()

        local building_count = math.random(4)+1
        for i = 1, building_count do
            GenerateBuildingPart(i)
        end

    end

    local function ResetClouds()
        for i = 1,7 do
            clouds[i] = {
                x = math.random(400)+20,
                y = math.random(320)+60
            }
        end
    end

    local function DrawClouds()
        for i = 1,4 do
            for j = 1,4 do
                SetColor(155,155,155)
                DrawRect( clouds[i].x+(10*j), clouds[i].y,60+math.random(4)-4,34+math.random(4)-4)
            end
        end
    end

    local function UpdateClouds()
        for i = 1,4 do
            clouds[i].x = clouds[i].x + 1
            if clouds[i].x > SCREEN_WIDTH then clouds[i].x = -60 end
        end
    end

    local function DrawBackground()
        --sky
        SetColor(88,84,205)
        DrawRect(0,0,SCREEN_WIDTH,SCREEN_HEIGHT)
        --ground
        SetColor(26,13,0)
        DrawRect(0,SCREEN_HEIGHT-50,SCREEN_WIDTH,SCREEN_HEIGHT)
    end

    local function DrawPoints()
        DrawText(30,30,"POINTS: "..points,255,255,255)
    end

    local function DrawLevel()
        DrawText(SCREEN_WIDTH-150,30,"LEVEL: "..level,255,255,255)
    end


    local function CheckLevelComplete()
        for i = 1, #building_parts do
            if building_parts[i].collapsed == 0 then
                return false
            end
        end
        return true
    end

    local function Menu_Up()
        menu_move_time = menu_time
        menu_selected = menu_selected - 1
        if menu_selected == 0 then menu_selected = 2 end
    end

    local function Menu_Down()
        menu_move_time = menu_time
        menu_selected = menu_selected + 1
        if menu_selected == 3 then menu_selected = 1 end
    end
--</game functions>

function GAME:Init()
    GameReset()
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

function GAME:Update()
    now = RealTime()

    if gameState == 0 then return end
    if not IsValid(thePlayer) then
        self:Stop()
        return
    end

    if now >= gameOverAt and gameState ~= 2 then
        gameState = 2
        return
    end

    if state == -1 then

        if thePlayer:KeyDown(IN_BACK) then
            if menu_move_time == 0 then
                Menu_Down()
            end
        end

        if thePlayer:KeyDown(IN_FORWARD) then
            if menu_move_time == 0 then
                Menu_Up()
            end
        end

        if thePlayer:KeyDown(IN_JUMP) then
            state = 1
        end

        if menu_move_time > 0 then
            menu_move_time = menu_move_time - 1
        end

    elseif state == 0 then -- in game
        if game_tick > 0 then game_tick = game_tick - 1 end

        if game_tick == 0 then
            game_tick = 4

            if thePlayer:KeyDown(IN_JUMP) then
                if bomb.alive == 0 then
                    DropBomb()
                    MACHINE:EmitSound("ambient/misc/clank2.wav", 50)
                end
            end

            if level_start == 1 then
                level_start = 0
                GenerateBuildingParts()
            end

            UpdateBuildingParts()
            UpdateBombTrail()
            UpdatePlane()
            UpdateClouds()

            if CheckLevelComplete() then
                NextLevel()
            end

            if bomb.alive == 1 then
                UpdateBomb()
            end

            if bomb_explode_time > 0 then
                ExplodeParticles()
            end


        end
    elseif state == 1 then
        if thePlayer:KeyDown(IN_JUMP) then
            if MACHINE:GetCoins() > 0 then
                GameReset()
            end
            MACHINE:TakeCoins(1)
            state = 0
        end
    end

end
surface.CreateFont("CustomFont0022",  
{ font = "Consolas",  
extended = false,  
size = 21,  weight = 200,  
blursize = 0,  
scanlines = 0,  
antialias = false,  
underline = false,  
italic = false,  
strikeout = true,  
symbol = false,  
rotary = false,  
shadow = true,  
additive = false,  
outline = false 
})    

surface.CreateFont("CustomFont0023",  
{ font = "Consolas",  
extended = false,  
size = 15,  weight = 200,  
blursize = 0,  
scanlines = 0,  
antialias = false,  
underline = false,  
italic = false,  
strikeout = true,  
symbol = false,  
rotary = false,  
shadow = true,  
additive = false,  
outline = false 
})


function GAME:DrawMarquee()
    surface.SetDrawColor(0, 0, 0, 255)
    surface.DrawRect(0, 0, MARQUEE_WIDTH, MARQUEE_HEIGHT)

    surface.SetFont("CustomFont0022")
    local tw, th = surface.GetTextSize("BLITZ Game")
    surface.SetTextColor(0, 155, 0, 255)
    surface.SetTextPos(-10+(MARQUEE_WIDTH / 2) - (tw / 2), (MARQUEE_HEIGHT / 2) - (th / 2))
    surface.DrawText("BLITZ ")

    surface.SetTextColor(0, 195, 0, 255)
    surface.SetTextPos(-11+(MARQUEE_WIDTH / 2) - (tw / 2), -1+(MARQUEE_HEIGHT / 2) - (th / 2))
    surface.DrawText("BLITZ ")

    surface.SetFont("CustomFont0023")
    surface.SetTextColor(0, 195, 0, 255)
    surface.SetTextPos(41+(MARQUEE_WIDTH / 2) - (tw / 2), -4+(MARQUEE_HEIGHT / 2) - (th / 2))
    surface.DrawText("C64")
    

    SetColor(110,110,110)
    DrawRect(206,5,20,50)

    SetColor(150,150,150)
    DrawRect(206-2,5,20,50)

    SetColor(110,110,110)
    DrawRect(180,25,20,30)

    SetColor(150,150,150)
    DrawRect(180-2,25,20,30)

    
end


function GAME:Draw()

    SetFont("DermaLarge")

    
    if gameState == 0 then

		SetColor(0,0,0)
		DrawRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

        local tw, th = surface.GetTextSize("INSERT COIN")

        surface.SetFont("DermaLarge")
        local tw, th = surface.GetTextSize("INSERT COIN")
        surface.SetTextColor(255, 255, 255, math.sin(now * 5) * 255)
        surface.SetTextPos((SCREEN_WIDTH / 2) - (tw / 2), SCREEN_HEIGHT - (th * 2))
        surface.DrawText("INSERT COIN")
		
        --Coins
        surface.SetFont("DermaDefault")
        local tw, th = surface.GetTextSize(MACHINE:GetCoins() .. " COIN(S)")
        surface.SetTextColor(255, 255, 255, 255)
        surface.SetTextPos(10, SCREEN_HEIGHT - (th * 2))
        surface.DrawText(MACHINE:GetCoins() .. " COIN(S)")
		return
	end
    if state == 0 then -- in game
        
        DrawBackground()
        DrawClouds()
        DrawPlane()
        DrawBombTrail()

        if bomb.alive == 1 then
            DrawBomb()
        end
	
        DrawBuildingParts()

        if bomb_explode_time > 0 then
            DrawExplodeParticles()
        end

        DrawPoints()
        DrawLevel()


        --Coins
        surface.SetFont("DermaDefault")
        local tw, th = surface.GetTextSize(MACHINE:GetCoins() .. " COIN(S)")
        surface.SetTextColor(255, 255, 255, 255)
        surface.SetTextPos(10, SCREEN_HEIGHT - (th * 2))
        surface.DrawText(MACHINE:GetCoins() .. " COIN(S)")
        return
    elseif state == 1 then -- gameover
        local tw, th = surface.GetTextSize("GAME OVER")
        DrawText ( ( SCREEN_WIDTH / 2) - (tw / 2), SCREEN_HEIGHT - (th * 2) -400,"GAME OVER", 255,255,255  )
        tw, th = surface.GetTextSize("POINTS: "..points)
        DrawText ( ( SCREEN_WIDTH / 2) - (tw / 2), SCREEN_HEIGHT - (th * 2) -300,"POINTS: "..points, 255,255,255  )
        tw, th = surface.GetTextSize("LEVEL: "..level)
        DrawText ( ( SCREEN_WIDTH / 2) - (tw / 2), SCREEN_HEIGHT - (th * 2)-250,"LEVEL: "..level, 255,255,255  )

        --Coins
        surface.SetFont("DermaDefault")
        local tw, th = surface.GetTextSize(MACHINE:GetCoins() .. " COIN(S)")
        surface.SetTextColor(255, 255, 255, 255)
        surface.SetTextPos(10, SCREEN_HEIGHT - (th * 2))
        surface.DrawText(MACHINE:GetCoins() .. " COIN(S)")

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
        GameReset()
    end
end

function GAME:OnCoinsInserted(ply, old, new)
    MACHINE:EmitSound("garrysmod/content_downloaded.wav", 50)

    if ply ~= LocalPlayer() then return end

    -- If a fullupdate occurs then the game will be reset,
	-- so when the player inserts a coin again
	--
    -- old will not be 0 so we can't use that - 
	-- instead check your if game state has reset to attract mode
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
