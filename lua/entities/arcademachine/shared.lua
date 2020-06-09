ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Arcade Machine"
ENT.Author = "ukgamer"
ENT.Category = "ukgamer"
ENT.Spawnable = false
ENT.AdminSpawnable = true

ENT.CanConstruct = function() return false end
ENT.CanTool = function() return false end

ENT.Class = "arcademachine"
ENT.MaxDist = 200

function ENT:OnSeatCreated(name, old, new)
    if IsValid(new) and not new.HasUpdatedAnim then
        new.HandleAnimation = function(veh, ply)
            return ply:LookupSequence("idle_all_01")
        end

        new.ArcadeMachine = self

        new.HasUpdatedAnim = true
    end
end

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "Seat")
    self:NetworkVar("Entity", 1, "Player")
    self:NetworkVar("Entity", 2, "Blocker")
    self:NetworkVar("String", 0, "CurrentGame")
    self:NetworkVar("Int", 0, "Coins")

    if CLIENT then
        self:NetworkVarNotify("Player", self.OnPlayerChange)
        self:NetworkVarNotify("CurrentGame", self.OnGameChange)
        self:NetworkVarNotify("Coins", self.OnCoinsChange)
    end

    self:NetworkVarNotify("Seat", self.OnSeatCreated)
    self:NetworkVarNotify("Blocker", self.OnBlockerCreated)
end

function ENT:CanProperty()
    return false
end