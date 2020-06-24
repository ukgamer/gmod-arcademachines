-- Code from 06/24/20 16:24:17PM
-- Source: <0:0:70542806|twent><flappybird_2.lua>(18369B)


--
-- Flappy Bird for the arcade machine system!
-- Rips assets/sounds (TODO) from FlapPyBird (thanks sourabhv).
--
-- This file is the "rewrite", excluding
-- useless variables and overall should be a bit
-- faster.
--
-- TODO:
--   Use collision library
--   Sounds (sucky)
--   Flappy falling when dead
--

-- we cache sprites globally so if the machine is updated
-- it can access the pipe sprite for marquee
flappy_sprites = flappy_sprites or {}


--FB = function()


local gap = 280
local baseURL = "https://raw.githubusercontent.com/sourabhv/FlapPyBird/master/assets/sprites/"
local baseURL_snd = (baseURL:gsub ("sprites", "audio")) -- LMAO
local lookup_flap =
{
	[0] = "up",
	[1] = "mid",
	[2] = "down"
}

--
local GAME = {}

GAME.Name = "Flappy Bird"

-- Vars, init stuff here
GAME.DownloadedSprites = false
GAME.DownloadingSprites = false
GAME.AmountSprites = nil
GAME.SpriteIndex = 1
GAME.FlappyState = 0 -- 0 1 2, upflap midflap lowflap
GAME.FlappyAngle = 45
GAME.FlappyY = 0

-- These values could be modified, but you probably shouldn't.
GAME.FlappyVel = 0
GAME.Gravity = -750
GAME.UpwardsGravity = 300
GAME.Score = nil

GAME.GameEnded = false
GAME.Dead = false
GAME.LastSpace = nil
GAME.LastFlap = nil
GAME.Started = false
GAME.CanStart = nil
GAME.CurrentPlayer = nil

GAME.backgrounds = { 0, 288, 288*2 }
GAME.pipes = {
	{ 800, math.random(225, 450) },
	{ 1000, math.random(225, 450) },
	{ 1200, math.random(225, 450) },
}
GAME.scored = {false, false, false}

