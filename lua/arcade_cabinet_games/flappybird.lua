--
-- Flappy Bird for the arcade machine system!
-- Rips assets/sounds from FlapPyBird (thanks sourabhv).
--
-- This file is the "rewrite", excluding
-- useless variables and overall "should be a bit
-- faster."
-- I've also switched over to a state system
-- to make it less complicated.
--
-- TODO:
--   Major bug: Multiple flappybird arcade machines spawning at the same time (ear)rape the client
--   Fix: Lag spikes kill your run
--   Fix: Lag spikes can allow you to bypass the pipe, not giving score.
--   Fix: Full updating kills the game
--   Fix: You can play other people's flappy bird game
--   Fonts
--

-- if SERVER then return end
-- FB = function()

--------------------------------------------------
local function NewBoxCollisionObject()
	return {
		pos = Vector(),
		ang = Angle(),
		collision = {
			type = COLLISION.TYPE_BOX
		}
	}
end

-- To make people happy (im not)
local HCSS = {
	["0"]                   = { ["h"] = 36 , ["w"] = 24 , },
	["1"]                   = { ["h"] = 36 , ["w"] = 16 , },
	["2"]                   = { ["h"] = 36 , ["w"] = 24 , },
	["3"]                   = { ["h"] = 36 , ["w"] = 24 , },
	["4"]                   = { ["h"] = 36 , ["w"] = 24 , },
	["5"]                   = { ["h"] = 36 , ["w"] = 24 , },
	["6"]                   = { ["h"] = 36 , ["w"] = 24 , },
	["7"]                   = { ["h"] = 36 , ["w"] = 24 , },
	["8"]                   = { ["h"] = 36 , ["w"] = 24 , },
	["9"]                   = { ["h"] = 36 , ["w"] = 24 , },
	["background_day"]      = { ["h"] = 512, ["w"] = 288, },
	["pipe_green"]          = { ["h"] = 320, ["w"] = 52 , },
	["yellowbird_upflap"]   = { ["h"] = 24 , ["w"] = 34 , },
	["yellowbird_downflap"] = { ["h"] = 24 , ["w"] = 34 , },
	["yellowbird_midflap"]  = { ["h"] = 24 , ["w"] = 34 , },
}
--------------------------------------------------

local GAME = {}
GAME.Name = "Flappy Bird"
GAME.Author = "twentysix"
GAME.Description = "Avoid the pipes! Use your spacebar to make the bird flap, pushing it up a bit.\nFYI: You can't go over the pipes, so don't even try."
GAME.LateUpdateMarquee = true

--------------------------------------------------
local GAME_STATE_SPRITEDL     = -1
local GAME_STATE_ATTRACT      = 0
local GAME_STATE_WAITCOIN     = 1
local GAME_STATE_DEAD         = 2
local GAME_STATE_STARTING     = 3
local GAME_STATE_PLAYING      = 4

AccessorFunc(GAME, "m_iState", "State")
GAME:SetState(GAME_STATE_SPRITEDL)

-- flag stuff
GAME.Flags = {}

function GAME:SetFlag(flag, value)
	self.Flags[flag] = value
end

function GAME:GetFlag(flag, default)
	if not default then
		default = false
	end

	return self.Flags[flag] or default
end

function GAME:ClearFlag(flag)
	self:SetFlag(flag, nil)
end
--------------------------------------------------

--------------------------------------------------
-- These values could be modified, but you probably shouldn't.
GAME:SetFlag("Gravity", -750)
GAME:SetFlag("UpGravity", 300)
GAME:SetFlag("FlappyVel", GAME:GetFlag("UpGravity"))

GAME:SetFlag("Score", 0)
GAME:SetFlag("LastSpace", SysTime())
GAME:SetFlag("LastFlap", SysTime())
GAME:SetFlag("FlappyState", 0)
GAME:SetFlag("BestScore", tonumber(util.GetPData("FlappyBird", "BestScore", 0)))
GAME:SetFlag("DrawScoreCounter", false)
GAME:SetFlag("BackgroundMoving", false)
GAME:SetFlag("DoReset", true)

