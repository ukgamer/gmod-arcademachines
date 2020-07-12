--[[
	This is pretty awful code but you're not supposed to read it anyways,
	I just wanted to be part of the arcade machines.

	Copyright 2020 PotcFdk

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at

		http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
]]

local STATE_MENU = 0
local STATE_GAME = 1
local STATE_WON  = 2
local STATE_LOST = 3

local GAME = {
	Name = 'Sudoku',
	Description = [[
	You will be presented with a 9x9 grid of fields. Some contain numbers between 1 and 9, some don't.
	This 9x9 grid is subdivided into 9 smaller 3x3 boxes.
	Your job is to fill in the missing fields with numbers between 1 and 9. These numbers have to meet certain criteria:

	Rules: Each number from 1 through 9 can only appear once per: line, column and 3x3 box.

	Controls:
	- WASD: move the cursor
	- NUMPAD 1-9: set a number
	- NUMPAD 0: clear a number
	- SPACE + NUMPAD 1-9: toggle a guess
	- SPACE + NUMPAD 0: unset all guesses
	- DEL: clear a field completely
	- ENTER: submit

	Once the sudoku is complete, you can press ENTER to check if it's correct.
	- If it's correct, you win!
	- If it's incorrect, you can either try to fix mistakes or try another one.

	You will get a prompt that tells you what to press in either case.

	GoTo-Mode:
	Alternative cursor mode. Press NUMPAD ENTER and then NUMPAD 1-9 to first select a 3x3 box and then the field within.

	数字は独身に限る]],
	SX = 500,
	SY = 500,

	state = STATE_MENU,

	check_mode = false,

	cursor = {x = 5, y = 5},

	key_handlers = {},
	pressing_key = {},

	alt_key_handlers = {},
	pressing_alt_key = {},

	grid = {},
	game_data = {},
	game_repository = {}
}

GAME.grid.border = {
	x = GAME.SX/20,
	y = GAME.SY/20
}

GAME.grid.width = {
	x = (GAME.SX/50)/3,
	y = (GAME.SY/50)/3
}

GAME.grid.length = {
	x = (GAME.SX-2*GAME.grid.border.x)/3,
	y = (GAME.SY-2*GAME.grid.border.y)/3
}

local border, width, length = GAME.grid.border, GAME.grid.width, GAME.grid.length

function GAME:GetDigitPos (digit_x, digit_y)
	return border.x + (math.floor(digit_x/3)-1)*(length.x-width.x) + (digit_x%3 + 2) * (length.x-width.x)/3 + 17,
		border.y + (math.floor(digit_y/3)-1)*(length.y-width.y) + (digit_y%3 + 2) * (length.y-width.y)/3 + 10
end

function GAME:GetGuessDigitPos (digit_x, digit_y, guess_digit)
	local guess_x = guess_digit == 9 and 10 or ((guess_digit-1)%4+1)*10
	local guess_y = guess_digit == 9 and 16 or math.floor(guess_digit/5) * 32
	return border.x + (math.floor(digit_x/3)-1)*(length.x-width.x) + (digit_x%3 + 2) * (length.x-width.x)/3 -4 + guess_x,
		border.y + (math.floor(digit_y/3)-1)*(length.y-width.y) + (digit_y%3 + 2) * (length.y-width.y)/3 + 2 + guess_y
end

function GAME:DrawGrid()
	if self:IsComplete() then
		surface.SetDrawColor(0, 255, 255, 255)
	end

	if self.check_mode then
		if self:IsValid() then
			surface.SetDrawColor(255, 255, 255, 255)
		else
			surface.SetDrawColor(255, 0, 0, 255)
		end
	else
		surface.SetDrawColor(255, 255, 255, 255)
	end

	for x = 0, 2 do
		local offset_x = x*(length.x-width.x)
		for y = 0, 2 do
			local offset_y = y*(length.y-width.y)
			surface.DrawRect(offset_x + border.x, offset_y + border.y, length.x, width.y)
			surface.DrawRect(offset_x + border.x+length.x-width.x, offset_y + border.y, width.x, length.y)
			surface.DrawRect(offset_x + border.x, offset_y + border.y+length.y-width.y, length.x, width.y)
			surface.DrawRect(offset_x + border.x, offset_y + border.y, width.x, length.y)

			-- subgrid
			for s_x = 0, 2 do
				local offset_s_x = offset_x + s_x * (length.x-width.x)/3
				for s_y = 0, 2 do
					local offset_s_y = offset_y + s_y * (length.y-width.y)/3
					surface.DrawRect(offset_s_x + border.x, offset_s_y + border.y, length.x/3, width.y/3)
					surface.DrawRect(offset_s_x + border.x+(length.x-width.x)/3, offset_s_y + border.y, width.x/3, length.y/3)
					surface.DrawRect(offset_s_x + border.x, offset_s_y + border.y+(length.y-width.y)/3, length.x/3, width.y/3)
					surface.DrawRect(offset_s_x + border.x, offset_s_y + border.y, width.x/3, length.y/3)
				end
			end
		end
	end
