local FONT = {}

function FONT:Exists(name)
    return false
    -- return pcall(function() surface.SetFont(name) end)
end

return FONT