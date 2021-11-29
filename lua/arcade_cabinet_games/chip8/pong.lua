--TESTGAME = function() -- For testing
local GAME = {}

GAME.Name = "Chip8 - Pong"
GAME.Author = "Xayr/ukgamer"
GAME.Description = "Chip8 emulator running Pong. W and S to move the bat."

local playing = false
local thePlayer = nil

local emulator = nil
local keys = {}
local isBeeping = false
local CHIP8_SCREEN_W = 64
local CHIP8_SCREEN_H = 32
local PIX_WIDTH = SCREEN_WIDTH / CHIP8_SCREEN_W
local PIX_HEIGHT = SCREEN_HEIGHT / CHIP8_SCREEN_H

function GAME:PlaySound(snd, looping)
    if SOUND.Sounds[snd] and IsValid(SOUND.Sounds[snd].sound) then
        if not looping then
            SOUND.Sounds[snd].sound:SetTime(0)
        end
        SOUND.Sounds[snd].sound:Play()
    end
end

function GAME:PauseSound(snd)
    if SOUND.Sounds[snd] and IsValid(SOUND.Sounds[snd].sound) then
        SOUND.Sounds[snd].sound:Pause()
    end
end

function GAME:Init()
    FILE:LoadFromURL(
        "https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/chip8/games/pong.ch8",
        "program",
        function(program)
            emulator = include("arcade_cabinet_games/chip8/emulator.lua")(file.Read(program.path))
            emulator:resetAll()
        end
    )

    SOUND:LoadFromURL("https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/chip8/sounds/beep.ogg", "beep", function(snd)
        snd:EnableLooping(true)
    end)
end

function GAME:Start()
    playing = true
    emulator:resetAll()
end

function GAME:Update()
    if playing then
        keys[1] = thePlayer:KeyDown(IN_FORWARD)
        keys[4] = thePlayer:KeyDown(IN_BACK)
    else
        keys[1] = false
        keys[4] = false
    end

    keys[2] = false
    keys[3] = false
    keys[5] = false
    keys[6] = false
    keys[7] = false
    keys[8] = false
    keys[9] = false
    keys[0] = false
    keys[0xA] = false
    keys[0xB] = false
    keys[0xC] = false
    keys[0xD] = false
    keys[0xE] = false
    keys[0xF] = false

    if not emulator then return end

    emulator:tick(keys)

    if emulator.tS > 0 then
        if not isBeeping then
            isBeeping = true
            if SOUND:ShouldPlaySound() then
                self:PlaySound("beep", true)
            end
        end
    else
        if isBeeping then
            isBeeping = false
            self:PauseSound("beep")
        end
    end
end

function GAME:DrawMarquee()
    surface.SetDrawColor(0, 0, 255, 255)
    surface.DrawRect(0, 0, MARQUEE_WIDTH, MARQUEE_HEIGHT)

    surface.SetFont("DermaLarge")
    local tw, th = surface.GetTextSize("Chip8 Pong")
    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos((MARQUEE_WIDTH / 2) - (tw / 2), (MARQUEE_HEIGHT / 2) - (th / 2))
    surface.DrawText("Chip8 Pong")
end

function GAME:Draw()
    if not emulator then return end

    for i = 0, CHIP8_SCREEN_W * CHIP8_SCREEN_H do
        if (emulator.DISPLAY[i] > 0) then
            surface.SetDrawColor(255, 255, 255, 255)
            local pgx = (PIX_WIDTH * (i - math.floor(i / CHIP8_SCREEN_W) * CHIP8_SCREEN_W))
            local pgy = PIX_HEIGHT * math.floor(i / CHIP8_SCREEN_W)
            surface.DrawRect(pgx, pgy, PIX_WIDTH, PIX_HEIGHT)
        end
    end

    if not playing then
        local text = "INSERT COIN"
        surface.SetFont("DermaLarge")
        local tw, th = surface.GetTextSize(text)
        surface.SetTextColor(255, 255, 255, RealTime() % 1 > 0.5 and 255 or 0)
        surface.SetTextPos((SCREEN_WIDTH / 2) - (tw / 2), SCREEN_HEIGHT - (th * 2))
        surface.DrawText(text)
    end
end

function GAME:OnStartPlaying(ply)
    if ply == LocalPlayer() then
        thePlayer = ply
    end
end

function GAME:OnStopPlaying(ply)
    if ply == thePlayer then
        playing = false
        thePlayer = nil
    end
end

function GAME:OnCoinsInserted(ply, old, new)
    if ply ~= LocalPlayer() then return end

    if new > 0 then
        self:Start()
    end
end

return GAME
--end -- For testing