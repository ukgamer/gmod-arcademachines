--[[
	--Welcome to hell
	Börk Berker by Henke.
	It started out as a simple test game, but turned into some kind of Breakout, Brick Breaker or other games you may know of.
	It has become quite messy, and some stuff are kind of hardcoded, but it's fine for the moment.
	--product of sweden
]]

--local function game() -- For testing
local GAME = {}

GAME.Name = "Börk Berker"

local gameState = 0 -- 0 = Attract mode, 1 = Playing, 2 = Waiting for coins update, 3 = next gameStage
local thePlayer = nil
local playerScore = 0

local gameOverAt = 0
local isGameOver = false

local moveX, moveY = 0, 0
local moveSpeed = 250
local moveSlowDown = 1250
local padObject

local boarder = Material("vgui/spawnmenu/hover")
local ballMaterial = Material("sprites/sent_ball")
local ballObject
local ballSpeed = 200
local maxBallSpeed = 300

local powerUpFallSpeed = 100

local reverseControl = false
local defaultBgColor = Color(25, 0, 25)
local bgColor = defaultBgColor

local hardnessColors = {
	[1] = Color(100, 200, 45), --green
	[2] = Color(200, 200, 45), --yellow
	[3] = Color(255, 100, 45), --orange
	[4] = Color(255, 0, 0) --red
}

local curSongLen = 0
local currentSong = ""
local nextMusicPlay = 0
local music = {
	{"music/hl1_song25_remix3.mp3", 61},
	{"music/hl2_song4.mp3", 65},
	{"music/hl2_song32.mp3", 42},
	{"music/hl2_song31.mp3", 92},
	{"music/hl2_song29.mp3", 135},
	{"music/hl2_song25_teleporter.mp3", 46},
	{"music/hl2_song20_submix0.mp3", 103},
	{"music/hl2_song16.mp3", 170},
	{"music/hl2_song15.mp3", 69},
	{"music/hl2_song14.mp3", 159},
	{"music/hl2_song12_long.mp3", 73},
	{"music/hl1_song10.mp3", 104},
	{"music/hl1_song15.mp3", 120},
}

local gameStage = 1
local lastObjectID = 0
local currentBrickAmount = 0
local objects = {}
local badPowerups = {}
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

local powerUps = {}
local basePowerUp = {
	icon = Material("sprites/key_12"),
	name = "base",
	time = 5,
}

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

local powerUpBGMat = Material("vgui/spawnmenu/hover")
local function SpawnPowerUp(name, pos)
	local data = table.Copy(powerUps[name])

	data.color = ColorRand()
	data.defaultSize = 20
	data.lerp = 0
	data.rev = false
	local powerUp = CreateBoxObject(pos, Vector(20, 20), color, function(x, y, w, h)
		surface.SetDrawColor(Color(125, 125, 125))
		surface.SetMaterial(powerUpBGMat)
		surface.DrawTexturedRect(x, y, w, h)
		surface.SetDrawColor(data.color)
		surface.SetMaterial(data.icon)
		surface.DrawTexturedRect(x + 2.5, y + 2.5, w - 5, h - 5)
	end)
	powerUp.data = data
	powerUp.isPowerup = true
end

local function MakePup(name, time, mat, init, update, reset, mean, fullDraw)
	powerUp = table.Copy(basePowerUp)
	powerUp.icon = Material(mat)
	powerUp.name = name
	powerUp.time = time
	powerUp.init = init
	powerUp.reset = reset or function() return end
	powerUp.update = update or function() return end
	powerUp.fullDraw = fullDraw
	if mean then
		powerUp.mean = mean
		table.insert(badPowerups, name)
	end

	powerUps[name] = powerUp
end

MakePup("big_pad", 10, "sprites/key_12", function(p)
	p.oldColor = padObject.render.color
	p.oldSizeX = padObject.size.x
	padObject.size.x = padObject.size.x * 2
	padObject.pos.x = padObject.pos.x - padObject.size.x / 4
end,

function(p)
	if CurTime() < p.endTime - p.time / 2 then
		padObject.render.color = p.oldColor
		return
	end

	if not p.nextFlick then
		p.nextFlick = CurTime() + 0.3
	end

	if CurTime() >= p.nextFlick then
		if p.invertColor then
			padObject.render.color = Color(255, 0, 0)
		else
			padObject.render.color = p.oldColor
		end
		p.invertColor = not p.invertColor
		p.nextFlick = CurTime() + 0.3
	end
end,

function(p)
	padObject.size.x = p.oldSizeX
	padObject.render.color = p.oldColor
	padObject.pos.x = padObject.pos.x + padObject.size.x / 2
end)

