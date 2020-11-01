--[[
	--Welcome to hell
	Börk Berker by Henke.
	It started out as a simple test game, but turned into some kind of Breakout, Brick Breaker or other games you may know of.
	It has become quite messy, and some stuff are kind of hardcoded, but it's fine for the moment.
	--product of sweden
]]

--TODO:
--[[
	Fix Known bugs:
	- Collisions may behave in odd ways at times (Might be fixed)
	- LAG can cause ball to phase through objects (Possibly due to FrameTime)

	Add:
	- More powerups
	- Prettier visuals (like, Lua run shows cmd prompt, Backgrounds, visuals for all powerups?)
	- More block typee

	Update:
	- Music, speed over time?
]]

--local function game() -- For testing
local GAME = {}
GAME.LateUpdateMarquee = true
GAME.Bodygroup = BG_GENERIC_TRACKBALL
GAME.Name = "Börk Berker"
GAME.Description = [[Controls:
Press SPACE (Jump key) to launch the ball.
Use A and D (Walk keys) to move the pad left or right.
Press R (Reload) to mute/unmute music.]]

local gameState = 0 -- 0 = Attract mode, 1 = Playing, 2 = Waiting for coins update, 3 = next gameStage
local thePlayer = nil
local playerScore = 0

local gameOverAt = 0
local isGameOver = false

local moveX = 0
local defaultMoveSpeed = 250
local moveSpeed = defaultMoveSpeed
local moveSlowDown = 1250
local padObject

local boarder = Material("vgui/spawnmenu/hover") --This is already vgui, keep as Material!
local ballMaterial = Material("sprites/sent_ball")
local ballObject
local defaultBallSpeed = 200
local ballSpeed = defaultBallSpeed
local maxBallSpeed = 300
local maxVelocity = 600

local powerUpFallSpeed = 100

local reverseControl = false
local defaultBgColor = Color(25, 0, 25)
local bgColor = defaultBgColor
local currentBgColor = bgColor

local bgColors = {
	Color(50, 0, 75),
	Color(75, 0, 50),
	Color(50, 50, 0),
	Color(50, 75, 50),
	Color(0, 50, 75),
	Color(50, 50, 75),
}

local hardnessColors = {
	[1] = Color(100, 200, 45), --green
	[2] = Color(200, 200, 45), --yellow
	[3] = Color(255, 100, 45), --orange
	[4] = Color(255, 0, 0) --red
}

local isMusicMuted = false
local currentSong = ""
local nextMusicPlay = 0
local music = {
	{"music/hl1_song25_remix3.mp3", 61}, --Good
	{"music/hl2_song31.mp3", 92}, --Good & Arcadey
	{"music/hl2_song15.mp3", 69}, --Good
	{"music/hl2_song29.mp3", 135},
	{"music/hl2_song20_submix0.mp3", 103}, --okay
	{"music/hl1_song17.mp3", 123},  --okay
	{"music/hl1_song10.mp3", 104}, --weird, but fine..
	{"music/hl1_song15.mp3", 120}, --okay
}

local gameStage = 1
local lastObjectID = 0
local currentBrickAmount = 0
local objects = {}

local baseBoxObject =  {
	id = 0,
	lastPos = Vector(0, 0),
	pos = Vector(0, 0),
	vel = Vector(0, 0),
	size = Vector(0, 0),
	render = {
		color = Color(255, 255, 255),
	},
	collision = {
		type = COLLISION.types.BOX,
		width = 0,
		height = 0,
	}
}

local currentPowerUps = {}
local powerUps = {}
local basePowerUp = {
	icon = Material("sprites/key_12"),
	name = "base",
	time = 5,
}

local soundTimesTable = {}
local function MakeSound(soundPath, pitch, level)
	-- We don't want the same sound to play too close to eachother
	if soundTimesTable[soundPath] and CurTime() < soundTimesTable[soundPath] + 0.05 then
		return
	end

	soundTimesTable[soundPath] = CurTime()
	SOUND:Play(soundPath, 75, pitch, level)
end

local function PlayMusic()
	if isMusicMuted then
		return
	end

	if CurTime() >= nextMusicPlay then

		local songTbl = table.Random(music)
		currentSong = songTbl[1]
		local dur = songTbl[2]

		local rng = 150 --math.random(150, 200)

		local playTime = dur / (rng / 100)
		curSongLen = playTime
		SOUND:EmitSound(currentSong, 75, rng, 0.1)
		nextMusicPlay = CurTime() + playTime + 1 --1s delay just give some space
	end
end

IMAGE:LoadFromMaterial("voice/icntlk_sv", "soundIcon")
IMAGE:LoadFromMaterial("debug/particleerror", "xMark")

local soundIcon = IMAGE.Images["soundIcon"].mat--IMAGE:LoadFromMaterial(name, key)
local xMarkIcon = IMAGE.Images["xMark"].mat