end

function GAME:DrawGridSelectionBox()
	surface.SetDrawColor(255, 255, 0, 255)
	if self.cursor.go_mode then -- go mode handling
		local offset_x, offset_y, scale = 0, 0, 1
		if not (self.cursor.x and self.cursor.y) then -- first stage
			offset_x, offset_y, scale = 0, 0, 3
		else
			offset_x = self.cursor.x*(length.x-width.x)
			offset_y = self.cursor.y*(length.y-width.y)
		end
		surface.DrawRect(offset_x + border.x, offset_y + border.y, (length.x-width.x)*scale, width.y)
		surface.DrawRect(offset_x + border.x+(length.x-width.x)*scale, offset_y + border.y, width.x, (length.y-width.y)*scale)
		surface.DrawRect(offset_x + border.x, offset_y + border.y+(length.y-width.y)*scale, (length.x-width.x)*scale, width.y)
		surface.DrawRect(offset_x + border.x, offset_y + border.y, width.x, (length.y-width.y)*scale)
		surface.SetDrawColor(255, 255, 0, 80)
		surface.DrawRect(offset_x + border.x, offset_y + border.y, (length.x-width.x)*scale+1, (length.y-width.y)*scale+1)
	else -- normal handling
		local x, y, s_x, s_y = math.floor(self.cursor.x/3), math.floor(self.cursor.y/3),
			self.cursor.x % 3, self.cursor.y % 3
		local offset_x = x*(length.x-width.x)
		local offset_y = y*(length.y-width.y)
		local offset_s_x = offset_x + (s_x - 1) * (length.x-width.x)/3
		local offset_s_y = offset_y + (s_y - 1) * (length.y-width.y)/3
		surface.DrawRect(offset_s_x + border.x, offset_s_y + border.y, length.x/3, width.y)
		surface.DrawRect(offset_s_x + border.x+(length.x-width.x)/3, offset_s_y + border.y, width.x, length.y/3+width.y/1.5--[[<- the width addition here is a hack; I got too tired to fix this the correct way]])
		surface.DrawRect(offset_s_x + border.x, offset_s_y + border.y+(length.y-width.y)/3, length.x/3, width.y)
		surface.DrawRect(offset_s_x + border.x, offset_s_y + border.y, width.x, length.y/3)
	end
end

function GAME:DrawGridContent(attract_mode)
	local valid, bad_entry = true
	if self.check_mode then
		valid, bad_entry = self:IsValid()
	end

	for x, col in next, self.game_data do
		for y, entry in next, col do
			if entry.digit then
				surface.SetFont("DermaLarge")
				if attract_mode then
					surface.SetTextColor(0, 150, 0, 255)
				elseif entry.seed then
					surface.SetTextColor(255, 255, 255, 255)
				else
					surface.SetTextColor(0, 255, 255, 255)
					if not valid then
						if entry == bad_entry then
							surface.SetTextColor(255, 0, 0, 255)
						end
					end
				end
				surface.SetTextPos(self:GetDigitPos(x, y))
				surface.DrawText(entry.digit)
			end
			if entry.guesses then
				for guess, set in next, entry.guesses do
					if set then
						surface.SetFont("DermaDefault")
						surface.SetTextColor(0, 255, 255, 255)
						surface.SetTextPos(self:GetGuessDigitPos(x, y, guess))
						surface.DrawText(guess)
					end
				end
			end
		end
	end
end

