ARCADE.AirHockey = ARCADE.AirHockey or {}

function ARCADE.AirHockey:OnLocalPlayerLeft()
    self.CurrentMachine = nil
end

local PressedUse = false

local ViewAngle = Angle(35, 90)
local Player1ScoreAngle = Angle(0, -90)
local Player2ScoreAngle = Angle(0, 90)

--hook.Remove("HUDPaint", "arcade_airhockey_debug")
-- hook.Add("HUDPaint", "arcade_airhockey_debug", function()
--     local boundary = {
--         Vector(-7, 60, 33.8),
--         Vector(-7, 57, 33.8),
--         Vector(7, 57, 33.8),
--         Vector(7, 60, 33.8),
--         Vector(-7, 60, 36),
--         Vector(-7, 57, 36),
--         Vector(7, 57, 36),
--         Vector(7, 60, 36)
--     }

--     for _, v in ipairs(ents.FindByClass("arcade_airhockey")) do
--         for k, v2 in ipairs(boundary) do
--             local pos = v:LocalToWorld(v2):ToScreen()

--             surface.SetDrawColor(0, 255, 0, 255)
--             surface.DrawRect(pos.x - 5, pos.y - 5, 10, 10)
--         end
--     end
-- end)

hook.Add("CalcVehicleView", "arcade_airhockey_view", function(veh, ply, view)
    local hockeyTable = ARCADE.AirHockey.CurrentMachine

    if not IsValid(hockeyTable) then return end

    if LocalPlayer():KeyDown(IN_SCORE) then
        local right = -40

        if hockeyTable:GetPlayer1() == LocalPlayer() then
            view.angles = hockeyTable:LocalToWorldAngles(Player1ScoreAngle)
        else
            right = 40
            view.angles = hockeyTable:LocalToWorldAngles(Player2ScoreAngle)
        end

        view.origin = hockeyTable:GetPos() + hockeyTable:GetRight() * right + hockeyTable:GetUp() * 85
    else
        view.origin = veh:GetPos() + veh:GetRight() * -10 + veh:GetUp() * 70
        view.angles = veh:LocalToWorldAngles(ViewAngle)
    end

    view.fov = 90

    return view
end)

hook.Add("CreateMove", "arcade_airhockey_move", function(cmd)
    if not IsValid(ARCADE.AirHockey.CurrentMachine) then
        PressedUse = false
        return
    end

    if bit.band(cmd:GetButtons(), IN_USE) ~= 0 then
        if not PressedUse then
            PressedUse = true
            PressedUseAt = RealTime()
        elseif RealTime() >= PressedUseAt + 0.8 then
            net.Start("arcade_leave")
            net.SendToServer()
            PressedUse = false
        end
    else
        PressedUse = false
    end
end)

hook.Add("Think", "arcade_airhockey_think", function()
    if
        (IsValid(ARCADE.AirHockey.CurrentMachine) and (ARCADE.AirHockey.CurrentMachine:GetPlayer1() ~= LocalPlayer() and ARCADE.AirHockey.CurrentMachine:GetPlayer2() ~= LocalPlayer())) or -- The player was pulled out of the machine somehow
        (ARCADE.AirHockey.CurrentMachine and not IsValid(ARCADE.AirHockey.CurrentMachine)) -- The machine was removed while we were in it
    then
        ARCADE.AirHockey:OnLocalPlayerLeft()
    end
end)