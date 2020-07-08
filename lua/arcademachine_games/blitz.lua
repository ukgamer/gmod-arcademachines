
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

--<Todo>
--  <+> plane explode animation
--  + plane start animation
--  + multiple bombs(Trails,Explosions)
--  + building particles while falling
--  + random background objects
--  + random cars (extra points)
--  + special weapons (level win bomb, slow down pickup)
--      - aquired through completing level 5,10,15,..
--  + recharging powerbar for movement
--  + air defence (avoidable by Left/Right(uses powerbar))
--  + <more> different themes
--</Todo>

--BGAME = function() -- For testing
local GAME = {}

GAME.Name = "Blitz"
GAME.Description = "Destroy buildings by dropping bombs with SPACE and complete as many levels as possible!"

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

    local building_material = Material("models/cs_havana/wndx1")

    local collapsing = {0,0,0,0,0,0,0,0,0,0,0,0}
    local building_spot = {0,0,0,0,0,0,0,0,0,0,0,0}
    local building_index = 0
    local generate_building_time = 0
    local generate_building_interval = 0

	local debug_text = ""
    local level_start = 1
    local level = 1
    local points = 0
    local lastUpdate = RealTime()
    local can_continue_time = 15

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

    local smoke_particles_spawners = {}
    local smoke_particles = {}

    local bomb_explode_particles = {}
    local bomb_explode_time = 0

    local bomb_trail_time = 0
    local bomb_trail = {}
    local bomb_trail_select = 0

    local clouds = {}

    local level_themes = {
        "day",
        "night"
    }

    local level_theme = level_themes[math.random(1)+1]

--</variables>

