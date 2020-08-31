ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Air Hockey Striker"
ENT.Author = "ukgamer"
ENT.Category = "ukgamer"
ENT.Spawnable = false

ENT.Class = "arcade_airhockey_striker"

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

local startPos1 = Vector(0, 50, 34.8)
local startPos2 = Vector(0, -50, 34.8)

function ENT:PhysicsSimulate(phys, delta)
    phys:Wake()

    local hockeyTable = self:GetAirHockeyTable()

    if not IsValid(hockeyTable) then return end

    local origin = hockeyTable:LocalToWorld(hockeyTable:GetStriker1() == self and startPos1 or startPos2)

    if not self.MoveVector then
        phys:UpdateShadow(origin, Angle(), FrameTime())
    else
        phys:UpdateShadow(origin + self.MoveVector, Angle(), FrameTime())
    end
end

hook.Add("StartCommand", "arcade_airhockey_move", function(ply, cmd)
    local veh = ply:GetVehicle()

    if not IsValid(veh) or not IsValid(veh.AirHockey) then return end

    local striker = veh.AirHockey:GetPlayer1() == ply and veh.AirHockey:GetStriker1() or veh.AirHockey:GetStriker2()

    local mouseX = math.Clamp(cmd:GetMouseX() * 0.1, -3, 3)
    local mouseY = math.Clamp(cmd:GetMouseY() * 0.1, -3, 3)

    striker.MoveVector = (striker.MoveVector or Vector()) + (veh.AirHockey:GetForward() * -mouseX) + (veh.AirHockey:GetRight() * -mouseY)
end)