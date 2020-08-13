local GAME = {}
local DOOM_URL = "https://www.playdosgames.com/play/doom/"

GAME.Name = "DOOM"
GAME.Description = "The original DOOM game. WASD to move, TAB to interact, SPACE to shoot, SHIFT to press enter"
GAME.LateUpdateMarquee = true

local function is_chromium()
	if BRANCH == "x86-64" or BRANCH == "chromium" then return true end -- chromium also exists in x86 and on the chromium branch
	return jit.arch == "x64" -- when x64 and chromium are finally pushed to stable
end

function GAME:Init()
	IMAGE:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/doom/logo.png", "doom_guy_logo", function(image)
		MARQUEE:UpdateMarquee()
	end)

	if not is_chromium() then return end

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

function GAME:Destroy()
	if not is_chromium() then return end
	self.Panel:Remove()
end

local current_player = nil
local has_paid = false
local next_coins_request = 0

local keys_down = {}
function GAME:HandleKey(game_key, key_code, key_char)
	if current_player:KeyDown(game_key) then
		if not keys_down[game_key] then
			self.Panel:QueueJavascript([[simulateKeyEvent('keydown', ]] .. key_code .. [[, ']] .. key_char .. [[');]])
			keys_down[game_key] = true
		end
	else
		if keys_down[game_key] then
			self.Panel:QueueJavascript([[simulateKeyEvent('keyup', ]] .. key_code .. [[, ']] .. key_char .. [[');]])
			keys_down[game_key] = false
		end
	end
end

local escape_key_code = 27
local escape_key_char = "Escape"
local paused = false
function GAME:Pause()
	if paused then return end
	self.Panel:QueueJavascript([[simulateKeyEvent('keydown', ]] .. escape_key_code .. [[, ']] .. escape_key_char .. [[');]])
	self.Panel:QueueJavascript([[simulateKeyEvent('keyup', ]] .. escape_key_code .. [[, ']] .. escape_key_char .. [[');]])
	paused = true
end

function GAME:UnPause()
	if not paused then return end
	self.Panel:QueueJavascript([[simulateKeyEvent('keydown', ]] .. escape_key_code .. [[, ']] .. escape_key_char .. [[');]])
	self.Panel:QueueJavascript([[simulateKeyEvent('keyup', ]] .. escape_key_code .. [[, ']] .. escape_key_char .. [[');]])
	paused = false
end

function GAME:Update()
	if not IsValid(current_player) or not self.Ready or not IsValid(self.Panel) then return end

	if has_paid and next_coins_request <= CurTime() then
		has_paid = false
		self:Pause()
	end

	if not has_paid then return end

	self:HandleKey(IN_FORWARD, 38, "ArrowUp")
	self:HandleKey(IN_BACK, 40, "ArrowDown")
	self:HandleKey(IN_MOVELEFT, 37, "ArrowLeft")
	self:HandleKey(IN_MOVERIGHT, 39, "ArrowRight")

	self:HandleKey(IN_SCORE, 32, " ")

	self:HandleKey(IN_JUMP, 17, "ControlLeft")

	self:HandleKey(IN_SPEED, 13, "Enter")
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

local function draw_text(text, col_text, col_bg)
	surface.SetDrawColor(col_bg)
	surface.DrawRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

	surface.SetTextColor(col_text)
	surface.SetFont("DermaDefaultBold")
	local tw, th = surface.GetTextSize(text)
	surface.SetTextPos(SCREEN_WIDTH / 2 - tw / 2, SCREEN_HEIGHT / 2 - th - 2)
	surface.DrawText(text)
end

local warn_text = "Sorry! DOOM only works on the x64 branch of Garry's Mod."
local pay_text = "Please insert coins to play / continue playing."
local red_bg_color = Color(155, 0, 0)
local black_bg_color = Color(0, 0, 0, 200)
local red_color = Color(255, 0, 0)
function GAME:Draw()
	if not is_chromium() then
		draw_text(warn_text, color_white, red_bg_color)
	else
		self.Panel:PaintManual()
		if not has_paid then
			draw_text(pay_text, red_color, black_bg_color)
		end
	end
end

-- player presses E and sits in
function GAME:OnStartPlaying(ply)
	if ply == LocalPlayer() then
		current_player = ply
	end
end

-- leaves the machine
function GAME:OnStopPlaying(ply)
	if ply == current_player then
		current_player = nil
		has_paid = false
		next_coins_request = 0
		paused = false
		self.Panel:OpenURL(DOOM_URL)
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
