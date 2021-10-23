--Tetris theme licensed under the Creative Commons Attribution-Share Alike 3.0 Unported license.
--https://commons.wikimedia.org/wiki/File:Tetris_theme.ogg

--8Bit songs
--https://www.fesliyanstudios.com/policy

--Example code used
--https://github.com/OneLoneCoder/videos/blob/master/OneLoneCoder_Tetris.cpp

--Notris, Tetris like game by Henka

local GAME = {}

GAME.Name = "Notris"
GAME.Author = "Henke"
GAME.Description = [[Not Tetris, but almost!
Strafe Keys (A & D) to move block.
Back Key (S) to push block down.
Forward Key (W) to rotate block.
Jump Key (SPACE) to instantly drop block.
Sprint Key (L Shift) to swap blocks.
Reload Key (R) to switch between mute modes.
]]

local resourceLink = "https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/notris/"

local songFiles = {
	"Moskau",
	"Polkka",
	"Powerup",
	"Retro_funk",
	"Surf",
	"Tetris_theme",
}

GAME.CabinetArtURL = resourceLink .. "art/ms_acabinet_artwork.png"
GAME.LateUpdateMarquee = true

local thePlayer = nil
local gameOverAt = 0
local gameState = 0 -- 0 = Attract mode 1 = Playing 2 = Waiting for coins update, 3 = gameOver

local LINES_LEVEL_UP = 5

local TICK_TIME = 0.05 --every 0.05 it will update the logic

--we are scaling up a 12x18 field of tetris
local FIELD_WIDTH, FIELD_HEIGHT = 12, 25
local FIELD_SCALE = 20
local FIELD_OFFSET_Y = -120

local score = 0
local lineCount = 0
local level = 0

local field = {}
local fallingLines = {}
local pieces = {}

local curPiece = -1
local nextPiece = -1

local speedTime = 1
local nextForcedDownMove = 0
local nextTick = 0

local startX = 4
local curX = startX
local curY = 0
local curRotation = 0

----------INPUTS----------
--different times for movement inputs
local nextDownMove  = 0
local nextRot       = 0
local nextSideMove1 = 0
local nextSideMove2 = 0

--check if held or not, allow fastly clicking keyboard
local dropHeld = false
local rotHeld  = false
local swapHeld = false
local muteHeld = false

local sideMove1Held = false
local sideMove2Held = false
local downMoveHeld  = false

--insta dropping piece
local shouldDropIt  = false
--Add slight delay after dropping to prevent double drops
local droppedAt = 0
-------------------------

----SOUND----
local soundList = {}
local muteMode = 1 --1 not muted, 2 music, 3 all off
-------------

-----ART-----
local marqueeArt
local backgroundArt

local soundIcon
local xMarkIcon

local backgroundCount = 9 --how many backgrounds exist on the atlas
local bgOffset = 1 / backgroundCount
local currentBackground = 1
local backgroundColor = Color(75, 75, 75)

-------------

----MUSIC----
local musicList = {}
local currentSong
-------------

function GAME:Setup()
	backgroundColor = HSVToColor(RealTime() * 100 % 360, 1, 0.5)
	self:RandomizePieces()

	for x = 1, FIELD_WIDTH do
		for y = 1, FIELD_HEIGHT do
			field[y * FIELD_WIDTH + x] = (x == 1 or x == FIELD_WIDTH or y == FIELD_HEIGHT) and 1 or 0
		end
	end
end