local backgrounds = {}
for i = 2, 7 do
	IMAGE:LoadFromMaterial("console/background0" .. i, "bork_background0" .. i)
	local mat = IMAGE.Images["bork_background0" .. i].mat
	table.insert(backgrounds, mat)
end

local currentBackground = backgrounds[1]

local function CreateBoxObject(pos, size, color, func)
	local ob = table.Copy(baseBoxObject)
	pos = pos or Vector(10, 10)
	size = size or Vector(10, 10)
	color = color or Color(255, 255, 255)

	ob.pos = pos
	ob.size = size
	ob.render.color = color
	ob.setPos = function(p) ob.pos = p end
	ob.setVel = function(v) ob.vel = v end

	if func then
		ob.render.func = func
	end

	ob.id = lastObjectID
	lastObjectID = lastObjectID + 1

	table.insert(objects, ob)

	return ob
end

IMAGE:LoadFromMaterial("vgui/spawnmenu/hover", "boarder")
IMAGE:LoadFromMaterial("sprites/sent_ball", "ball")

boarder = IMAGE.Images["boarder"].mat
ballMaterial = IMAGE.Images["ball"].mat

local function SpawnPowerUp(name, pos)
	local data = table.Copy(powerUps[name])

	data.color = ColorRand()
	data.defaultSize = 20
	data.lerp = 0
	data.rev = false
	local powerUp = CreateBoxObject(pos, Vector(20, 20), color, function(x, y, w, h)
		surface.SetDrawColor(Color(125, 125, 125, 255))
		surface.SetMaterial(boarder)
		surface.DrawTexturedRect(x, y, w, h)

		surface.SetDrawColor(data.color:Unpack())
		surface.SetMaterial(data.icon)
		surface.DrawTexturedRect(x + 2.5, y + 2.5, w - 5, h - 5)
	end)
	powerUp.data = data
	powerUp.isPowerup = true
end

local function MakePup(name, time, mat, init, update, reset, mean, fullDraw)
	local powerUp = table.Copy(basePowerUp)

	IMAGE:LoadFromMaterial(mat, mat .. "_powerup")
	powerUp.icon = IMAGE.Images[mat .. "_powerup"].mat
	powerUp.name = name
	powerUp.time = time
	powerUp.init = init
	powerUp.reset = reset or function() return end
	powerUp.update = update or function() return end
	powerUp.fullDraw = fullDraw
	powerUp.mean = mean

	powerUps[name] = powerUp
end

MakePup("big_pad", 20, "sprites/key_12", function(p)
	p.oldSizeX = padObject.size.x
	padObject.size.x = padObject.size.x * 2
	padObject.pos.x = padObject.pos.x - padObject.size.x / 4
end,
nil,
function(p)
	padObject.size.x = p.oldSizeX
	padObject.pos.x = padObject.pos.x + padObject.size.x / 2
end)

MakePup("big_ball", -1, "sgm/playercircle", function(p)
	p.oldSize = ballObject.size
	p.oldColor = ballObject.render.color
	ballObject.size = ballObject.size * 2
	ballObject.pos = ballObject.pos - ballObject.size / 4
	ballObject.isBigBall = true
	ballObject.bigBallUses = 15 + gameStage
end,
function(p)
	local maxHits = 15 + gameStage
	local hitsLeft = ballObject.bigBallUses

	if hitsLeft < 1 then
		p.destroy = true
	end

	local colorR = math.Remap(hitsLeft, 0, maxHits, 255, p.oldColor.r)
	local colorG = math.Remap(hitsLeft, 0, maxHits, 0, p.oldColor.g)
	local colorB = math.Remap(hitsLeft, 0, maxHits, 0, p.oldColor.b)
	ballObject.render.color = Color(colorR, colorG, colorB)
end,
function(p)
	ballObject.isBigBall = false
	ballObject.size = p.oldSize
	ballObject.pos = ballObject.pos + ballObject.size / 2
	ballObject.render.color = p.oldColor
	ballObject.bigBallUses = 15 + gameStage
end)

MakePup("lua_run", 0, "editor/lua_run", function(p)
	MakeSound("buttons/button1.wav", 100, 0.75)

	local toKill = math.random(5, 10)
	local available = {}
	for k, v in pairs(objects) do
		if v.isBlock and not v.destroyed then
			table.insert(available, v)
		end
	end

	if table.IsEmpty(available) then
		return
	end

	for i = 1, toKill do
		local block = table.Random(available)
		if block.hardness > 1 then
			local newHard = block.hardness - 1
			block.hardness = newHard
			block.render.color = hardnessColors[newHard]
		else
			block.destroyed = true
		end
		playerScore = playerScore + 20
	end
end, nil, nil, false, true)

