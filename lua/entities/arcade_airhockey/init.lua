AddCSLuaFile("cl_init.lua")
AddCSLuaFile("cl_hooks.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

resource.AddSingleFile("models/props_arcade/hockeytable001a.mdl")
resource.AddSingleFile("models/props_arcade/hockeytable001a.phy")
resource.AddSingleFile("models/props_arcade/hockeytable001a.sw.vtx")
resource.AddSingleFile("models/props_arcade/hockeytable001a.vvd")
resource.AddSingleFile("models/props_arcade/hockeytable001a.dx80.vtx")
resource.AddSingleFile("models/props_arcade/hockeytable001a.dx90.vtx")

resource.AddFile("materials/models/props_arcade/hockeytable/hockeytable001a.vmt")
resource.AddSingleFile("materials/models/props_arcade/hockeytable/hockeytable001a_normal.vtf")

resource.AddSingleFile("materials/models/props_arcade/hockeytable/score_left.vmt")
resource.AddSingleFile("materials/models/props_arcade/hockeytable/score_right.vmt")
resource.AddSingleFile("materials/models/props_arcade/hockeytable/score_atlas.vtf")
resource.AddSingleFile("materials/models/props_arcade/hockeytable/score_blank.vtf")

local LocalPlayAreaBoundary = {
    Vector(-28, -60, 33.8),
    Vector(-28, 60, 33.8),
    Vector(28, 60, 33.8),
    Vector(28, -60, 33.8),
    Vector(-28, -60, 42),
    Vector(-28, 60, 42),
    Vector(28, 60, 42),
    Vector(28, -60, 42)
}

local LocalGoalBoundary1 = {
    Vector(-7, 60, 33.8),
    Vector(-7, 57, 33.8),
    Vector(7, 57, 33.8),
    Vector(7, 60, 33.8),
    Vector(-7, 60, 36),
    Vector(-7, 57, 36),
    Vector(7, 57, 36),
    Vector(7, 60, 36)
}

local LocalGoalBoundary2 = {
    Vector(-7, -60, 33.8),
    Vector(-7, -57, 33.8),
    Vector(7, -57, 33.8),
    Vector(7, -60, 33.8),
    Vector(-7, -60, 36),
    Vector(-7, -57, 36),
    Vector(7, -57, 36),
    Vector(7, -60, 36)
}

local AirSound = "plats/crane/vertical_start.wav"

local function WithinBounds(point, vecs)
    local b1, b2, _, b4, t1, _, t3, _ = unpack(vecs)

    local dir1 = (t1 - b1)
    local size1 = dir1:Length()
    dir1 = dir1 / size1

    local dir2 = (b2 - b1)
    local size2 = dir2:Length()
    dir2 = dir2 / size2

    local dir3 = (b4 - b1)
    local size3 = dir3:Length()
    dir3 = dir3 / size3

    local cube3d_center = (b1 + t3) / 2.0

    local dir_vec = point - cube3d_center

    local res1 = math.abs(dir_vec:Dot(dir1)) * 2 < size1
    local res2 = math.abs(dir_vec:Dot(dir2)) * 2 < size2
    local res3 = math.abs(dir_vec:Dot(dir3)) * 2 < size3

    return res1 and res2 and res3
end

function ENT:SpawnFunction(ply, tr)
    if not tr.Hit then return end

    local ent = ents.Create(self.Class)
    ent:SetPos(tr.HitPos)
    ent:SetAngles(Angle(0, (ply:GetPos() - tr.HitPos):Angle().y, 0))
    ent:Spawn()
    ent:Activate()

    ent.Owner = ply
    undo.Create(self.Class)
        undo.AddEntity(ent)
        undo.SetPlayer(ply)
    undo.Finish()

    return ent
end

function ENT:Initialize()
    self:SetModel("models/props_arcade/hockeytable001a.mdl")

    self:SetUseType(SIMPLE_USE)

    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetCustomCollisionCheck(true)
    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:EnableMotion(false)
    end

    construct.SetPhysProp(nil, self, 0, self:GetPhysicsObject(), { Material = "ice" })

    -- Seat 1
    local seat1 = ents.Create("prop_vehicle_prisoner_pod")
    seat1:SetModel("models/nova/airboat_seat.mdl")
    seat1:SetParent(self)
    seat1:SetKeyValue("vehiclescript", "scripts/vehicles/prisoner_pod.txt")
    seat1:SetKeyValue("limitview", "0")
    seat1:SetLocalPos(Vector(0, 80, -7))
    seat1:SetLocalAngles(Angle(0, 180, 0))
    -- Can't use nodraw on server as entity will not be networked
    seat1:SetRenderMode(RENDERMODE_NONE)
    seat1:DrawShadow(false)
    seat1:Spawn()
    seat1:SetNotSolid(true)
    self:DeleteOnRemove(seat1)

    -- Seat 2
    local seat2 = ents.Create("prop_vehicle_prisoner_pod")
    seat2:SetModel("models/nova/airboat_seat.mdl")
    seat2:SetParent(self)
    seat2:SetKeyValue("vehiclescript", "scripts/vehicles/prisoner_pod.txt")
    seat2:SetKeyValue("limitview", "0")
    seat2:SetLocalPos(Vector(0, -80, -7))
    seat2:SetLocalAngles(Angle(0, 0, 0))
    -- Can't use nodraw on server as entity will not be networked
    seat2:SetRenderMode(RENDERMODE_NONE)
    seat2:DrawShadow(false)
    seat2:Spawn()
    seat2:SetNotSolid(true)
    self:DeleteOnRemove(seat2)

    self:SetSeat1(seat1)
    self:SetSeat2(seat2)
    seat1:SetOwner(self:GetOwner())
    seat2:SetOwner(self:GetOwner())

    self:Reset()
end

function ENT:RespawnPuck()
    local pos = self:LocalToWorld(Vector(0, 0, 34.8))

    if IsValid(self:GetPuck()) then
        self:GetPuck():SetPos(pos)
        self:GetPuck():SetAngles(Angle())
        self:GetPuck():SetLocalAngularVelocity(Angle())
        return
    end

    local puck = ents.Create("arcade_airhockey_puck")
    puck:SetCustomCollisionCheck(true)
    puck:SetPos(pos)
    puck:Spawn()
    self:DeleteOnRemove(puck)

    self:SetPuck(puck)
    puck:SetOwner(self:GetOwner())
    puck:SetAirHockeyTable(self)
end

function ENT:RespawnStriker1()
    local pos = self:LocalToWorld(Vector(0, 50, 34.8))

    if IsValid(self:GetStriker1()) then
        self:GetStriker1():SetPos(pos)
        self:GetStriker1():SetAngles(Angle())
        self:GetStriker1():SetLocalAngularVelocity(Angle())
        return
    end

    local striker1 = ents.Create("arcade_airhockey_striker")
    striker1:SetCustomCollisionCheck(true)
    striker1:SetPos(pos)
    striker1:Spawn()
    self:DeleteOnRemove(striker1)

    self:SetStriker1(striker1)
    striker1:SetOwner(self:GetOwner())
    striker1:SetAirHockeyTable(self)
end

function ENT:RespawnStriker2()
    local pos = self:LocalToWorld(Vector(0, -50, 34.8))

    if IsValid(self:GetStriker2()) then
        self:GetStriker2():SetPos(pos)
        self:GetStriker2():SetAngles(Angle())
        self:GetStriker2():SetLocalAngularVelocity(Angle())
        return
    end

    local striker2 = ents.Create("arcade_airhockey_striker")
    striker2:SetCustomCollisionCheck(true)
    striker2:SetPos(pos)
    striker2:Spawn()
    striker2:SetSkin(1)
    self:DeleteOnRemove(striker2)

    self:SetStriker2(striker2)
    striker2:SetOwner(self:GetOwner())
    striker2:SetAirHockeyTable(self)
end

function ENT:Reset()
    self:StopSound(AirSound)
    self:EmitSound(AirSound, 50, 255, 0.2)

    self:SetScore1(0)
    self:SetScore2(0)

    self:RespawnPuck()
    self:RespawnStriker1()
    self:RespawnStriker2()
end

function ENT:Think()
    if self:GetSeat1():GetDriver() ~= self:GetPlayer1() then
        self:SetPlayer1(NULL)
    end
    if self:GetSeat2():GetDriver() ~= self:GetPlayer2() then
        self:SetPlayer2(NULL)
    end

    local boundary, goalBoundary1, goalBoundary2 = {}, {}, {}
    for k, v in ipairs(LocalPlayAreaBoundary) do
        boundary[k] = self:LocalToWorld(v)
    end
    for k, v in ipairs(LocalGoalBoundary1) do
        goalBoundary1[k] = self:LocalToWorld(v)
    end
    for k, v in ipairs(LocalGoalBoundary2) do
        goalBoundary2[k] = self:LocalToWorld(v)
    end

    if not IsValid(self:GetPuck()) or not WithinBounds(self:GetPuck():GetPos(), boundary) then
        self:RespawnPuck()
    end
    if not IsValid(self:GetStriker1()) or not WithinBounds(self:GetStriker1():GetPos(), boundary) then
        self:RespawnStriker1()
    end
    if not IsValid(self:GetStriker2()) or not WithinBounds(self:GetStriker2():GetPos(), boundary) then
        self:RespawnStriker2()
    end

    if WithinBounds(self:GetPuck():GetPos(), goalBoundary1) then
        self:SetScore2(self:GetScore2() + 1)
        self:RespawnPuck()
        self:EmitSound("ui/hitsound_vortex" .. math.random(1, 5) .. ".wav", 55)
    end

    if WithinBounds(self:GetPuck():GetPos(), goalBoundary2) then
        self:SetScore1(self:GetScore1() + 1)
        self:RespawnPuck()
        self:EmitSound("ui/hitsound_vortex" .. math.random(1, 5) .. ".wav", 55)
    end

    self:NextThink(CurTime())
    return true
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    if not IsValid(self:GetSeat1():GetDriver()) then
        self:SetPlayer1(activator)
        activator:EnterVehicle(self:GetSeat1())
        self:GetSeat1().CanLeaveVehicle = false
        activator.ArcadeWasAllowedWeaponsInVehicle = activator:GetAllowWeaponsInVehicle()
        activator:SetAllowWeaponsInVehicle(false)
    elseif not IsValid(self:GetSeat2():GetDriver()) then
        self:SetPlayer2(activator)
        activator:EnterVehicle(self:GetSeat2())
        self:GetSeat2().CanLeaveVehicle = false
        activator.ArcadeWasAllowedWeaponsInVehicle = activator:GetAllowWeaponsInVehicle()
        activator:SetAllowWeaponsInVehicle(false)
    end
end

function ENT:OnRemove()
    self:StopSound(AirSound)
end

hook.Add("ShouldCollide", "arcade_airhockey_collisions", function(ent1, ent2)
    if
        ent1:GetClass() == "arcade_airhockey" and
        (not ent2:IsWorld() and not ent2:IsPlayer() and ent2:GetClass() ~= "arcade_airhockey_puck" and ent2:GetClass() ~= "arcade_airhockey_striker")
    then
        return false
    end

    if
        ent1:GetClass() == "arcade_airhockey_striker" and
        (not ent2:IsWorld() and ent2:GetClass() ~= "arcade_airhockey_puck" and ent2:GetClass() ~= "arcade_airhockey")
    then
        return false
    end

    if
        ent1:GetClass() == "arcade_airhockey_puck" and
        (not ent2:IsWorld() and ent2:GetClass() ~= "arcade_airhockey_striker" and ent2:GetClass() ~= "arcade_airhockey")
    then
        return false
    end

    return true
end)

hook.Add("PlayerLeaveVehicle", "arcade_airhockey_leavevehicle", function(ply, veh)
    if not IsValid(veh.AirHockey) then return end

    ply:SetPos(veh:GetPos() + veh:GetForward() * -10 + veh:GetUp() * 10)
    ply:SetEyeAngles((veh.AirHockey:GetPos() - ply:EyePos()):Angle())
end)