local KANJI do
	local K = {'乙','了','又','与','及','丈','刃','凡','勺','互','弔','井','升',
		'丹','乏','匁','屯','介','冗','凶','刈','匹','厄','双','孔','幻','斗',
		'斤','且','丙','甲','凸','丘','斥','仙','凹','召','巨','占','囚','奴',
		'尼','巧','払','汁','玄','甘','矛','込','弐','朱','吏','劣','充','妄',
		'企','仰','伐','伏','刑','旬','旨','匠','叫','吐','吉','如','妃','尽',
		'帆','忙','扱','朽','朴','汚','汗','江','壮','缶','肌','舟','芋','芝',
		'巡','迅','亜','更','寿','励','含','佐','伺','伸','但','伯','伴','呉',
		'克','却','吟','吹','呈','壱','坑','坊','妊','妨','妙','肖','尿','尾',
		'岐','攻','忌','床','廷','忍','戒','戻','抗','抄','択','把','抜','扶',
		'抑','杉','沖','沢','沈','没','妥','狂','秀','肝','即','芳','辛','迎',
		'邦','岳','奉','享','盲','依','佳','侍','侮','併','免','刺','劾','卓',
		'叔','坪','奇','奔','姓','宜','尚','屈','岬','弦','征','彼','怪','怖',
		'肩','房','押','拐','拒','拠','拘','拙','拓','抽','抵','拍','披','抱',
		'抹','昆','昇','枢','析','杯','枠','欧','肯','殴','況','沼','泥','泊',
		'泌','沸','泡','炎','炊','炉','邪','祈','祉','突','肢','肪','到','茎',
		'苗','茂','迭','迫','邸','阻','附','斉','甚','帥','衷','幽','為','盾',
		'卑','哀','亭','帝','侯','俊','侵','促','俗','盆','冠','削','勅','貞',
		'卸','厘','怠','叙','咲','垣','契','姻','孤','封','峡','峠','弧','悔',
		'恒','恨','怒','威','括','挟','拷','挑','施','是','冒','架','枯','柄',
		'柳','皆','洪','浄','津','洞','牲','狭','狩','珍','某'}
	local nK = #K
	KANJI = function() local p = math.random(1,nK) return K[p] end
end

function GAME:UpdateAttract()
	if CurTime() > (self.next_attract_tick or 0) then
		for _, col in next, self.game_data do
			local overflow = col[9]
			for line = 9, 2, -1 do
				col[line] = col[line-1]
				if col[line] and col[line].digit then
					col[line].digit = KANJI()
				end
			end
			if overflow then
				overflow.digit = nil
				col[1] = overflow
			end
		end
		self.next_attract_tick = CurTime()+0.2
	end

	if math.random()>0.8 then
		--local x, y = math.random(1,9), math.random(1,9)
		for x = 1, 9 do
			for y = 9, 1, -1 do
				if self.game_data[x][y] and self.game_data[x][y].digit then
					self.game_data[x][y].digit = KANJI()
					break
				end
			end
		end
	end

	if math.random()>0.5 then
		local x = (not self.last_attract_x_duration or self.last_attract_x_duration < 3 or math.random()>0.2) and self.last_attract_x or math.random(1,9)
		self.last_attract_x = x
		self.last_attract_x_duration = (self.last_attract_x_duration or 0)+1

		self.game_data[x][1] = self.game_data[x][1] or {}
		self.game_data[x][1].digit = KANJI()
	end
end

function GAME:DrawAttract()
	self:DrawUI()
	self:DrawGrid()
	self:UpdateAttract()
	self:DrawGridContent(true)
end

function GAME:DrawUI ()
	surface.SetFont("DermaLarge")
	surface.SetTextColor(255, 255, 255, 255)
	surface.SetTextPos(10,0)
	surface.DrawText("SUDOKU ARCADE")

	surface.SetFont("DermaDefault")
	surface.SetTextPos(400,10)
	surface.DrawText("COINS: " .. MACHINE:GetCoins())

	surface.SetTextPos(10,self.SY-30)
	surface.DrawText("Usage:    WASD to move the cursor    NUMPAD 1-9 to enter a number    NUMPAD 0 to unset")
	surface.SetTextPos(10,self.SY-18)
	surface.DrawText("    hold SPACE and NUMPAD 1-9 to toggle a guess    SPACE and NUMPAD 0 to clear all guesses")
	surface.SetTextPos(10,self.SY-5)
	surface.DrawText("    NUMPAD ENTER for \"Go-To\"-Mode    DEL to clear a field    ENTER to submit (costs 1 coin)")
end