MakePup("small_pad", 15, "hud/killicons/default", function(p)
	p.oldSizeX = padObject.size.x
	padObject.size.x = padObject.size.x / 2
	padObject.pos.x = padObject.pos.x + padObject.size.x / 2
end,
nil,
function(p)
	padObject.size.x = p.oldSizeX
	padObject.pos.x = padObject.pos.x - padObject.size.x / 4
end, true)

MakePup("monk", 10, "sprites/obsolete", function(p)
	reverseControl = true
	MakeSound("vo/ravenholm/madlaugh04.wav", 100, 0.75)
end,
nil,
function(p)
	reverseControl = false
end, true, true)

MakePup("speed", 15, "decals/decal_signroute006a",
function(p)
	p.oldColor = padObject.render.color
	padObject.render.color = Color(100, 255, 100)
	MakeSound("npc/dog/dog_pneumatic2.wav", 100, 0.5)
	moveSpeed = moveSpeed * 1.5
end,
nil,
function(p)
	padObject.render.color = p.oldColor
	moveSpeed = defaultMoveSpeed
end, false, true)

local function UpdatePowerups()
	for k, ob in pairs(objects) do
		if padObject.id ~= ob.id and not ob.destroyed and ob.isPowerup then

			local data = ob.data
			if data.rev then
				data.lerp = data.lerp - FrameTime() * 2

				if data.lerp <= 0 then
					data.lerp = 0
					data.rev = false
				end
			elseif not data.rev then
				data.lerp = data.lerp + FrameTime() * 2

				if data.lerp >= 1 then
					data.lerp = 1
					data.rev = true
				end
			end

			local col = math.Remap(data.lerp, 0, 1, 100, 255)
			if data.fullDraw then
				data.color = Color(255, 255, 255)
			elseif data.mean then
				data.color = Color(data.lerp * 255, 0, 0)
			else
				data.color = Color(data.lerp * 255, col, data.lerp * 255)
			end

			ob.size = Vector(data.defaultSize + data.lerp * 5, data.defaultSize + data.lerp * 5)

			--this started as unintended behaviour, but i liked it and modified it to use it as an effect
			local map = math.Remap(data.lerp, 0, 1, -1, 1)
			ob.pos.x = ob.pos.x + map / 3

			ob.setVel(Vector(0, powerUpFallSpeed))
			if COLLISION:IsColliding(padObject, ob) then
				local hasPowerUp = false

				if not table.IsEmpty(currentPowerUps) then
					for name, powerUp in pairs(currentPowerUps) do
						if powerUp then
							if data.mean and not powerUp.mean then --If the powerup is mean, we kill all good powerups
								powerUp.reset(powerUp)
								currentPowerUps[name] = nil
							elseif not data.mean and powerUp.mean then --If it's nice we kill all bad ones
								powerUp.reset(powerUp)
								currentPowerUps[name] = nil
							end

							if name == data.name then --if there's already a powerup with this name, we just extend time
								hasPowerUp = true

								if name == "big_ball" then
									ballObject.bigBallUses = ballObject.bigBallUses + 15 --we just add 15, harsh solution, but it works
								else
									powerUp.endTime = powerUp.endTime + powerUp.time
								end
							end
						end
					end
				end

				if not hasPowerUp then
					currentPowerUps[data.name] = data
				end

				MakeSound("friends/friend_online.wav", 150, 0.5)
				ob.destroyed = true
			end

			if not ob.destroyed and ob.pos.y >= SCREEN_HEIGHT + ob.size.y then
				ob.destroyed = true
			end
		end
	end

	if table.IsEmpty(currentPowerUps) then
		return
	end

	for name, powerUp in pairs(currentPowerUps) do
		if powerUp then
			if not powerUp.hasInit then
				powerUp.hasInit = true
				powerUp.init(powerUp)
				powerUp.endTime = CurTime() + powerUp.time
			end

			if powerUp.hasInit then
				powerUp.update(powerUp)

				if powerUp.destroy then
					powerUp.reset(powerUp)
					currentPowerUps[name] = nil
				end

				if powerUp.time > -1 and CurTime() >= powerUp.endTime then
					powerUp.reset(powerUp)
					currentPowerUps[name] = nil
				end
			end
		end
	end
end

local function RespawnBall()
	if shouldRespawnBall then
		ballObject.launched = false
		ballObject.setVel(Vector(0, 0))
		ballObject.setPos(padObject.pos + Vector(padObject.size.x / 2 - ballObject.size.x / 2, -ballObject.size.y))
		MakeSound("npc/dog/dog_playfull4.wav", 150, 0.5)
		shouldRespawnBall = false
	end
end

