include("shared.lua")
include("cl_hooks.lua")

local ScreenWidth = 64 * 5
local ScreenHeight = 64
local DigitMaterial = CreateMaterial(
    "AirHockey_Digit_Material",
    "UnlitGeneric",
    {
        ["$basetexture"] = "models/props_arcade/hockeytable/score_atlas"
    }
)

local function DrawDigit(x, y, w, h, digit)
    local startX, startY = 0, 0

    if digit == "|" then
        startX = 2 * 64
        startY = 2 * 64
    else
        digit = tonumber(digit)

        -- There's probably some clever maths way to do this but this works
        startX = digit * 64

        if digit < 4 then
            startY = 0 * 64
        elseif digit < 8 then
            startY = 1 * 64
        else
            startY = 2 * 64
        end
    end

    local startU = startX / 256
    local startV = startY / 256
    local endU = (startX + 64) / 256
    local endV = (startY + 64) / 256

    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(DigitMaterial)
    surface.DrawTexturedRectUV(x, y, w, h, startU, startV, endU, endV)
end

local function DrawScore(score)
    local w, h = 64, ScreenHeight * 0.6
    local y = (ScreenHeight * 0.5) - (h * 0.5)

    for i = 1, #score do
        DrawDigit((i - 1) * 64, y, w, h, score[i])
    end
end

ENT.Initialized = false

function ENT:Initialize()
    self.Initialized = true

    local num = math.random(9999)

    self.Screen1Texture = self.Screen1Texture or GetRenderTargetEx(
        "AirHockey_Screen1_" .. self:EntIndex() .. "_" .. num,
        ScreenWidth,
        ScreenHeight,
        RT_SIZE_DEFAULT,
        MATERIAL_RT_DEPTH_NONE,
        1,
        CREATERENDERTARGETFLAGS_HDR,
        IMAGE_FORMAT_DEFAULT
    )
    self.Screen1Material = self.Screen1Material or CreateMaterial(
        "AirHockey_Screen1_Material_" .. self:EntIndex() .. "_" .. num,
        "VertexLitGeneric",
        {
            ["$basetexture"] = self.Screen1Texture:GetName(),
            ["$model"] = 1,
            ["$selfillum"] = 1,
            ["$selfillummask"] = "dev/reflectivity_30b"
        }
    )

    self.Screen2Texture = self.Screen2Texture or GetRenderTargetEx(
        "AirHockey_Screen2_" .. self:EntIndex() .. "_" .. num,
        ScreenWidth,
        ScreenHeight,
        RT_SIZE_DEFAULT,
        MATERIAL_RT_DEPTH_NONE,
        1,
        CREATERENDERTARGETFLAGS_HDR,
        IMAGE_FORMAT_DEFAULT
    )
    self.Screen2Material = self.Screen2Material or CreateMaterial(
        "AirHockey_Screen2_Material_" .. self:EntIndex() .. "_" .. num,
        "VertexLitGeneric",
        {
            ["$basetexture"] = self.Screen2Texture:GetName(),
            ["$model"] = 1,
            ["$selfillum"] = 1,
            ["$selfillummask"] = "dev/reflectivity_30b"
        }
    )

    self:UpdateScreens()
end

function ENT:OnRemove()

end

function ENT:Think()
    -- Work around init not being called on the client sometimes
    if not self.Initialized then
        self:Initialize()
    end

    -- Workaround network var notify not triggering for null entity
    if self.LastPlayer1 and self.LastPlayer1 ~= self:GetPlayer1() then
        self:OnPlayerChange("Player1", self.LastPlayer1, self:GetPlayer1())
    end
    if self.LastPlayer2 and self.LastPlayer2 ~= self:GetPlayer2() then
        self:OnPlayerChange("Player2", self.LastPlayer2, self:GetPlayer2())
    end

    -- If we weren't nearby when the machine was spawned we won't get notified
    -- when the seat was created so manually call
    if IsValid(self:GetSeat1()) and not self:GetSeat1().AirHockey then
        self:OnSeatCreated("Seat1", nil, self:GetSeat1())
    end
    if IsValid(self:GetSeat2()) and not self:GetSeat2().AirHockey then
        self:OnSeatCreated("Seat2", nil, self:GetSeat2())
    end

    -- Used to work around GetScoreX not returning the correct value after the
    -- network var notify was called
    if self.ScoreChange then
        self:UpdateScreens()
        self.ScoreChange = nil
    end
end

function ENT:Draw()
    local ignoreZ = IsValid(ARCADE.AirHockey.CurrentMachine) and
        ARCADE.AirHockey.CurrentMachine == self and
        not LocalPlayer():ShouldDrawLocalPlayer()

    if ignoreZ then
        cam.IgnoreZ(true)
    end

    -- To prevent using string table slots, don't set the submaterial on the server
    -- and just override it here
    render.MaterialOverrideByIndex(1, self.Screen1Material)
    render.MaterialOverrideByIndex(2, self.Screen2Material)
    self:DrawModel()
    render.MaterialOverrideByIndex()

    if ignoreZ then
        cam.IgnoreZ(false)
    end
end

function ENT:OnScoreChange(name, old, new)
    self.ScoreChange = true
end

function ENT:OnLocalPlayerEntered()
    ARCADE.AirHockey.CurrentMachine = self
end

function ENT:UpdateScreens()
    local score1 = math.Clamp(self:GetScore1(), 0, 99)
    local score2 = math.Clamp(self:GetScore2(), 0, 99)

    render.PushRenderTarget(self.Screen1Texture)
        cam.Start2D()
            surface.SetDrawColor(0, 0, 0, 255)
            surface.DrawRect(0, 0, ScreenWidth, ScreenHeight)

            DrawScore(string.format("%02d|%02d", score1, score2))
        cam.End2D()
    render.PopRenderTarget()

    render.PushRenderTarget(self.Screen2Texture)
        cam.Start2D()
            surface.SetDrawColor(0, 0, 0, 255)
            surface.DrawRect(0, 0, ScreenWidth, ScreenHeight)

            DrawScore(string.format("%02d|%02d", score2, score1))
        cam.End2D()
    render.PopRenderTarget()
end