local function LoadResources()

	SOUND:LoadFromURL(resourceLink .. "sfx/4_lines_cleared.ogg", "4_lines")
	SOUND:LoadFromURL(resourceLink .. "sfx/block_placed.ogg", "placed")
	SOUND:LoadFromURL(resourceLink .. "sfx/block_rotated.ogg", "rotate")
	SOUND:LoadFromURL(resourceLink .. "sfx/game_over.ogg", "game_over")
	SOUND:LoadFromURL(resourceLink .. "sfx/line_cleared.ogg", "line")
	SOUND:LoadFromURL(resourceLink .. "sfx/wall.ogg", "wall")
	SOUND:LoadFromURL(resourceLink .. "sfx/switch.ogg", "swap")

	for k, song in ipairs(songFiles) do
		local name = "music_" .. song

		SOUND:LoadFromURL(resourceLink .. "music/" .. song .. ".ogg", name)
		table.insert(musicList, name)
	end

	IMAGE:LoadFromURL(resourceLink .. "art/ms_acabinet_marque.png", "marquee", function(image)
		marqueeArt = image.mat
		CABINET:UpdateMarquee()
	end)

	IMAGE:LoadFromURL(resourceLink .. "art/background_atlas.png", "bg", function(image)
		backgroundArt = image.mat
	end)


	IMAGE:LoadFromMaterial("voice/icntlk_sv", "soundIcon")
	IMAGE:LoadFromMaterial("debug/particleerror", "xMark")

	soundIcon = IMAGE.Images["soundIcon"].mat
	xMarkIcon = IMAGE.Images["xMark"].mat

end

function GAME:Init()
	LoadResources()
	self:Setup()
end

function GAME:Destroy()
	score = 0
	level = 0
	speedTime = 1

	lineCount = 0
	field = {}
	fallingLines = {}
	pieces = {}

	curPiece = -1
	nextPiece = -1
	currentLineCount = 0
	nextForcedDownMove = 0

	nextTick = 0
	tickCounter = 0

	curX = startX
	curY = 0
	curRotation = 0

	shouldDropIt = false
	droppedAt = 0
end

local function PlaySound(snd)
	if muteMode == 3 or not SOUND:ShouldPlaySound() then return end
	if SOUND.Sounds[snd] and IsValid(SOUND.Sounds[snd].sound) then
		SOUND.Sounds[snd].sound:SetTime(0)
		SOUND.Sounds[snd].sound:Set3DFadeDistance(64, 128)
		SOUND.Sounds[snd].sound:SetVolume(0.5)
		SOUND.Sounds[snd].sound:Play()
		table.insert(soundList, snd)
	end
end

local function PauseSound(snd) --no args means all sounds in soundList pause
	if snd and SOUND.Sounds[snd] and IsValid(SOUND.Sounds[snd].sound) then
		SOUND.Sounds[snd].sound:Pause()
	else
		for _, sound in ipairs(soundList) do
			if SOUND.Sounds[sound] and IsValid(SOUND.Sounds[sound].sound) then
				SOUND.Sounds[sound].sound:Pause()
			end
		end
	end
end