local function UpdateBallObject()
	if not ballObject.launched then
		ballObject.setPos(padObject.pos + Vector(padObject.size.x / 2 - ballObject.size.x / 2, -ballObject.size.y))
		return
	end

	local velX, velY = ballObject.vel.x, ballObject.vel.y
	local posX, posY = ballObject.pos.x, ballObject.pos.y

	for k, ob in pairs(objects) do
		if ballObject.id ~= ob.id and not ob.destroyed and not ob.isPowerup and COLLISION:IsColliding(ballObject, ob) then
			--We can't hit the same object 2 times without bouncing of something else first, since we can't stand still this makes sense
			if ballObject.lastHitID == ob.id then
				return
			end

			ballObject.lastHitID = ob.id
			local ball = ballObject

			local left 	= ob.pos.x
			local up   	= ob.pos.y
			local right	= ob.pos.x + ob.size.x
			local down 	= ob.pos.y + ob.size.y

			local ballLeft 	= ball.pos.x
			local ballUp   	= ball.pos.y
			local ballRight	= ball.pos.x + ball.size.x
			local ballDown 	= ball.pos.y + ball.size.y

			local lastBallLeft 	= ball.lastPos.x
			local lastBallUp   	= ball.lastPos.y
			local lastBallRight	= ball.lastPos.x + ball.size.x
			local lastBallDown 	= ball.lastPos.y + ball.size.y

			local collidedLeft 	= lastBallRight < left and ballRight >= left
			local collidedRight	= lastBallLeft >= right and ballLeft < right
			local collidedUp   	= lastBallDown < up and ballDown >= up
			local collidedDown 	= lastBallUp >= down and ballUp < down

			--bigball smashes through blocks
			if ballObject.isBigBall and ob.isBlock then
				if ballObject.bigBallUses > 0 then
					if ob.hardness > 1 and ob.hardness + 1 < ballObject.bigBallUses then
						ballObject.bigBallUses = ballObject.bigBallUses - (ob.hardness - 1)
						ob.hardness = 1
					else
						ballObject.bigBallUses = ballObject.bigBallUses - 1
					end
				end
			else
				local vel_Y = math.abs(ballObject.vel.y)
				local vel_X = math.abs(ballObject.vel.x)

				if collidedUp then
					ballObject.vel.y = -vel_Y
				elseif collidedDown then
					ballObject.vel.y = vel_Y
				end

				if collidedLeft then
					ballObject.vel.x = -vel_X
				elseif collidedRight then
					ballObject.vel.x = vel_X
				end
			end

			if ob.isBlock then
				playerScore = playerScore + 20

				if ob.hardness > 1 then
					local newHard = ob.hardness - 1

					ob.hardness = newHard
					ob.render.color = hardnessColors[newHard]
					MakeSound("weapons/airboat/airboat_gun_energy2.wav", math.random(125, 200), 0.2)
				else
					local shouldSpawnPup = math.random(0, 100)

					--up to 60% chance of powerup the higher stage!
					local chancePlus = gameStage < 50 and gameStage or 50

					if shouldSpawnPup >= 90 - chancePlus then
						local rndPup = table.Random(table.GetKeys(powerUps))
						SpawnPowerUp(rndPup, ob.pos)
					end

					ob.destroyed = true
					local len = ballObject.vel:Length()
					len = math.Clamp(len, 100, 230)

					len = len + math.random(-15, 25)

					if ballObject.isBigBall then
						MakeSound("weapons/physcannon/energy_disintegrate" .. math.random(4, 5) .. ".wav", math.random(150, 200), 0.15)
					else
						MakeSound("friends/friend_join.wav", len, 0.5)
						if ballObject.vel.x >= maxBallSpeed - 10 or ballObject.vel.x <= -maxBallSpeed - 10 then
							MakeSound("weapons/fx/rics/ric" .. math.random(1, 5) .. ".wav", 100, 0.1)
						end
					end
				end
			end

			if ob == padObject then
				ballObject.vel.x = padObject.vel.x / 2 + ballObject.vel.x
				ballObject.vel.y = -math.abs(ballObject.vel.y)
				MakeSound("npc/combine_gunship/attack_start2.wav", math.random(150, 250), 0.1)
			end
		end
	end

	local margin = 10
	if posX <= 0 + margin then
		ballObject.lastHitID = - 1
		ballObject.setVel(Vector(math.abs(ballObject.vel.x), velY))
	end

	if posY <= 0 + margin then
		ballObject.lastHitID = - 1
		ballObject.setVel(Vector(velX, math.abs(ballObject.vel.y)))
	end

	if posX >= SCREEN_WIDTH - ballObject.size.x - margin then
		ballObject.lastHitID = - 1
		ballObject.setVel(Vector(-math.abs(ballObject.vel.x), velY))
	end

	--out of bounds
	if posY >= SCREEN_HEIGHT + ballObject.size.y * 4 and not shouldRespawnBall then
		GAME:GameOver()
	end
end

