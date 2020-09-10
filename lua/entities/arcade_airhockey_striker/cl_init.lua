include("shared.lua")

ENT.Initialized = false

function ENT:Initialize()
    self.Initialized = true

    self:SetPredictable(true)
end

function ENT:Think()
    if not self.Initialized then
        self:Initialize()
    end
end

function ENT:Draw()
    local ignoreZ = IsValid(ARCADE.AirHockey.CurrentMachine) and
        (ARCADE.AirHockey.CurrentMachine:GetStriker1() == self or ARCADE.AirHockey.CurrentMachine:GetStriker2() == self) and
        not LocalPlayer():ShouldDrawLocalPlayer()

    if ignoreZ then
        cam.IgnoreZ(true)
    end

    self:DrawModel()

    if ignoreZ then
        cam.IgnoreZ(false)
    end
end