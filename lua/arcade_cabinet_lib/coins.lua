local COINS = {}

function COINS:TakeCoins(amount)
    if not amount or amount > self:GetCoins() then return end

    net.Start("arcade_cabinet_takecoins")
        net.WriteInt(amount, 16)
    net.SendToServer()
end

function COINS:GetCoins()
    if not IsValid(MACHINE) then return end
    return MACHINE:GetCoins()
end

return COINS