AddCSLuaFile("cl_init.lua")
AddCSLuaFile("cl_hooks.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

resource.AddSingleFile("materials/icon64/arcade_cabinet.png")

resource.AddSingleFile("models/props_arcade/cabinet/cabinet.mdl")
resource.AddSingleFile("models/props_arcade/cabinet/cabinet.phy")
resource.AddSingleFile("models/props_arcade/cabinet/cabinet.sw.vtx")
resource.AddSingleFile("models/props_arcade/cabinet/cabinet.vvd")
resource.AddSingleFile("models/props_arcade/cabinet/cabinet.dx80.vtx")
resource.AddSingleFile("models/props_arcade/cabinet/cabinet.dx90.vtx")
resource.AddFile("materials/models/props_arcade/cabinet/cabinet.vmt")
resource.AddFile("materials/models/props_arcade/cabinet/cabinet_artwork.vmt")
resource.AddFile("materials/models/props_arcade/cabinet/cabinet_driving.vmt")
resource.AddFile("materials/models/props_arcade/cabinet/cabinet_artwork_driving.vmt")
resource.AddSingleFile("materials/models/props_arcade/cabinet/cabinet_artwork_normal.vtf")
resource.AddSingleFile("materials/models/props_arcade/cabinet/cabinet_artwork_driving_normal.vtf")
resource.AddFile("materials/models/props_arcade/cabinet/cabinet_buttons.vmt")
resource.AddSingleFile("materials/models/props_arcade/cabinet/cabinet_buttons_normal.vtf")
resource.AddFile("materials/models/props_arcade/cabinet/cabinet_marque.vmt")
resource.AddFile("materials/models/props_arcade/cabinet/cabinet_marque_driving.vmt")
resource.AddSingleFile("materials/models/props_arcade/cabinet/cabinet_outerglass.vmt")
resource.AddFile("materials/models/props_arcade/cabinet/cabinet_screen.vmt")
resource.AddFile("materials/models/props_arcade/cabinet/cabinet_wheel.vmt")
resource.AddSingleFile("materials/models/props_arcade/cabinet/cabinet_wheel_normal.vtf")

local function RecursiveAddCSGameFiles(path)
    local prefix = path .. "/"

    local _, dirs = file.Find(prefix .. "*", "LUA")
    local files = file.Find(prefix .. "*.lua", "LUA")

    for _, f in ipairs(files) do
        AddCSLuaFile(prefix .. f)
    end

    for _, d in ipairs(dirs) do
        RecursiveAddCSGameFiles(prefix .. d)
    end
end

RecursiveAddCSGameFiles("arcade_cabinet_games")
RecursiveAddCSGameFiles("arcade_cabinet_lib")

AddCSLuaFile("arcade_cabinet_launcher.lua")

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
    self:SetModel("models/props_arcade/cabinet/cabinet.mdl")

    self:SetUseType(SIMPLE_USE)

    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:PhysicsInit(SOLID_VPHYSICS)
    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:EnableMotion(false)
    end

    -- Seat
    local seat = ents.Create("prop_vehicle_prisoner_pod")
    seat:SetModel("models/nova/airboat_seat.mdl")
    seat:SetParent(self)
    seat:SetKeyValue("vehiclescript", "scripts/vehicles/prisoner_pod.txt")
    seat:SetKeyValue("limitview", "0")
    seat:SetLocalPos(Vector(30, 0, -7))
    seat:SetLocalAngles(Angle(0, 90, 0))
    -- Can't use nodraw on server as entity will not be networked
    seat:SetRenderMode(RENDERMODE_NONE)
    seat:DrawShadow(false)
    seat:Spawn()
    seat:SetNotSolid(true)
    self:DeleteOnRemove(seat)

    if FindMetaTable("Player").TakeCoins then
        self:SetMSCoinCost(1000)
    end

    timer.Simple(0.05, function() -- Thanks gmod
        self:SetSeat(seat)
        self:OnSeatCreated("Seat", NULL, seat)
        seat:SetOwner(self:GetOwner())
    end)

    self.CanLeaveVehicle = false
end

function ENT:Think()
    if self:GetSeat():GetDriver() ~= self:GetPlayer() then
        self:SetPlayer(self:GetSeat():GetDriver())
        self:SetCoins(0)
    end

    self:NextThink(CurTime() + 0.1)
    return true
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    if not IsValid(self:GetPlayer()) then
        self:SetPlayer(activator)
        self:GetPlayer():EnterVehicle(self:GetSeat())
        self:GetSeat().CanLeaveVehicle = false
        self:GetPlayer().ArcadeWasAllowedWeaponsInVehicle = self:GetPlayer():GetAllowWeaponsInVehicle()
        self:GetPlayer():SetAllowWeaponsInVehicle(false)
    end
end

function ENT:OnRemove()

end

hook.Add("PlayerLeaveVehicle", "arcade_cabinet_leavevehicle", function(ply, veh)
    if not IsValid(veh.ArcadeCabinet) then return end

    ply:SetPos(veh:GetPos() + veh:GetForward() * -10 + veh:GetUp() * 10)
    ply:SetEyeAngles((veh.ArcadeCabinet:GetPos() - ply:EyePos()):Angle())
end)

util.AddNetworkString("arcade_cabinet_insertcoin")
net.Receive("arcade_cabinet_insertcoin", function(len, ply)
    local veh = ply:GetVehicle()

    if not IsValid(veh) or not IsValid(veh.ArcadeCabinet) or veh.ArcadeCabinet:GetPlayer() ~= ply then return end

    local cost = veh.ArcadeCabinet:GetMSCoinCost()

    if cost > 0 and ply.TakeCoins and veh.ArcadeCabinet:GetPlayer() == ply then
        if ply:GetCoins() > cost then
            ply:TakeCoins(cost, "Arcade")
        else
            return
        end
    end

    veh.ArcadeCabinet:SetCoins(veh.ArcadeCabinet:GetCoins() + 1)
end)

util.AddNetworkString("arcade_cabinet_takecoins")
net.Receive("arcade_cabinet_takecoins", function(len, ply)
    local veh = ply:GetVehicle()

    if not IsValid(veh) or not IsValid(veh.ArcadeCabinet) or veh.ArcadeCabinet:GetPlayer() ~= ply then return end

    local amount = net.ReadInt(16)

    if not amount or amount > veh.ArcadeCabinet:GetCoins() then return end

    veh.ArcadeCabinet:SetCoins(veh.ArcadeCabinet:GetCoins() - amount)
end)