local oldBallPositions = {}
local nextSample = 0
local function UpdateObjects()
	for k,v in pairs(objects) do
		if v.vel ~= Vector(0, 0) then
			v.lastPos = v.pos

			local clamp = v.id == ballObject.id and maxBallSpeed or maxVelocity

			v.vel.x = math.Clamp(v.vel.x, -clamp, clamp)
			v.vel.y = math.Clamp(v.vel.y, -clamp, clamp)
			v.setPos(v.pos + (v.vel * FrameTime()))

			if v.id == ballObject.id and RealTime() >= nextSample then
				table.insert(oldBallPositions, v.pos)

				if table.Count(oldBallPositions) >= 5 then
					table.remove(oldBallPositions, 1)
				end
				nextSample = RealTime() + 0.05
			end
		end

		--just to not bother with col x, y all the time
		if v.size ~= Vector(v.collision.width, v.collision.height) then
			v.collision.width = v.size.x
			v.collision.height = v.size.y
		end

		-- any of them who got destroyed?
		if v.destroyed then
			if v.isBlock and not v.blockBreak then
				currentBrickAmount = currentBrickAmount - 1
				v.blockBreak = true
			end
			v = nil
		end
	end
end

local function RenderObjects()
	if ballObject.vel:Length() >= maxBallSpeed - 10 then
		for i = 1, #oldBallPositions do
			local alpha = math.Remap(i, 0, #oldBallPositions, 0, 255)

			local col = ballObject.render.color
			col.a = alpha

			surface.SetDrawColor(col:Unpack())
			surface.SetMaterial(ballMaterial)
			local posX, posY = oldBallPositions[i].x, oldBallPositions[i].y
			local scaleX, scaleY = ballObject.size.x, ballObject.size.y
			surface.DrawTexturedRect(posX, posY, scaleX, scaleY)
		end
	end

	for k, ob in pairs(objects) do
		if not ob.destroyed then
			if ob.render.func then
				ob.render.func(ob.pos.x, ob.pos.y, ob.size.x, ob.size.y)
			elseif ob.render.color then
				local w, h = ob.size.x, ob.size.y
				surface.SetDrawColor(ob.render.color:Unpack())
				surface.DrawRect(ob.pos.x, ob.pos.y, w, h)
				surface.SetDrawColor(255, 255, 255, 100)
				surface.SetMaterial(boarder)
				surface.DrawTexturedRect(ob.pos.x, ob.pos.y, w, h)
			end
		elseif not ob.renderKill and ob.isBlock then
			if not ob.kill then
				ob.kill = {}
				ob.kill.lerp = 1
				ob.kill.color = Color(255, 255, 0)
				ob.kill.color2 = Color(255, 0, 0)
			end

			ob.kill.lerp = ob.kill.lerp - FrameTime() * 2

			surface.DrawCircle(ob.pos.x + ob.size.x / 2, ob.pos.y + ob.size.y / 2, 10 - ob.kill.lerp * 10, ob.kill.color:Unpack())
			surface.DrawCircle(ob.pos.x + ob.size.x / 2, ob.pos.y + ob.size.y / 2, 5 - ob.kill.lerp * 5, ob.kill.color2:Unpack())

			if ob.kill.lerp <= 0 then
				ob.renderKill = true
			end
		end
	end
end

local function ResetGame()
	isGameOver = false
	moveSpeed = defaultMoveSpeed
	ballSpeed = defaultBallSpeed

	reverseControl = false
	bgColor = table.Random(bgColors)
	currentBrickAmount = 0
	lastObjectID = 0
	objects = {}
	badPowerups = {}
	currentPowerUps = {}

	padObject = CreateBoxObject(Vector(0, 0), Vector(50, 10), Color(50, 125, 255))

	ballObject = CreateBoxObject(Vector(0, 0), Vector(17.5, 17.5), nil, function(x, y, w, h)
		surface.SetDrawColor(ballObject.render.color)
		surface.SetMaterial(ballMaterial)
		surface.DrawTexturedRect(x, y, w, h)
	end)

	padObject.setPos(Vector(SCREEN_WIDTH / 2 - padObject.size.x / 2, SCREEN_HEIGHT - padObject.size.y * 2))
	ballObject.setPos(padObject.pos + Vector(0, -ballObject.size.y))
	ballObject.render.color = Color(100, 200, 255)

	gameState = 1

	currentBackground = table.Random(backgrounds)

	local hardBlocks = gameStage - 1

	--less blocks in the first stages
	local blockAmn = gameStage < #hardnessColors and gameStage or #hardnessColors
	local yAmn = math.Remap(blockAmn, 1, #hardnessColors, 80, 40)

	for x = 1, (SCREEN_WIDTH / 40) - 1 do
		for y = 1, (SCREEN_HEIGHT / yAmn) - 1 do
			local col = hardnessColors[1]
			local hardness = 1

			if y <= hardBlocks then
				local curColor = gameStage
				local hits = gameStage

				if gameStage > #hardnessColors then
					curColor = #hardnessColors
					hits = #hardnessColors
				end

				col = hardnessColors[curColor]
				hardness = hits
			end

			local block = CreateBoxObject(Vector(40 * x, 20 * y + 40), Vector(20, 10), col, nil, true)
			block.isBlock = true
			block.hardness = hardness

			currentBrickAmount = currentBrickAmount + 1
		end
	end
end

function GAME:GameOver()
	if not isGameOver then

		MakeSound("weapons/physcannon/energy_disintegrate4.wav", 150, 0.5)
		MakeSound("npc/combine_gunship/gunship_ping_search.wav", 150, 0.25)
		if COINS:GetCoins() > 1 then
			self:Continue()
			return
		end

		for name, powerUp in pairs(currentPowerUps) do
			if powerUp and powerUp.endTime and powerUp.time ~= 0 and not powerUp.pauseTime then
				powerUp.pauseTime = powerUp.endTime - CurTime()
			end
		end

		gameOverAt = RealTime() + 10
		isGameOver = true
	end
end

function GAME:Init()
	IMAGE:LoadFromURL("https://github.com/ukgamer/gmod-arcademachines-assets/raw/master/borkberker/images/ms_acabinet_marque.png", "marquee", function(image)
		CABINET:UpdateMarquee()
	end)

	IMAGE:LoadFromURL("https://github.com/ukgamer/gmod-arcademachines-assets/raw/master/borkberker/images/ms_acabinet_artwork.png", "cabinet", function(image)
		CABINET:UpdateCabinetArt()
	end)
end

function GAME:Start()
	gameStage = 1
	playerScore = 0
	ResetGame()
end

local nextBallSpawn = 0
function GAME:Continue()
	gameState = 1
	isGameOver = false
	shouldRespawnBall = true
	nextBallSpawn = CurTime() + 1
	--RespawnBall()
	COINS:TakeCoins(1)

	--Continue the game with the same time they had when it paused
	for name, powerUp in pairs(currentPowerUps) do
		if powerUp and powerUp.pauseTime then
			powerUp.endTime = CurTime() + powerUp.pauseTime
			powerUp.pauseTime = nil
		end
	end
end

function GAME:Stop()
	objects = {}
	gameState = 0
end
local lastRPress = 0
local timeToNextStage = 0
-- Called every frame while the local player is nearby
-- WALK key is "reserved" for coin insert
function GAME:Update()
	if gameState == 0 then return end
	if not IsValid(thePlayer) then
		self:Stop()
		return
	end

	if isGameOver and RealTime() >= gameOverAt and gameState ~= 2 then
		-- Taking coins takes time to be processed by the server and for
		-- OnCoinsLost to be called, so wait until the coin amount has changed
		-- to know whether to end the game/lose a life/etc.
		COINS:TakeCoins(1)
		gameState = 2
		return
	end

	if isGameOver then return end

	if shouldRespawnBall and CurTime() >= nextBallSpawn then
		RespawnBall()
	end

	if currentBrickAmount < 1 then--currentBrickAmount <= 0 then
		if gameState ~= 3 then
			gameState = 3

			MakeSound("friends/message.wav", 250, 0.25)
			timeToNextStage = RealTime() + 2
		end

		if gameState == 3 and RealTime() >= timeToNextStage then
			gameStage = gameStage + 1
			ResetGame()
			gameState = 1
		end

		return
	end

	if not padObject or not ballObject then
		return
	end

	PlayMusic()
	if thePlayer:KeyDown(IN_RELOAD) then
		if CurTime() > lastRPress + 0.05 then
			isMusicMuted = not isMusicMuted

			if isMusicMuted then
				SOUND:StopSound(currentSong)
			else
				nextMusicPlay = 0
			end
		end
		lastRPress = CurTime()
	end

	if thePlayer:KeyDown(IN_JUMP) and not ballObject.launched then
		local trueVel = padObject.vel.x > ballSpeed and ballSpeed or padObject.vel.x < -ballSpeed and -ballSpeed or 0
		if trueVel >= -25 and trueVel <= 25 then
			local rng = math.random(0, 1)
			if rng == 0 then
				trueVel = math.Rand(-ballSpeed / 4, -ballSpeed / 2) --cur ballspeed is 200, so this would be min 50, max 100
			else
				trueVel = math.Rand(ballSpeed / 4, ballSpeed / 2)
			end
		end

		ballObject.setPos(ballObject.pos + Vector(0, -5)) -- -5 margin of error incase
		ballObject.setVel(Vector(trueVel, -ballSpeed)) --always kick the ball upward
		ballObject.launched = true
	end

	-- halt the pad, since im using velocities
	if moveX < moveSpeed / 4 and moveX > -moveSpeed / 4 then
		moveX = 0
	end

	if thePlayer:KeyDown(reverseControl and IN_MOVERIGHT or IN_MOVELEFT) then
		moveX = padObject.pos.x > 0 and -moveSpeed or 0
	elseif moveX < -1 then
		moveX = moveX + FrameTime() * moveSlowDown
	end

	if thePlayer:KeyDown(reverseControl and IN_MOVELEFT or IN_MOVERIGHT) then
		moveX = padObject.pos.x < SCREEN_WIDTH - padObject.size.x and moveSpeed or 0
	elseif moveX > 1 then
		moveX = moveX - FrameTime() * moveSlowDown
	end

	--pre movement for more solid collision checks
	UpdateBallObject()
	UpdateObjects()
	--post movement for more solid collision checks
	UpdateBallObject()

	UpdatePowerups()
	padObject.setVel(Vector(moveX, 0))

	--fail safes
	if padObject.pos.x < 0 then
		padObject.pos.x = 0
		padObject.vel.x = 0
	end

	if padObject.pos.x > SCREEN_WIDTH - padObject.size.x then
		padObject.pos.x = SCREEN_WIDTH - padObject.size.x
		padObject.vel.x = 0
	end
end

-- Called once on init
function GAME:DrawMarquee()
	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(IMAGE.Images.marquee.mat)
	surface.DrawTexturedRect(0, 0, MARQUEE_WIDTH, MARQUEE_HEIGHT)
end

function GAME:DrawCabinetArt()
	surface.SetMaterial(IMAGE.Images.cabinet.mat)
	surface.SetDrawColor(255, 255, 255)
	surface.DrawTexturedRect(0, 0, CABINET_ART_WIDTH, CABINET_ART_HEIGHT)
end

local demoObjects = {}
function GAME:DrawDemo()
	surface.SetDrawColor(50, 50, 100)
	surface.DrawRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

	if table.IsEmpty(demoObjects) then
		for x = 1, (SCREEN_WIDTH / 40) - 1 do
			for y = 1, (SCREEN_HEIGHT / 40) - 1 do
				local tab = {}
				tab.func = function()
					surface.SetDrawColor(hardnessColors[1]:Unpack())
					surface.DrawRect(x * 40, 20 * y + 40, 20, 10)
				end

				table.insert(demoObjects, tab)
			end
		end

		local pad = {isPad = true}
		pad.func = function(x, y)
			surface.SetDrawColor(50, 125, 255)
			surface.DrawRect(x, y, 40, 10)
		end

		table.insert(demoObjects, pad)

		local ball = {isBall = true}
		ball.func = function(x, y)
			surface.SetDrawColor(100, 200, 255)
			surface.SetMaterial(ballMaterial)
			surface.DrawTexturedRect(x, y, 20, 20)
		end

		table.insert(demoObjects, ball)
	end

	--i was going to make it move more but... is fine
	for k,v in pairs(demoObjects) do
		local sin = math.sin(RealTime() * 2) * SCREEN_WIDTH / 3
		if v.isPad then
			v.func(sin + SCREEN_WIDTH / 2 - 20, SCREEN_HEIGHT - 40)
		elseif v.isBall then
			v.func(sin + SCREEN_WIDTH / 2 - 10, SCREEN_HEIGHT - 60)
		else
			v.func()
		end
	end

	local text = self.Name .. "!"
	surface.SetFont("ContentHeader")
	local tW, tH = surface.GetTextSize(text)
	local tPosX, tPosY = SCREEN_WIDTH / 2 - tW / 2, tH + 100 + math.sin(RealTime() * 3) * 40

	surface.SetTextColor(0, 0, 0)
	surface.SetTextPos(tPosX + 2, tPosY + 2)
	surface.DrawText(text)

	surface.SetTextColor(0, 0, 0)
	surface.SetTextPos(tPosX - 2, tPosY - 2)
	surface.DrawText(text)

	surface.SetTextColor(0, 0, 0)
	surface.SetTextPos(tPosX + 2, tPosY - 2)
	surface.DrawText(text)

	surface.SetTextColor(0, 0, 0)
	surface.SetTextPos(tPosX - 2, tPosY + 2)
	surface.DrawText(text)

	surface.SetTextColor(255, 255, 255)
	surface.SetTextPos(tPosX, tPosY)
	surface.DrawText(text)
end

-- Called every frame while the local player is nearby
-- The screen is cleared to black for you
function GAME:Draw()
	surface.SetDrawColor(currentBgColor:Unpack())
	surface.SetMaterial(currentBackground)
	surface.DrawTexturedRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

	if gameState == 0 then
		self:DrawDemo()
		surface.SetFont("DermaLarge")
		local tW, tH = surface.GetTextSize("INSERT COIN")
		surface.SetTextColor(255, 255, 255, math.sin(RealTime() * 5) * 255)
		surface.SetTextPos((SCREEN_WIDTH / 2) - (tW / 2), SCREEN_HEIGHT - (tH * 2))
		surface.DrawText("INSERT COIN")
		return
	end

	if gameState == 1 then
		local score = "Score: " .. playerScore
		surface.SetFont("DermaLarge")
		local tW = surface.GetTextSize(score)
		surface.SetTextColor(255, 255, 255)
		surface.SetTextPos(SCREEN_WIDTH / 2 - tW / 2, 0)
		surface.DrawText(score)
	end

	if gameState == 3 then
		local text = "Stage " .. gameStage .. " clear!"
		surface.SetFont("ScoreboardDefaultTitle")
		local tW, tH = surface.GetTextSize(text)
		surface.SetTextColor(255, 200, 255)
		surface.SetTextPos(SCREEN_WIDTH / 2 - tW / 2, SCREEN_HEIGHT / 2 - tH / 2)
		surface.DrawText(text)
		return
	end

	local sin = math.sin(RealTime() * 2.5) * 10
	local colorR = math.Remap(sin, -10, 10, bgColor.r, bgColor.r * 1.75)
	local colorG = math.Remap(sin, -10, 10, bgColor.g, bgColor.g * 1.75)
	local colorB = math.Remap(sin, -10, 10, bgColor.b, bgColor.b * 1.75)
	currentBgColor = Color(colorR, colorG, colorB)

	local margin = 10
	local text = "Coins left: " .. COINS:GetCoins() - 1
	surface.SetFont("GModNotify")
	local tW, tH = surface.GetTextSize(text)

	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawRect(margin / 2, margin / 2, tW + margin, tH + margin)

	surface.SetTextColor(50, 125, 2555)
	surface.SetTextPos(margin, margin)
	surface.DrawText(text)

	local i = 1
	for name, powerUp in pairs(currentPowerUps) do
		if powerUp and powerUp.endTime and powerUp.time ~= 0 then

			surface.SetDrawColor(255, 255, 255)
			surface.SetMaterial(powerUp.icon)
			local x, y = SCREEN_WIDTH - 24 * i - margin, SCREEN_HEIGHT - 20 - margin * 4
			surface.DrawTexturedRect(x, y, 20, 20)

			local txt = math.Round(powerUp.endTime - CurTime(), 0) .. "s"
			if powerUp.pauseTime then
				txt = math.Round(powerUp.pauseTime) .. "s"
			end
			if powerUp.time == -1 and ballObject.isBigBall then
				txt = ballObject.bigBallUses
			end

			surface.SetFont("Default")
			tW, tH = surface.GetTextSize(txt)
			surface.SetTextColor(50, 125, 255)
			surface.SetTextPos(x + 10 - tW / 2, y + 20)
			surface.DrawText(txt)
			i = i + 1
		end
	end

	local soundIconPosX, soundIconPosY = SCREEN_WIDTH - 42, 10

	if isMusicMuted then
		surface.SetDrawColor(255, 0, 0, 50)
	else
		surface.SetDrawColor(255, 255, 255, 50)
	end

	surface.SetMaterial(soundIcon)
	surface.DrawTexturedRect(soundIconPosX, soundIconPosY, 32, 32)

	if isMusicMuted then
		surface.SetMaterial(xMarkIcon)
		surface.DrawTexturedRect(soundIconPosX, soundIconPosY, 32, 32)
	end
	RenderObjects()

	if isGameOver then
		local col = Color(255, 50, 50)
		local txt = "GAME OVER IN " .. math.max(0, math.floor(gameOverAt - RealTime()))
		surface.SetFont("DermaLarge")
		tW, tH = surface.GetTextSize(txt)

		surface.SetDrawColor(0, 0, 0, 225)
		surface.DrawRect(SCREEN_WIDTH / 2 - tW / 2, SCREEN_HEIGHT / 2 - tH / 2, tW, tH)

		surface.SetTextColor(col:Unpack())
		surface.SetTextPos(SCREEN_WIDTH / 2 - tW / 2, SCREEN_HEIGHT / 2 - tH / 2)
		surface.DrawText(txt)

		txt = "Insert coin to continue.."
		local tW2, tH2 = surface.GetTextSize(txt)

		local x, y = SCREEN_WIDTH / 2 - tW2 / 2, SCREEN_HEIGHT / 2 - tH2 / 2 + tH
		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawRect(x, y, tW2, tH2)
		surface.SetTextPos(x, y)
		surface.DrawText(txt)
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

	nextMusicPlay = 0
	SOUND:StopSound(currentSong)
end

function GAME:OnCoinsInserted(ply, old, new)
	if ply ~= LocalPlayer() then return end

	if gameState == 0 and new > 0 then
		self:Start()
	end

	if isGameOver and new > 0 then
		self:Continue()
	end
end

function GAME:OnCoinsLost(ply, old, new)
	if ply ~= LocalPlayer() then return end

	if new == 0 then
		self:Stop()
	end
end

return GAME
--end -- For testing

--local ent = this
--if IsValid(ent) and ent.SetGame then
--	ent:SetGame(game)
--end
