if SERVERID == nil then return end

hook.Add("MTAShouldPickpocket", "arcade_nomug", function(ply)
    local veh = ply:GetVehicle()

    if not IsValid(veh) or not IsValid(veh.ArcadeCabinet) then return end

    return false
end)

hook.Add("ArcadeCabinetInsertCoin", "arcade_insertcoin", function(ply, cost)
    if ply:GetCoins() > cost then
        ply:TakeCoins(cost, "Arcade")
    else
        return false
    end
end)