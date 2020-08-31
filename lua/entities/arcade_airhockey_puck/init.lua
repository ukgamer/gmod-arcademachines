AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

resource.AddSingleFile("models/props_arcade/hockeypuck001a.mdl")
resource.AddSingleFile("models/props_arcade/hockeypuck001a.phy")
resource.AddSingleFile("models/props_arcade/hockeypuck001a.sw.vtx")
resource.AddSingleFile("models/props_arcade/hockeypuck001a.vvd")
resource.AddSingleFile("models/props_arcade/hockeypuck001a.dx80.vtx")
resource.AddSingleFile("models/props_arcade/hockeypuck001a.dx90.vtx")

resource.AddSingleFile("models/props_arcade/hockeypuck001a_phys.mdl")
resource.AddSingleFile("models/props_arcade/hockeypuck001a_phys.phy")
resource.AddSingleFile("models/props_arcade/hockeypuck001a_phys.sw.vtx")
resource.AddSingleFile("models/props_arcade/hockeypuck001a_phys.vvd")
resource.AddSingleFile("models/props_arcade/hockeypuck001a_phys.dx80.vtx")
resource.AddSingleFile("models/props_arcade/hockeypuck001a_phys.dx90.vtx")

resource.AddFile("materials/models/props_arcade/hockeytable/hockeypuck001a.vmt")
resource.AddSingleFile("materials/models/props_arcade/hockeytable/hockeypuck001a_normal.vtf")

function ENT:Initialize()
    self:SetModel("models/props_arcade/hockeypuck001a.mdl")

    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:DrawShadow(false)
    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:SetMass(50)
    end

    construct.SetPhysProp(nil, self, 0, self:GetPhysicsObject(), { Material = "ice" })
end

function ENT:GravGunPickupAllowed(ply)
    return false
end