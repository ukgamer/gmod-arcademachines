ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Air Hockey Puck"
ENT.Author = "ukgamer"
ENT.Category = "ukgamer"
ENT.Spawnable = false

ENT.Class = "arcade_airhockey_puck"

function ENT:CanConstruct()
    return false
end

function ENT:CanTool()
    return false
end

function ENT:CanProperty()
    return false
end