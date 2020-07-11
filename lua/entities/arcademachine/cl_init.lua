include("shared.lua")

local Debug = CreateClientConVar("arcademachine_debug", 0, true, false)
local FOV = CreateClientConVar("arcademachine_fov", 70, true, false)
local DisablePAC = CreateClientConVar("arcademachine_disable_pac", 1, true, false)
--local DisableOutfitter = CreateClientConVar("arcademachine_disable_outfitter", 1, true, false)
local DisableOthers = CreateClientConVar("arcademachine_disable_others_when_active", 0, true, false)

local LookDist = 100
local MaxDist = 200

local ScreenWidth = 512
local ScreenHeight = 512
local MarqueeWidth = 512
local MarqueeHeight = 179

local PressedWalk = false
local PressedUse = false
local PressedUseAt = 0

local PACWasDisabled = false
--local OutfitterWasDisabled = false

local LoadedLibs = {}

local QueuedSounds = {}
local NextQueueAt = 0

local function DebugPrint(...)
    if Debug:GetBool() then
        print("[ARCADE]", ...)
    end
end

local function ClearImageCache()
    local path = "arcademachines/cache/images"
    for _, v in ipairs(file.Find(path .. "/*", "DATA")) do
        file.Delete(path .. "/" .. v)
    end
end

local function ReloadMachines()
    for _, v in ipairs(ents.FindByClass("arcademachine")) do
        if v:GetCurrentGame() then
            v:SetGame(v:GetCurrentGame())
        elseif v.Game then
            if v.Game.Destroy then
                v.Game:Destroy()
            end
            if v.Game.Init then
                v.Game:Init()
            end
        end
    end
end

AMSettingsPanel = AMSettingsPanel or nil
local function ShowSettingsPanel()
    if not IsValid(AMSettingsPanel) then
        AMSettingsPanel = vgui.Create("DFrame")
        AMSettingsPanel:SetSize(ScrW() * 0.15, ScrH() * 0.15)
        AMSettingsPanel:SetMinimumSize(200, 200)
        AMSettingsPanel:SetTitle("Arcade Machine Settings")
        AMSettingsPanel:DockPadding(10, 30, 10, 10)
    
        local scroll = vgui.Create("DScrollPanel", AMSettingsPanel)
        scroll:Dock(FILL)

        local label = vgui.Create("DLabel", scroll)
        label:Dock(TOP)
        label:SetWrap(true)
        label:SetAutoStretchVertical(true)
        label:DockMargin(0, 0, 0, 10)
        label:SetFont("DermaDefaultBold")
        label:SetText("Performance")

        if pac then
            local checkbox = vgui.Create("DCheckBoxLabel", scroll)
            checkbox:Dock(TOP)
            checkbox:DockMargin(0, 0, 0, 5)
            checkbox:SetText("Disable PAC when in machine")
            checkbox:SetConVar("arcademachine_disable_pac")
            checkbox:SetValue(DisablePAC:GetBool())
            checkbox:SizeToContents()
        end

        local checkbox = vgui.Create("DCheckBoxLabel", scroll)
        checkbox:Dock(TOP)
        checkbox:DockMargin(0, 0, 0, 5)
        checkbox:SetText("Disable other machines when in machine")
        checkbox:SetConVar("arcademachine_disable_others_when_active")
        checkbox:SetValue(DisableOthers:GetBool())
        checkbox:SizeToContents()

        local label = vgui.Create("DLabel", scroll)
        label:Dock(TOP)
        label:SetWrap(true)
        label:SetAutoStretchVertical(true)
        label:DockMargin(0, 0, 0, 10)
        label:SetFont("DermaDefaultBold")
        label:SetText("Debug")

        local button = vgui.Create("DButton", scroll)
        button:Dock(TOP)
        button:DockMargin(0, 0, 0, 5)
        button:SetText("Clear image cache")
        button.DoClick = function()
            ClearImageCache()
        end

        local button = vgui.Create("DButton", scroll)
        button:Dock(TOP)
        button:DockMargin(0, 0, 0, 5)
        button:SetText("Reload machines")
        button.DoClick = function()
            ReloadMachines()
        end
    end

    AMSettingsPanel:Center()
    AMSettingsPanel:MakePopup()
