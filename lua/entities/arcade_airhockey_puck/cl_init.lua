include("shared.lua")

function ENT:Draw()
    local ignoreZ = IsValid(ARCADE.AirHockey.CurrentMachine) and
        ARCADE.AirHockey.CurrentMachine:GetPuck() == self and
        not LocalPlayer():ShouldDrawLocalPlayer()

    if ignoreZ then
        cam.IgnoreZ(true)
    end

    self:DrawModel()

    if ignoreZ then
        cam.IgnoreZ(false)
    end
end