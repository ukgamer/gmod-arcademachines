local GAME = {}
local URL = "https://ukgamer.github.io/gmod-arcademachines-assets/pacman/pacman.html"

GAME.Name = "PacMan"
GAME.Description = [[The original PacMan game.

Start = SPACE
Movement = WASD
]]

GAME.LateUpdateMarquee = true
GAME.Bodygroup = BG_GENERIC_RECESSED_JOYSTICK

local function is_chromium()
    if BRANCH == "x86-64" or BRANCH == "chromium" then return true end -- chromium also exists in x86 and on the chromium branch
    return jit.arch == "x64" -- when x64 and chromium are finally pushed to stable
end

function GAME:InitializeEmulator()
    if IsValid(self.Panel) then
        self.Panel:Remove()
    end

    local html = vgui.Create("DHTML")
    html:SetPaintedManually(true)
    html:OpenURL(URL)

    self.Panel = html
end

function GAME:Init()
    IMAGE:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/pacman/images/marquee.jpg", "marquee", function(image)
        CABINET:UpdateMarquee()
    end)

    IMAGE:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/pacman/images/cabinet.png", "cabinet", function(image)
        CABINET:UpdateCabinetArt()
    end)

    if not is_chromium() then return end
end

function GAME:Destroy()
    if IsValid(self.Panel) then
        self.Panel:Remove()
    end
end

local current_player = nil

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

function GAME:Update()
    if not IsValid(current_player) or not IsValid(self.Panel) then return end

    local forward_key = input.LookupBinding("+forward", true)
    if forward_key then
        self:HandleKey(input.GetKeyCode(forward_key), 38, "ArrowUp")
    end

    local back_key = input.LookupBinding("+back", true)
    if back_key then
        self:HandleKey(input.GetKeyCode(back_key), 40, "ArrowDown")
    end

    local left_key = input.LookupBinding("+moveleft", true)
    if left_key then
        self:HandleKey(input.GetKeyCode(left_key), 37, "ArrowLeft")
    end

    local right_key = input.LookupBinding("+moveright", true)
    if right_key then
        self:HandleKey(input.GetKeyCode(right_key), 39, "ArrowRight")
    end

    self:HandleKey(KEY_SPACE, 49, "Digit1")
end

function GAME:DrawMarquee()
    surface.SetMaterial(IMAGE.Images["marquee"].mat)
    surface.SetDrawColor(255, 255, 255)
    surface.DrawTexturedRect(0, 0, MARQUEE_WIDTH, MARQUEE_HEIGHT)
end

function GAME:DrawCabinetArt()
    surface.SetMaterial(IMAGE.Images["cabinet"].mat)
    surface.SetDrawColor(255, 255, 255)
    surface.DrawTexturedRect(0, 0, CABINET_ART_WIDTH, CABINET_ART_HEIGHT)
end

local warn_text = "Sorry! This only works on the x64 branch of Garry's Mod."
local play_text = "Press USE to play!"
local red_color = Color(255, 0, 0)
local white_color = Color(255, 255, 255)

function GAME:Draw()
    if not is_chromium() then
        surface.SetTextColor(red_color)
        surface.SetFont("DermaDefaultBold")
        local tw, th = surface.GetTextSize(warn_text)
        surface.SetTextPos(SCREEN_WIDTH / 2 - tw / 2, SCREEN_HEIGHT / 2 - th - 2)
        surface.DrawText(warn_text)
    else
        if IsValid(self.Panel) then
            self.Panel:PaintManual()
        else
            surface.SetTextColor(white_color)
            surface.SetFont("DermaLarge")
            local tw, th = surface.GetTextSize(play_text)
            surface.SetTextPos(SCREEN_WIDTH / 2 - tw / 2, SCREEN_HEIGHT / 2 - th - 2)
            surface.DrawText(play_text)
        end
    end
end

function GAME:OnStartPlaying(ply)
    if ply == LocalPlayer() then
        current_player = ply

        self:InitializeEmulator()
    end
end

function GAME:OnStopPlaying(ply)
    if ply == current_player then
        current_player = nil

        if IsValid(self.Panel) then
            self.Panel:Remove()
        end
    end
end

function GAME:OnCoinsInserted(ply, old, new)
    if ply ~= LocalPlayer() or not IsValid(self.Panel) then return end

    self.Panel:QueueJavascript([[
        simulateKeyEvent('keydown', 53, 'Digit5');
        setTimeout(simulateKeyEvent, 100, 'keyup', 53, 'Digit5');
    ]])
end

function GAME:OnCoinsLost(ply, old, new)

end

return GAME