MakePup("big_ball", 10, "sgm/playercircle", function(p)
	p.oldSize = ballObject.size
	p.oldColor = ballObject.render.color
	ballObject.size = ballObject.size * 2
	ballObject.pos = ballObject.pos - ballObject.size / 4
end,

function(p)
	if CurTime() < p.endTime - p.time / 2 then
		ballObject.render.color = p.oldColor
		return
	end

	if not p.nextFlick then
		p.nextFlick = CurTime() + 0.3
	end

	if CurTime() >= p.nextFlick then
		if p.invertColor then
			ballObject.render.color = Color(255, 0, 0)
		else
			ballObject.render.color = p.oldColor
		end
		p.invertColor = not p.invertColor
		p.nextFlick = CurTime() + 0.3
	end
end,

function(p)
	ballObject.size = p.oldSize
	ballObject.pos = ballObject.pos + ballObject.size / 2
	ballObject.render.color = p.oldColor
end)

MakePup("lua_run", 0, "editor/lua_run", function(p)
	sound.Play("buttons/button1.wav", MACHINE:GetPos(), 75, 100, 0.75)
	
	local toKill = math.random(5, 10)
	local available = {}
	for k, v in pairs(objects) do
		if v.isBlock and not v.destroyed then
			table.insert(available, v)
		end
	end

	for i = 1, toKill do
		if not table.IsEmpty(available) then
			local block = table.Random(available)
			if block.hardness > 1 then
				block.hardness = block.hardness - 1
				block.render.color = hardnessColors[block.hardness]
			else
				block.destroyed = true
				currentBrickAmount = currentBrickAmount - 1
			end
			playerScore = playerScore + 20
		end
	end
end)

MakePup("small_pad", 15, "hud/killicons/default", function(p)
	p.oldSizeX = padObject.size.x
	padObject.size.x = padObject.size.x / 2
	padObject.pos.x = padObject.pos.x + padObject.size.x / 2
end,
function(p) end,
function(p)
	padObject.size.x = p.oldSizeX
	padObject.pos.x = padObject.pos.x - padObject.size.x / 4
end, true)

MakePup("monk", 10, "models/monk/grigori_head", function(p)
	reverseControl = true
	sound.Play("vo/ravenholm/madlaugh04.wav", MACHINE:GetPos(), 75, 100, 0.75)
end,
function(p) end,
function(p)
	reverseControl = false
end, true, true)

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

			local color = math.Remap(data.lerp, 0, 1, 100, 255)
			if data.fullDraw then
				data.color = Color(255, 100, 100)
			elseif data.mean then
				data.color = Color(data.lerp * 255, 0, 0)
			else
				data.color = Color(data.lerp * 255, color, data.lerp * 255)
			end
			ob.size = Vector(data.defaultSize + data.lerp * 5, data.defaultSize + data.lerp * 5)

			--this started as unintended behaviour, but i liked it and modified it to use it as an effect
			local map = math.Remap(data.lerp, 0, 1, -1, 1)
			ob.pos.x = ob.pos.x + map / 3

			ob.setVel(Vector(0, powerUpFallSpeed))
			if COLLISION:IsColliding(padObject, ob) then
				local hasPowerup = false
				local mean = false
				if not table.IsEmpty(padObject.currentPowerups) then
					if ob.data.mean then
						mean = true
					end

					for i = 1, #padObject.currentPowerups do
						local powerUp = padObject.currentPowerups[i]

						if powerUp then
							if mean then 
								powerUp.reset(powerUp) --if we hit a bad powerup all the positive/previous ones reset
								padObject.currentPowerups[i] = nil
							elseif ob.data.name == powerUp.name then
								powerUp.endTime  = CurTime() + ob.data.time
								hasPowerup = true
							end

							if not mean then --if we hit a good powerup all the bad ones reset
								if badPowerups[powerUp.name] then
									powerUp.reset(powerUp)
									padObject.currentPowerups[i] = nil
								end
							end
						end
					end
				end

				if not hasPowerup then
					if mean then
						playerScore = playerScore - 100
					else
						playerScore = playerScore + 100
					end

					table.insert(padObject.currentPowerups, ob.data)
				end

				sound.Play("friends/friend_online.wav", MACHINE:GetPos(), 75, 150, 0.5)
				ob.destroyed = true
			end

			if ob.pos.y >= SCREEN_HEIGHT + ob.size.y then
				ob.destroyed = true
			end
		end
	end

	if not table.IsEmpty(padObject.currentPowerups) then
		for i = 1, #padObject.currentPowerups do
			local powerUp = padObject.currentPowerups[i]

			if powerUp then
				if not powerUp.hasInit then
					powerUp.hasInit = true
					powerUp.init(powerUp)
					powerUp.endTime = CurTime() + powerUp.time
					return
				end

				powerUp.update(powerUp)

				if CurTime() >= powerUp.endTime then
					powerUp.reset(powerUp)
					padObject.currentPowerups[i] = nil
				end
			end
		end
	end
