-- To stop people accidentally tapping E and leaving, don't let them leave normally
-- the client has to tell us in a net message that they really want to leave
hook.Add("CanExitVehicle", "arcade_canexitvehicle", function(veh, ply)
    if not IsValid(veh.ArcadeMachine) and not IsValid(veh.AirHockey) then return end

    return veh.CanLeaveVehicle
end)

util.AddNetworkString("arcade_leave")
net.Receive("arcade_leave", function(len, ply)
    local veh = ply:GetVehicle()

    if not IsValid(veh) or (not IsValid(veh.ArcadeMachine) and not IsValid(veh.AirHockey)) then return end

    veh.CanLeaveVehicle = true
    ply:ExitVehicle()
    ply:SetAllowWeaponsInVehicle(ply.ArcadeWasAllowedWeaponsInVehicle)
end)

local NoSitEnts = {
    "arcade_airhockey",
    "arcade_airhockey_puck",
    "arcade_airhockey_striker",
    "arcade_cabinet"
}

hook.Add("OnPlayerSit", "arcade_nosit", function(ply, pos, ang, parent, parentbone, veh)
    if table.HasValue(NoSitEnts, parent:GetClass()) then return false end
end)