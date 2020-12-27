local CABINET = {}

function CABINET:UpdateMarquee()
    if not IsValid(MACHINE) then return end
    MACHINE:UpdateMarquee()
end

return CABINET