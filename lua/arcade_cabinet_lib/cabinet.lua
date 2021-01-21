local CABINET = {}

function CABINET:UpdateMarquee()
    if not IsValid(ENTITY) then return end
    ENTITY:UpdateMarquee()
end

return CABINET