end

list.Set("DesktopWindows", "ArcadeMachines", {
    title = "Arcade Machines",
    icon = "icon64/arcademachine.png",
    init = function(icon, window)
        ShowSettingsPanel()
    end
})

AMInfoPanel = AMInfoPanel or nil
local LookingAt = nil
local function ShowInfoPanel(machine)
    if LookingAt == machine then return end

    if LookingAt ~= machine and IsValid(AMInfoPanel) then
        AMInfoPanel:Remove()
    end

    LookingAt = machine

    local bg = Color(0, 0, 0, 200)

    AMInfoPanel = vgui.Create("DFrame")
    AMInfoPanel:SetPaintedManually(true)
    AMInfoPanel:SetSize(ScrW() * 0.15, ScrH() * 0.2)
    AMInfoPanel:SetMinimumSize(300, 300)
    AMInfoPanel:SetPos(0, ScrH() * 0.5 - (AMInfoPanel:GetTall() * 0.5))
    AMInfoPanel:SetTitle("")
    AMInfoPanel:SetDraggable(false)
    AMInfoPanel:ShowCloseButton(false)
    AMInfoPanel:DockPadding(10, 10, 10, 20)
    AMInfoPanel.Paint = function(self, w, h)
        draw.RoundedBoxEx(20, 0, 0, w, h, bg, false, true, false, true)

        local text = "Open chat and mouse over to scroll (default Y)"

        surface.SetTextColor(200, 200, 200, 255)
        surface.SetFont("DermaDefaultBold")
        local tw, th = surface.GetTextSize(text)
        surface.SetTextPos(w * 0.5 - (tw * 0.5), h - th - 5)
        surface.DrawText(text)
    end

    local scroll = vgui.Create("DScrollPanel", AMInfoPanel)
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

    local cost = machine:GetMSCoinCost()

    if cost > 0 then
        local label = vgui.Create("DLabel", scroll)
        label:Dock(TOP)
        label:SetWrap(true)
        label:SetAutoStretchVertical(true)
        label:DockMargin(0, 0, 0, 15)
        label:SetFont("DermaDefault")
        label:SetText("This machine costs " .. cost .. " coin(s) to play.")
    end

    local label = vgui.Create("DLabel", scroll)
    label:Dock(TOP)
    label:SetWrap(true)
    label:SetAutoStretchVertical(true)
    label:DockMargin(0, 0, 0, 10)
    label:SetFont("DermaDefaultBold")
    label:SetText("Instructions/Controls")

    local label = vgui.Create("DLabel", scroll)
    label:Dock(TOP)
    label:SetWrap(true)
    label:SetAutoStretchVertical(true)
    label:DockMargin(0, 0, 0, 15)
    label:SetFont("DermaDefault")
    label:SetText("Press your WALK key (default ALT) to insert coins. Use scroll wheel to zoom. Hold USE (default E) to exit (you will lose any ununsed coins!). Settings can be found in the context menu (default C).")

    if machine.Game and machine.Game.Description then
        local label = vgui.Create("DLabel", scroll)
        label:Dock(TOP)
        label:SetWrap(true)
        label:SetAutoStretchVertical(true)
        label:DockMargin(0, 0, 0, 10)
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

local BG = {
    BG_GENERIC_JOYSTICK = 0,
    BG_GENERIC_TRACKBALL = 1,
    BG_GENERIC_RECESSED_JOYSTICK = 2,
    BG_GENERIC_RECESSED_TRACKBALL = 3,
    BG_DRIVING = 4
}

local Bodygroups = {
    [BG.BG_GENERIC_JOYSTICK] = { 0, 0 },
    [BG.BG_GENERIC_TRACKBALL] = { 0, 2 },
    [BG.BG_GENERIC_RECESSED_JOYSTICK] = { 1, 0 },
    [BG.BG_GENERIC_RECESSED_TRACKBALL] = { 1, 2 },
    [BG.BG_DRIVING] = { 2, 3 }
}

AMCurrentMachine = AMCurrentMachine or nil

