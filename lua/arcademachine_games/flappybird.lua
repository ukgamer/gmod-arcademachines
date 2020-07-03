--
-- Flappy Bird for the arcade machine system!
-- Rips assets/sounds from FlapPyBird (thanks sourabhv).
--
-- This file is the "rewrite", excluding
-- useless variables and overall "should be a bit
-- faster."
--
-- TODO:
--   Fix: Lag spikes kill your run
--   Fix: Lag spikes can allow you to bypass the pipe, not giving score.
--   Fonts
--

--
--- I don't know why this is here and I don't understand
--- my own comment.
-- we cache sprites globally so if the machine is updated
-- it can access the pipe sprite for marquee
--
--- I'll at least localize it...
--
local flappy_sprites = {}

--- developing
-- FB = function()
local gap = 280
local startpos = 800
local pipe_interval = 200
local baseURL = "https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/flappybird/images/"
local baseURL_snd = "https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/flappybird/sounds/"

local lookup_flap = {
	[0] = "up",
	[1] = "mid",
	[2] = "down"
}

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
GAME.DrawScore = false
GAME.GameEnded = false
GAME.Dead = false
GAME.LastSpace = nil
GAME.LastFlap = nil
GAME.Started = false
GAME.CanStart = nil
GAME.CurrentPlayer = nil
-- Default settings for the game to be cool
GAME.backgrounds = {0, 288, 288 * 2}
GAME.scored = {false, false, false}

-- I was mad when making this.
local HardCodedSpriteShit = 
{
	["4"] = {
		["h"] = 36,
		["w"] = 24,
	},
	["pipe_green"] = {
		["h"] = 320,
		["w"] = 52,
	},
	["1"] = {
		["h"] = 36,
		["w"] = 16,
	},
	["5"] = {
		["h"] = 36,
		["w"] = 24,
	},
	["9"] = {
		["h"] = 36,
		["w"] = 24,
	},
	["6"] = {
		["h"] = 36,
		["w"] = 24,
	},
	["yellowbird_upflap"] = {
		["h"] = 24,
		["w"] = 34,
	},
	["8"] = {
		["h"] = 36,
		["w"] = 24,
	},
	["background_day"] = {
		["h"] = 512,
		["w"] = 288,
	},
	["3"] = {
		["h"] = 36,
		["w"] = 24,
	},
	["7"] = {
		["h"] = 36,
		["w"] = 24,
	},
	["2"] = {
		["h"] = 36,
		["w"] = 24,
	},
	["yellowbird_downflap"] = {
		["h"] = 24,
		["w"] = 34,
	},
	["yellowbird_midflap"] = {
		["h"] = 24,
		["w"] = 34,
	},
	["0"] = {
		["h"] = 36,
		["w"] = 24,
	}
}

local biggy = HardCodedSpriteShit.yellowbird_midflap.w
local biggh = HardCodedSpriteShit.yellowbird_midflap.h
GAME.TheFlappy = 
{
	pos = Vector(SCREEN_HEIGHT / 2 - biggy / 2, SCREEN_HEIGHT / 8 - biggh / 2),
	collision = {
		type = COLLISION.types.BOX, -- see types above
		width = biggy, -- if COLLISION_TYPE_BOX
		height = biggh, -- if COLLISION_TYPE_BOX
	}
}

GAME.pipes = {}
local INVIS_BOUNDARY = 10000
local function GenPipe(x)
	local y = math.random(0, 250) - 250
	return
	{
		{
			pos = Vector (x, y),
			ang = Angle(),
			collision = {
				type = COLLISION.types.BOX,
				width = HardCodedSpriteShit.pipe_green.w,
				height = HardCodedSpriteShit.pipe_green.h
			}
		},
		{
			pos = Vector (x, y + HardCodedSpriteShit.pipe_green.h + gap / 2),
			ang = Angle(),
			collision = {
				type = COLLISION.types.BOX,
				width = HardCodedSpriteShit.pipe_green.w,
				height = HardCodedSpriteShit.pipe_green.h
			}
		},
		{
			pos = Vector (x, y - INVIS_BOUNDARY),
			ang = Angle(),
			collision = {
				type = COLLISION.types.BOX,
				width = HardCodedSpriteShit.pipe_green.w,
				height = INVIS_BOUNDARY
			}
		},
		
	}
