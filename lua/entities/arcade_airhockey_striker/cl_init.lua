include("shared.lua")

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