local function ShuffleMusic()
	if muteMode ~= 1 or table.IsEmpty(musicList) then return end

	local songNum = math.random(1, #musicList)
	local song = musicList[songNum]

	--we don't want to play the same song 2 times in a row
	if song == currentSong then
		if songNum < #musicList then
			song = musicList[songNum + 1]
		else
			song = musicList[1]
		end
	end

	if SOUND.Sounds[song] and IsValid(SOUND.Sounds[song].sound) then
		currentSong = SOUND.Sounds[song].sound
		currentSongLength = currentSong:GetLength()
		currentSong:SetVolume(0.25)
		currentSong:Play()
	end
end

local function UpdateMusic()
	if muteMode == 1 and IsValid(currentSong) and currentSong:GetState() == 0 then
		ShuffleMusic()
	end
end

local function StopMusic()
	if currentSong and IsValid(currentSong) then
		currentSong:Pause()
	end
end

-- 1 = normal, 2 = mute music, 3 = mute all
local function MuteToggle()
	muteMode = muteMode % 3 + 1

	if muteMode > 1 then
		StopMusic()
	else
		ShuffleMusic()
	end

	if muteMode == 3 then
		PauseSound()
	end
end

function GAME:Start()
	self:Reset()
	ShuffleMusic()
	gameState = 1
end

function GAME:Reset()
	self:Destroy()
	self:Setup()
	PauseSound()
	StopMusic()
end

function GAME:GameOver()
	StopMusic()
	PauseSound()
	PlaySound("game_over")
	gameState = 3
	gameOverAt = RealTime()
end

function GAME:Stop()
	self:Reset()
	gameState = 0
end

local colors = {
	[1] = Color(255, 255, 255),--white
	[2] = Color(0, 247, 247),  --cyan
	[3] = Color(255, 54, 54),    --red
	[4] = Color(0, 230, 25),    --green
	[5] = Color(240, 240, 0),  -- yellow
	[6] = Color(240, 37, 240),  --magenta
	[7] = Color(50, 120, 255),    --blue
	[8] = Color(255, 136, 8)   -- orange
}

--Shapes
local tetros = {
	[0] = {--nothing
		0,
	},
	{
		0,0,2,0,
		0,0,2,0,
		0,0,2,0,
		0,0,2,0
	},
	{
		0,0,3,0,
		0,3,3,0,
		0,3,0,0,
		0,0,0,0
	},
	{
		0,4,0,0,
		0,4,4,0,
		0,0,4,0,
		0,0,0,0
	},
	{
		0,0,0,0,
		0,5,5,0,
		0,5,5,0,
		0,0,0,0
	},
	{
		0,0,6,0,
		0,6,6,0,
		0,0,6,0,
		0,0,0,0
	},
	{
		0,0,7,0,
		0,0,7,0,
		0,7,7,0,
		0,0,0,0
	},
	{
		0,8,0,0,
		0,8,0,0,
		0,8,8,0,
		0,0,0,0
	},
}

function GAME:RandomizePieces()
	if table.IsEmpty(pieces) then --fill table with 4 of each piece to pick from
		for tetro = 1, #tetros do
			--for i = 1, 2 do -- insert this piece 4 times
				table.insert(pieces, tetro)
			--end
		end
	end

	if curPiece == -1 then
		curPiece = table.remove(pieces, math.random(1, #pieces))
	else
		curPiece = nextPiece
	end

	local key = math.random(1, #pieces)

	if pieces[key] == nextPiece or pieces[key] == curPiece then
		for i = 1, #pieces do
			key = math.random(1, #pieces)
			local p = pieces[key]
			if p ~= nextPiece or p ~= curPiece then
				break
			end
		end
	end

	nextPiece = table.remove(pieces, key)
end

local function RotateBlock(x, y, r, pieceCheck)
	local sum = 0

	-- 0, 1, 2, 3
	y = y - 1
	x = x - 1


	pieceCheck = pieceCheck or curPiece
	-- straight and square don't apply to this
	if pieceCheck ~= 1 and pieceCheck ~= 4 then
		local scrMid = FIELD_WIDTH / 2

		local dir = curX < scrMid  and -1 or curX > scrMid and 1 or 0
		if dir < 0 and r == 270 then
			x = x - 1
		end

		if dir > 0 and r == 90 then
			x = x + 1
		end
	end

	sum = r == 0   and (y * 4) + x +  1       or sum
	sum = r == 90  and 12 + (y + 1) - (x * 4) or sum
	sum = r == 180 and 15 - (y * 4) - (x - 1) or sum
	sum = r == 270 and 3  - (y - 1) + (x * 4) or sum

	return sum
end

local function CanPlace(piece, rot, posX, posY)
	for x = 1, 4 do
		for y = 1, 4 do


			local pi = RotateBlock(x, y, rot, piece)
			local fi = (posY + y) * FIELD_WIDTH + (posX + x)

			if posX + x >= 0 and posX + x <= FIELD_WIDTH + 1 and posY + y >= 0 and posY + y <= FIELD_HEIGHT + 1 then

				local p = tetros[piece] and tetros[piece][pi] or 0

				if p and p ~= 0 and field[fi] ~= 0 then
					return false
				end
			else
				return false
			end
		end
	end

	return true
end

local function TryMovePiece(stepX, stepY, rot, held)
	rot = rot or 0
	local sumR = curRotation + rot <= 270 and curRotation + rot or 0
	local sumX = curX + (stepX or 0)
	local sumY = curY + (stepY or 0)

	if CanPlace(curPiece, sumR, sumX, sumY) then
		if curRotation ~= sumR then
			PlaySound("rotate")
		end

		curRotation = sumR
		curX = sumX
		curY = sumY
	elseif not held then
		PlaySound("wall")
	end
end

local function TrySwapPiece()
	if CanPlace(nextPiece, curRotation, curX, curY) then
		local oldPiece = curPiece
		curPiece = nextPiece
		nextPiece = oldPiece
		PlaySound("swap")
	end
end

function GAME:UpdateInputs()

	if thePlayer:KeyDown(IN_RELOAD) then
		if not muteHeld then
			MuteToggle()
			muteHeld = true
		end
	else
		muteHeld = false
	end

	if thePlayer:KeyDown(IN_JUMP) then
		if not dropHeld then
			if gameState == 3 then
				if COINS:GetCoins() > 1 then
					COINS:TakeCoins(1)
					self:Start()
				end
			elseif RealTime() > droppedAt + 0.2 then
				shouldDropIt = true
			end

			dropHeld = true
		end
	else
		dropHeld = false
	end

	if gameState == 3 then return end

	if thePlayer:KeyDown(IN_FORWARD) then
		if not rotHeld or RealTime() > nextRot then
			TryMovePiece(0, 0, 90, rotHeld)
			nextRot = RealTime() + 0.2
		end
		rotHeld = true
	else
		rotHeld = false
	end

	if thePlayer:KeyDown(IN_MOVELEFT) then
		if not sideMove1Held or RealTime() >= nextSideMove1 then
			TryMovePiece(-1, nil, nil, sideMove1Held)
			nextSideMove1 = RealTime() + 0.2
		end
		sideMove1Held = true
	else
		sideMove1Held = false
	end

	if thePlayer:KeyDown(IN_MOVERIGHT) then
		if not sideMove2Held or RealTime() >= nextSideMove2 then
			TryMovePiece(1, nil, nil, sideMove2Held)
			nextSideMove2 = RealTime() + 0.2
		end
		sideMove2Held = true
	else
		sideMove2Held = false
	end

	if thePlayer:KeyDown(IN_BACK) then
		if not downMoveHeld or RealTime() >= nextDownMove then
			TryMovePiece(nil, 1, nil, downMoveHeld)
			nextDownMove = RealTime() + 0.15
		end
		downMoveHeld = true
	else
		downMoveHeld = false
	end

	if thePlayer:KeyDown(IN_SPEED) then
		if not swapHeld then
			TrySwapPiece()
		end

		swapHeld = true
	else
		swapHeld = false
	end
end

local function GetDropY()
	local validY = 0

	for i = curY, FIELD_HEIGHT do
		if CanPlace(curPiece, curRotation, curX, i) then
			validY = i
		else
			return validY
		end
	end
end

local nextAttractUpdate = 0
local attractHasFoundSpot = false
local bestAttractX = 0
local bestRotation = 0
local swapPiece = -1
local dropTime = 0

local function FindSpot()
	attractHasFoundSpot = true
	bestAttractX = 0
	bestRotation = 0
	swapPiece = -1
	dropTime = RealTime() + 1

	local bestY = 0

	for r = 0, 3 do
		r = r * 90
		for x = 0, FIELD_WIDTH-3 do
			for y = 0, FIELD_HEIGHT do
				if CanPlace(curPiece, r, x, y) and y > bestY then
					bestAttractX = x
					bestY = y
					bestRotation = r
					swapPiece = curPiece
				end

				if CanPlace(nextPiece, r, x, y) and y > bestY then
					bestAttractX = x
					bestY = y
					bestRotation = r
					swapPiece = nextPiece
				end

			end
		end
	end
end

local function AttractModePlay()

	if not attractHasFoundSpot then --resets when placed
		FindSpot()
		return --less spastic behaviour
	end

	if curRotation ~= bestRotation then
		TryMovePiece(0, 0, bestRotation)
	end

	if curPiece ~= swapPiece then
		TrySwapPiece()
	end

	if curX ~= bestAttractX then
		local dir = bestAttractX > curX and 1 or bestAttractX < curX and -1

		TryMovePiece(dir, nil, nil, true)
		dropTime = RealTime() + 1
	end

	if RealTime() >= dropTime then
		shouldDropIt = true
	end
end

function GAME:Update()
	local now = RealTime()

	if gameState == 0 then
		if now > nextAttractUpdate then
			AttractModePlay()
			nextAttractUpdate = now + math.Rand(0.1, 0.5)
		end
	elseif not IsValid(thePlayer) then
		self:Stop()
		return
	else
		self:UpdateInputs()
	end

	UpdateMusic()
	-- game over
	if gameState == 3 then
		-- if we don't have enough coins we stop, shouldn't be possible to be less then 1 coin
		if COINS:GetCoins() == 1 and now > gameOverAt + 5 then
			COINS:TakeCoins(1)
		end
		return
	end

	if shouldDropIt then
		curY = GetDropY()
		shouldDropIt = false
		nextTick = now
		nextForcedDownMove = now
		droppedAt = now
	end

	if now < nextTick then return end

	nextTick = now + TICK_TIME

	--Fall on this tick if there are lines
	if not table.IsEmpty(fallingLines) then
		for k, line in ipairs(fallingLines) do
			for x = 2, FIELD_WIDTH-1 do
				for y = line, 2, -1 do
					field[y * FIELD_WIDTH + x] = field[(y - 1) * FIELD_WIDTH + x]
				end
			end

			lineCount = lineCount + 1
			if lineCount % LINES_LEVEL_UP == 0 then
				level = level + 1
				backgroundColor = HSVToColor(RealTime() % 360, 1, 0.5)
				speedTime = speedTime / 1.08
			end
		end

		local lines = #fallingLines
		if lines > 3 then
			PlaySound("4_lines")
		else
			PlaySound("line")
		end
		score = score + (lines * lines) * 100 --better be collecting those lines :p

		table.Empty(fallingLines)
	end

	if now < nextForcedDownMove then return end

	nextForcedDownMove = now + speedTime
	if CanPlace(curPiece, curRotation, curX, curY + 1) then
		curY = curY + 1
		return
	end

	-- Place piece
	for x = 1, 4 do
		for y = 1, 4 do

			local object = tetros[curPiece] and tetros[curPiece][RotateBlock(x, y, curRotation)]
			if object and object > 0 then
				field[(curY + y) * FIELD_WIDTH + (curX + x)] = curPiece + 1
			end
		end
	end

	PlaySound("placed")
	--for attract mode
	attractHasFoundSpot = false
	--25 score for placing a piece
	score = score + 25

	-- Check lines
	for y = 1, 4 do
		if curY + y < FIELD_HEIGHT then
			local hasLine = true

			for x = 2, FIELD_WIDTH-1 do
				local object = field[(curY + y) * FIELD_WIDTH + x]
				if object and hasLine then --Check if previous line was true and check if this is too
					hasLine = object > 0
				end
			end

			if hasLine then --all blocks matched
				for x = 2, FIELD_WIDTH-1 do
					field[(curY + y) * FIELD_WIDTH + x] = 0
				end

				table.insert(fallingLines, curY + y)
			end
		end
	end

	-- Next piece
	curX = startX
	curY = 0
	curRotation = 0

	self:RandomizePieces()

	-- Can't fit?
	if not CanPlace(curPiece, curRotation, curX, curY) then
		if gameState == 0 then
			self:Reset()
		else
			self:GameOver()
		end
	end
end

-- Called once on init
function GAME:DrawMarquee()
	if not marqueeArt then return end

	surface.SetMaterial(marqueeArt)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawTexturedRect(0, 0, MARQUEE_WIDTH, MARQUEE_HEIGHT)
end

local FIELD_RECT_X = FIELD_SCALE + 3 * FIELD_SCALE
local FIELD_RECT_Y = FIELD_OFFSET_Y + 3 * FIELD_SCALE
local FIELD_RECT_W = FIELD_WIDTH * FIELD_SCALE - FIELD_SCALE * 2 -2
local FIELD_RECT_H = FIELD_HEIGHT * FIELD_SCALE - FIELD_SCALE - 2

local function DrawGameOver()
	local text = "GAME OVER"

	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawRect(FIELD_RECT_X, FIELD_RECT_Y, FIELD_RECT_W, FIELD_RECT_H)

	surface.SetTextColor(255, 255, 255)
	surface.SetFont("ScoreboardDefaultTitle")
	local tW, tH = surface.GetTextSize(text)
	surface.SetTextPos(FIELD_SCALE / 2 + FIELD_WIDTH / 2 + tW / 2, FIELD_SCALE * 2 + FIELD_HEIGHT * 2 + tH * 2)
	surface.DrawText(text)

	local insert = "INSERT COIN TO RESTART"
	if COINS:GetCoins() > 1 then
		insert = "PRESS SPACE TO RESTART"
	end

	tW, tH = surface.GetTextSize(insert)
	surface.SetTextPos(SCREEN_WIDTH / 2 - tW / 2, SCREEN_HEIGHT-tH)
	surface.DrawText(insert)
end

local sampMod = 11
local fallOff = 0.1
local songSamples = {}
local lastSample = 1
local nextBackground = 1

local function UpdateBackground()
	local now = RealTime()

	if gameState == 3 then
		surface.SetDrawColor(255, 0, 0, 255)
	else
		local alphaValue = 0

		if muteMode == 1 and IsValid(currentSong) then
			currentSong:FFT(songSamples, 1)

			if not table.IsEmpty(songSamples) then
				local sample = songSamples[1] * sampMod

				if sample < lastSample then
					sample = Lerp(fallOff, lastSample, sample)
				end

				alphaValue = math.Clamp(sample * 255, 85, 255)
				surface.SetDrawColor(backgroundColor.r, backgroundColor.g, backgroundColor.b, alphaValue)

				lastSample = sample
			end
		else
			alphaValue = 25 + math.abs(math.sin(now * 0.5)) * 255
			surface.SetDrawColor(backgroundColor.r, backgroundColor.g, backgroundColor.b, alphaValue)
		end

		--Try change background when it's dark, but if it takes too long we swap anyway
		if now > nextBackground and alphaValue <= 50 or now > nextBackground + 5 then
			currentBackground = math.random(1, backgroundCount)
			nextBackground = now + 15
		end
	end

	if backgroundArt then
		surface.SetMaterial(backgroundArt)
		surface.DrawTexturedRectUV(FIELD_RECT_X, FIELD_RECT_Y, FIELD_RECT_W, FIELD_RECT_H, bgOffset * currentBackground, 0, bgOffset * currentBackground - bgOffset, 1)
	end
end

function GAME:Draw()
	--bg
	UpdateBackground()

	for x = 1, FIELD_WIDTH do
		for y = 1, FIELD_HEIGHT do
			--Draw board/placed pieces
			local object = field[y * FIELD_WIDTH + x]
			if object and object ~= 0 then
				surface.SetDrawColor(colors[object])
				surface.DrawRect((x + 2) * FIELD_SCALE, FIELD_OFFSET_Y + (y + 2) * FIELD_SCALE, FIELD_SCALE - 2, FIELD_SCALE - 2)
			end
		end
	end

	local THREE_QUARTER = SCREEN_WIDTH / 4 * 3

	for x = 1, 4 do
		for y = 1, 4 do
			--Draw main piece & ghost
			local object = tetros[curPiece] and tetros[curPiece][RotateBlock(x, y, curRotation)]
			if object and object > 0 then
				local color = colors[object]
				if gameState == 3 then
					surface.SetDrawColor(255, 0, 0, 100 + math.Clamp(math.abs(math.sin(RealTime() * 2)), 0, 1) * 155)
				else
					surface.SetDrawColor(color)
				end

				--Draw piece
				local dX = (curX + x + 2) * FIELD_SCALE
				surface.DrawRect(dX, FIELD_OFFSET_Y + (curY + y + 2) * FIELD_SCALE, FIELD_SCALE - 2, FIELD_SCALE - 2)

				--Draw ghost
				surface.SetDrawColor(255, 255, 255)
				surface.DrawOutlinedRect(dX, FIELD_OFFSET_Y + (y + 2) * FIELD_SCALE + GetDropY() * FIELD_SCALE, FIELD_SCALE - 2, FIELD_SCALE - 2, 2)
			end

			--Draw next piece
			local drawnPiece = tetros[nextPiece] and tetros[nextPiece][RotateBlock(x, y, 0)]
			if drawnPiece and drawnPiece > 0 then
				surface.SetDrawColor(colors[drawnPiece])
				surface.DrawRect(THREE_QUARTER + (x * FIELD_SCALE) - 2 * FIELD_SCALE, (y * FIELD_SCALE) + 50, FIELD_SCALE - 2, FIELD_SCALE - 2)
			end
		end
	end

	surface.SetTextColor(255, 255, 255)
	surface.SetFont("ChatFont")

	local text = "NEXT BLOCK"
	local tW, tH = surface.GetTextSize(text)
	surface.SetTextPos(THREE_QUARTER - tW / 2 + FIELD_SCALE, FIELD_SCALE * 2)
	surface.DrawText(text)

	surface.SetFont("ScoreboardDefaultTitle")

	text = "SCORE: " .. score
	tW, tH = surface.GetTextSize(text)
	surface.SetTextPos(THREE_QUARTER - tW / 2 + FIELD_SCALE, tH + SCREEN_HEIGHT / 3)
	surface.DrawText(text)

	text = "LEVEL: " .. level
	tW, tH = surface.GetTextSize(text)
	surface.SetTextPos(THREE_QUARTER - tW / 2 + FIELD_SCALE, tH + SCREEN_HEIGHT / 2.4) --No clue why this is 2.4 and not 2.5
	surface.DrawText(text)

	text = "LINES: " .. lineCount
	tW, tH = surface.GetTextSize(text)
	surface.SetTextPos(THREE_QUARTER - tW / 2 + FIELD_SCALE, tH + SCREEN_HEIGHT / 2)
	surface.DrawText(text)

	if gameState == 0 then
		surface.SetFont("DermaLarge")
		local tw, th = surface.GetTextSize("INSERT COIN")
		surface.SetTextColor(255, 255, 255, math.sin(RealTime() * 5) * 255)
		surface.SetTextPos((SCREEN_WIDTH / 2) - (tw / 2), SCREEN_HEIGHT - (th * 2))
		surface.DrawText("INSERT COIN")
		return
	end

	text = "COINS: " .. COINS:GetCoins() - 1
	tW, tH = surface.GetTextSize(text)
	surface.SetTextPos(THREE_QUARTER - tW / 2 + FIELD_SCALE, SCREEN_HEIGHT / 1.25)
	surface.DrawText(text)

	local soundIconPosX, soundIconPosY = SCREEN_WIDTH - 42, 10

	if muteMode == 2 then
		surface.SetDrawColor(255, 128, 0, 50)
	elseif muteMode == 3 then
		surface.SetDrawColor(255, 0, 0, 50)
	else
		surface.SetDrawColor(255, 255, 255, 50)
	end

	surface.SetMaterial(soundIcon)
	surface.DrawTexturedRect(soundIconPosX, soundIconPosY, 32, 32)

	if muteMode == 3 then
		surface.SetMaterial(xMarkIcon)
		surface.DrawTexturedRect(soundIconPosX, soundIconPosY, 32, 32)
	end

	if gameState == 3 then
		DrawGameOver()
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

		StopMusic()
		PauseSound()
	end
end

function GAME:OnCoinsInserted(ply, old, new)
	if ply ~= LocalPlayer() then return end

	-- If a fullupdate occurs then the game will be reset, so when the player inserts a coin again
	-- old will not be 0 so we can't use that - instead check your if game state has reset to attract mode
	if new >= 1 and gameState == 0 then
		self:Start()
	end

	if new > 1 and gameState == 3 then
		self:Start()
		COINS:TakeCoins(1)
	end
end

function GAME:OnCoinsLost(ply, old, new)
	if ply ~= LocalPlayer() then return end

	if new == 0 then
		self:Stop()
	end
end

return GAME
