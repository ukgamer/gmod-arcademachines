local GAME = {}
local DOOM_URL = "https://www.playdosgames.com/play/doom/"

GAME.Name = "DOOM"
GAME.Description = [[The original DOOM game.
WASD to move,
R to interact,
SPACE to shoot,
SHIFT to strafe left and right,
Numerical keys to switch weapons,
M to show the map]]

GAME.LateUpdateMarquee = true

local function is_chromium()
	if BRANCH == "x86-64" or BRANCH == "chromium" then return true end -- chromium also exists in x86 and on the chromium branch
	return jit.arch == "x64" -- when x64 and chromium are finally pushed to stable
end

function GAME:InitializeEmulator()
	if IsValid(self.Panel) then
		self.Panel:Remove()
	end

	self.Ready = false

	local html = vgui.Create("DHTML")
	html:SetPaintedManually(true)
	html:OpenURL(DOOM_URL)

	local doom_game = self
	function html:OnDocumentReady()
		doom_game.Ready = true

		self:QueueJavascript([[{
			var canvas = document.getElementById("canvas");
			var header = document.getElementsByTagName("header")[0];

			header.style.display = "none";
			canvas.style.position = "fixed";
			canvas.style.padding = "0";
			canvas.style.margin = "0";
			canvas.style.top = "0";
			canvas.style.left = "0";
			canvas.style.width = "100%";
			canvas.style.transform = "scale(0.75, 1.2) translate(-90px, 40px)";
			canvas.focus();

			function simulateKeyEvent(eventType, keyCode, charCode) {
				var e = document.createEventObject ? document.createEventObject() : document.createEvent("Events");
				if (e.initEvent) e.initEvent(eventType, true, true);

				e.keyCode = keyCode;
				e.which = keyCode;
				e.charCode = charCode;

				// Dispatch directly to Emscripten's html5.h API (use this if page uses emscripten/html5.h event handling):
				if (typeof JSEvents !== 'undefined' && JSEvents.eventHandlers && JSEvents.eventHandlers.length > 0) {
					for(var i = 0; i < JSEvents.eventHandlers.length; ++i) {
						if ((JSEvents.eventHandlers[i].target == Module['canvas'] || JSEvents.eventHandlers[i].target == window)
						&& JSEvents.eventHandlers[i].eventTypeString == eventType) {
							JSEvents.eventHandlers[i].handlerFunc(e);
						}
					}
				} else {
					// Dispatch to browser for real (use this if page uses SDL or something else for event handling):
					Module['canvas'].dispatchEvent ? Module['canvas'].dispatchEvent(e) : Module['canvas'].fireEvent("on" + eventType, e);
				}
			}
		}]])
	end

	self.Panel = html
end


function GAME:Init()
	IMAGE:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/doom/logo.png", "doom_guy_logo", function(image)
		CABINET:UpdateMarquee()
	end)

	if not is_chromium() then return end
end

function GAME:Destroy()
	if not is_chromium() then return end
	if IsValid(self.Panel) then
		self.Panel:Remove()
	end
end

local current_player = nil
local has_paid = false
local next_coins_request = 0

local keys_down = {}
function GAME:HandleKey(game_key, key_code, key_char)
	if input.IsKeyDown(game_key) then
		if not keys_down[game_key] then
			if IsValid(self.Panel) then
				self.Panel:QueueJavascript([[simulateKeyEvent('keydown', ]] .. key_code .. [[, ']] .. key_char .. [[');]])
			end
			keys_down[game_key] = true
		end
	else
		if keys_down[game_key] then
			if IsValid(self.Panel) then
				self.Panel:QueueJavascript([[simulateKeyEvent('keyup', ]] .. key_code .. [[, ']] .. key_char .. [[');]])
			end
			keys_down[game_key] = false
		end
	end
end

local pause_key_code = 19
local pause_key_name = "Pause"
local paused = false
function GAME:Pause()
	if paused then return end
	if IsValid(self.Panel) then
		self.Panel:QueueJavascript([[simulateKeyEvent('keydown', ]] .. pause_key_code .. [[, ']] .. pause_key_name .. [[');]])
		self.Panel:QueueJavascript([[simulateKeyEvent('keyup', ]] .. pause_key_code .. [[, ']] .. pause_key_name .. [[');]])
	end
	paused = true
end

function GAME:UnPause()
	if not paused then return end
	if IsValid(self.Panel) then
		self.Panel:QueueJavascript([[simulateKeyEvent('keydown', ]] .. pause_key_code .. [[, ']] .. pause_key_name .. [[');]])
		self.Panel:QueueJavascript([[simulateKeyEvent('keyup', ]] .. pause_key_code .. [[, ']] .. pause_key_name .. [[');]])
	end
	paused = false
end

