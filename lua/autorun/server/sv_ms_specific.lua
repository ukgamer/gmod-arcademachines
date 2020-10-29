if SERVERID == nil then return end

hook.Add("MTAShouldPickpocket", "arcade_nomug", function(ply)
    local veh = ply:GetVehicle()

    if not IsValid(veh) or not IsValid(veh.ArcadeMachine) then return end

    return false
end)