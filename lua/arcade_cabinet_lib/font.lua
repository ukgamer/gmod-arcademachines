local FONT = {}

function FONT:Exists(name)
    return pcall(function() surface.SetFont(name) end)
end

return FONT