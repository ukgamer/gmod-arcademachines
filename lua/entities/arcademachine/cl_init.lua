include("shared.lua")

local FOV = CreateClientConVar("arcademachine_fov", 70, true, false)

local ScreenWidth = 512
local ScreenHeight = 512
local MarqueeWidth = 256
local MarqueeHeight = 80

local PressedScore = false
local PressedUse = false
local HoldUseUntil = 0

ENT.Initialized = false

function ENT:Initialize()
    self.Initialized = true

    self.ScreenTexture = GetRenderTargetEx(
        "ArcadeMachine_Screen_" .. self:EntIndex(),
        ScreenWidth,
        ScreenHeight,
        RT_SIZE_DEFAULT,
        MATERIAL_RT_DEPTH_NONE,
        1,
        CREATERENDERTARGETFLAGS_AUTOMIPMAP,
        IMAGE_FORMAT_DEFAULT
    )
    self.ScreenMaterial = CreateMaterial(
        "ArcadeMachine_Screen_Material_" .. self:EntIndex(),
        "UnlitGeneric",
        {
            ["$basetexture"] = self.ScreenTexture:GetName(),
            ["$model"] = 1
        }
    )

    self.MarqueeTexture = GetRenderTargetEx(
        "ArcadeMachine_Marquee_" .. self:EntIndex(),
        MarqueeWidth,
        256, -- Not the same as the drawable area
        RT_SIZE_DEFAULT,
        MATERIAL_RT_DEPTH_NONE,
        1,
        CREATERENDERTARGETFLAGS_HDR,
        IMAGE_FORMAT_DEFAULT
    )
    self.MarqueeMaterial = CreateMaterial(
        "ArcadeMachine_Marquee_Material_" .. self:EntIndex(),
        "UnlitGeneric",
        {
            ["$basetexture"] = self.MarqueeTexture:GetName(),
            ["$model"] = 1,
            ["$nodecal"] = 1
        }
    )

    self.Entity:SetSubMaterial(4, "!ArcadeMachine_Screen_Material_" .. self:EntIndex())
    self.Entity:SetSubMaterial(3, "!ArcadeMachine_Marquee_Material_" .. self:EntIndex())

    self.Active = self.Active or false
    self.Game = self.Game or nil

    if self:GetCurrentGame() and not self.Game then
        self:LoadGameFromFile(self:GetCurrentGame())
    end

    self:UpdateMarquee()
    self:UpdateScreen()
end

function ENT:OnRemove()
    if self.Game and self.Game.Destroy then
        self.Game:Destroy()
    end
end

function ENT:Think()
    -- Work around init not being called on the client sometimes
    if not self.Initialized then
        self:Initialize()
    end

    -- Workaround network var notify not triggering for null entity
    if self.Game and self.LastPlayer and self.LastPlayer ~= self:GetPlayer() then
        self.Game:OnStopPlaying(self.LastPlayer)
        self.LastPlayer = nil
    end

    -- If we weren't nearby when the machine was spawned we won't get notified
    -- when the seat was created so manually call OnSeatCreated
    if IsValid(self:GetSeat()) and not self:GetSeat().ArcadeMachine then
        self:OnSeatCreated("Seat", self:GetSeat(), self:GetSeat())
    end

    if LocalPlayer():GetPos():DistToSqr(self.Entity:GetPos()) > (self.MaxDist * self.MaxDist) then
        if self.Active then
            self.Active = false
            self:OnLeftRange()
        end
    else
        if not self.Active then
            self.Active = true
            self:OnEnteredRange()
        end
    end

    if self.Active and self.Game then
        if IsValid(self:GetPlayer()) and self:GetPlayer() == LocalPlayer() then
            local pressed = input.LookupBinding("+walk") and self:GetPlayer():KeyDown(IN_WALK) or input.IsKeyDown(KEY_LALT)

            if pressed then
                if not PressedScore then
                    net.Start("arcademachine_insertcoin")
                    net.SendToServer()
    
                    PressedScore = true
                end
            else
                PressedScore = false
            end
        end

        self.Game:Update()
    end
end

function ENT:OnEnteredRange()
    self:UpdateScreen()
end

function ENT:OnLeftRange()
    self:UpdateScreen()
end

function ENT:Draw()
    self.Entity:DrawModel()

    if not self.Active or not self.Game then
        return
    end

    self:UpdateScreen()
end

function ENT:OnBlockerCreated(name, old, new)
    new.RenderOverride = function() end
end

-- Isn't called when player becomes nil...
function ENT:OnPlayerChange(name, old, new)
    if not self.Game then return end
    
    if IsValid(new) then
        if old ~= new then
            self.Game:OnStartPlaying(new)
            self.LastPlayer = new
        end
    else
        self.Game:OnStopPlaying(old)
    end
