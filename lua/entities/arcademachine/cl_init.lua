include("shared.lua")

local FOV = CreateClientConVar("arcademachine_fov", 70, true, false)
local DisablePAC = CreateClientConVar("arcademachine_disable_pac", 1, true, false)
--local DisableOutfitter = CreateClientConVar("arcademachine_disable_outfitter", 1, true, false)
local DisableOthers = CreateClientConVar("arcademachine_disable_others_when_active", 0, true, false)

local LookDist = 100
local MaxDist = 200

local ScreenWidth = 512
local ScreenHeight = 512
local MarqueeWidth = 256
local MarqueeHeight = 89

local PressedWalk = false
local PressedUse = false
local PressedUseAt = 0

local PACWasDisabled = false
--local OutfitterWasDisabled = false

local LoadedLibs = {}

local QueuedSounds = {}
local NextQueueAt = 0

CurrentMachine = CurrentMachine or nil

local function WrappedInclusion(path, upvalues)
    local gameMeta = setmetatable(upvalues, { __index = _G, __newindex = _G })

    local gameFunc = (isfunction(path) and path or CompileFile(path))
    setfenv(gameFunc, gameMeta)
    return gameFunc()
end

local InfoPanel = nil
local LookingAt = nil
local function ShowInfoPanel(machine)
    LookingAt = machine

    local bg = Color(0, 0, 0, 200)

    InfoPanel = vgui.Create("DFrame")
    
    InfoPanel:SetSize(ScrW() * 0.15, ScrH() * 0.25)
    InfoPanel:SetMinimumSize(350, 350)
    InfoPanel:SetPos(0, ScrH() * 0.5 - (InfoPanel:GetTall() * 0.5))
    InfoPanel:SetTitle("")
    InfoPanel:SetDraggable(false)
    InfoPanel:ShowCloseButton(false)
    InfoPanel:DockPadding(10, 10, 10, 20)
    InfoPanel.Paint = function(self, w, h)
        draw.RoundedBoxEx(20, 0, 0, w, h, bg, false, true, false, true)

        local text = "Open chat and mouse over to scroll (default Y)"

        surface.SetTextColor(255, 255, 255, 255)
        surface.SetFont("DermaDefaultBold")
        local tw, th = surface.GetTextSize(text)
        surface.SetTextPos(w * 0.5 - (tw * 0.5), h - th - 5)
        surface.DrawText(text)
    end

    local scroll = vgui.Create("DScrollPanel", InfoPanel)
    scroll:Dock(FILL)
    local sbar = scroll:GetVBar()
    sbar.Paint = function(self, w, h) end
    sbar.btnUp.Paint = function(self, w, h) end
    sbar.btnDown.Paint = function(self, w, h) end
    sbar.btnGrip.Paint = function(self, w, h) end

    if machine.Game then
        local label = vgui.Create("DLabel", scroll)
        label:Dock(TOP)
        label:SetWrap(true)
        label:SetAutoStretchVertical(true)
        label:DockMargin(0, 0, 0, 15)
        label:SetFont("DermaLarge")
        label:SetText(machine.Game.Name)
    end

    local label = vgui.Create("DLabel", scroll)
    label:Dock(TOP)
    label:SetWrap(true)
    label:SetAutoStretchVertical(true)
    label:DockMargin(0, 0, 0, 15)
    label:SetFont("DermaDefaultBold")
    label:SetText("Instructions/Controls")

    local label = vgui.Create("DLabel", scroll)
    label:Dock(TOP)
    label:SetWrap(true)
    label:SetAutoStretchVertical(true)
    label:DockMargin(0, 0, 0, 15)
    label:SetFont("DermaDefault")
    label:SetText("Press your WALK key (default ALT) to insert coins. Use scroll wheel to zoom. Hold USE (default E) to exit (you will lose any ununsed coins!).")

    if DisablePAC:GetBool() and pac then
        local label = vgui.Create("DLabel", scroll)
        label:Dock(TOP)
        label:SetWrap(true)
        label:SetAutoStretchVertical(true)
        label:DockMargin(0, 0, 0, 15)
        label:SetFont("DermaDefault")
        label:SetText("WARNING: PAC will be temporarily disabled to help with performance while playing. It will be re-enabled when you exit the machine. This functionality can be disabled in the console with arcademachine_disable_pac 0.")
    end

    if machine.Game.Description then
        local label = vgui.Create("DLabel", scroll)
        label:Dock(TOP)
        label:SetWrap(true)
        label:SetAutoStretchVertical(true)
        label:DockMargin(0, 0, 0, 15)
        label:SetFont("DermaDefaultBold")
        label:SetText("Game Information")

        local label = vgui.Create("DLabel", scroll)
        label:Dock(TOP)
        label:SetWrap(true)
        label:SetAutoStretchVertical(true)
        label:DockMargin(0, 0, 0, 15)
        label:SetFont("DermaDefault")
        label:SetText(machine.Game.Description)
    end