end

local function RespawnBall()
	ballObject.launched = false
	ballObject.setVel(Vector(0, 0))
	ballObject.setPos(padObject.pos + Vector(padObject.size.x / 2 - ballObject.size.x / 2, -ballObject.size.y))
	sound.Play("npc/dog/dog_playfull4.wav", MACHINE:GetPos(), 75, 150, 0.5)
end

local function UpdateBallObject()
	if not ballObject.launched then
		ballObject.setPos(padObject.pos + Vector(padObject.size.x / 2 - ballObject.size.x / 2, -ballObject.size.y))
		return
	end

	local lastPos = ballObject.lastPos
	local velX, velY = ballObject.vel.x, ballObject.vel.y
	local posX, posY = ballObject.pos.x, ballObject.pos.y

	for k, ob in pairs(objects) do
		if ballObject.id ~= ob.id and not ob.destroyed and not ob.isPowerup and COLLISION:IsColliding(ballObject, ob) then

			--hits happening at the same time can cancel out velocities and cause weird behaviour
			if ballObject.lastCollision and RealTime() - ballObject.lastCollision < 0.01 then
				return
			end

			ballObject.lastCollision = RealTime()

			local ball = ballObject

			local left = ob.pos.x
			local up   = ob.pos.y
			local right= ob.pos.x + ob.size.x
			local down = ob.pos.y + ob.size.y

			local ballLeft = ball.pos.x
			local ballUp   = ball.pos.y
			local ballRight= ball.pos.x + ball.size.x
			local ballDown = ball.pos.y + ball.size.y

			local lastBallLeft = ball.lastPos.x
			local lastBallUp   = ball.lastPos.y
			local lastBallRight= ball.lastPos.x + ball.size.x
			local lastBallDown = ball.lastPos.y + ball.size.y

			local collidedLeft = lastBallRight < left and ballRight >= left
			local collidedRight= lastBallLeft >= right and ballLeft < right
			local collidedUp   = lastBallDown < up and ballDown >= up
			local collidedDown = lastBallUp >= down and ballUp < down

			if collidedUp or collidedDown then
				ballObject.vel.y = -ballObject.vel.y
			end

			if collidedLeft or collidedRight then
				ballObject.vel.x = -ballObject.vel.x
			end

			if ob.isBlock then
				playerScore = playerScore + 20
				if ob.hardness > 1 then
					ob.hardness = ob.hardness - 1
					ob.render.color = hardnessColors[ob.hardness]
				else
					local shouldSpawnPup = math.random(0, 100)

					if shouldSpawnPup >= 90 then
						local rndPup = table.Random(table.GetKeys(powerUps))
						SpawnPowerUp(rndPup, ob.pos)
					end
	
					currentBrickAmount = currentBrickAmount - 1
					ob.destroyed = true
					local pos = MACHINE:GetPos()
	
					local len = ballObject.vel:Length()
					len = math.Clamp(len, 100, 255)
					sound.Play("friends/friend_join.wav", pos, 75, len, 0.5)
					if ballObject.vel.x >= maxBallSpeed - 10 or ballObject.vel.x <= -maxBallSpeed - 10 then
						sound.Play("weapons/fx/rics/ric" .. math.random(1, 5) ..".wav", pos, 50, 100, 0.1)
					end
				end
			end

			if ob == padObject then
				ballObject.vel.x = padObject.vel.x / 2 + ballObject.vel.x
				ballObject.vel.y = -math.abs(ballObject.vel.y)
				sound.Play("npc/combine_gunship/attack_start2.wav", MACHINE:GetPos(), 75, math.random(150, 250), 0.1)
			end
		end
	end

	if posX <= 0 + ballObject.size.x then
		ballObject.setVel(Vector(math.abs(ballObject.vel.x), velY))
	end

	if posY <= 0 + ballObject.size.y then
		ballObject.setVel(Vector(velX, math.abs(ballObject.vel.y)))
	end

	if posX >= SCREEN_WIDTH - ballObject.size.x * 2 then
		ballObject.setVel(Vector(-math.abs(ballObject.vel.x), velY))
	end

	--out of bounds
	if posY >= SCREEN_HEIGHT + ballObject.size.y * 4 then
		--RespawnBall()
		GAME:GameOver()
	end