GAME.CurrentPlayer = nil
GAME.Backgrounds = {
	0,
	288,
	288 * 2
}
-- since we'll have 3 pipes we have 3 booleans
GAME.ScoredPipes = {
	false,
	false,
	false
}
--------------------------------------------------

--------------------------------------------------
local function GetSound(snd)
	snd = SOUND.Sounds[snd]

	if snd and snd.status == SOUND.STATUS_LOADED then
		return snd.sound
	end

	return nil
end

local function PlaySound(snd)
	snd = GetSound(snd)

	if snd == nil or not IsValid(snd) then return end
	snd:SetTime(0)
	snd:Play()
end
--------------------------------------------------

--------------------------------------------------
local PIPE_GAP = 280
local PIPE_START = 800
local PIPE_INTERVAL = 200
local PIPE_INVIS_BOUNDARY = 10000
local BIRD_WIDTH = HCSS.yellowbird_midflap.w
local BIRD_HEIGHT = HCSS.yellowbird_midflap.h

GAME.Pipes = {}

GAME.TheFlappy = NewBoxCollisionObject()
local FLAPPY = GAME.TheFlappy

FLAPPY.pos = Vector(SCREEN_HEIGHT / 2 - BIRD_WIDTH / 2, SCREEN_HEIGHT / 2 - BIRD_HEIGHT / 2)
FLAPPY.collision.width = BIRD_WIDTH
FLAPPY.collision.height = BIRD_HEIGHT

local function GeneratePipe(xpos)
	local ypos = math.random(0, 250) - 250

	local upper_pipe = NewBoxCollisionObject()
	upper_pipe.pos = Vector(xpos, ypos)
	upper_pipe.collision.width = HCSS.pipe_green.w
	upper_pipe.collision.height = HCSS.pipe_green.h

	local lower_pipe = NewBoxCollisionObject()
	lower_pipe.pos = Vector(xpos, ypos + HCSS.pipe_green.h + PIPE_GAP / 2)
	lower_pipe.collision.width = HCSS.pipe_green.w
	lower_pipe.collision.height = HCSS.pipe_green.h

	local invis_boundary = NewBoxCollisionObject()
	invis_boundary.pos = Vector(xpos, ypos - PIPE_INVIS_BOUNDARY)
	invis_boundary.collision.width = HCSS.pipe_green.w
	invis_boundary.collision.height = PIPE_INVIS_BOUNDARY

	return {
		upper_pipe,
		lower_pipe,
		invis_boundary
	}
end

function GAME:ResetPipes()
	self.Pipes = {
		GeneratePipe(PIPE_START),
		GeneratePipe(PIPE_START + PIPE_INTERVAL),
		GeneratePipe(PIPE_START + PIPE_INTERVAL * 2)
	}
end

function GAME:GetClosestPipe()
	local closest_diff, closest_pipe = 100000, nil

	if not self.Pipes or next(self.Pipes) == nil or #self.Pipes < 1 then
		return closest_pipe, closest_diff
	end

	for i = 1, #self.Pipes do
		local pipe = self.Pipes[i]

		local realdiff = SCREEN_WIDTH / 2 - pipe[1].pos.x - HCSS.yellowbird_midflap.w / 2
		local diff = math.abs(realdiff)

		if diff < 150 and diff < closest_diff then
			closest_diff = realdiff
			closest_pipe = i
		end
	end

	return closest_pipe, closest_diff
end

function GAME:FlappyIsCollidingWithPipe()
	local i = (self:GetClosestPipe())
	if not i then
		return false
	end

	local pipe = self.Pipes[i]
	local up, down, invis = unpack(pipe)
	local pipe_offset = 230

	local colliding_up = false
	local colliding_down = false

	--
	-- On god this code is ugly, and I would rather
	-- not write something like this ever again.
	--
	-- At least it's much better than checking if a vector
	-- is within a box 8 times.
	--
	if up then
		up.pos.y = up.pos.y - pipe_offset

		if
			(COLLISION:BoxCollision(self.TheFlappy, up)
			or COLLISION:BoxCollision(self.TheFlappy, invis))
		and not colliding_up then
			colliding_up = true
		end

		if COLLISION:BoxCollision(self.TheFlappy, invis) and not colliding_up then
			colliding_up = true
		end

		up.pos.y = up.pos.y + pipe_offset
	end

	if down then
		down.pos.y = down.pos.y - pipe_offset

		if COLLISION:BoxCollision(self.TheFlappy, down) and not colliding_down then
			colliding_down = true
		end

		down.pos.y = down.pos.y + pipe_offset
	end

	if colliding_up or colliding_down then
		return true
	end

	return false