end

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
        CREATERENDERTARGETFLAGS_HDR,
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
        16,
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

    self.InRange = self.InRange or false
    self.Game = self.Game or nil
    self.LoadedSounds = self.LoadedSounds or {}

    if self:GetCurrentGame() and not self.Game then
        self:SetGame(self:GetCurrentGame())
    end

    self:UpdateMarquee()
    self:UpdateScreen()
end

function ENT:OnRemove()
    if self.Game and self.Game.Destroy then
        self.Game:Destroy()
    end

    self:StopSounds()
end

function ENT:Think()
    -- Work around init not being called on the client sometimes
    if not self.Initialized then
        self:Initialize()
    end

    -- Workaround network var notify not triggering for null entity
    if self.LastPlayer and self.LastPlayer ~= self:GetPlayer() then
        self:OnPlayerChange("Player", self.LastPlayer, self:GetPlayer())
    end

    -- If we weren't nearby when the machine was spawned we won't get notified
    -- when the seat was created so manually call
    if IsValid(self:GetSeat()) and not self:GetSeat().ArcadeMachine then
        self:OnSeatCreated("Seat", nil, self:GetSeat())
    end

    if DisableOthers:GetBool() and CurrentMachine and CurrentMachine ~= self then
        return
    end

    if LocalPlayer() and LocalPlayer():GetPos():DistToSqr(self.Entity:GetPos()) > MaxDist * MaxDist then
        if self.InRange then
            self.InRange = false
            self:OnLeftRange()
        end
    else
        if not self.InRange then
            self.InRange = true
            self:OnEnteredRange()
        end
    end

    if self.InRange and self.Game then
        if IsValid(self:GetPlayer()) and self:GetPlayer() == LocalPlayer() then
            local pressed = input.LookupBinding("+walk") and self:GetPlayer():KeyDown(IN_WALK) or input.IsKeyDown(KEY_LALT)

            if pressed then
                if not PressedWalk then
                    PressedWalk = true

                    local cost = self:GetMSCoinCost()

                    if cost > 0 and LocalPlayer().GetCoins and LocalPlayer():GetCoins() < cost then
                        notification.AddLegacy("You don't have enough coins!", NOTIFY_ERROR, 5)
                        return
                    end

                    net.Start("arcademachine_insertcoin")
                    net.SendToServer()
                end
            else
                PressedWalk = false
            end
        end

        for _, v in pairs(self.LoadedSounds) do
            if IsValid(v) then
                v:SetPos(self.Entity:GetPos())
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
    -- To prevent using string table slots, don't set the submaterial on the server
    -- and just override it here
    render.MaterialOverrideByIndex(3, self.MarqueeMaterial)
    render.MaterialOverrideByIndex(4, self.ScreenMaterial)
    self.Entity:DrawModel()
    render.MaterialOverrideByIndex()

    if not self.InRange or not self.Game or (DisableOthers:GetBool() and CurrentMachine and CurrentMachine ~= self) then
        return
    end

    self:UpdateScreen()
end

-- Isn't called when player becomes nil...
function ENT:OnPlayerChange(name, old, new)
    if IsValid(new) then
        if old ~= new then
            if old and self.Game then
                self.Game:OnStopPlaying(old)
            end

            if self.Game then
                self.Game:OnStartPlaying(new)
            end
            
            self.LastPlayer = new

            if new == LocalPlayer() then
                self:OnLocalPlayerEntered()
            end
        end
    else
        if self.Game then
            self.Game:OnStopPlaying(old)
        end

        self.LastPlayer = nil

        if old == LocalPlayer() then
            self:OnLocalPlayerLeft()
        end
    end
end

function ENT:OnLocalPlayerEntered()
    CurrentMachine = self

    local cost = self:GetMSCoinCost()

    if cost > 0 then
        local msg = "This machine takes " .. cost .. " Metastruct coin(s) at a time."
        LocalPlayer():ChatPrint(msg)
        notification.AddLegacy(msg, NOTIFY_HINT, 10)
    end

    if DisablePAC:GetBool() and pac then
        pac.Disable()
        PACWasDisabled = true
    else
        PACWasDisabled = false
    end

    --[[if DisableOutfitter:GetBool() and outfitter then
        outfitter.SetHighPerf(true, true)
        outfitter.DisableEverything()
        OutfitterWasDisabled = true
    else
        OutfitterWasDisabled = false
    end--]]
end

function ENT:OnLocalPlayerLeft()
    CurrentMachine = nil

    if DisablePAC:GetBool() and PACWasDisabled then
        pac.Enable()
    end

    --[[if DisableOutfitter:GetBool() and OutfitterWasDisabled then
        outfitter.SetHighPerf(false, true)
        outfitter.EnableEverything()
    end--]]
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

            if self.InRange then
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

    self:SetGame(new)
end

function ENT:StopSounds()
    for k, v in pairs(self.LoadedSounds) do
        if IsValid(v) then
            v:Stop()
        end
    end

    table.Empty(self.LoadedSounds)
    if QueuedSounds[self:EntIndex()] then
        QueuedSounds[self:EntIndex()] = nil
    end
