ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Air Hockey"
ENT.Author = "ukgamer"
ENT.Category = "ukgamer"
ENT.Spawnable = false

ENT.Class = "arcade_airhockey"

function ENT:OnSeatCreated(name, old, new)
    if IsValid(new) and not new.HasUpdatedAnim then
        new.HandleAnimation = function(veh, ply)
            return ply:LookupSequence("idle_all_01")
        end

        new.AirHockey = self

        new.HasUpdatedAnim = true
    end
end

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "Score1")
    self:NetworkVar("Int", 1, "Score2")
    self:NetworkVar("Entity", 0, "Seat1")
    self:NetworkVar("Entity", 1, "Seat2")
    self:NetworkVar("Entity", 2, "Player1")
    self:NetworkVar("Entity", 3, "Player2")
    self:NetworkVar("Entity", 4, "Puck")
    self:NetworkVar("Entity", 5, "Striker1")
    self:NetworkVar("Entity", 6, "Striker2")

    if CLIENT then
        self:NetworkVarNotify("Score1", self.OnScoreChange)
        self:NetworkVarNotify("Score2", self.OnScoreChange)
    end

    self:NetworkVarNotify("Player1", self.OnPlayerChange)
    self:NetworkVarNotify("Player2", self.OnPlayerChange)

    self:NetworkVarNotify("Seat1", self.OnSeatCreated)
    self:NetworkVarNotify("Seat2", self.OnSeatCreated)
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

-- Isn't called when player becomes nil...
function ENT:OnPlayerChange(name, old, new)
    if CLIENT then
        local key = name == "Player1" and "LastPlayer1" or "LastPlayer2"

        if IsValid(new) then
            if old ~= new then
                self[key] = new

                if new == LocalPlayer() then
                    self:OnLocalPlayerEntered()
                end
            end
        else
            self[key] = nil

            if old == LocalPlayer() then
                ARCADE.AirHockey:OnLocalPlayerLeft()
            end
        end
    else
        if not IsValid(new) then
            self:Reset()
        end
    end
end