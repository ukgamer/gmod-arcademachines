ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Air Hockey Striker"
ENT.Author = "ukgamer"
ENT.Category = "ukgamer"
ENT.Spawnable = false

ENT.Class = "arcade_airhockey_striker"

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "AirHockeyTable")
    self:NetworkVar("Vector", 0, "MoveVector")
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

local StartPos1 = Vector(0, 50, 34.8)
local StartPos2 = Vector(0, -50, 34.8)

local LocalBoundary1 = {
    Vector(24, 57, 33.8),
    Vector(24, 2, 33.8),
    Vector(-24, 2, 33.8),
    Vector(-24, 57, 33.8),
    Vector(24, 57, 40),
    Vector(24, 2, 40),
    Vector(-24, 2, 40),
    Vector(-24, 57, 40)
}

local LocalBoundary2 = {
    Vector(24, -57, 33.8),
    Vector(24, -2, 33.8),
    Vector(-24, -2, 33.8),
    Vector(-24, -57, 33.8),
    Vector(24, -57, 40),
    Vector(24, -2, 40),
    Vector(-24, -2, 40),
    Vector(-24, -57, 40)
}

function ENT:PhysicsSimulate(phys, delta)
    phys:Wake()

    if not self.GetMoveVector then return end

    local hockeyTable = self:GetAirHockeyTable()

    if not IsValid(hockeyTable) then return end

    local origin = hockeyTable:LocalToWorld(hockeyTable:GetStriker1() == self and StartPos1 or StartPos2)

    phys:UpdateShadow(self:GetMoveVector() and origin + self:GetMoveVector() or origin, Angle(0, hockeyTable:GetAngles().y), FrameTime())
end

hook.Add("StartCommand", "arcade_airhockey_move", function(ply, cmd)
    local veh = ply:GetVehicle()

    if not IsValid(veh) or not IsValid(veh.AirHockey) then return end

    local striker = veh.AirHockey:GetPlayer1() == ply and veh.AirHockey:GetStriker1() or veh.AirHockey:GetStriker2()

    if not striker.GetMoveVector then return end

    -- TODO: Add configurable mouse sensitivity
    local mouseX = math.Clamp(cmd:GetMouseX() * 0.1, -3, 3)
    local mouseY = math.Clamp(cmd:GetMouseY() * 0.1, -3, 3)

    local mult = veh.AirHockey:GetPlayer1() == ply and -1 or 1

    local targetPos = (striker:GetMoveVector() or Vector()) + (veh.AirHockey:GetForward() * mouseX * mult) + (veh.AirHockey:GetRight() * mouseY * mult)

    local absTargetPos = veh.AirHockey:WorldToLocal(veh.AirHockey:LocalToWorld(striker == veh.AirHockey:GetStriker1() and StartPos1 or StartPos2) + targetPos)

    if
        (striker == veh.AirHockey:GetStriker1() and ARCADE:WithinBounds(absTargetPos, LocalBoundary1)) or
        (striker == veh.AirHockey:GetStriker2() and ARCADE:WithinBounds(absTargetPos, LocalBoundary2))
    then
        striker:SetMoveVector(targetPos)
    end
end)