function GAME:DrawMenu()
	surface.SetFont("DermaDefault")
	surface.SetTextPos(10,50)
	surface.DrawText("By inserting a coin, you can start the game.")
	surface.SetTextPos(10,70)
	surface.DrawText("You can edit the sudoku for as long as you want.")
	surface.SetTextPos(10,90)
	surface.DrawText("Once you're confident that you got it right, you can press ENTER.")
	surface.SetTextPos(10,110)
	surface.DrawText("This will consume one coin.")
	surface.SetTextPos(10,130)
	surface.DrawText("If you got it right, you win.")
	surface.SetTextPos(10,150)
	surface.DrawText("If you've made a mistake, it will display one random mistake with red color.")
	surface.SetTextPos(10,170)
	surface.DrawText("You can try to fix it and re-try by spending another coin.")
	surface.SetTextPos(10,190)
	surface.DrawText("Everything is explained in the arcade machine description, a short command")
	surface.SetTextPos(10,210)
	surface.DrawText("reference/summary is at the bottom!")

	surface.SetTextPos(10,290)
	surface.DrawText("Rules: Each number from 1 through 9 can only appear once per  line,  column,  3x3 box")
	surface.SetTextPos(10,310)
	surface.DrawText("Yoar goal is to fill in all empty fields so that the entire puzzle is 100 % filled with numbers")
	surface.SetTextPos(10,330)
	surface.DrawText("and all numbers meet the rules!")
end

function GAME:DrawGameOver()
	surface.SetDrawColor(0,0,0,255)
	surface.DrawRect(border.x, self.SY/3, self.SY-border.x, self.SY/3)
	surface.SetDrawColor(255,0,0,255)
	surface.DrawRect(0, self.SY/3, self.SY, width.y)
	surface.DrawRect(0, self.SY*2/3-4, self.SY, width.y)

	surface.SetFont("DermaLarge")
	surface.SetTextColor(255, 255, 255, 255)
	surface.SetTextPos(240,0)
	surface.DrawText("GAME OVER")
	local sw, sh = surface.GetTextSize("YOU LOST")
	surface.SetTextPos((self.SX-sw)/2,(self.SY-sh)/2-20)
	surface.DrawText("YOU LOST")
	surface.SetFont("DermaDefault")
	if MACHINE:GetCoins() > 0 then
		surface.SetTextPos(100,270)
		surface.DrawText("You can press SPACE to try again with you remaining coins")
		surface.SetTextPos(120,290)
		surface.DrawText("or press ENTER again to start a new game instead.")
	else
		surface.SetTextPos(25,270)
		surface.DrawText("You can insert another coin to continue or press ENTER again to start a new game instead.")
	end
end

function GAME:DrawWin()
	surface.SetDrawColor(0,0,0,255)
	surface.DrawRect(border.x, self.SY/3, self.SY-border.x, self.SY/3)
	surface.SetDrawColor(0,255,0,255)
	surface.DrawRect(0, self.SY/3, self.SY, width.y)
	surface.DrawRect(0, self.SY*2/3-4, self.SY, width.y)

	surface.SetFont("DermaLarge")
	surface.SetTextColor(255, 255, 255, 255)
	local sw, sh = surface.GetTextSize("YOU WON")
	surface.SetTextPos((self.SX-sw)/2,(self.SY-sh)/2-20)
	surface.DrawText("YOU WON")
	surface.SetFont("DermaDefault")
	if MACHINE:GetCoins() > 0 then
		surface.SetTextPos(30,270)
		surface.DrawText("Amazing! You did it! You can press ENTER to start a new game with your remaining coins.")
	else
		surface.SetTextPos(80,270)
		surface.DrawText("Amazing! You did it! You can press ENTER to go back to the main menu.")
	end
end

function GAME:InitGameData ()
	table.Empty (self.game_data)

	for x = 1, 10 do
		self.game_data[x] = {}
	end

	local x, y = 1, 1
	for digit in self.active_game:gmatch(".") do
		digit = tonumber(digit)
		if digit == 0 then digit = nil end
		self.game_data[x][y] = {
			x = x,
			y = y,
			digit = digit,
			group = math.floor(x/3)..':'..math.floor(y/3), -- the same for all in a 3x3 box
			seed = digit and true or nil
		}
		x = x + 1
		if x == 10 then -- line full, go to next line
			x = 1
			y = y + 1
		end
	end
end