function GAME:Update()
	if not IsValid(current_player) or not self.Ready or not IsValid(self.Panel) then return end

	if has_paid and next_coins_request <= CurTime() then
		has_paid = false
		self:Pause()
	end

	if not has_paid then return end

	-- move forward
	local forward_key = input.LookupBinding("+forward", true)
	if forward_key then
		self:HandleKey(input.GetKeyCode(forward_key), 38, "ArrowUp")
	end

	-- move back
	local back_key = input.LookupBinding("+back", true)
	if back_key then
		self:HandleKey(input.GetKeyCode(back_key), 40, "ArrowDown")
	end

	-- rotate left
	local left_key = input.LookupBinding("+moveleft", true)
	if left_key then
		self:HandleKey(input.GetKeyCode(left_key), 37, "ArrowLeft")
	end

	-- rotate right
	local right_key = input.LookupBinding("+moveright", true)
	if right_key then
		self:HandleKey(input.GetKeyCode(right_key), 39, "ArrowRight")
	end

	-- interact
	local interact_key = input.LookupBinding("+reload", true)
	if interact_key then
		self:HandleKey(input.GetKeyCode(interact_key), 32, " ")
	end

	-- shoot
	local space_key = input.LookupBinding("+jump", true)
	if space_key then
		self:HandleKey(input.GetKeyCode(space_key), 17, "ControlLeft")
	end

	-- strafe
	local speed_key = input.LookupBinding("+speed", true)
	if speed_key then
		self:HandleKey(input.GetKeyCode(speed_key), 18, "Alt")
	end

	-- enter
	self:HandleKey(KEY_ENTER, 13, "Enter")

	-- map
	self:HandleKey(KEY_M, 9, "Tab")

	self:HandleKey(KEY_P, pause_key_code, pause_key_name)

	-- weapon selection
	for i = 1, 9 do
		self:HandleKey(1 + i, 48 + i, i)
	end
end

function GAME:DrawMarquee()
	local logo = IMAGE.Images["doom_guy_logo"]
	surface.SetDrawColor(155, 0, 0)
	surface.DrawRect(0, 0, MARQUEE_WIDTH, MARQUEE_HEIGHT)

	draw.NoTexture()
	surface.SetMaterial(logo.mat)
	surface.SetDrawColor(255, 255, 255)
	surface.DrawTexturedRect(0, 0, MARQUEE_WIDTH, MARQUEE_HEIGHT)
end

local warn_text = "Sorry! DOOM only works on the x64 branch of Garry's Mod."
local pay_text = "Please insert coins to play / continue playing."
local play_text = "Press USE to play!"
local red_bg_color = Color(155, 0, 0)
local black_bg_color = Color(0, 0, 0, 200)
local red_color = Color(255, 0, 0)
local white_color = Color(255, 255, 255)

local function draw_text(text, col_text, col_bg)
	surface.SetDrawColor(col_bg)
	surface.DrawRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

	surface.SetTextColor(col_text)
	surface.SetFont("DermaDefaultBold")
	local tw, th = surface.GetTextSize(text)
	surface.SetTextPos(SCREEN_WIDTH / 2 - tw / 2, SCREEN_HEIGHT / 2 - th - 2)
	surface.DrawText(text)
end

local function draw_play_text()
	surface.SetTextColor(white_color)
	surface.SetFont("DermaLarge")
	local tw, th = surface.GetTextSize(play_text)
	surface.SetTextPos(SCREEN_WIDTH / 2 - tw / 2, SCREEN_HEIGHT / 2 - th - 2)
	surface.DrawText(play_text)
end

function GAME:Draw()
	if not is_chromium() then
		draw_text(warn_text, color_white, red_bg_color)
	else
		if IsValid(self.Panel) then
			self.Panel:PaintManual()
			if not has_paid then
				draw_text(pay_text, red_color, black_bg_color)
			end
		else
			draw_play_text()
		end
	end
end

-- player presses E and sits in
function GAME:OnStartPlaying(ply)
	if ply == LocalPlayer() then
		current_player = ply

		self:InitializeEmulator()
	end
end

-- leaves the machine
function GAME:OnStopPlaying(ply)
	if ply == current_player then
		current_player = nil
		has_paid = false
		next_coins_request = 0
		paused = false

		if IsValid(self.Panel) then
			self.Panel:Remove()
		end
	end
end

-- player inserts coins into the machine
function GAME:OnCoinsInserted(ply, old, new)
	has_paid = true

	local cur_time, time_to_next_coins = CurTime(), 60 * 5
	if next_coins_request > cur_time then
		-- add time to what we already have (+5mins)
		next_coins_request = next_coins_request + cur_time + time_to_next_coins
	else
		-- request coins in 5 mins
		next_coins_request = cur_time + time_to_next_coins
	end

	self:UnPause()
end

-- player coin change was networked, we're ready
function GAME:OnCoinsLost(ply, old, new) end

return GAME