-- To stop people accidentally tapping E and leaving, don't let them leave normally
-- the client has to tell us in a net message that they really want to leave
hook.Add("CanExitVehicle", "arcade_canexitvehicle", function(veh, ply)
    if not IsValid(veh.ArcadeCabinet) then return end

    return veh.CanLeaveVehicle
end)

util.AddNetworkString("arcade_leave")
net.Receive("arcade_leave", function(len, ply)
    local veh = ply:GetVehicle()

    if not IsValid(veh) or not IsValid(veh.ArcadeCabinet) then return end

    veh.CanLeaveVehicle = true
    ply:ExitVehicle()
    ply:SetAllowWeaponsInVehicle(ply.ArcadeWasAllowedWeaponsInVehicle)
end)

local NoSitEnts = {
    ["arcade_cabinet"] = true
}

hook.Add("OnPlayerSit", "arcade_nosit", function(ply, pos, ang, parent, parentbone, veh)
    if IsValid(parent) and NoSitEnts[parent:GetClass()] then return false end
end)