function GAME:Init()
	if not self.game_repository or #self.game_repository == 0 then
		if FILE.Files.sudokugames and FILE.Files.sudokugames.path then
			local games = file.Read(FILE.Files.sudokugames.path)
			self.game_repository = string.Split(games, "\n")
		end
	end
	self.active_game = self.game_repository[math.random(1, #self.game_repository)] or "004300209005009001070060043006002087190007400050083000600000105003508690042910300"
	self:InitGameData ()
end

function GAME:Draw()
	if not IsValid(self.player) then
		self:DrawAttract()
		return
	end

	self:DrawUI()
	if self.state == STATE_MENU then
		self:DrawMenu()
	elseif self.state == STATE_GAME or self.state == STATE_WON or self.state == STATE_LOST then
		self:DrawGrid()
		self:DrawGridContent()
		self:DrawGridSelectionBox()
	end

	if self.state == STATE_LOST then
		self:DrawGameOver()
	elseif self.state == STATE_WON then
		self:DrawWin()
	end
end

function GAME:RegisterKeyHandler(key, on_handler, off_handler)
	table.insert (self.key_handlers, {key_code = key, on_callback = on_handler, off_callback = off_handler})
end

function GAME:RegisterAltKeyHandler(key, handler)
	table.insert (self.alt_key_handlers, {key_code = key, callback = handler})
end

function GAME:UnregisterAllKeyHandlers()
	table.Empty(self.key_handlers)
	table.Empty(self.alt_key_handlers)
end

function GAME:IsComplete()
	local number_count = 0
	for _, col in next, self.game_data do
		for _, entry in next, col do
			if entry.digit then
				number_count = number_count + 1
			end
		end
	end
	return number_count == 9*9
end

function GAME:IsValid()
	do -- check column rule
		for _, col in next, self.game_data do
			local numbers = {}
			for _, entry in next, col do
				if entry.digit then
					if not numbers[entry.digit] then
						numbers[entry.digit] = entry
					else
						return false, not entry.seed and entry or numbers[entry.digit]
					end
				end
			end
		end
	end

	do -- check row rule
		for y = 1, 9 do
			local numbers = {}
			for x = 1, 9 do
				local entry = self.game_data[x][y]
				if entry.digit then
					if not numbers[entry.digit] then
						numbers[entry.digit] = entry
					else
						return false, not entry.seed and entry or numbers[entry.digit]
					end
				end
			end
		end
	end

	do -- check sub-box rule
		for factor_x = 0, 2 do
			for factor_y = 0, 2 do
				local numbers = {}
				for x = 1, 3 do
					for y = 1, 3 do
						local entry = self.game_data[factor_x*3+x][factor_y*3+y]
						if entry.digit then
							if not numbers[entry.digit] then
								numbers[entry.digit] = entry
							else
								return false, not entry.seed and entry or numbers[entry.digit]
							end
						end
					end
				end
			end
		end
	end

	return true
end

function GAME:SetWinStateFromGameData()
	if self.state ~= STATE_GAME then return end

	if self:IsComplete() and self:IsValid() then
		self.state = STATE_WON
	else
		self.state = STATE_LOST
	end

	self:Stop()

	if self.state == STATE_WON then
		if MACHINE:GetCoins() > 0 then
			self:RegisterAltKeyHandler(KEY_ENTER, function()
				self:Init()
				self:Start()
				self.state = STATE_GAME
			end)
		else
			self:RegisterAltKeyHandler(KEY_ENTER, function()
				self.state = STATE_MENU
			end)
		end
	elseif self.state == STATE_LOST then
		if MACHINE:GetCoins() > 0 then
			self:RegisterKeyHandler(IN_JUMP, function()
				self:Start()
				self.state = STATE_GAME
			end)
			self:RegisterAltKeyHandler(KEY_ENTER, function()
				self:Init()
				self:Start()
				self.state = STATE_GAME
			end)
		else
			self:RegisterAltKeyHandler(KEY_ENTER, function()
				self.state = STATE_MENU
			end)
		end
	end
end

function GAME:Update()
	if not IsValid(self.player) then
		self:Stop()
		return
	end

	for _, handler in next, self.key_handlers do
		if self.player:KeyDown (handler.key_code) then
			if handler.on_callback and not self.pressing_key[handler.key_code] then
				handler.on_callback()
			end
			self.pressing_key[handler.key_code] = true
		else
			if handler.off_callback and self.pressing_key[handler.key_code] then handler.off_callback() end
			self.pressing_key[handler.key_code] = nil
		end
	end

	for _, handler in next, self.alt_key_handlers do
		if input.IsButtonDown (handler.key_code) then
			if not self.pressing_alt_key[handler.key_code] then
				self.check_mode = false -- disable check mode on any key press
				handler.callback()
			end
			self.pressing_alt_key[handler.key_code] = true
		else
			self.pressing_alt_key[handler.key_code] = nil
		end
	end
end

function GAME:Start()
	self:UnregisterAllKeyHandlers()

	self:RegisterKeyHandler(IN_MOVELEFT,  function()
		if self.cursor.go_mode then return end
		self.cursor.x = math.max(1, self.cursor.x - 1)
	end)
	self:RegisterKeyHandler(IN_MOVERIGHT, function()
		if self.cursor.go_mode then return end
		self.cursor.x = math.min(9, self.cursor.x + 1)
	end)
	self:RegisterKeyHandler(IN_FORWARD,   function()
		if self.cursor.go_mode then return end
		self.cursor.y = math.max(1, self.cursor.y - 1)
	end)
	self:RegisterKeyHandler(IN_BACK,      function()
		if self.cursor.go_mode then return end
		self.cursor.y = math.min(9, self.cursor.y + 1)
	end)

	self:RegisterKeyHandler(IN_JUMP,
		function() self.cursor.toggle_mode =  true end,
		function() self.cursor.toggle_mode = false end
	)

	local go_mode_map = {
		{x = 0, y = 2},
		{x = 1, y = 2},
		{x = 2, y = 2},
		{x = 0, y = 1},
		{x = 1, y = 1},
		{x = 2, y = 1},
		{x = 0, y = 0},
		{x = 1, y = 0},
		{x = 2, y = 0}
	}

	for i = 1, 9 do
		self:RegisterAltKeyHandler(_G['KEY_PAD_' .. i], function()
			if self.cursor.go_mode then -- GO mode!
				if not (self.cursor.x and self.cursor.y) then -- first stage
					local target = go_mode_map[i]
					self.cursor.x, self.cursor.y = target.x, target.y
				else -- second stage
					local target = go_mode_map[i]
					self.cursor.x = self.cursor.x*3 + target.x + 1
					self.cursor.y = self.cursor.y*3 + target.y + 1
					self.cursor.go_mode = false
				end
			else -- normal mode!
				if not self.game_data[self.cursor.x][self.cursor.y].seed then
					if self.cursor.toggle_mode then
						if not self.game_data[self.cursor.x][self.cursor.y].guesses then
							self.game_data[self.cursor.x][self.cursor.y].guesses = {[i] = true}
						else
							self.game_data[self.cursor.x][self.cursor.y].guesses[i] = not self.game_data[self.cursor.x][self.cursor.y].guesses[i]
						end
					else
						self.game_data[self.cursor.x][self.cursor.y].digit = i
					end
				end
			end
		end)
	end

	self:RegisterAltKeyHandler(KEY_PAD_ENTER, function()
		self.cursor.go_mode = true
		self.cursor.x = nil
		self.cursor.y = nil
	end)

	self:RegisterAltKeyHandler(KEY_PAD_0, function()
		if not self.game_data[self.cursor.x][self.cursor.y].seed then
			if self.cursor.toggle_mode then
				self.game_data[self.cursor.x][self.cursor.y].guesses = nil
			else
				self.game_data[self.cursor.x][self.cursor.y].digit = nil
			end
		end
	end)

	self:RegisterAltKeyHandler(KEY_DELETE, function()
		if not self.game_data[self.cursor.x][self.cursor.y].seed then
			self.game_data[self.cursor.x][self.cursor.y].digit = nil
			self.game_data[self.cursor.x][self.cursor.y].guesses = nil
		end
	end)

	self:RegisterAltKeyHandler(KEY_ENTER, function()
		if self:IsComplete() then
			MACHINE:TakeCoins(1)
			self.check_mode = true
		end
	end)
end

function GAME:Stop()
	self:UnregisterAllKeyHandlers()
end

function GAME:OnStartPlaying(ply)
	if ply ~= LocalPlayer() then return end

	FILE:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/sudoku/games.txt", "sudokugames")

	self.player = ply
	self.state = STATE_MENU
	self:Init()
	self:Start()
end

function GAME:OnStopPlaying(ply)
	if ply ~= LocalPlayer() then return end
	self.player = nil
	self:Stop()
end

function GAME:OnCoinsInserted(ply, old, new)
	if ply ~= LocalPlayer() then return end
	if self.state == STATE_MENU then
		self:Init()
	end
	if self.state == STATE_MENU or self.state == STATE_LOST then
		self.state = STATE_GAME
		self:Start()
	end
end

function GAME:OnCoinsLost(ply, old, new)
    if ply ~= LocalPlayer() then return end
	self:SetWinStateFromGameData()
end

return GAME
