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

local MinX, MaxX = -23, 23
local MinY1, MaxY1 = -47, 6
local MinY2, MaxY2 = -6, 47

function ENT:PhysicsSimulate(phys, delta)
    phys:Wake()

    if not self.GetMoveVector then return end

    local hockeyTable = self:GetAirHockeyTable()

    if not IsValid(hockeyTable) then return end

    local origin = hockeyTable:GetStriker1() == self and StartPos1 or StartPos2

    phys:UpdateShadow(hockeyTable:LocalToWorld(origin + self:GetMoveVector()), Angle(0, hockeyTable:GetAngles().y), FrameTime())
end

hook.Add("StartCommand", "arcade_airhockey_move", function(ply, cmd)
    local veh = ply:GetVehicle()

    if not IsValid(veh) or not IsValid(veh.AirHockey) then return end

    local striker = veh.AirHockey:GetPlayer1() == ply and veh.AirHockey:GetStriker1() or veh.AirHockey:GetStriker2()

    if not striker.GetMoveVector then return end

    local isPlayer1 = veh.AirHockey:GetPlayer1() == ply

    -- TODO: Add configurable mouse sensitivity
    local mouseX = math.Clamp(cmd:GetMouseX() * 0.1, -3, 3)
    local mouseY = math.Clamp(cmd:GetMouseY() * 0.1, -3, 3)

    local multX = isPlayer1 and -1 or 1
    local multY = isPlayer1 and 1 or -1

    local targetPos = striker:GetMoveVector()

    targetPos.x = math.Clamp(targetPos.x + (mouseX * multX), MinX, MaxX)
    targetPos.y = math.Clamp(targetPos.y + (mouseY * multY), isPlayer1 and MinY1 or MinY2, isPlayer1 and MaxY1 or MaxY2)

    striker:SetMoveVector(targetPos)
end)