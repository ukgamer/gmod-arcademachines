AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

resource.AddSingleFile("models/metastruct/ms_acabinet.mdl")
resource.AddSingleFile("models/metastruct/ms_acabinet.phy")
resource.AddSingleFile("models/metastruct/ms_acabinet.sw.vtx")
resource.AddSingleFile("models/metastruct/ms_acabinet.vvd")
resource.AddSingleFile("models/metastruct/ms_acabinet.dx80.vtx")
resource.AddSingleFile("models/metastruct/ms_acabinet.dx90.vtx")
resource.AddFile("materials/models/ms_acabinet/ms_acabinet.vmt")
resource.AddFile("materials/models/ms_acabinet/ms_acabinet_artwork.vmt")
resource.AddSingleFile("materials/models/ms_acabinet/ms_acabinet_artwork_normal.vtf")
resource.AddFile("materials/models/ms_acabinet/ms_acabinet_buttons.vmt")
resource.AddSingleFile("materials/models/ms_acabinet/ms_acabinet_buttons_normal.vtf")
resource.AddFile("materials/models/ms_acabinet/ms_acabinet_marque.vmt")
resource.AddSingleFile("materials/models/ms_acabinet/ms_acabinet_outerglass.vmt")
resource.AddFile("materials/models/ms_acabinet/ms_acabinet_screen.vmt")

local function AddCSGameFiles()
    local ext = "games/"
    for _, file in pairs(file.Find(ext .. "*.lua", "LUA")) do
        AddCSLuaFile(ext .. file)
    end

    ext = "lib/"
    for _, file in pairs(file.Find(ext .. "*.lua", "LUA")) do
        AddCSLuaFile(ext .. file)
    end
end
concommand.Add("arcademachine_addcsgamefiles", AddCSGameFiles)
AddCSGameFiles()

function ENT:SpawnFunction(ply, tr)
    if (!tr.Hit) then return end
    
    local ent = ents.Create(self.Class)
    ent:SetPos(tr.HitPos)
    ent:Spawn()
    ent:SetAngles(Angle(0, (ply:GetPos() - tr.HitPos):Angle().y, 0))
    ent:Activate()
    
    ent.Owner = ply
    undo.Create(self.Class)
        undo.AddEntity(ent)
        undo.SetPlayer(ply)
    undo.Finish()
    
    return ent
end

function ENT:Initialize()
    self.Entity:SetModel("models/metastruct/ms_acabinet.mdl")
    self.Entity:SetSubMaterial(4, "!ArcadeMachine_Screen_Material_" .. self:EntIndex())
    self.Entity:SetSubMaterial(3, "!ArcadeMachine_Marquee_Material_" .. self:EntIndex())
    
    self:SetUseType(SIMPLE_USE)

    self.Entity:SetBodygroup(0, math.random(0, 1))

    self.Entity:SetMoveType(MOVETYPE_VPHYSICS)
    self.Entity:SetSolid(SOLID_VPHYSICS)
    self.Entity:PhysicsInit(SOLID_VPHYSICS)
    local phys = self.Entity:GetPhysicsObject()
    if phys:IsValid() then
        phys:EnableMotion(false)
    end

    -- Seat
    local seat = ents.Create("prop_vehicle_prisoner_pod")
    seat:SetModel("models/nova/airboat_seat.mdl")
    seat:SetParent(self)
    seat:SetKeyValue("vehiclescript", "scripts/vehicles/prisoner_pod.txt")
    seat:SetKeyValue("limitview", "0")
    seat:SetAngles(Angle(0, 90, 0))
    seat:SetLocalPos(Vector(30, 0, -7))
    -- Can't use nodraw on server as entity will not be networked
    seat:SetRenderMode(RENDERMODE_NONE)
    seat:DrawShadow(false)
    seat:Spawn()
    seat:SetNotSolid(true)
    self:DeleteOnRemove(seat)

    -- Blocker
    local blocker = ents.Create("prop_physics")
    blocker:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    blocker:SetParent(self)
    blocker:SetLocalPos(Vector(30, 0, -7))
    blocker:SetRenderMode(RENDERMODE_NONE)
    blocker:SetMoveType(MOVETYPE_NONE)
    blocker:DrawShadow(false)
    blocker:Spawn()
    blocker:SetNotSolid(true)
    self:DeleteOnRemove(blocker)
    self.BlockerInitialized = false

    if _R.Player.TakeCoins then
        self:SetMSCoinCost(100)
    end

    timer.Simple(0.05, function() -- Thanks gmod
        self:SetSeat(seat)
        self:SetBlocker(blocker)
        self:SetOwner(nil)
        seat:SetOwner(self:GetOwner())
        blocker:SetOwner(self:GetOwner())
    end)

    self.CanLeaveVehicle = false
