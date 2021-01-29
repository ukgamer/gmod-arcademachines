local LAUNCHER = {}

function LAUNCHER:LaunchGame(game)
    if not IsValid(ENTITY) then return end
    ENTITY:SetGame(game)
end

return LAUNCHER