end

function ENT:SetGame(game, forceLibLoad)
    if self.Game then
        if self.Game.Destroy then
            self.Game:Destroy()
        end
        self.Game = nil
    end

    self:StopSounds()

    if game and game ~= "" then
        local upvalues = {
            MACHINE = self,
            SCREEN_WIDTH = ScreenWidth,
            SCREEN_HEIGHT = ScreenHeight,
            MARQUEE_WIDTH = MarqueeWidth,
            MARQUEE_HEIGHT = MarqueeHeight
        }

        if LoadedLibs[game] and not forceLibLoad then
            upvalues.COLLISION = LoadedLibs[game].COLLISION
            upvalues.IMAGE = LoadedLibs[game].IMAGE
            upvalues.FONT = LoadedLibs[game].FONT
        else
            LoadedLibs[game] = {
                COLLISION = include("arcademachine_lib/collision.lua"),
                IMAGE = include("arcademachine_lib/image.lua"),
                FONT = include("arcademachine_lib/font.lua")
            }

            upvalues.COLLISION = LoadedLibs[game].COLLISION
            upvalues.IMAGE = LoadedLibs[game].IMAGE
            upvalues.FONT = LoadedLibs[game].FONT
        end

        -- Allow each instance to have its own copy of sound library in case they want to
        -- play the same sound at the same time (needs to emit from the machine)
        upvalues.SOUND = WrappedInclusion("arcademachine_lib/sound.lua", { MACHINE = self, QUEUE = QueuedSounds })

        self.Game = WrappedInclusion(isfunction(game) and game or "arcademachine_games/" .. game .. ".lua", upvalues)
        if self.Game.Init then
            self.Game:Init()
        end

        if IsValid(self:GetPlayer()) and self:GetPlayer() == LocalPlayer() then
            self.Game:OnStartPlaying(self:GetPlayer())
        end
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
    if not IsValid(CurrentMachine) then
        return
    end

    local tp = veh.GetThirdPersonMode and veh:GetThirdPersonMode() or false

    if tp then return end

    if CurrentMachine:GetBodygroup(0) == 1 then
        view.origin = veh:GetPos() + veh:GetRight() * -8 + veh:GetUp() * 72
    else
        view.origin = veh:GetPos() + veh:GetUp() * 64
    end

    view.fov = FOV:GetInt()

    return view
end)

hook.Add("CreateMove", "arcademachine_scroll", function(cmd)
    if not IsValid(CurrentMachine) then
        PressedUse = false
        return
    end

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
            PressedUseAt = RealTime()
        elseif RealTime() >= PressedUseAt + 0.8 then
            net.Start("arcademachine_leave")
            net.SendToServer()
            PressedUse = false
        end
    else
        PressedUse = false
    end
end)

hook.Add("ScoreboardShow", "arcademachine_scoreboard", function()
    if not IsValid(CurrentMachine) then return end

    return false
end)

local notificationColor = Color(255, 255, 255)
hook.Add("HUDPaint", "arcademachine_hud", function()
    if PressedUse then
        notificationColor.a = 50 + math.abs(math.sin(RealTime() * 10) * 205)

        draw.DrawText("Keep holding USE to exit the machine!", "DermaLarge", ScrW() * 0.5, ScrH() * 0.3, notificationColor, TEXT_ALIGN_CENTER)
    end
end)

hook.Add("Think", "arcademachine_think", function()
    if not IsValid(CurrentMachine) then
        local tr = util.TraceLine(util.GetPlayerTrace(LocalPlayer(), EyeAngles():Forward()))

        if
            IsValid(tr.Entity) and
            tr.Entity:GetClass() == "arcademachine" and
            tr.Entity:GetPos():DistToSqr(LocalPlayer():GetPos()) < LookDist * LookDist
        then
            if LookingAt ~= tr.Entity and IsValid(InfoPanel) then
                InfoPanel:Remove()
            end

            if not IsValid(InfoPanel) then
                ShowInfoPanel(tr.Entity)
            end
        else
            if IsValid(InfoPanel) then
                InfoPanel:Remove()
            end

            LookingAt = nil
        end
    elseif IsValid(InfoPanel) then
        InfoPanel:Remove()

        LookingAt = nil
    end

    if RealTime() < NextQueueAt then return end

    local k, v = next(QueuedSounds)

    if k then
        if #v > 0 then
            v[1].context:LoadQueued(v[1])
            table.remove(v, 1)
        else
            QueuedSounds[k] = nil
        end
    end

    NextQueueAt = RealTime() + 0.05
end)

hook.Add("PrePlayerDraw", "arcademachine_hideplayers", function(ply)
    if not IsValid(CurrentMachine) or ply == LocalPlayer() then return end

    local min, max = LocalPlayer():WorldSpaceAABB()

    return ply:GetPos():WithinAABox(min, max)
end)

hook.Add("HUDDrawTargetID", "arcademachine_hideplayers", function()
    if not IsValid(CurrentMachine) then return end

    return false
end)