local function WrappedInclusion(path, upvalues)
    local gameMeta = setmetatable(upvalues, { __index = _G, __newindex = _G })

    local gameFunc = (isfunction(path) and path or CompileFile(path))
    setfenv(gameFunc, gameMeta)
    return gameFunc()
end

ENT.Initialized = false

function ENT:Initialize()
    self.Initialized = true

    local num = math.random(9999)

    self.ScreenTexture = GetRenderTargetEx(
        "ArcadeMachine_Screen_" .. self:EntIndex() .. "_" .. num,
        ScreenWidth,
        ScreenHeight,
        RT_SIZE_DEFAULT,
        MATERIAL_RT_DEPTH_NONE,
        1,
        CREATERENDERTARGETFLAGS_HDR,
        IMAGE_FORMAT_DEFAULT
    )
    self.ScreenMaterial = CreateMaterial(
        "ArcadeMachine_Screen_Material_" .. self:EntIndex() .. "_" .. num,
        "VertexLitGeneric",
        {
            ["$basetexture"] = self.ScreenTexture:GetName(),
            ["$model"] = 1,
            ["$selfillum"] = 1,
            ["$selfillummask"] = "dev/reflectivity_30b"
        }
    )

    self.MarqueeTexture = GetRenderTargetEx(
        "ArcadeMachine_Marquee_" .. self:EntIndex() .. "_" .. num,
        MarqueeWidth,
        256, -- Not the same as the drawable area
        RT_SIZE_DEFAULT,
        MATERIAL_RT_DEPTH_NONE,
        16,
        CREATERENDERTARGETFLAGS_HDR,
        IMAGE_FORMAT_DEFAULT
    )
    self.MarqueeMaterial = CreateMaterial(
        "ArcadeMachine_Marquee_Material_" .. self:EntIndex() .. "_" .. num,
        "VertexLitGeneric",
        {
            ["$basetexture"] = self.MarqueeTexture:GetName(),
            ["$model"] = 1,
            ["$nodecal"] = 1,
            ["$selfillum"] = 1,
            ["$selfillummask"] = "dev/reflectivity_30b"
        }
    )

    self.InRange = self.InRange or false
    self.Game = self.Game or nil
    self.LoadedSounds = self.LoadedSounds or {}
    
    -- Used to work around network variable spamming being changed from
    -- empty to a game and back again when loaded into room on MS
    self.AllowGameChangeAt = 0

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

    if self.LastGameNWVar ~= nil and self.AllowGameChangeAt - RealTime() <= 0 then
        DebugPrint(self:EntIndex(), "change game to", self.LastGameNWVar, "at", RealTime())
        self:SetGame(self.LastGameNWVar)
        self.LastGameNWVar = nil
        self.AllowGameChangeAt = RealTime() + 1
    end

    -- Used to work around GetCoins not returning the correct value after the
    -- network var notify was called
    if self.CoinChange and self.CoinChange.new == self:GetCoins() and IsValid(self:GetPlayer()) then
        if self.Game then
            if self.CoinChange.new > self.CoinChange.old and self.Game.OnCoinsInserted then
                self.Game:OnCoinsInserted(self:GetPlayer(), self.CoinChange.old, self.CoinChange.new)
            end
        
            if self.CoinChange.new < self.CoinChange.old and self.Game.OnCoinsLost then
                self.Game:OnCoinsLost(self:GetPlayer(), self.CoinChange.old, self.CoinChange.new)
            end
        end
        
        self.CoinChange = nil
    end

    if DisableOthers:GetBool() and AMCurrentMachine and AMCurrentMachine ~= self then
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
    local marqueeIndex = self.Entity:GetBodygroup(0)

    if IsValid(AMCurrentMachine) and AMCurrentMachine == self and not LocalPlayer():ShouldDrawLocalPlayer() then
        cam.IgnoreZ(true)
    end

    -- To prevent using string table slots, don't set the submaterial on the server
    -- and just override it here
    render.MaterialOverrideByIndex(marqueeIndex == 2 and 7 or 3, self.MarqueeMaterial)
    render.MaterialOverrideByIndex(4, self.ScreenMaterial)
    self.Entity:DrawModel()
    render.MaterialOverrideByIndex()

    if IsValid(AMCurrentMachine) and AMCurrentMachine == self and not LocalPlayer():ShouldDrawLocalPlayer() then
        cam.IgnoreZ(false)
    end

    if not self.InRange or not self.Game or (DisableOthers:GetBool() and AMCurrentMachine and AMCurrentMachine ~= self) then
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
    AMCurrentMachine = self

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
    AMCurrentMachine = nil

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
    self.CoinChange = { old = old, new = new }