-- some helper functions
--- TODO: Remove lazyURLImage, maybe make an URLImage library?
function GAME:QueueDownloadSprite(png)
	flappy_sprites [#flappy_sprites + 1] = { png, surface.LazyURLImage (baseURL .. png) }
end

-- why do i do this to myself
local function Vector2D (x, y)
	return Vector (x, y, 0)
end

-- gets closest pipe to the flappy
function GAME:GetClosestPipe ()
	local bg = flappy_sprites ["pipe_green"]
	local flap = string.format ("yellowbird_%sflap", lookup_flap [self.FlappyState])
	local birdsprite = flappy_sprites [flap]

	if not bg or not birdsprite then
		return nil, nil
	end

	local closest_diff, closest_pipe = 100000, nil
	for i = 1, #self.pipes do
		local pipe = self.pipes [i]

		local realdiff = SCREEN_WIDTH / 2 - pipe[1] - birdsprite.w/2
		local diff = math.abs (realdiff)
		if diff < 150 and diff < closest_diff then
			closest_diff = realdiff
			closest_pipe = i
		end
	end

	return closest_pipe, closest_diff
end

-- if flappy is colliding with the pipe
-- todo: collision library
function GAME:FlappyIsCollidingWithPipe()
	local flap = string.format ("yellowbird_%sflap", lookup_flap [self.FlappyState])

	local bg = flappy_sprites ["pipe_green"]
	local birdsprite = flappy_sprites [flap]
	if bg and birdsprite then
		
		local i = (self:GetClosestPipe())
		if not i then return false end
		local tw, th = birdsprite.w * 1.25, birdsprite.h * 1.25
		local tw2, th2 = birdsprite.w, birdsprite.h

		local bg_pos_x, bg_pos_y = self.pipes [i] [1], self.pipes [i] [2]
		local f_pos_x , f_pos_y  = SCREEN_WIDTH / 2 - tw / 2, SCREEN_HEIGHT / 2 - th / 2 + self.FlappyY

		local pipe_bounds =
		{
			-- bottom
			{
				-- top left
				Vector2D (bg_pos_x, bg_pos_y),
				-- bottom right
				Vector2D (bg_pos_x + bg.w, bg_pos_y + bg.h),
			},
			-- top
			{
				-- top left
				Vector2D (bg_pos_x, bg_pos_y - gap/2),
				-- bottom right
				Vector2D (bg_pos_x + bg.w, bg_pos_y - gap/2 - bg.h),
			}
		}

		local flappy_bounds =
		{
			-- top left
			Vector2D (f_pos_x - tw2 / 2, f_pos_y - th / 2),
			-- top right
			Vector2D (f_pos_x + tw2	 / 2, f_pos_y - th / 2),
			-- bottom left
			Vector2D (f_pos_x - tw2	 / 2, f_pos_y + th / 2),
			-- bottom right
			Vector2D (f_pos_x + tw2 / 2, f_pos_y + th / 2),
		}

		-- bottom pipe
		local bl_touch_bpipe = flappy_bounds [3]:WithinAABox (pipe_bounds [1] [1], pipe_bounds [1] [2])
		local br_touch_bpipe = flappy_bounds [4]:WithinAABox (pipe_bounds [1] [1], pipe_bounds [1] [2])
		local tl_touch_bpipe = flappy_bounds [1]:WithinAABox (pipe_bounds [1] [1], pipe_bounds [1] [2])
		local tr_touch_bpipe = flappy_bounds [2]:WithinAABox (pipe_bounds [1] [1], pipe_bounds [1] [2])

		if tl_touch_bpipe or tr_touch_bpipe
		or bl_touch_bpipe or br_touch_bpipe
		then
			return true 
		end

		-- upper pipe
		local bl_touch_tpipe = flappy_bounds [3]:WithinAABox (pipe_bounds [2] [1], pipe_bounds [2] [2])
		local br_touch_tpipe = flappy_bounds [4]:WithinAABox (pipe_bounds [2] [1], pipe_bounds [2] [2])
		local tl_touch_tpipe = flappy_bounds [1]:WithinAABox (pipe_bounds [2] [1], pipe_bounds [2] [2])
		local tr_touch_tpipe = flappy_bounds [2]:WithinAABox (pipe_bounds [2] [1], pipe_bounds [2] [2])

		if tl_touch_tpipe or tr_touch_tpipe
		or bl_touch_tpipe or br_touch_tpipe
		then
			return true 
		end
		
	end

	return false
end

-- Move chatprint to notifications?
function GAME:Die()
	//LocalPlayer():ChatPrint("Died")
	self.Dead = true
	SOUND.Sounds["hit"].sound:Play()
	timer.Simple(0.15, function()
		SOUND.Sounds["die"].sound:Play()
	end)
	MACHINE:TakeCoins(1)
	self.Attracting = false
end

function GAME:Start()
	-- I don't know how this gets called with
	-- less than one coins, but it works.
	if MACHINE:GetCoins() < 1 then return end 

	self:Reset()
	self.CanStart = 0
	self.Score = 0
	self.Started = true 
	self.Dead = false
	self.GameEnded = false
	self.backgrounds = { 0, 288, 288*2 }
	self.pipes = {
		{ 800, math.random(225, 450) },
		{ 1000, math.random(225, 450) },
		{ 1200, math.random(225, 450) },
	}
	self.scored = {false, false, false}
		self.Attracting = true

	-- Need new sound
	MACHINE:EmitSound("/vo/npc/barney/ba_letsdoit.wav", 50)
end

function GAME:Reset()
	self.FlappyState = 0
	self.FlappyAngle = 45
    self.FlappyW = SCREEN_WIDTH / 2
	self.FlappyY = SCREEN_HEIGHT / 8
	self.FlappyVel = 0
	self.LastSpace = nil 
	self.LastFlap = nil
	self.CanStart = SysTime() + 1.5
	self.Attracting = false
end

-- game logic
function GAME:Init()
	-- download sprites and sounds
	-- todo: use image library
	self:QueueDownloadSprite ("yellowbird-upflap.png")
	self:QueueDownloadSprite ("yellowbird-midflap.png")
	self:QueueDownloadSprite ("yellowbird-downflap.png")
	self:QueueDownloadSprite ("pipe-green.png")
	self:QueueDownloadSprite ('background-day.png')
	for i = 0, 9 do
		self:QueueDownloadSprite (i .. ".png")
	end
	self:QueueDownloadSprite ('message.png')

	--message.png

	local function ld(snd, cb)
		SOUND:LoadFromURL(baseURL_snd .. snd, (snd:gsub ("%.ogg", "")), cb or function() end)
	end

	ld "swoosh.ogg"
	ld "point.ogg"
	ld "hit.ogg"
	ld "die.ogg"

	self.CanStart = 0
	self.Attracting = true
end

-- REQUIRED
-- Called when someone sits in the seat
function GAME:OnStartPlaying(ply)
	if ply == LocalPlayer() then
		self.CurrentPlayer = ply
		self:Reset()
		self.GameEnded = true
		self.Dead = false
		self.Attracting = false
	end
end

-- REQUIRED
-- Called when someone leaves the seat
function GAME:OnStopPlaying(ply)
	if ply == self.CurrentPlayer then
		self.CurrentPlayer = nil
		self.Attracting = true
		self.Dead = false
	end
end

function GAME:IsBeingPlayed()
	return IsValid(self.CurrentPlayer) and MACHINE:GetCoins() > 0
end

function GAME:Update()
	
	local bgsprite = flappy_sprites ["background_day"]
	if bgsprite and self.Attracting then
		for i = 1, #self.backgrounds do
			local bg_pos_x = self.backgrounds [i]
			
			self.backgrounds [i] = self.backgrounds [i] - FrameTime() * 75
			if self.backgrounds [i] < -bgsprite.w then
				self.backgrounds [i] = self.backgrounds [i] + bgsprite.w * 3
			end
		end
	end
	
	-- sprite download routine
	if not self.DownloadedSprites and not self.DownloadingSprites then
		self.DownloadingSprites = true
		self.AmountSprites = #flappy_sprites
	end

	if self.DownloadingSprites then
		local sprite = flappy_sprites [self.SpriteIndex]
		local w, h, img = sprite [2] ()

		if w or h or img then
			local coolName = sprite [1]:gsub ("-", "_"):gsub ("%.png", "")
			flappy_sprites [coolName] = 
			{
				w = w,
				h = h,
				img = img
			}
			flappy_sprites [self.SpriteIndex] = nil
			self.SpriteIndex = self.SpriteIndex + 1
		end

		if self.SpriteIndex > self.AmountSprites then
			self.DownloadingSprites = false
			self.DownloadedSprites = true
			MACHINE:UpdateMarquee()
		end
	end

	if not self:IsBeingPlayed() then return end


	-- pressing space, starting game or making bird flap
	if input.IsKeyDown(KEY_SPACE) then
		-- sending flappy into the air
		if not self.GameEnded and not self.Dead then
			if not self.LastSpace then
				self.LastSpace = 0
				SOUND.Sounds["swoosh"].sound:SetTime(0)
				SOUND.Sounds["swoosh"].sound:Play()
			end

			self.LastSpace = self.LastSpace + 1

			if self.LastSpace < 10 then
				self.FlappyVel = self.UpwardsGravity
				self.FlappyState = 0
			end
		-- game ended, we need to start
		elseif self.GameEnded and not self.Dead and not self.Started then
			if SysTime() > self.CanStart and ((self.LastSpace or 0) < 2) then
				self:Start()
				self.Started = true
			else
				self.LastSpace = nil
				return
			end
		-- we died or game ended somehow
		elseif (self.GameEnded or self.Dead) and self.Started then
			self:Reset()

			self.Started = false
			self.Dead = false
			self.CanStart = SysTime()
		end
	else
		self.LastSpace = nil
	end

	-- dont do any more processing if game not being played
	if self.GameEnded then return end

	-- stop the game if there is no coins
	if MACHINE:GetCoins() <= 0 then
		--self:Reset()
		self:Reset()
		self.GameEnded = true 

		return
	end

	-- check, flappy is on floor or colliding with nearest pipe
	local flap = string.format ("yellowbird_%sflap", lookup_flap [self.FlappyState])
	local sprite = flappy_sprites [flap]
	if (self.FlappyY > SCREEN_HEIGHT / 2) or self:FlappyIsCollidingWithPipe() then
		self.GameEnded = true 
		self:Die()
		return
	end

	-- modify flappy velocity and y value
	self.FlappyVel = self.FlappyVel + self.Gravity * FrameTime()
	self.FlappyY = self.FlappyY - (self.FlappyVel * FrameTime())

	-- controls flappy animation
	if not self.LastFlap then 
		self.LastFlap = SysTime()
	else
		if self.LastFlap + 0.1 < SysTime() then
			if self.FlappyState == 0 then
				self.FlappyState = 1
			elseif self.FlappyState == 1 then 
				self.FlappyState = 2
			else
				self.FlappyState = 0
			end
			self.LastFlap = SysTime()
		end
	end

	-- add score
	local closest_pipe, closest_dist = self:GetClosestPipe()
	if closest_pipe and closest_dist < 100000 then
		if closest_dist > sprite.w and not self.scored[closest_pipe] then
			self.scored[closest_pipe] = true
			self.Score = self.Score + 1
			//self.CurrentPlayer:ChatPrint("Score: " .. self.Score)
		end 
		--epoe.api.print(closest_pipe,closest_dist)
		--epoe.api.print(table.ToString(sprite))
	end

	-- update background position
	
	-- update pipe position
	local pipesprite = flappy_sprites ["pipe_green"]
	if pipesprite then
		for i = 1, #self.pipes do
			local bg_pos_x = self.pipes [i] [1]
			local bg_pos_y = self.pipes [i] [2]
			
			self.pipes [i] [1] = self.pipes [i] [1] - FrameTime() * 100

			if self.pipes [i] [1] < -pipesprite.w then
				self.pipes [i] [1] = self.pipes [i] [1] + 200 * 3
				self.pipes [i] [2] = math.random(225, 450)
				self.scored [i] = false
			end
		end
	end
end

-- pipe marquee
function GAME:DrawMarquee()
	local pipe = flappy_sprites ["pipe_green"]
	if not pipe then return end

	local mw = MARQUEE_WIDTH
	local mh = MARQUEE_HEIGHT

	local numPipes = 12
	local divsize = pipe.w / (mw / numPipes)
	surface.SetDrawColor(60, 255, 60, 255)
	surface.DrawRect(0, 0, mw, mh)

	local e = 0 
	for i = 1, numPipes do
		local a = math.random (1, mh / 4)
		surface.SetMaterial (pipe.img)
		surface.SetDrawColor (255, 255, 255)
		surface.DrawTexturedRect (e, mh / 2 + a, pipe.w /  divsize, pipe.h /  divsize)
		surface.DrawTexturedRectRotated (e + ((pipe.w / divsize) / 2), mh / 2  + a- (55 * divsize / 2), pipe.w /  divsize, pipe.h /  divsize, math.deg (math.rad (180)))
		e = e + pipe.w /  divsize
	end

	draw.NoTexture()
	--surface.SetDrawColor(0, 0, 255, 255)
    --surface.DrawRect(0, 0, MARQUEE_WIDTH, MARQUEE_HEIGHT)

    surface.SetFont("DermaLarge")
    local tw, th = surface.GetTextSize(self.Name)
    surface.SetTextColor(0, 0, 0, 255)
    surface.SetTextPos((mw / 2) - (tw / 2) + 2, (mh / 2) - (th / 2) + 2)
    surface.DrawText(self.Name)
    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos((mw / 2) - (tw / 2), (mh / 2) - (th / 2))
    surface.DrawText(self.Name)
end

function GAME:Draw()
	local w = SCREEN_WIDTH
	local h = SCREEN_HEIGHT
	local draw_score = true

	local function eugh()
		if not self:IsBeingPlayed() then return end

		-- draw pipes
		local pipe = flappy_sprites ["pipe_green"]
		if pipe then
			for i = 1, #self.pipes do
				local bg_pos_x = self.pipes [i] [1]
				local bg_pos_y = self.pipes [i] [2]


				surface.SetMaterial (pipe.img)
				surface.SetDrawColor (255, 255, 255)
				surface.DrawTexturedRect (bg_pos_x, bg_pos_y, pipe.w, pipe.h)
				surface.DrawTexturedRectRotated (bg_pos_x + pipe.w / 2, bg_pos_y - 300, pipe.w, pipe.h, math.deg (math.rad (180)))
				if self.Debug then
					draw.NoTexture()
					surface.SetDrawColor (255, 0, 0)
					surface.DrawRect (bg_pos_x - 5, bg_pos_y - 5, 10, 10)
					surface.DrawRect (bg_pos_x - 5, bg_pos_y - gap / 2 - 5, 10, 10)
				end
			end
		end

		local flap = string.format ("yellowbird_%sflap", lookup_flap [self.FlappyState])
		local birdsprite = flappy_sprites [flap]

		if birdsprite and not (self.GameEnded or self.Dead) then	-- drwas bird
			local tw, th = birdsprite.w * 1.25, birdsprite.h * 1.25
			local x = SCREEN_WIDTH / 2 - tw / 2
			local y = SCREEN_HEIGHT / 2 - th / 2 + self.FlappyY

			if self.Debug then
				draw.NoTexture()
				surface.SetDrawColor (255, 255, 0)
				surface.DrawRect (x - tw/2, y - th/2, tw, th)
			end

			surface.SetMaterial (birdsprite.img)
			surface.SetDrawColor (255, 255, 255)
			surface.DrawTexturedRectRotated(x, y, tw, th, 0)

			if self.Debug then
				draw.NoTexture()
				surface.SetDrawColor (255, 0, 0)
				surface.DrawRect (x - 5, y - 5, 10, 10)
			end
		end

		-- is there sprites being downloaded
		local sprite = flappy_sprites [self.SpriteIndex]
		if sprite and self.DownloadingSprites then
			local text = "Downloading Sprite " .. self.SpriteIndex .. " (" .. sprite[1] .. "/" .. self.AmountSprites .. ")..."
			text = string.upper (text)

			surface.SetFont("DermaLarge")
			surface.SetTextColor(255, 255, 255, 255)
			surface.SetTextPos(10, 10)
			surface.DrawText(text)
		end

		-- dead text
		if self.Dead then
			surface.SetFont("DermaLarge")
			local text = "YOU'RE DEAD"
			local tw,th = surface.GetTextSize(text)

			surface.SetTextColor(255, 0, 0, 255)
			surface.SetTextPos(SCREEN_WIDTH/2 - tw / 2, SCREEN_HEIGHT / 4 - th / 2)
			surface.DrawText(text)
		end

		if draw_score then
			local digits = string.Explode('', tostring(self.Score or 0))
			local total_width = 0
			local single_width
			local total_height
			
			for i = 1, #digits do
				local digit = flappy_sprites[digits[i]]
				if not total_height then
					single_width = digit.w
					total_height = digit.h
				end
				total_width = total_width + digit.w
			end

			local mid = SCREEN_WIDTH / 2 - total_width / 2 
			local height = SCREEN_HEIGHT / 4 - total_height / 2
			
			local ws = mid
			for i = 1, #digits do
				local digit = flappy_sprites[digits[i]]
				
				surface.SetMaterial(digit.img)
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawTexturedRect(ws, height, digit.w, digit.h)
				ws = ws + digit.w
			end
		end
	end

	-- todo: attract screen
    --if not isPlaying then
		if not self.DownloadedSprites then
			surface.SetDrawColor(HSVToColor(RealTime() * 50 % 360, 1, 0.5))
			surface.DrawRect(0, 0, w, h)
			--return
		end
    --end

    -- draw backgrounds
	local bg = flappy_sprites ["background_day"]
	if bg then
		for i = 1, #self.backgrounds do
			local bg_pos_x = self.backgrounds [i]
			surface.SetMaterial (bg.img)
			surface.SetDrawColor (255, 255, 255)
			surface.DrawTexturedRect (bg_pos_x, 0, bg.w, bg.h)
		end
	end

	if self.GameEnded or self.Dead and SysTime() > self.CanStart then
		draw_score = false
	end

	eugh()

	-- insert coin / start text
	if self.GameEnded or self.Dead and SysTime() > self.CanStart then
		surface.SetFont("DermaLarge")
		if MACHINE:GetCoins() >= 1 then 
			local text = "PRESS SPACE TO START"
			local tw, th = surface.GetTextSize(text)

			surface.SetTextColor(255, 255, 255, 255)
			surface.SetTextPos(SCREEN_WIDTH / 2 - tw/2, SCREEN_HEIGHT / 2 - th / 2)
			surface.DrawText(text)
		else
			self.Attracting = true
			local text = "INSERT COIN(S) TO PLAY"
			local tw, th = surface.GetTextSize(text)

			surface.SetTextColor(255, 0, 0, math.sin(RealTime() * 5) * 255)
			surface.SetTextPos((w / 2) - (tw / 2), SCREEN_HEIGHT / 2 + SCREEN_HEIGHT / 4 - th / 2)
			surface.DrawText(text)
		end
	end

	-- little coin label
	surface.SetFont("DermaDefault")
    local tw, th = surface.GetTextSize(MACHINE:GetCoins() .. " COIN(S)")
    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos(10, h - (th * 2))
    surface.DrawText(MACHINE:GetCoins() .. " COIN(S)")

	

end

function GAME:OnCoinsInserted(ply, old, new)
	--print("OnCoinsInserted")
    MACHINE:EmitSound("garrysmod/content_downloaded.wav", 50)
	--print(MACHINE:GetCoins())
	if (new == 1) then
		--self.CurrentPlayer:ChatPrint("Fat")
		self:Reset()
		self.backgrounds = { 0, 288, 288*2 }
		self.pipes = {
			{ 800, math.random(225, 450) },
			{ 1000, math.random(225, 450) },
			{ 1200, math.random(225, 450) },
		}
		self.scored = {false, false, false}
		self.Dead = false
	end
end

function GAME:OnCoinsLost(ply, old, new)
	--print("OnCoinsLost")
	if new < 1 then
		self:Reset()
		self.GameEnded = true
	end
end

--return GAME



--end