end

function ENT:UpdateMarquee()
    render.PushRenderTarget(self.MarqueeTexture)
        cam.Start2D()
            surface.SetDrawColor(0, 0, 0, 255)
            surface.DrawRect(0, 0, MarqueeWidth, MarqueeHeight)

            if self.Game and self.Game.DrawMarquee then
                self.Game:DrawMarquee()
            else
                surface.SetFont("DermaLarge")
                local w, h = surface.GetTextSize(self.Game and self.Game.Name or "Arcade Machine")
                surface.SetTextColor(255, 255, 255, 255)
                surface.SetTextPos((MarqueeWidth / 2) - (w / 2), (MarqueeHeight / 2) - (h / 2))
                surface.DrawText(self.Game and self.Game.Name or "Arcade Machine")
            end
        cam.End2D()
    render.PopRenderTarget()
end

function ENT:UpdateScreen()
    render.PushRenderTarget(self.ScreenTexture)
        cam.Start2D()
            surface.SetDrawColor(0, 0, 0, 255)
            surface.DrawRect(0, 0, ScreenWidth, ScreenHeight)

            if self.Active then
                if self.Game then
                    self.Game:Draw()
                else
                    surface.SetFont("DermaLarge")
                    local w, h = surface.GetTextSize("NO GAME LOADED")
                    surface.SetTextColor(255, 255, 255, 255)
                    surface.SetTextPos((ScreenWidth / 2) - (w / 2), ScreenHeight / 2)
                    surface.DrawText("NO GAME LOADED")
                end
            end
        cam.End2D()
    render.PopRenderTarget()
end

function ENT:OnCoinsChange(name, old, new)
    if new > old and self.Game and self.Game.OnCoinsInserted then
        self.Game:OnCoinsInserted(self:GetPlayer(), old, new)
    end

    if new < old and self.Game and self.Game.OnCoinsLost then
        self.Game:OnCoinsLost(self:GetPlayer(), old, new)
    end
end

function ENT:OnGameChange(name, old, new)
    if old == new then return end

    self:LoadGameFromFile(new)
end

function ENT:LoadGameFromFile(filename)
    self:SetGame(filename == "" and "" or include("games/" .. filename .. ".lua"))
end

function ENT:SetGame(game)
    if self.Game then
        if self.Game.Destroy then
            self.Game:Destroy()
        end
        self.Game = nil
    end

    if game and game ~= "" then
        self.Game = game
        self.Game:Init(self, ScreenWidth, ScreenHeight, MarqueeWidth, MarqueeHeight)
    end

    self:UpdateMarquee()
    self:UpdateScreen()
end

function ENT:TakeCoins(amount)
    if not amount or amount > self:GetCoins() then return end

    net.Start("arcademachine_takecoins")
        net.WriteInt(amount, 16)
    net.SendToServer()
end

hook.Add("CalcVehicleView", "arcademachine_view", function(veh, ply, view)
    local veh = LocalPlayer():GetVehicle()
    
    if not IsValid(veh) then return end

    local tp = veh.GetThirdPersonMode and veh:GetThirdPersonMode() or false

    if tp then return end

    local machine = veh.ArcadeMachine

    if not IsValid(machine) then return end

    if machine:GetBodygroup(0) == 1 then
        view.origin = veh:GetPos() + veh:GetRight() * -8 + veh:GetUp() * 72
    else
        view.origin = veh:GetPos() + veh:GetUp() * 64
    end

    view.fov = FOV:GetInt()

    return view
end)

hook.Add("CreateMove", "arcademachine_scroll", function(cmd)
    local veh = LocalPlayer():GetVehicle()
    
    if not IsValid(veh) then return end

    local machine = veh.ArcadeMachine

    if not IsValid(machine) then return end

    local fov = FOV:GetInt()

    if cmd:GetMouseWheel() < 0 and fov < 100 then
        FOV:SetInt(fov + 2)
    end
    if cmd:GetMouseWheel() > 0 and fov > 40 then
        FOV:SetInt(fov - 2)
    end

    if bit.band(cmd:GetButtons(), IN_USE) ~= 0 then
        if not PressedUse then
            PressedUse = true
            HoldUseUntil = RealTime() + 0.8
        elseif RealTime() >= HoldUseUntil then
            net.Start("arcademachine_leave")
            net.SendToServer()
            PressedUse = false
        end
    else
        PressedUse = false
    end
end)

hook.Add("ScoreboardShow", "arcademachine_scoreboard", function()
    local veh = LocalPlayer():GetVehicle()
    
    if not IsValid(veh) then return end

    local machine = veh.ArcadeMachine

    if not IsValid(machine) then return end

    return false
end)