end
--------------------------------------------------

local Image_BaseURL = "https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/flappybird/images/"
local Sound_BaseURL = "https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/flappybird/sounds/"

local function InitFlagIfNotExists(flag, val)
	if not GAME.Flags[flag] then
		GAME:SetFlag(flag, val)
	end
end

local function LoadSound(snd, cb)
	SOUND:LoadFromURL(Sound_BaseURL .. snd, snd:gsub("%.ogg", ""), cb or function() end)
end

-- flappy bird specific stuff
function GAME:Reset()
	self:SetFlag("Score", 0)
	self:SetFlag("LastSpace", SysTime())
	self:SetFlag("LastFlap", SysTime())
	self:SetFlag("FlappyState", 0)
	self:SetFlag("FlappyVel", self:GetFlag("UpGravity"))

	self:ResetPipes()
	self.Backgrounds = { 0, 288, 288 * 2 }
	self.ScoredPipes = { false, false, false }

	FLAPPY.pos = Vector(SCREEN_HEIGHT / 2 - BIRD_WIDTH / 2, SCREEN_HEIGHT / 8 - BIRD_HEIGHT / 2)
	FLAPPY.collision.width = BIRD_WIDTH
	FLAPPY.collision.height = BIRD_HEIGHT
end

function GAME:Start()
	self:SetState(GAME_STATE_PLAYING)

	PlaySound("swoosh")

	FLAPPY.pos = Vector(SCREEN_HEIGHT / 2 - BIRD_WIDTH / 2, SCREEN_HEIGHT / 8 - BIRD_HEIGHT / 2)
	FLAPPY.collision.width = BIRD_WIDTH
	FLAPPY.collision.height = BIRD_HEIGHT
end

function GAME:Die()
	self:SetState(GAME_STATE_DEAD)
	self:SetFlag("BackgroundMoving", false)

	local OurScore = self:GetFlag("Score", 0)
	if OurScore > self:GetFlag("BestScore") then
		util.SetPData("FlappyBird", "BestScore", OurScore)
	end

	PlaySound("hit")

	timer.Simple(0.15, function()
		PlaySound("die")
	end)

	COINS:TakeCoins(1)
end

function GAME:MovePipes()
	if self.Pipes and #self.Pipes > 0 then
		for i = 1, #self.Pipes do
			local pipe_obj = self.Pipes[i]
			local up, down, invis = pipe_obj[1], pipe_obj[2], pipe_obj[3]
			up.pos.x = up.pos.x - FrameTime() * 100
			down.pos.x = down.pos.x - FrameTime() * 100
			invis.pos.x = invis.pos.x - FrameTime() * 100
			-- We only need to check the position of one pipe
			-- as we know the pipes are above each other
			if up.pos.x < -up.collision.width then
				up.pos.x = up.pos.x + PIPE_INTERVAL * 3
				down.pos.x = down.pos.x + PIPE_INTERVAL * 3
				invis.pos.x = invis.pos.x + PIPE_INTERVAL * 3
				self.ScoredPipes[i] = false
			end
		end
	end
end

GAME.SpriteQueue = {}
function GAME:Init()
	-- download sprites, sprite data and sounds
	table.insert(self.SpriteQueue, "yellowbird-upflap.png")
	table.insert(self.SpriteQueue, "yellowbird-midflap.png")
	table.insert(self.SpriteQueue, "yellowbird-downflap.png")
	table.insert(self.SpriteQueue, "pipe-green.png")
	table.insert(self.SpriteQueue, "background-day.png")

	for i = 0, 9 do
		table.insert(self.SpriteQueue, i .. ".png")
	end
	table.insert(self.SpriteQueue, "logo.png")

	LoadSound("swoosh.ogg", function(snd) snd:SetVolume(0.65) end)
	LoadSound("point.ogg", function(snd) snd:SetVolume(0.65) end)
	LoadSound("hit.ogg")
	LoadSound("die.ogg")