end

local oldBallPositions = {}
local nextSample = 0
local function UpdateObjects()
	for k,v in pairs(objects) do
		if v.vel ~= Vector(0, 0) then
			v.lastPos = v.pos
			v.vel.x = math.Clamp(v.vel.x, -maxBallSpeed, maxBallSpeed)
			v.vel.y = math.Clamp(v.vel.y, -maxBallSpeed, maxBallSpeed)
			v.setPos(v.pos + (v.vel * FrameTime()))

			if v.id == ballObject.id then
				if RealTime() >= nextSample then
					table.insert(oldBallPositions, v.pos)
					
					if table.Count(oldBallPositions) >= 5 then
						table.remove(oldBallPositions, 1)
					end
					nextSample = RealTime() + 0.05
				end
			end
		end

		--just to not bother with col x, y all the time
		if v.size ~= Vector(v.collision.width, v.collision.height) then
			v.collision.width = v.size.x
			v.collision.height = v.size.y
		end

		-- any of them who got destroyed? let's kill them now
		if v.destroyed then
			v = nil
		end
	end
end

local function RenderObjects()
	if ballObject.vel:Length() >= maxBallSpeed - 10 then
		for i = 1, #oldBallPositions do
			local colorR = math.Remap(i, 0, #oldBallPositions, bgColor.r, ballObject.render.color.r)
			local colorG = math.Remap(i, 0, #oldBallPositions, bgColor.g, ballObject.render.color.g)
			local colorB = math.Remap(i, 0, #oldBallPositions, bgColor.b, ballObject.render.color.b)

			surface.SetDrawColor(colorR, colorG, colorB, 255)
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
			else
				local w, h = ob.size.x, ob.size.y
				surface.SetDrawColor(ob.render.color:Unpack())
				surface.DrawRect(ob.pos.x, ob.pos.y, w, h)
				surface.SetDrawColor(255, 255, 255)
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
	moveSpeed = 250
	ballSpeed = 200

	reverseControl = false
	bgColor = defaultBgColor

	lastObjectID = 0
	objects = {}
	badPowerups = {}

	padObject = CreateBoxObject(Vector(0, 0), Vector(50, 10), Color(50, 125, 255))
	padObject.currentPowerups = {}

	ballObject = CreateBoxObject(Vector(0, 0), Vector(17.5, 17.5), nil, function(x, y, w, h)
		surface.SetDrawColor(ballObject.render.color)
		surface.SetMaterial(ballMaterial)
		surface.DrawTexturedRect(x, y, w, h)
	end)

	padObject.setPos(Vector(SCREEN_WIDTH / 2 - padObject.size.x / 2, SCREEN_HEIGHT - padObject.size.y * 2))
	ballObject.setPos(padObject.pos + Vector(0, -ballObject.size.y))
	ballObject.render.color = Color(100, 200, 255)

	gameState = 1

	local hardBlocks = gameStage - 1

	--less blocks in the first stages
	local blockAmn = gameStage < #hardnessColors and gameStage or #hardnessColors
	local yAmn = math.Remap(blockAmn, 0, #hardnessColors, 80, 40)

	for x = 1, (SCREEN_WIDTH / 40) - 1 do
		for y = 1, (SCREEN_HEIGHT / yAmn) - 1 do
			local block
			local color = hardnessColors[1]
			local hardness = 1

			if y <= hardBlocks then
				local curColor = gameStage
				local hits = gameStage
				if hardBlocks > #hardnessColors then
					curColor = #hardnessColors
					hits = #hardnessColors
				end

				color = hardnessColors[curColor]
				hardness = hits
			end

			block = CreateBoxObject(Vector(40 * x, 20 * y + 40), Vector(20, 10), color)
			block.isBlock = true
			block.hardness = hardness
			currentBrickAmount = currentBrickAmount + 1
		end
	end
end

function GAME:Init()
end

function GAME:Destroy()
end

function GAME:GameOver()
	if not isGameOver then
		sound.Play("weapons/physcannon/energy_disintegrate4.wav", MACHINE:GetPos(), 75, 150, 0.5)
		sound.Play("npc/combine_gunship/gunship_ping_search.wav", MACHINE:GetPos(), 75, 150, 0.25)
		local time = 10
		if MACHINE:GetCoins() > 1 then
			time = 5
		end
		--weapons\physcannon\energy_disintegrate4.wav
		gameOverAt = RealTime() + time
		isGameOver = true
	end
end

function GAME:Start()
	gameStage = 1
	playerScore = 0
	ResetGame()
end

function GAME:Continue()
	gameState = 1
	isGameOver = false
	RespawnBall()
end

function GAME:Stop()
	objects = {}
	gameState = 0
end

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
		MACHINE:TakeCoins(1)
		gameState = 2
		return
	end

	if isGameOver then return end

	if CurTime() >= nextMusicPlay then
		local songTbl = table.Random(music)
		currentSong = songTbl[1]
		local dur = songTbl[2]

		local rng = math.random(150, 200)

		local playTime = dur / (rng / 100)
		curSongLen = playTime
		MACHINE:EmitSound(currentSong, 75, rng, 0.1)
		nextMusicPlay = CurTime() + playTime
	end

	if currentBrickAmount <= 0 then
		if gameState ~= 3 then
			gameState = 3

			if musicObject then
				musicObject:Stop()
			end

			sound.Play("friends/message.wav", MACHINE:GetPos(), 75, 250, 0.25)
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

	if thePlayer:KeyDown(IN_JUMP) then
		if not ballObject.launched then
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
	surface.SetDrawColor(45, 0, 45, 255)
	surface.DrawRect(0, 0, MARQUEE_WIDTH, MARQUEE_HEIGHT)
	surface.SetMaterial(boarder)
	surface.SetDrawColor(0, 200, 255)--, g, b, a=255)
	surface.DrawTexturedRect(0, 0, MARQUEE_WIDTH, MARQUEE_HEIGHT)

	for i = 1, 6 do
		surface.SetDrawColor(0, 200, 100)
		surface.DrawRect(i * 33, 19, 20, 10)
		surface.DrawRect(i * 33, 39, 20, 10)
		surface.DrawRect(i * 33, 59, 20, 10)
	end

	surface.SetDrawColor(255, 255, 255, 50)
	surface.DrawRect(10, MARQUEE_HEIGHT / 2 - 25, MARQUEE_WIDTH - 20, 50)
	surface.SetFont("ScoreboardDefaultTitle")
	local tw, th = surface.GetTextSize(self.Name)
	surface.SetTextColor(0, 0, 0, 255)
	surface.SetTextPos((MARQUEE_WIDTH / 2) - (tw / 2), (MARQUEE_HEIGHT / 2) - (th / 2) - 10)
	surface.SetDrawColor(0, 200, 250)
	surface.DrawText(self.Name)
	surface.SetMaterial(ballMaterial)
	surface.DrawTexturedRect(69, MARQUEE_HEIGHT / 2 - 17, 18, 18)

	surface.SetFont("ScoreboardDefault")
	local tW, tH = surface.GetTextSize("Endless Beta")
	surface.SetTextColor(0, 0, 0, 255)
	surface.SetTextPos((MARQUEE_WIDTH / 2) - (tW / 2), MARQUEE_HEIGHT / 2)
	surface.DrawText("Endless Beta")
end

-- Called every frame while the local player is nearby
-- The screen is cleared to black for you
local demoObjects = {}
function GAME:Draw()
	surface.SetDrawColor(bgColor:Unpack())
	surface.DrawRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

	if gameState == 0 then
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
				surface.SetDrawColor(hardnessColors[1]:Unpack())
				surface.DrawRect(x, y, 40, 10)
			end

			table.insert(demoObjects, pad)

			local ball = {isBall = true}
			ball.func = function(x, y)
				surface.SetDrawColor(Color(0, 200, 255))
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
				local range = 
				v.func(sin + SCREEN_WIDTH / 2 - 10, SCREEN_HEIGHT - 60)
			else
				v.func()
			end
		end

		local text = self.Name + "!"
		surface.SetFont("ContentHeader")
		local tW, tH = surface.GetTextSize(text)
		local tPosX, tPosY = SCREEN_WIDTH / 2 - tW / 2, tH + 100 + math.sin(RealTime() * 3) * 40

		surface.SetTextColor(0, 0, 0)
		surface.SetTextPos(tPosX + 2, tPosY + 2)
		surface.DrawText(text)

		surface.SetTextColor(0, 0, 0)
		surface.SetTextPos(tPosX - 2, tPosY - 2)
		surface.DrawText(text)

		surface.SetTextColor(255, 255, 255)
		surface.SetTextPos(tPosX, tPosY)
		surface.DrawText(text)

		surface.SetFont("DermaLarge")
		local tw, th = surface.GetTextSize("INSERT COIN")
		surface.SetTextColor(255, 255, 255, math.sin(RealTime() * 5) * 255)
		surface.SetTextPos((SCREEN_WIDTH / 2) - (tw / 2), SCREEN_HEIGHT - (th * 2))
		surface.DrawText("INSERT COIN")
		return
	end

	if gameState == 1 then
		local score = "Score: " .. playerScore
		surface.SetFont("DermaLarge")
		local tW, tH = surface.GetTextSize(score)
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

	local sin = math.sin(RealTime() * 2) * 10
	local color = math.Remap(sin, -10, 10, 10, 35)
	bgColor = Color(color, 0, color)

	RenderObjects()

	if isGameOver then
		local col = Color(255, 50, 50)
		local txt = "GAME OVER IN " .. math.max(0, math.floor(gameOverAt - RealTime()))

		if MACHINE:GetCoins() > 1 then
			txt = "CONTINUE IN " .. math.max(0, math.floor(gameOverAt - RealTime()))
			col = Color(100, 255, 0)
		end

		surface.SetFont("DermaLarge")
		local tw, th = surface.GetTextSize(txt)
		surface.SetTextColor(col:Unpack())
		surface.SetTextPos(SCREEN_WIDTH / 2 - tw / 2, SCREEN_HEIGHT / 2 - th / 2)
		surface.DrawText(txt)
	end

	local text = "Coins left: " .. MACHINE:GetCoins() - 1
	surface.SetFont("GModNotify")
	local tw, th = surface.GetTextSize(text)
	surface.SetTextColor(255, 100, 255, 255)
	surface.SetTextPos(10, SCREEN_HEIGHT - (th * 2))
	surface.DrawText(text)
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
	MACHINE:StopSound(currentSong)
end

function GAME:OnCoinsInserted(ply, old, new)
	MACHINE:EmitSound("garrysmod/content_downloaded.wav", 50)

	if ply ~= LocalPlayer() then return end

	if gameState == 0 and new > 0 then
		self:Start()
	end
end

function GAME:OnCoinsLost(ply, old, new)
    if ply ~= LocalPlayer() then return end

    if new == 0 then
        self:Stop()
    end

    if new > 0 then
        self:Continue()
    end
end

return GAME
--end -- For testing

--local ent = Entity(2500)
--if IsValid(ent) and ent.SetGame then
--	ent:SetGame(game)
--end