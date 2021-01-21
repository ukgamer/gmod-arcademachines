local COINS = {}

function COINS:TakeCoins(amount)
    if not amount or amount > self:GetCoins() then return end

    net.Start("arcade_cabinet_takecoins")
        net.WriteInt(amount, 16)
    net.SendToServer()
end

function COINS:GetCoins()
    if not IsValid(ENTITY) then return end
    return ENTITY:GetCoins()
end

return COINS