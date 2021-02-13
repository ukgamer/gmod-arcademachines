if SERVERID == nil then return end

hook.Add("ArcadeCabinetCanPlayerAfford", "arcade_canafford", function(cost)
    return LocalPlayer():GetCoins() >= cost
end)