end

function ENT:Think()
    if not IsValid(self:GetPlayer()) or self:GetSeat():GetDriver() ~= self:GetPlayer() then
        self:SetPlayer(nil)
        self:SetCoins(0)
        self:GetBlocker():SetNotSolid(true)
    end

    self:NextThink(CurTime() + 0.1)
    return true
end

function ENT:Use(activator, caller)
    if not activator:IsPlayer() or not activator:IsValid() then return end

    if not IsValid(self:GetPlayer()) then
        self:SetPlayer(activator)
        self:GetPlayer():EnterVehicle(self:GetSeat())
        self.CanLeaveVehicle = false
        self:GetPlayer().ArcadeWasAllowedWeaponsInVehicle = self:GetPlayer():GetAllowWeaponsInVehicle()
        self:GetPlayer():SetAllowWeaponsInVehicle(false)

        if not self.BlockerInitialized then
            self:GetBlocker():PhysicsInitBox(Vector(-16, -16, 0), Vector(16, 16, 72))
            self.BlockerInitialized = true
        end
        self:GetBlocker():SetNotSolid(false)
    end
end

function ENT:OnRemove()

end

-- To stop people accidentally tapping E and leaving, don't let them leave normally
-- the client has to tell us in a net message that they really want to leave
hook.Add("CanExitVehicle", "arcademachine_canexitvehicle", function(veh, ply)
    if not veh.ArcadeMachine then return end

    return veh.ArcadeMachine.CanLeaveVehicle
end)

util.AddNetworkString("arcademachine_leave")
net.Receive("arcademachine_leave", function(len, ply)
    local veh = ply:GetVehicle()

    if not IsValid(veh) or not IsValid(veh.ArcadeMachine) or veh.ArcadeMachine:GetPlayer() ~= ply then return end

    veh.ArcadeMachine.CanLeaveVehicle = true
    ply:ExitVehicle()
    ply:SetAllowWeaponsInVehicle(ply.ArcadeWasAllowedWeaponsInVehicle)
end)

hook.Add("PlayerLeaveVehicle", "arcademachine_leavevehicle", function(ply, veh)
    if not IsValid(veh.ArcadeMachine) or not IsValid(veh.ArcadeMachine:GetBlocker()) then return end

    veh.ArcadeMachine:GetBlocker():SetNotSolid(true)

    ply:SetPos(veh:GetPos() + veh:GetForward() * -10 + veh:GetUp() * 10)
    ply:SetEyeAngles((veh.ArcadeMachine:GetPos() - ply:EyePos()):Angle())
end)

util.AddNetworkString("arcademachine_insertcoin")
net.Receive("arcademachine_insertcoin", function(len, ply)
    local veh = ply:GetVehicle()

    if not IsValid(veh) or not IsValid(veh.ArcadeMachine) or veh.ArcadeMachine:GetPlayer() ~= ply then return end

    local cost = veh.ArcadeMachine:GetMSCoinCost()

    if cost > 0 and ply.TakeCoins and veh.ArcadeMachine:GetPlayer() == ply then
        if ply:GetCoins() > cost then
            ply:TakeCoins(cost, "Arcade")
        else
            return
        end
    end

    veh.ArcadeMachine:SetCoins(veh.ArcadeMachine:GetCoins() + 1)
end)

util.AddNetworkString("arcademachine_takecoins")
net.Receive("arcademachine_takecoins", function(len, ply)
    local veh = ply:GetVehicle()

    if not IsValid(veh) or not IsValid(veh.ArcadeMachine) or veh.ArcadeMachine:GetPlayer() ~= ply then return end

    local amount = net.ReadInt(16)

    if not amount or amount > veh.ArcadeMachine:GetCoins() then return end

    veh.ArcadeMachine:SetCoins(veh.ArcadeMachine:GetCoins() - amount)
end)