end
local function ResetPipes(_game)
	_game.pipes = {
		GenPipe(startpos),
		GenPipe(startpos + pipe_interval),
		GenPipe(startpos + pipe_interval * 2)
	}
end

ResetPipes(GAME)

local DEFAULT_STATION
sound.PlayFile("sound/ui/hint.wav", "noblock", function(snd)
	if not snd then return end
	DEFAULT_STATION = snd
end)

local function GetSound(snd)
	snd = SOUND.Sounds[snd]

	--local ply = GAME.CurrentPlayer or LocalPlayer()

	if snd and snd.status == SOUND.STATUS_LOADED then
		--snd.sound:SetPos(ply:GetPos() or Vector())
		return snd.sound
	end

	--DEFAULT_STATION:SetPos(ply:GetPos() or Vector())
	return DEFAULT_STATION
end

-- some helper functions
function GAME:QueueDownloadSprite(png)
	flappy_sprites[#flappy_sprites + 1] = {png}
end

-- gets closest pipe to the flappy
function GAME:GetClosestPipe()
	local closest_diff, closest_pipe = 100000, nil

	if not self.pipes or next(self.pipes) == nil or #self.pipes < 1 then
		return closest_pipe, closest_diff
	end

	for i = 1, #self.pipes do
		local pipe = self.pipes[i]
		local realdiff = SCREEN_WIDTH / 2 - pipe[1].pos.x - HardCodedSpriteShit.yellowbird_midflap.w / 2
		local diff = math.abs(realdiff)

		if diff < 150 and diff < closest_diff then
			closest_diff = realdiff
			closest_pipe = i
		end
	end

	return closest_pipe, closest_diff
end

-- if flappy is colliding with the pipe
function GAME:FlappyIsCollidingWithPipe()
	local i = (self:GetClosestPipe())
	if not i then
		return false
	end

	local pipe = self.pipes[i]
	local up, down = pipe[1], pipe[2]
	local invis = pipe[3]
	local FAT = 230

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
		up.pos.y = up.pos.y - FAT
		if COLLISION:BoxCollision(self.TheFlappy, up) and not colliding_up then
			colliding_up = true
		end
		if COLLISION:BoxCollision(self.TheFlappy, invis) and not colliding_up then
			colliding_up = true
		end
		up.pos.y = up.pos.y + FAT
	end

	if down then
		down.pos.y = down.pos.y - FAT
		if COLLISION:BoxCollision(self.TheFlappy, down) and not colliding_down then
			colliding_down = true
		end
		down.pos.y = down.pos.y + FAT
	end

	if colliding_up or colliding_down then
		return true
	end

	return false
end

-- TODO: Move chatprint to notifications?
GAME.OldScore = tonumber(util.GetPData("FlappyBird", "BestScore", 0))
function GAME:Die()
	self.Dead = true
	self.DrawScore = true
	
	util.SetPData("FlappyBird", "BestScore", self.OldScore)
	GetSound("hit"):Play()

	timer.Simple(0.15, function()
		GetSound("die"):Play()
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
	self.backgrounds = {0, 288, 288 * 2}
	ResetPipes(self)
	self.scored = {false, false, false}
	self.Attracting = true
	self.DrawScore = true
	
	-- Need new sound
	MACHINE:EmitSound("/vo/npc/barney/ba_letsdoit.wav", 50)
end

function GAME:Reset()
	self.FlappyState = 0
	-- self.FlappyAngle = 45
	self.TheFlappy.pos =  Vector(SCREEN_HEIGHT / 2 - biggy / 2, SCREEN_HEIGHT / 8 - biggh / 2)
	self.FlappyVel = 0
	self.LastSpace = nil
	self.LastFlap = nil
	self.CanStart = SysTime() + 1.5
	self.Attracting = false
	self.DrawScore = false
	self.pipes = {}
end

-- game logic
function GAME:Init()
	-- download sprites, sprite data and sounds
	self:QueueDownloadSprite("yellowbird-upflap.png")
	self:QueueDownloadSprite("yellowbird-midflap.png")
	self:QueueDownloadSprite("yellowbird-downflap.png")
	self:QueueDownloadSprite("pipe-green.png")
	self:QueueDownloadSprite('background-day.png')

	for i = 0, 9 do
		self:QueueDownloadSprite(i .. ".png")
	end

	local function ld(snd, cb)
		SOUND:LoadFromURL(baseURL_snd .. snd, (snd:gsub("%.ogg", "")), cb or function() end)
	end

	ld("swoosh.ogg", function(snd) snd:SetVolume(0.65) end)
	ld("point.ogg", function(snd) snd:SetVolume(0.65) end)
	ld("hit.ogg")
	ld("die.ogg")

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

local processing = false
function GAME:Update()
	local bgsprite = IMAGE.Images["background_day"]

	if bgsprite and bgsprite.status == IMAGE.STATUS_LOADED and self.Attracting then
		for i = 1, #self.backgrounds do
			local bg_pos_x = self.backgrounds[i]
			local _bg = HardCodedSpriteShit.background_day
			self.backgrounds[i] = self.backgrounds[i] - FrameTime() * 75

			if self.backgrounds[i] < -_bg.w then
				self.backgrounds[i] = self.backgrounds[i] + _bg.w * 3
			end
		end
	end

	-- sprite download routine
	if not self.DownloadedSprites and not self.DownloadingSprites then
		self.DownloadingSprites = true
		self.AmountSprites = table.Count(flappy_sprites)
	end

	if self.DownloadingSprites then
		local sprite = flappy_sprites[self.SpriteIndex]
		local coolName = sprite[1]:gsub("-", "_"):gsub("%.png", "")

		if not processing then
			IMAGE:LoadFromURL(baseURL .. sprite[1], coolName)
			processing = true
		else
			local _i = IMAGE.Images[coolName]
			if _i and next(_i) ~= nil and _i.status == IMAGE.STATUS_LOADED then
				processing = false
				flappy_sprites[self.SpriteIndex] = nil
				self.SpriteIndex = self.SpriteIndex + 1
				if _i.status == 2 then
					error("processing " .. sprite[1] .. " failed")
				end
			end
		end

		if self.SpriteIndex > self.AmountSprites then
			self.DownloadingSprites = false
			self.DownloadedSprites = true
			MACHINE:UpdateMarquee()
		end
	end

	if not self:IsBeingPlayed() or not self.DownloadedSprites then return end

	-- pressing space, starting game or making bird flap
	if input.IsKeyDown(KEY_SPACE) then
		-- sending flappy into the air
		if not self.GameEnded and not self.Dead then
			if not self.LastSpace then
				self.LastSpace = 0

				local swoosh = GetSound("swoosh")
				swoosh:SetTime(0)
				swoosh:Play()
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
			if SysTime() > self.CanStart and ((self.LastSpace or 0) < 2) then
				self:Reset()
				self.Started = false
				self.Dead = false
				self.CanStart = SysTime() + 1.5
			else
				self.LastSpace = nil

				return
			end
		end
	else
		self.LastSpace = nil
	end

	-- dont do any more processing if game not being played
	if self.GameEnded then return end

	-- stop the game if there is no coins
	if MACHINE:GetCoins() <= 0 then
		self:Reset()
		self.GameEnded = true

		return
	end

	-- check, flappy is on floor or colliding with nearest pipe
	local FLAPPY = self.TheFlappy
	if (FLAPPY.pos.y > SCREEN_HEIGHT / 2) or self:FlappyIsCollidingWithPipe() then
		self.GameEnded = true
		self:Die()
		self.CanStart = SysTime() + 1.5

		return
	end

	-- modify flappy velocity and y value
	self.FlappyVel = self.FlappyVel + self.Gravity * FrameTime()
	FLAPPY.pos.y = FLAPPY.pos.y - (self.FlappyVel * FrameTime())

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
		if closest_dist > FLAPPY.collision.width and not self.scored[closest_pipe] then
			self.scored[closest_pipe] = true
			self.Score = self.Score + 1
			
			local point = GetSound("point")
			point:SetTime(0)
			point:Play()

			
			if self.Score > self.OldScore then
				self.OldScore = self.Score
			end
		end
	end

	--update pipe position
	if self.pipes and #self.pipes > 0 then
		for i = 1, #self.pipes do
			local pipe_obj = self.pipes[i]
			local up, down, invis = pipe_obj[1], pipe_obj[2], pipe_obj[3]

			up.pos.x = up.pos.x - FrameTime() * 100
			down.pos.x = down.pos.x - FrameTime() * 100
			invis.pos.x = invis.pos.x - FrameTime() * 100

			-- We only need to check the position of one pipe
			-- as we know the pipes are above each other
			if up.pos.x < -up.collision.width then
				up.pos.x = up.pos.x + pipe_interval * 3
				down.pos.x = down.pos.x + pipe_interval * 3
				invis.pos.x = invis.pos.x - FrameTime() * 100

				self.scored[i] = false
			end
		end
	end
end

-- pipe marquee
function GAME:DrawMarquee()
	if not self.DownloadedSprites then return end
	local pipe = IMAGE.Images["background_day"]
	if pipe.status ~= IMAGE.STATUS_LOADED then return end

	local pipe_data = HardCodedSpriteShit.background_day

	local mw = MARQUEE_WIDTH
	local mh = MARQUEE_HEIGHT

	local num = 3
	local multw = mw / pipe_data.w
	local multh = mh / pipe_data.h

	local perw = pipe_data.w / (multw * num)
	local perh = pipe_data.w / (multw * num)
	
	--print(mw,mh)
	--PrintTable(pipe_data)


	surface.SetMaterial(pipe.mat)
	surface.SetDrawColor(255, 255, 255)

	local xo = 0
	for i = 1, num do
		surface.DrawTexturedRect(xo, 0, perw, perh)
		xo = xo + perw
	end

	draw.NoTexture()

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
	--self.DrawScore = true

	-- i just had this function here for ease, it returns
	-- inside this function and not the whole draw function
	local function DoMainDrawFunc()
		if not self:IsBeingPlayed() then return end

		-- draw pipes
		local pipe = IMAGE.Images["pipe_green"]
		if pipe and pipe.status == IMAGE.STATUS_LOADED and self.pipes and #self.pipes > 0 then
			for i = 1, #self.pipes do
				local pipe_obj = self.pipes[i]
				local low, up = pipe_obj[1], pipe_obj[2]
				
				surface.SetDrawColor(255, 255, 255)
				surface.SetMaterial(pipe.mat)

				surface.DrawTexturedRect(up.pos.x, up.pos.y, up.collision.width, up.collision.height)
				surface.DrawTexturedRectRotated(up.pos.x + up.collision.width / 2, up.pos.y - (gap + 20), up.collision.width, up.collision.height, math.deg(math.rad(180)))
			end
		end

		local flap = string.format("yellowbird_%sflap", lookup_flap[self.FlappyState])
		local birdsprite = IMAGE.Images[flap]

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

		-- is there sprites being downloaded?
		local sprite = flappy_sprites[self.SpriteIndex]
		if sprite and self.DownloadingSprites then
			local text = "Downloading Sprite " .. self.SpriteIndex .. " (" .. sprite[1] .. "/" .. self.AmountSprites .. ")..."
			text = string.upper(text)
			surface.SetFont("DermaLarge")
			surface.SetTextColor(255, 255, 255, 255)
			surface.SetTextPos(10, 10)
			surface.DrawText(text)
		end

		-- dead text
		if self.Dead then
			surface.SetFont("DermaLarge")
			local text = "YOU'RE DEAD"
			local tw, th = surface.GetTextSize(text)
			surface.SetTextColor(255, 0, 0, 255)
			surface.SetTextPos(SCREEN_WIDTH / 2 - tw / 2, SCREEN_HEIGHT / 8 - th / 2)
			surface.DrawText(text)
		end

		--if self.GameEnded and self.Dead and not self.Started then
		--	self.DrawScore = true
		--end

		if self.DrawScore then
			local digits = string.Explode('', tostring(self.Score or 0))
			local total_width = 0
			local single_width
			local total_height

			for i = 1, #digits do
				local digit = HardCodedSpriteShit[digits[i]]

				if not total_height then
					single_width = digit.w
					total_height = digit.h
				end

				total_width = total_width + digit.w
			end

			local _ = (self.GameEnded or self.Dead)
			local mid = SCREEN_WIDTH / 2 - total_width / 2
			local height = (not _ and SCREEN_HEIGHT / 4 or SCREEN_HEIGHT / 2) - total_height / 2
			local ws = mid

			for i = 1, #digits do
				local digit = IMAGE.Images[digits[i]]
				surface.SetMaterial(digit.mat)
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawTexturedRect(ws, height, single_width, total_height)
				ws = ws + single_width
			end
		end
	end

	if not self.DownloadedSprites then
		surface.SetDrawColor(HSVToColor(RealTime() * 50 % 360, 1, 0.5))
		surface.DrawRect(0, 0, w, h)
	end

	-- draw backgrounds
	local bg = IMAGE.Images["background_day"]
	if bg and bg.status == IMAGE.STATUS_LOADED then
		for i = 1, #self.backgrounds do
			local bg_pos_x = self.backgrounds[i]
			local _bgw = HardCodedSpriteShit.background_day.w
			local _bgh = HardCodedSpriteShit.background_day.h
			surface.SetMaterial(bg.mat)
			surface.SetDrawColor(255, 255, 255)
			surface.DrawTexturedRect(bg_pos_x, 0, _bgw, _bgh)
		end
	end

	--if self.GameEnded or self.Dead and SysTime() > self.CanStart then
	--	self.DrawScore = false
	--end

	-- we call the main draw function here so we dont screw with everything
	DoMainDrawFunc()

	-- insert coin / start text
	if self.GameEnded or self.Dead and SysTime() > self.CanStart then
		surface.SetFont("DermaLarge")

		if MACHINE:GetCoins() >= 1 then
			local text = "PRESS SPACE TO START"
			local h
			if self.GameEnded and not self.Dead  then
				h = SCREEN_HEIGHT / 2 - th / 2
			else
				h = SCREEN_HEIGHT / 2 + SCREEN_HEIGHT / 4 - th / 2
				text = "PRESS SPACE TO RESET"
			end
			local tw, th = surface.GetTextSize(text)
			surface.SetTextColor(255, 255, 255, 255)
			surface.SetTextPos(SCREEN_WIDTH / 2 - tw / 2, h)
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
	surface.SetFont("TargetID")
	local t = MACHINE:GetCoins() .. " COIN(S)"
	local tw, th = surface.GetTextSize(t)
	surface.SetTextColor(255, 255, 255, 255)
	surface.SetTextPos(10, h - th - 10)
	surface.DrawText(t)

	-- best score
	local t = "BEST SCORE: " .. self.OldScore
	local tw, th = surface.GetTextSize(t)
	surface.SetTextColor(255, 255, 255, 255)
	surface.SetTextPos(SCREEN_HEIGHT - tw - 10, 10)
	surface.DrawText(t)

	-- self.OldScore
end

function GAME:OnCoinsInserted(ply, old, new)
	MACHINE:EmitSound("garrysmod/content_downloaded.wav", 50)

	if (new == 1) then
		self:Reset()
		self.backgrounds = {0, 288, 288 * 2}
		ResetPipes(self)
		self.scored = {false, false, false}
		self.Dead = false
	end
end

function GAME:OnCoinsLost(ply, old, new)
	if new < 1 then
		self:Reset()
		self.GameEnded = true
		self.DrawScore = false
	end
end

return GAME
-- end