end

function GAME:Update()
	local bgsprite = IMAGE.Images["background_day"]
	if bgsprite and bgsprite.status == IMAGE.STATUS_LOADED and self:GetFlag("BackgroundMoving", false) then
		for i = 1, #self.Backgrounds do
			local _bg = HCSS.background_day
			self.Backgrounds[i] = self.Backgrounds[i] - FrameTime() * 75

			if self.Backgrounds[i] < -_bg.w then
				self.Backgrounds[i] = self.Backgrounds[i] + _bg.w * 3
			end
		end
	end

	-- we're downloading sprites
	if self:GetState() == GAME_STATE_SPRITEDL then
		InitFlagIfNotExists("DoneDownloadingSprites", false)
		InitFlagIfNotExists("AmountOfSprites", #self.SpriteQueue)
		InitFlagIfNotExists("SpriteIndex", 1)
		InitFlagIfNotExists("ProcessingSprite", false)

		local sprite = self.SpriteQueue[self:GetFlag("SpriteIndex")]
		local cool_name = sprite:gsub("-", "_"):gsub("%.png", "")

		if not self:GetFlag("ProcessingSprite") then
			self:SetFlag("ProcessingSprite", true)

			IMAGE:LoadFromURL(Image_BaseURL .. sprite, cool_name)
		else
			local image = IMAGE.Images[cool_name]

			if image and istable(image) and image.status == IMAGE.STATUS_LOADED then
				self:SetFlag("ProcessingSprite", false)
				self:SetFlag("SpriteIndex", self:GetFlag("SpriteIndex") + 1)

				if self:GetFlag("SpriteIndex") > self:GetFlag("AmountOfSprites") then
					self:SetState(GAME_STATE_ATTRACT)
					self:ResetPipes()
					CABINET:UpdateMarquee()
				end
			end
			-- dont do anything if the image hasn't loaded
		end

	-- attracting players
	elseif self:GetState() == GAME_STATE_ATTRACT then
		self:SetFlag("BackgroundMoving", true)
		self:MovePipes()

	-- waiting for coins
	elseif self:GetState() == GAME_STATE_WAITCOIN then
		self:SetFlag("BackgroundMoving", true)
		self:MovePipes()
		if COINS:GetCoins() > 0 and IsValid(self.CurrentPlayer) then
			self:SetState(GAME_STATE_STARTING)
		end

	-- we're dead
	elseif self:GetState() == GAME_STATE_DEAD then
		InitFlagIfNotExists("WhenNextStart", SysTime() + 1)
		self:SetFlag("BackgroundMoving", false)

		if input.IsKeyDown(KEY_SPACE) and SysTime() > self:GetFlag("WhenNextStart") then
			self:SetState(GAME_STATE_STARTING)
			self:ClearFlag("WhenNextStart")
			self:Reset()
		end

	-- we're about to start the game
	elseif self:GetState() == GAME_STATE_STARTING then
		InitFlagIfNotExists("WhenNextStart", SysTime() + 1)
		self:SetFlag("BackgroundMoving", false)

		if input.IsKeyDown(KEY_SPACE) and SysTime() > self:GetFlag("WhenNextStart") then
			self:Start()
		end

	-- we're playing, do game logic here
	elseif self:GetState() == GAME_STATE_PLAYING then
		self:SetFlag("BackgroundMoving", true)

		if (FLAPPY.pos.y > SCREEN_HEIGHT / 2) or self:FlappyIsCollidingWithPipe() then
			self:Die()
		end

		-- modify flappy velocity and y value
		self:SetFlag("FlappyVel", self:GetFlag("FlappyVel") + self:GetFlag("Gravity") * FrameTime())
		FLAPPY.pos.y = FLAPPY.pos.y - (self:GetFlag("FlappyVel") * FrameTime())

		-- pipe moving routine
		self:MovePipes()

		if input.IsKeyDown(KEY_SPACE) then
			-- sending flappy into the air
			if not self:GetFlag("LastSpace") then
				self:SetFlag("LastSpace", 0)

				PlaySound("swoosh")
			end

			self:SetFlag("LastSpace", self:GetFlag("LastSpace") + 1)

			if self:GetFlag("LastSpace") < 10 then
				self:SetFlag("FlappyVel", self:GetFlag("UpGravity"))
				self:SetFlag("FlappyState", 0)
			end
		else
			self:ClearFlag("LastSpace")
		end

		if not self:GetFlag("LastFlap") then
			self:SetFlag("LastFlap", SysTime())
		else
			if self:GetFlag("LastFlap") + 0.1 < SysTime() then
				if self:GetFlag("FlappyState") ==  0 then
					self:SetFlag("FlappyState", 1)
				elseif self:GetFlag("FlappyState") ==  1 then
					self:SetFlag("FlappyState", 2)
				else
					self:SetFlag("FlappyState", 0)
				end

				self:SetFlag("LastFlap", SysTime())
			end
		end

		local closest_pipe, closest_dist = self:GetClosestPipe()
		if closest_pipe and closest_dist < 100000 and closest_dist > FLAPPY.collision.width and not self.ScoredPipes[closest_pipe] then
			self.ScoredPipes[closest_pipe] = true
			self:SetFlag("Score", self:GetFlag("Score") + 1)

			PlaySound("point")

			if self:GetFlag("Score") > self:GetFlag("BestScore") then
				self:SetFlag("BestScore", self:GetFlag("Score"))
			end
		end

	end
end

function GAME:OnStartPlaying(ply)
	if ply == LocalPlayer() then
		self.CurrentPlayer = ply
		self:SetState(GAME_STATE_WAITCOIN)
	end
end

function GAME:OnStopPlaying(ply)
	if ply == LocalPlayer() then
		self.CurrentPlayer = nil
		self:SetState(GAME_STATE_ATTRACT)
	end
end

function GAME:OnCoinsInserted(ply, old, new)
	-- print(ply,self.CurrentPlayer,LocalPlayer())
	if ply ~= LocalPlayer() then return end

	if new > 0 and self:GetState() == GAME_STATE_WAITCOIN then
		self:Reset()
		self:SetState(GAME_STATE_STARTING)
	end
end

function GAME:OnCoinsLost(ply, old, new)
	-- print(ply,self.CurrentPlayer,LocalPlayer())
	if ply ~= LocalPlayer() then return end

	if new < 1 then
		self:SetState(GAME_STATE_WAITCOIN)
	end
end

function GAME:DrawMarquee()
	local bg = IMAGE.Images["background_day"]
	if not bg or bg.status ~= IMAGE.STATUS_LOADED then return end

	local bg_data = HCSS.background_day

	local mw = MARQUEE_WIDTH
	local mh = MARQUEE_HEIGHT

	local num = 3
	local multw = mw / bg_data.w

	local perw = bg_data.w / (multw * .9)
	local perh = bg_data.w / (multw * .9)

	surface.SetMaterial(bg.mat)
	surface.SetDrawColor(255, 255, 255)

	local xo = 0
	for i = 1, num do
		surface.DrawTexturedRect(xo, 0, perw, perh)
		xo = xo + perw
	end

	draw.NoTexture()

	local fb = IMAGE.Images["logo"] -- 840x263
	if fb and fb.status == IMAGE.STATUS_LOADED then
		local bg_pos_x = mw / 2
		local bg_pos_y = mh / 2
		local _bgw = 840 / 2
		local _bgh = 263 / 2
		bg_pos_x = bg_pos_x - _bgw / 2
		bg_pos_y = bg_pos_y - _bgh / 2
		surface.SetMaterial(fb.mat)
		surface.SetDrawColor(255, 255, 255)
		surface.DrawTexturedRect(bg_pos_x, bg_pos_y, _bgw, _bgh)
	end
end

function GAME:DrawPipes(w, h)
	-- draw pipes
	local pipe = IMAGE.Images["pipe_green"]
	if pipe and pipe.status == IMAGE.STATUS_LOADED and self.Pipes and #self.Pipes > 0 then
		for i = 1, #self.Pipes do
			local pipe_obj = self.Pipes[i]
			local _, up = pipe_obj[1], pipe_obj[2]

			surface.SetDrawColor(255, 255, 255)
			surface.SetMaterial(pipe.mat)
			surface.DrawTexturedRect(up.pos.x, up.pos.y, up.collision.width, up.collision.height)
			surface.DrawTexturedRectRotated(up.pos.x + up.collision.width / 2, up.pos.y - (PIPE_GAP + 20), up.collision.width, up.collision.height, math.deg(math.rad(180)))
		end
	end
end

function GAME:DrawScore(w, h, isDead)
	if isDead == nil then
		isDead = false
	end

	local digits = string.Explode('', tostring(self:GetFlag("Score", 0)))
	local total_width = 0
	local single_width
	local total_height

	for i = 1, #digits do
		local digit = HCSS[digits[i]]

		if not total_height then
			single_width = digit.w
			total_height = digit.h
		end

		total_width = total_width + digit.w
	end

	local mid = SCREEN_WIDTH / 2 - total_width / 2
	local height = (not isDead and SCREEN_HEIGHT / 4 or SCREEN_HEIGHT / 2) - total_height / 2
	local ws = mid
	for i = 1, #digits do
		local digit = IMAGE.Images[digits[i]]
		surface.SetMaterial(digit.mat)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(ws, height, single_width, total_height)
		ws = ws + single_width
	end
end

local FlappyBirdSpriteLookup = {
	[0] = "up",
	[1] = "mid",
	[2] = "down"
}
function GAME:DrawFlappy(w, h)
	local flap = string.format("yellowbird_%sflap", FlappyBirdSpriteLookup[self:GetFlag("FlappyState")])
	local birdsprite = IMAGE.Images[flap]
	-- print(birdsprite)

	--- I'm leaving this in here :)
	-- drwas bird
	if birdsprite and birdsprite.status == IMAGE.STATUS_LOADED and not (self.GameEnded or self.Dead) then
		local bird = self.TheFlappy
		local tw, th = bird.collision.width * 1.25, bird.collision.height * 1.25
		local x = SCREEN_WIDTH / 2
		local y = SCREEN_HEIGHT / 2 - th / 2 + bird.pos.y

		surface.SetMaterial(birdsprite.mat)
		surface.SetDrawColor(255, 255, 255)
		surface.DrawTexturedRectRotated(x, y, tw, th, 0)
	end
end

local draw_logo_states = {
	[GAME_STATE_ATTRACT] = true,
	[GAME_STATE_WAITCOIN] = true
}
function GAME:DrawLogoOnScreen()
	local fb = IMAGE.Images["logo"] -- 840x263
	if fb and fb.status == IMAGE.STATUS_LOADED and draw_logo_states[self:GetState()] then
		local bg_pos_x = SCREEN_WIDTH / 2
		local bg_pos_y = SCREEN_HEIGHT / 4
		local _bgw = 840 / 3
		local _bgh = 263 / 3
		bg_pos_x = bg_pos_x - _bgw / 2
		bg_pos_y = bg_pos_y - _bgh / 2
		surface.SetMaterial(fb.mat)
		surface.SetDrawColor(255, 255, 255)
		surface.DrawTexturedRect(bg_pos_x, bg_pos_y, _bgw, _bgh)
	end
end
function GAME:Draw()
	local w = SCREEN_WIDTH
	local h = SCREEN_HEIGHT

	-- we draw background first
	local bg = IMAGE.Images["background_day"]
	if bg and bg.status == IMAGE.STATUS_LOADED then
		for i = 1, #self.Backgrounds do
			local bg_pos_x = self.Backgrounds[i]
			local _bgw = HCSS.background_day.w
			local _bgh = HCSS.background_day.h
			surface.SetMaterial(bg.mat)
			surface.SetDrawColor(255, 255, 255)
			surface.DrawTexturedRect(bg_pos_x, 0, _bgw, _bgh)
		end
	end



	-- we're downloading sprites
	if self:GetState() == GAME_STATE_SPRITEDL then
		local perc = self:GetFlag("SpriteIndex", 1) / self:GetFlag("AmountOfSprites", 1)

		surface.SetDrawColor(HSVToColor(RealTime() * 50 % 360, 1, 0.5))
		surface.DrawRect(0, 0, w - w * perc, h)
	-- attracting players
	elseif self:GetState() == GAME_STATE_ATTRACT then
		self:DrawPipes(w, h)
		self:DrawLogoOnScreen()
		--print("Attracting...")
	-- waiting for coins
	elseif self:GetState() == GAME_STATE_WAITCOIN then
		self:DrawPipes(w, h)
		self:DrawLogoOnScreen()

		surface.SetFont("DermaLarge")

		local text = "INSERT COINS"
		local tw, th = surface.GetTextSize(text)
		surface.SetTextColor(255, 255, math.sin(CurTime() * 5) * 255, 255)
		surface.SetTextPos(SCREEN_WIDTH / 2 - tw / 2, SCREEN_HEIGHT / 2 - th / 2)
		surface.DrawText(text)

		text = "TO PLAY"
		tw, th = surface.GetTextSize(text)
		surface.SetTextColor(255, 255, math.sin(CurTime() * 5) * 255, 255)
		surface.SetTextPos(SCREEN_WIDTH / 2 - tw / 2, SCREEN_HEIGHT / 2 - th / 2 + th)
		surface.DrawText(text)
	-- we're dead
	elseif self:GetState() == GAME_STATE_DEAD then
		self:DrawPipes(w, h)
		self:DrawScore(w, h, true)

		surface.SetFont("DermaLarge")

		local text = "YOU'RE DEAD"
		local tw, th = surface.GetTextSize(text)
		surface.SetTextColor(255, 0, 0, 255)
		surface.SetTextPos(SCREEN_WIDTH / 2 - tw / 2, SCREEN_HEIGHT / 8 - th / 2)
		surface.DrawText(text)

		text = "PRESS SPACE TO RESET"
		local y = SCREEN_HEIGHT / 2 + SCREEN_HEIGHT / 4 - th / 2
		tw, _ = surface.GetTextSize(text)
		surface.SetTextColor(255, 255, 255, 255)
		surface.SetTextPos(SCREEN_WIDTH / 2 - tw / 2, y)
		surface.DrawText(text)

	-- we're about to start the game
	elseif self:GetState() == GAME_STATE_STARTING then
		surface.SetFont("DermaLarge")

		local text = "PRESS SPACE TO START"
		local tw, th = surface.GetTextSize(text)
		local y = SCREEN_HEIGHT / 2 - SCREEN_HEIGHT / 4 - th / 2
		surface.SetTextColor(255, 255, 255, 255)
		surface.SetTextPos(SCREEN_WIDTH / 2 - tw / 2, y)
		surface.DrawText(text)
		self:DrawFlappy(w, y)

	-- we're playing, do game logic here
	elseif self:GetState() == GAME_STATE_PLAYING then
		self:DrawPipes(w, h)
		self:DrawFlappy(w, h)
		self:DrawScore(w, h, false)

	end

	surface.SetFont("TargetID")
	local t = COINS:GetCoins() .. " COIN(S)"
	local tw, th = surface.GetTextSize(t)
	surface.SetTextColor(255, 255, 255, 255)
	surface.SetTextPos(10, h - th - 10)
	surface.DrawText(t)

	-- best score
	t = "BEST SCORE: " .. self:GetFlag("BestScore", 0)
	tw = surface.GetTextSize(t)
	surface.SetTextColor(255, 255, 255, 255)
	surface.SetTextPos(SCREEN_HEIGHT - tw - 10, 10)
	surface.DrawText(t)
end

--------------------------------------------------

return GAME




-- end 