end

function ENT:OnGameChange(name, old, new)
    if old == new then return end

    DebugPrint(
        self:EntIndex(),
        "new", new,
        "old", old,
        "at", RealTime(),
        "remain", self.AllowGameChangeAt ~= 0 and self.AllowGameChangeAt - RealTime() or "(first load)"
    )

    self.LastGameNWVar = new

    if self.AllowGameChangeAt == 0 or self.AllowGameChangeAt - RealTime() > 0 then
        self.AllowGameChangeAt = RealTime() + 1
        DebugPrint(self:EntIndex(), "delaying game change until", self.AllowGameChangeAt)
    end
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

        for k, v in pairs(BG) do
            upvalues[k] = v
        end

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

        if self.Game.Bodygroup and Bodygroups[self.Game.Bodygroup] then
            timer.Simple(1, function() -- Thanks gmod
                self.Entity:SetBodygroup(0, Bodygroups[self.Game.Bodygroup][1])
                self.Entity:SetBodygroup(1, Bodygroups[self.Game.Bodygroup][2])
            end)
        end

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
    if not IsValid(AMCurrentMachine) then
        return
    end

    local tp = veh.GetThirdPersonMode and veh:GetThirdPersonMode() or false

    if tp then return end

    if AMCurrentMachine:GetBodygroup(0) == 1 then
        view.origin = veh:GetPos() + veh:GetRight() * -8 + veh:GetUp() * 72
    else
        view.origin = veh:GetPos() + veh:GetUp() * 64
    end

    view.fov = FOV:GetInt()

    return view
end)

hook.Add("CreateMove", "arcademachine_scroll", function(cmd)
    if not IsValid(AMCurrentMachine) then
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
    if not IsValid(AMCurrentMachine) then return end

    return false
end)

local notificationColor = Color(255, 255, 255)
hook.Add("HUDPaint", "arcademachine_hud", function()
    -- Paint manually so the panel hides when the camera is out
    if IsValid(AMInfoPanel) then
        AMInfoPanel:PaintManual()
    end

    if PressedUse then
        notificationColor.a = 50 + math.abs(math.sin(RealTime() * 10) * 205)

        draw.DrawText("Keep holding USE to exit the machine!", "DermaLarge", ScrW() * 0.5, ScrH() * 0.3, notificationColor, TEXT_ALIGN_CENTER)
    end
end)

hook.Add("Think", "arcademachine_think", function()
    if not IsValid(AMCurrentMachine) then
        local tr = util.TraceLine(util.GetPlayerTrace(LocalPlayer(), EyeAngles():Forward()))

        if
            IsValid(tr.Entity) and
            tr.Entity:GetClass() == "arcademachine" and
            tr.Entity:GetPos():DistToSqr(LocalPlayer():GetPos()) < LookDist * LookDist
        then
            ShowInfoPanel(tr.Entity)
        else
            if IsValid(AMInfoPanel) then
                AMInfoPanel:Remove()
            end
            LookingAt = nil
        end
    else
        if IsValid(AMInfoPanel) then
            AMInfoPanel:Remove()
        end
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
    if not IsValid(AMCurrentMachine) or ply == LocalPlayer() then return end

    local min, max = LocalPlayer():WorldSpaceAABB()

    return ply:GetPos():WithinAABox(min, max)
end)

hook.Add("HUDDrawTargetID", "arcademachine_hideplayers", function()
    if not IsValid(AMCurrentMachine) then return end

    return false
end)

hook.Add("ContextMenuOpen", "arcademachine_nocontextmenu", function()
    if not IsValid(AMCurrentMachine) then return end

    return false
end)