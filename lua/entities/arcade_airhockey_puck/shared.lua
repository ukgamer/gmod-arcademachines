ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Air Hockey Puck"
ENT.Author = "ukgamer"
ENT.Category = "ukgamer"
ENT.Spawnable = false

ENT.Class = "arcade_airhockey_puck"

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "AirHockeyTable")
end

function ENT:CanConstruct()
    return false
end

function ENT:CanTool()
    return false
end

function ENT:CanProperty()
    return false
end

-- function ENT:PhysicsSimulate(phys, delta)
--     phys:Wake()

--     local params = {
--         pos = phys:GetPos(),
--         angle = Angle(),
--         maxangular = 0,
--         deltatime = delta
--     }

--     phys:ComputeShadowControl(params)
-- end