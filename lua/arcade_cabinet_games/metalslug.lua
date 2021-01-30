local GAME = {}
local URL = "https://ukgamer.github.io/gmod-arcademachines-assets/metalslug/metalslug.html"

GAME.Name = "Metal Slug"
GAME.Author = "ukgamer"
GAME.Description = [[Metal Slug arcade game.

Start = SHIFT
Movement = WASD
Jump = SPACE
Fire = MOUSE1
Grenade = MOUSE2
]]

GAME.CabinetArtURL = "https://ukgamer.github.io/gmod-arcademachines-assets/metalslug/images/ms_acabinet_artwork.png"
GAME.LateUpdateMarquee = true

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
    IMAGE:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/metalslug/images/marquee.jpg", "marquee", function(image)
        CABINET:UpdateMarquee()
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
    if current_player:KeyDown(game_key) then
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

    self:HandleKey(IN_FORWARD, 38, "ArrowUp")
    self:HandleKey(IN_BACK, 40, "ArrowDown")
    self:HandleKey(IN_MOVELEFT, 37, "ArrowLeft")
    self:HandleKey(IN_MOVERIGHT, 39, "ArrowRight")

    self:HandleKey(IN_ATTACK, 17, "ControlLeft")
    self:HandleKey(IN_ATTACK2, 32, "Space")
    self:HandleKey(IN_SPEED, 49, "Digit1")
    self:HandleKey(IN_JUMP, 18, "AltLeft")
end

function GAME:DrawMarquee()
    surface.SetMaterial(IMAGE.Images["marquee"].mat)
    surface.SetDrawColor(255, 255, 255)
    surface.DrawTexturedRect(0, 0, MARQUEE_WIDTH, MARQUEE_HEIGHT)
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