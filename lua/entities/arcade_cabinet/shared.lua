ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Arcade Cabinet"
ENT.Author = "ukgamer"
ENT.Category = "ukgamer"
ENT.Spawnable = false
ENT.Instructions = "Press your USE key to play."

ENT.Class = "arcade_cabinet"

function ENT:OnSeatCreated(name, old, new)
    if IsValid(new) and not new.HasUpdatedAnim then
        new.HandleAnimation = function(veh, ply)
            return ply:LookupSequence("idle_all_01")
        end

        new.ArcadeCabinet = self

        new.HasUpdatedAnim = true
    end
end

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "Seat")
    self:NetworkVar("Entity", 1, "Player")
    self:NetworkVar("String", 0, "CurrentGame")
    self:NetworkVar("Int", 0, "Coins")
    self:NetworkVar("Int", 1, "Cost")
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