-- some functions awadasdawhdjawkdhaskfjsahdkjsh
    local function SetColor(r,g,b)
        surface.SetDrawColor(r,g,b,255)
    end

    local function DrawRect(xr,yr,w,h)
        surface.DrawRect(xr, yr, w, h)
    end

    local function DrawTexturedRect(xr,yr,w,h)
        surface.DrawTexturedRect(xr, yr, w, h)
    end

    local function SetFont(font)
        surface.SetFont(font)
    end

    local function SetMaterial(mat)
        surface.SetMaterial(mat)
    end

    local function DrawText(xt,yt,txt,r,g,b)
        surface.SetTextColor(Color(r,g,b,255))
        surface.SetTextPos(xt, yt)
        surface.DrawText(txt)
    end

    local function DebugLog(txt)
		debug_text = txt .. "\n" .. debug_text
	end

    local function ShowDebug()
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

        level_theme = level_themes[math.random(#level_themes)]

        clouds = {}

         button = {
            w = 200,
            h = 50
        }
    
         plane = {
            x = -10,
            y = 80,
            speed = 6
        }
    
         bomb = {
            x = -10,
            y = -10,
            w = 10,
            h = 10,
            alive = 0,
            speed = 12
        }

        for i = 1,3 do
            bomb_trail[i] = {
                x = 0,
                y = 0
            }
        end

        for i = 1, 15 do
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

        for i = 1,300 do
            smoke_particles[i] = {
                alive = 0,
                alive_time = 0,
                x = 0,
                y = 0,
                clr = Color(255,255,255,155),
                w = 28,
                h = 22
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
        can_continue_time = RealTime()
        MACHINE:EmitSound("ambient/explosions/exp3.wav", 100)
    end

    local function FindFreeSmokeParticle()
        for i=1,#smoke_particles do
            if smoke_particles[i].alive == 0 then
                return i
            end
        end
        return -1
    end

    local function SpawnSmokeParticle(spawn_x, spawn_y, spawn_w, spawn_h)
        local freeIndex = FindFreeSmokeParticle()
        if freeIndex == -1 then

        else
            smoke_particles[freeIndex].alive = 1
            smoke_particles[freeIndex].alive_time = 0
            smoke_particles[freeIndex].x = spawn_x
            smoke_particles[freeIndex].y = spawn_y
            smoke_particles[freeIndex].w = spawn_w
            smoke_particles[freeIndex].h = spawn_h
            local brightness = math.random(70)+110
            smoke_particles[freeIndex].alpha = 140
            smoke_particles[freeIndex].clr = Color(brightness,brightness,brightness,smoke_particles[freeIndex].alpha)

        end
    end

    local function DestroySmokeParticle(index)
        smoke_particles[index].alive = 0
        smoke_particles[index].x = -200
        smoke_particles[index].y = -200
    end

    local function UpdateSmokeParticles()
        for i=1,#smoke_particles do
            if smoke_particles[i].alive == 1 then
                if smoke_particles[i].alpha > 0 then
                    smoke_particles[i].alpha = smoke_particles[i].alpha - 1 
                end
                smoke_particles[i].clr = Color(smoke_particles[i].clr.r,smoke_particles[i].clr.g,smoke_particles[i].clr.b,smoke_particles[i].alpha)
                
                smoke_particles[i].y = smoke_particles[i].y - math.random(2)+1
                smoke_particles[i].x = smoke_particles[i].x + math.random(4)-2 +0.5
                smoke_particles[i].alive_time = smoke_particles[i].alive_time + 1
                if smoke_particles[i].alive_time > 150 + math.random(20) then
                    DestroySmokeParticle(i)
                end
            end
        end
    end

    local function DrawSmokeParticles()
        for i=1,#smoke_particles do
            if smoke_particles[i].alive == 1 then
                SetColor(smoke_particles[i].clr)
                DrawRect(smoke_particles[i].x,smoke_particles[i].y,smoke_particles[i].w,smoke_particles[i].h)
            end
        end
    end

    local function CheckCollision(x_1, y_1, x_2, y_2, w, h)
        return 
            (x_1 > x_2 and 
             x_1 < x_2 + (w) and
             y_1 > y_2 and 
             y_1 < y_2 + (h) )
    end

    local function CheckPlaneCollision()
        for i = 1 , #building_parts do
            if CheckCollision(plane.x+72,plane.y+20,building_parts[i].x,building_parts[i].y,building_parts[i].w+20,building_parts[i].h+20) then
                Gameover()
            end
        end
    end

    local function UpdatePlane()
        CheckPlaneCollision()

        plane.x = plane.x + (plane.speed+(level/2))

        if plane.x > SCREEN_WIDTH+20 then
            plane.y = plane.y + 30
            plane.x = -85
            if plane.y > (SCREEN_HEIGHT - 20) then
                Gameover()
            end
        end
    end

    local function DrawPlane(offx,offy)

    local lower_color = 0

        if level_theme == "night" then
            lower_color = 80
        end

        --plane base
        SetColor(220-lower_color,220-lower_color,220-lower_color)
        DrawRect(offx, offy, 80, 20)

        --plane base front
        SetColor(220-lower_color,220-lower_color,220-lower_color)
        DrawRect(offx+72, offy+3, 15, 15)

        --wing
        SetColor(120,120,120)
        DrawRect(offx+20, offy+8, 40, 7)

        --wing tail 1
        SetColor(220-lower_color,220-lower_color,220-lower_color)
        DrawRect(offx, offy-9, 20, 10)

        --wing tail 2
        SetColor(220-lower_color,220-lower_color,220-lower_color)
        DrawRect(offx+10, offy-4, 20, 10)
           
        --glass
        --SetColor(0,115,55)
       -- DrawRect(offx+62, offy+2, 20, 7)
       SetColor(30,145,30)
       DrawRect(offx+66, offy+2, 20, 6)

    end

    local function DrawBomb()
		SetColor(195,0,0)
		DrawRect(bomb.x,bomb.y,bomb.w,bomb.h)
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
            bomb_explode_particles[i].x = bomb_explode_particles[i].x + (bomb_explode_particles[i].x_change)
            bomb_explode_particles[i].y = bomb_explode_particles[i].y + (bomb_explode_particles[i].y_change + bomb_explode_particles[i].downvel)
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
            bomb_explode_particles[i].x_change = (math.sin(math.random(360)) * 2)
            bomb_explode_particles[i].y_change = (math.cos(math.random(360)) * 2)
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
            
            bomb.y = bomb.y + (bomb.speed +(level/8))
            bomb.x = bomb.x + 2
            
            if bomb.y > SCREEN_HEIGHT - 40 then
                BombExplode()
            end

            for i = 1 , #building_parts do
                if CheckCollision(bomb.x+(bomb.w/2),bomb.y+(bomb.h/2),building_parts[i].x,building_parts[i].y,building_parts[i].w,building_parts[i].h) then
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

    local function DrawBombAmmo()

    end

    local function UpdateBuildingParts()
        for i = 1 , #building_parts do

            if building_parts[i].collapsing == 1 or building_parts[i].collapsed == 1 then
                
                building_parts[i].next_smoke = building_parts[i].next_smoke + 1
                if building_parts[i].next_smoke >  building_parts[i].smoke_interval then
                    building_parts[i].next_smoke = 0 - math.random(5)
                    building_parts[i].smoked_for = building_parts[i].smoked_for + 1
                    if building_parts[i].smoked_for < 8 +math.random(9) then 
                        SpawnSmokeParticle(building_parts[i].x,building_parts[i].y,math.random(7)+13,math.random(7)+13)
                    end
                end
            end

            if building_parts[i].collapsing == 1 then
                building_parts[i].y = building_parts[i].y + 5
                if building_parts[i].y > SCREEN_HEIGHT - 55 then
                    building_parts[i].x = building_parts[i].x + math.random(18) - 9
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

            if level_theme == "day" then
                SetColor(120,120,120)
            elseif level_theme == "night" then
                SetColor(80,80,80)
            end
            
            --base
            DrawRect(building_parts[i].x + shake_x ,building_parts[i].y + shake_y ,building_parts[i].w,building_parts[i].h)
            
            if building_parts[i].collapsing == 1 or building_parts[i].collapsed == 1 then
                SetColor(90,90,90)
            else
                SetColor(240,240,100)
            end
            --window 1
            DrawRect(5+building_parts[i].x + shake_x ,4+building_parts[i].y + shake_y ,building_parts[i].w/5,building_parts[i].h-8)
            --window 2
            DrawRect((building_parts[i].w-5-(building_parts[i].w/5))+building_parts[i].x + shake_x ,4+building_parts[i].y + shake_y ,building_parts[i].w/5,building_parts[i].h-8)
        end
        --SetMaterial("")
    end
    
    local function GetBuildingPartsOffset()
        local parts_offset = 5
        if level < 11 then
            parts_offset = 5
        elseif level < 23 then
            parts_offset = 4
        elseif level < 28 then
            parts_offset = 3
        else
            parts_offset = 2
        end
        return parts_offset
    end

    local function LockBuildingSpot()
        local random_x = math.random(6)+1
        while building_spot[random_x] == 1 do
            random_x = math.random(8)+1
        end
        building_spot[random_x] = 1
        return random_x
    end

    local function GenerateBuildingPart(ind)

        local random_x = LockBuildingSpot()
        local offset_part_num = GetBuildingPartsOffset()
        local random_part_num = math.random(4+offset_part_num)+2
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
            part.smoke_interval = math.random(9)+3
            part.next_smoke = 20
            part.smoked_for = 0
            building_parts[building_index] = part
        end
	end

    local function GenerateBuildingParts()
        local building_count = math.random(5)+1
        for i = 1, building_count do
            GenerateBuildingPart(i)
        end
    end

    local function ResetClouds()
        for i = 1,7 do
            clouds[i] = {
                x = math.random(400)+0,
                y = math.random(320)+80
            }
        end
    end

    local function DrawClouds()
        for i = 1,4 do
            if level_theme == "day" then
                SetColor(155,155,155)
            elseif level_theme == "night" then
                SetColor(95,95,95)
            end

            DrawRect( clouds[i].x, clouds[i].y,80,44)
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
        if level_theme == "day" then
            SetColor(88,84,205)
        elseif level_theme == "night" then
            SetColor(18,14,105)
        end

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

    if state == 0 then -- in game
        if lastUpdate + 0.025 < RealTime() then
            lastUpdate = RealTime()

            if thePlayer:KeyDown(IN_JUMP) then
                if bomb.alive == 0 then
                    DropBomb()
                    MACHINE:EmitSound("ambient/misc/clank2.wav", 50)
                end
            end

            if level_start == 1 then
                MACHINE:StopSound("ambient/atmosphere/city_tone.wav")
                MACHINE:EmitSound("ambient/atmosphere/city_tone.wav", 40)
                level_start = 0
                GenerateBuildingParts()
            end

            UpdateBuildingParts()
            UpdateBombTrail()
            UpdatePlane()
            UpdateClouds()
            UpdateSmokeParticles()

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
    elseif state == 1 then --gameover
        if thePlayer:KeyDown(IN_JUMP) then
            if MACHINE:GetCoins() > 0 then
                if can_continue_time + 2 < RealTime() then
                    GameReset()
                    MACHINE:TakeCoins(1)
                    state = 0
                end
            end
        end
    end
end

surface.CreateFont("CustomFont0022",  
    { font = "Consolas",  
    extended = false,  
    size = 68,  weight = 200,  
    blursize = 0,  
    scanlines = 7,  
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
    size = 17,  weight = 200,  
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
    surface.SetTextColor(0, 75, 0, 255)
    surface.SetTextPos(-10+(MARQUEE_WIDTH / 2) - (tw / 2),-10+ (MARQUEE_HEIGHT / 2) - (th / 2))
    surface.DrawText("BLITZ ")

    surface.SetTextColor(0, 225, 0, 255)
    surface.SetTextPos(-13+(MARQUEE_WIDTH / 2) - (tw / 2),-10+ -3+(MARQUEE_HEIGHT / 2) - (th / 2))
    surface.DrawText("BLITZ ")

    surface.SetFont("CustomFont0023")
    surface.SetTextColor(0, 195, 0, 255)
    surface.SetTextPos(126+(MARQUEE_WIDTH / 2) - (tw / 2), -4+(MARQUEE_HEIGHT / 2) - (th / 2))
    --surface.DrawText("C64")
    
    --building1
    SetColor(110,110,110)
    DrawRect(MARQUEE_WIDTH - 106,90,20,50)
    --building1(back)
    SetColor(150,150,150)
    DrawRect(MARQUEE_WIDTH - 106-2,90,20,50)
    --building2
    SetColor(110,110,110)
    DrawRect(MARQUEE_WIDTH - 80,110,20,30)
    --building2(back)
    SetColor(150,150,150)
    DrawRect(MARQUEE_WIDTH - 80-2,110,20,30)


    SetColor(100,0,0)
    DrawRect(MARQUEE_WIDTH - 186-2+18,54,6,6)
    SetColor(100,0,0)
    DrawRect(MARQUEE_WIDTH - 180-2+18,60,8,8)
    SetColor(200,0,0)
    DrawRect(MARQUEE_WIDTH - 175-2-1+18,70-1,10,10)
    

    DrawPlane(MARQUEE_WIDTH - 210,20)

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
		return
	end
    if state == 0 then -- in game
        
        DrawBackground()
        DrawClouds()
        DrawPlane(plane.x,plane.y)
        DrawBombTrail()
        DrawSmokeParticles()

        if bomb.alive == 1 then
            DrawBomb()
        end
	
        DrawBuildingParts()

        if bomb_explode_time > 0 then
            DrawExplodeParticles()
        end

        DrawPoints()
        DrawLevel()

        return

    elseif state == 1 then -- gameover
        local tw, th = surface.GetTextSize("GAME OVER")
        DrawText ( ( SCREEN_WIDTH / 2) - (tw / 2), SCREEN_HEIGHT - (th * 2) -400,"GAME OVER", 255,255,255  )
        tw, th = surface.GetTextSize("POINTS: "..points)
        DrawText ( ( SCREEN_WIDTH / 2) - (tw / 2), SCREEN_HEIGHT - (th * 2) -300,"POINTS: "..points, 255,255,255  )
        tw, th = surface.GetTextSize("LEVEL: "..level)
        DrawText ( ( SCREEN_WIDTH / 2) - (tw / 2), SCREEN_HEIGHT - (th * 2)-250,"LEVEL: "..level, 255,255,255  )

        if can_continue_time + 2 < RealTime() then
            surface.SetTextColor(255, 255, 255, math.sin(now * 5) * 255)
            tw, th = surface.GetTextSize("PRESS SPACE TO RESTART")
            surface.SetTextPos(( SCREEN_WIDTH / 2) - (tw / 2), SCREEN_HEIGHT - (th * 2) -80)
            surface.DrawText("PRESS SPACE TO RESTART")
        end

    end

    --Coins
    surface.SetFont("DermaDefault")
    local tw, th = surface.GetTextSize(MACHINE:GetCoins() .. " COIN(S)")
    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos(10, SCREEN_HEIGHT - (th * 2))
    surface.DrawText(MACHINE:GetCoins() .. " COIN(S)")

end

function GAME:OnStartPlaying(ply)
    if ply == LocalPlayer() then
        thePlayer = ply
    end
end
function GAME:OnStopPlaying(ply)
    if ply == thePlayer then
        MACHINE:StopSound("ambient/atmosphere/city_tone.wav")
        thePlayer = nil
        GameReset()
    end
end
function GAME:OnCoinsInserted(ply, old, new)
    MACHINE:EmitSound("garrysmod/content_downloaded.wav", 50)
    if ply ~= LocalPlayer() then 
        return 
    end
    if new > 0 and gameState == 0 then
        self:Start()
    end
end
function GAME:OnCoinsLost(ply, old, new)
    if ply ~= LocalPlayer() then 
        return 
    end
    if new == 0 then self:Stop() 
    
    end
    if new > 0 then self:Start() 
    
    end
end

return GAME
--end -- For testing
