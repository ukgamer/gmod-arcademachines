ARCADE.Cabinet = ARCADE.Cabinet or {
    UI = {},
    QueuedSounds = {},
    FOV = CreateClientConVar("arcade_cabinet_fov", 70, true, false),
    DisableBloom = CreateClientConVar("arcade_cabinet_disable_bloom", 1, true, false),
    DisablePAC = CreateClientConVar("arcade_cabinet_disable_pac", 1, true, false),
    DisableOutfitter = CreateClientConVar("arcade_cabinet_disable_outfitter", 1, true, false),
    DisableOthers = CreateClientConVar("arcade_cabinet_disable_others_when_active", 0, true, false),
    DisableSoundsOutside = CreateClientConVar("arcade_cabinet_disable_sounds_outside", 0, true, false),
    BloomWasDisabled = false,
    PACWasDisabled = false,
    OutfitterWasDisabled = false,
    MSBrowserWasDisabled = false
}

function ARCADE.Cabinet:OnLocalPlayerLeft()
    self.CurrentCabinet = nil

    if self.DisableBloom:GetBool() and self.BloomWasDisabled then
        LocalPlayer():ConCommand("mat_disable_bloom 0")
    end

    if self.DisablePAC:GetBool() and self.PACWasDisabled then
        pac.Enable()
    end

    if self.MSBrowserWasDisabled then
        LocalPlayer():ConCommand("webbrowser_f1_open 1")
    end

    --[[if self.DisableOutfitter:GetBool() and OutfitterWasDisabled then
        outfitter.SetHighPerf(false, true)
        outfitter.EnableEverything()
    end--]]
end

surface.CreateFont("AMInfoFont", {
    font = "Tahoma",
    extended = true,
    size = 16
})

surface.CreateFont("AMInfoFontBold", {
    font = "Tahoma",
    extended = true,
    size = 16,
    weight = 1000
})

local LookingAt = nil
local PressedF1 = false
local ShowInfoPanel = false

local PressedUse = false

local NextQueueAt = 0

local LookDist = 100

if IsValid(ARCADE.Cabinet.UI.SettingsPanel) then
    ARCADE.Cabinet.UI.SettingsPanel:Remove()
end

do
    ARCADE.Cabinet.UI.SettingsPanel = vgui.Create("DFrame")
    ARCADE.Cabinet.UI.SettingsPanel:SetSize(ScrW() * 0.18, ScrH() * 0.2)
    ARCADE.Cabinet.UI.SettingsPanel:SetMinimumSize(200, 200)
    ARCADE.Cabinet.UI.SettingsPanel:SetTitle("Arcade Cabinet Settings")
    ARCADE.Cabinet.UI.SettingsPanel:DockPadding(10, 30, 10, 10)
    ARCADE.Cabinet.UI.SettingsPanel:SetDeleteOnClose(false)
    ARCADE.Cabinet.UI.SettingsPanel:SetVisible(false)

    local scroll = vgui.Create("DScrollPanel", ARCADE.Cabinet.UI.SettingsPanel)
    scroll:Dock(FILL)

    local label = vgui.Create("DLabel", scroll)
    label:Dock(TOP)
    label:SetWrap(true)
    label:SetAutoStretchVertical(true)
    label:DockMargin(0, 0, 0, 10)
    label:SetFont("AMInfoFontBold")
    label:SetText("General")

    local checkbox = vgui.Create("DCheckBoxLabel", scroll)
    checkbox:Dock(TOP)
    checkbox:DockMargin(0, 0, 0, 5)
    checkbox:SetFont("AMInfoFont")
    checkbox:SetText("Disable bloom when in cabinet")
    checkbox:SetConVar("arcade_cabinet_disable_bloom")
    checkbox:SetValue(ARCADE.Cabinet.DisableBloom:GetBool())
    checkbox:SizeToContents()

    checkbox = vgui.Create("DCheckBoxLabel", scroll)
    checkbox:Dock(TOP)
    checkbox:DockMargin(0, 0, 0, 5)
    checkbox:SetFont("AMInfoFont")
    checkbox:SetText("Disable sounds when outside cabinet (does not stop current sounds)")
    checkbox:SetConVar("arcade_cabinet_disable_sounds_outside")
    checkbox:SetValue(ARCADE.Cabinet.DisableSoundsOutside:GetBool())
    checkbox:SizeToContents()

    label = vgui.Create("DLabel", scroll)
    label:Dock(TOP)
    label:SetWrap(true)
    label:SetAutoStretchVertical(true)
    label:DockMargin(0, 0, 0, 10)
    label:SetFont("AMInfoFontBold")
    label:SetText("Performance")

    checkbox = vgui.Create("DCheckBoxLabel", scroll)
    checkbox:Dock(TOP)
    checkbox:DockMargin(0, 0, 0, 5)
    checkbox:SetFont("AMInfoFont")
    checkbox:SetText("Disable PAC when in cabinet")
    checkbox:SetConVar("arcade_cabinet_disable_pac")
    checkbox:SetValue(ARCADE.Cabinet.DisablePAC:GetBool())
    checkbox:SizeToContents()

    checkbox = vgui.Create("DCheckBoxLabel", scroll)
    checkbox:Dock(TOP)
    checkbox:DockMargin(0, 0, 0, 5)
    checkbox:SetFont("AMInfoFont")
    checkbox:SetText("Disable other cabinets when in cabinet")
    checkbox:SetConVar("arcade_cabinet_disable_others_when_active")
    checkbox:SetValue(ARCADE.Cabinet.DisableOthers:GetBool())
    checkbox:SizeToContents()

    label = vgui.Create("DLabel", scroll)
    label:Dock(TOP)
    label:SetWrap(true)
    label:SetAutoStretchVertical(true)
    label:DockMargin(0, 0, 0, 10)
    label:SetFont("AMInfoFontBold")
    label:SetText("Debug")

    local button = vgui.Create("DButton", scroll)
    button:Dock(TOP)
    button:DockMargin(0, 0, 0, 5)
    button:SetFont("AMInfoFont")
    button:SetText("Clear cache")
    button.DoClick = function()
        LocalPlayer():ConCommand("arcade_cabinet_clear_cache")
    end

    button = vgui.Create("DButton", scroll)
    button:Dock(TOP)
    button:DockMargin(0, 0, 0, 5)
    button:SetFont("AMInfoFont")
    button:SetText("Reload cabinets")
    button.DoClick = function()
        LocalPlayer():ConCommand("arcade_cabinet_reload")
    end
end

list.Set("DesktopWindows", "ArcadeCabinets", {
    title = "Arcade Cabinets",
    icon = "icon64/arcade_cabinet.png",
    init = function(icon, window)
        ARCADE.Cabinet.UI.SettingsPanel:SetVisible(true)
        ARCADE.Cabinet.UI.SettingsPanel:Center()
        ARCADE.Cabinet.UI.SettingsPanel:MakePopup()
    end
})

if IsValid(ARCADE.Cabinet.UI.InfoPanel) then
    ARCADE.Cabinet.UI.InfoPanel:Remove()
end

do
    ARCADE.Cabinet.UI.InfoPanel = vgui.Create("DFrame")
    ARCADE.Cabinet.UI.InfoPanel:SetPaintedManually(true)
    ARCADE.Cabinet.UI.InfoPanel:SetSize(ScrW() * 0.15, ScrH() * 0.2)
    ARCADE.Cabinet.UI.InfoPanel:SetMinimumSize(300, 300)
    ARCADE.Cabinet.UI.InfoPanel:SetPos(0, ScrH() * 0.5 - (ARCADE.Cabinet.UI.InfoPanel:GetTall() * 0.5))
    ARCADE.Cabinet.UI.InfoPanel:SetTitle("")
    ARCADE.Cabinet.UI.InfoPanel:SetDraggable(false)
    ARCADE.Cabinet.UI.InfoPanel:ShowCloseButton(false)
    ARCADE.Cabinet.UI.InfoPanel:DockPadding(10, 10, 10, 20)
    ARCADE.Cabinet.UI.InfoPanel.Paint = function(self, w, h)
        draw.RoundedBoxEx(20, 0, 0, w, h, ARCADE.UI.ControlsBgCol, false, true, false, true)

        local text = "Open chat and mouse over to scroll (default Y)"

        surface.SetTextColor(ARCADE.UI.ControlsTextCol)
        surface.SetFont("AMInfoFontBold")
        local tw, th = surface.GetTextSize(text)
        surface.SetTextPos(w * 0.5 - (tw * 0.5), h - th - 5)
        surface.DrawText(text)
    end

    local scroll = vgui.Create("DScrollPanel", ARCADE.Cabinet.UI.InfoPanel)
    scroll:Dock(FILL)
    local sbar = scroll:GetVBar()
    sbar.Paint = function(self, w, h) end
    sbar.btnUp.Paint = function(self, w, h) end
    sbar.btnDown.Paint = function(self, w, h) end
    sbar.btnGrip.Paint = function(self, w, h) end

    ARCADE.Cabinet.UI.GameLabel = vgui.Create("DLabel", scroll)
    ARCADE.Cabinet.UI.GameLabel:Dock(TOP)
    ARCADE.Cabinet.UI.GameLabel:SetWrap(true)
    ARCADE.Cabinet.UI.GameLabel:SetAutoStretchVertical(true)
    ARCADE.Cabinet.UI.GameLabel:DockMargin(0, 0, 0, 15)
    ARCADE.Cabinet.UI.GameLabel:SetFont("DermaLarge")
    ARCADE.Cabinet.UI.GameLabel:SetText("")

    ARCADE.Cabinet.UI.CoinsLabel = vgui.Create("DLabel", scroll)
    ARCADE.Cabinet.UI.CoinsLabel:Dock(TOP)
    ARCADE.Cabinet.UI.CoinsLabel:SetWrap(true)
    ARCADE.Cabinet.UI.CoinsLabel:SetAutoStretchVertical(true)
    ARCADE.Cabinet.UI.CoinsLabel:DockMargin(0, 0, 0, 15)
    ARCADE.Cabinet.UI.CoinsLabel:SetFont("AMInfoFontBold")
    ARCADE.Cabinet.UI.CoinsLabel:SetText("")

    local label = vgui.Create("DLabel", scroll)
    label:Dock(TOP)
    label:SetWrap(true)
    label:SetAutoStretchVertical(true)
    label:DockMargin(0, 0, 0, 10)
    label:SetFont("AMInfoFontBold")
    label:SetText("Game Information")

    ARCADE.Cabinet.UI.AuthorLabel = vgui.Create("DLabel", scroll)
    ARCADE.Cabinet.UI.AuthorLabel:Dock(TOP)
    ARCADE.Cabinet.UI.AuthorLabel:SetWrap(true)
    ARCADE.Cabinet.UI.AuthorLabel:SetAutoStretchVertical(true)
    ARCADE.Cabinet.UI.AuthorLabel:DockMargin(0, 0, 0, 15)
    ARCADE.Cabinet.UI.AuthorLabel:SetFont("AMInfoFont")
    ARCADE.Cabinet.UI.AuthorLabel:SetText("")

    ARCADE.Cabinet.UI.DescriptionLabel = vgui.Create("DLabel", scroll)
    ARCADE.Cabinet.UI.DescriptionLabel:Dock(TOP)
    ARCADE.Cabinet.UI.DescriptionLabel:SetWrap(true)
    ARCADE.Cabinet.UI.DescriptionLabel:SetAutoStretchVertical(true)
    ARCADE.Cabinet.UI.DescriptionLabel:DockMargin(0, 0, 0, 15)
    ARCADE.Cabinet.UI.DescriptionLabel:SetFont("AMInfoFont")
    ARCADE.Cabinet.UI.DescriptionLabel:SetText("")
end

local function ToggleInfoPanel(cabinet)
    if not IsValid(cabinet) or not cabinet.Game or cabinet.InLauncher then
        if IsValid(ARCADE.Cabinet.UI.InfoPanel) then
            ARCADE.Cabinet.UI.InfoPanel:SetVisible(false)
        end
        LookingAt = nil
        return
    end

    if LookingAt == cabinet then return end

    LookingAt = cabinet

    ARCADE.Cabinet.UI.InfoPanel:SetVisible(true)

    local cost = cabinet:GetCost()

    if cost > 0 then
        ARCADE.Cabinet.UI.CoinsLabel:SetVisible(true)
        ARCADE.Cabinet.UI.CoinsLabel:SetText("This game costs " .. cost .. " coin(s) to play.")
    else
        ARCADE.Cabinet.UI.CoinsLabel:SetVisible(false)
    end

    ARCADE.Cabinet.UI.GameLabel:SetText(cabinet.Game.Name)

    if cabinet.Game.Author then
        ARCADE.Cabinet.UI.AuthorLabel:SetVisible(true)
        ARCADE.Cabinet.UI.AuthorLabel:SetText("Author: " .. cabinet.Game.Author)
    else
        ARCADE.Cabinet.UI.AuthorLabel:SetVisible(false)
    end

    if cabinet.Game.Description then
        ARCADE.Cabinet.UI.DescriptionLabel:SetVisible(true)
        ARCADE.Cabinet.UI.DescriptionLabel:SetText(cabinet.Game.Description)
    else
        ARCADE.Cabinet.UI.DescriptionLabel:SetVisible(false)
    end
end

hook.Add("CalcVehicleView", "arcade_cabinet_view", function(veh, ply, view)
    if not IsValid(ARCADE.Cabinet.CurrentCabinet) then return end

    if vrmod and vrmod.IsPlayerInVR and vrmod.IsPlayerInVR() then return end

    local tp = veh.GetThirdPersonMode and veh:GetThirdPersonMode() or false

    if tp then return end

    if ARCADE.Cabinet.CurrentCabinet:GetBodygroup(0) == 1 then
        view.origin = veh:GetPos() + veh:GetRight() * -8 + veh:GetUp() * 72
    else
        view.origin = veh:GetPos() + veh:GetUp() * 64
    end

    view.fov = ARCADE.Cabinet.FOV:GetInt()

    return view
end)

hook.Add("CreateMove", "arcade_cabinet_scroll", function(cmd)
    if not IsValid(ARCADE.Cabinet.CurrentCabinet) then
        PressedUse = false
        PressedF1 = false
        return
    end

    if input.IsKeyDown(KEY_F1) then
        if not PressedF1 then
            ShowInfoPanel = not ShowInfoPanel
            PressedF1 = true
        end
    else
        PressedF1 = false
    end

    local fov = ARCADE.Cabinet.FOV:GetInt()

    if cmd:GetMouseWheel() < 0 and fov < 100 then
        ARCADE.Cabinet.FOV:SetInt(fov + 2)
    end
    if cmd:GetMouseWheel() > 0 and fov > 40 then
        ARCADE.Cabinet.FOV:SetInt(fov - 2)
    end

    if bit.band(cmd:GetButtons(), IN_USE) ~= 0 then
        if not PressedUse then
            PressedUse = true
            PressedUseAt = RealTime()
        elseif RealTime() >= PressedUseAt + 0.8 then
            net.Start("arcade_leave")
            net.SendToServer()
            PressedUse = false
        end
    else
        PressedUse = false
    end
end)

hook.Add("Think", "arcade_cabinet_think", function()
    if
        (IsValid(ARCADE.Cabinet.CurrentCabinet) and ARCADE.Cabinet.CurrentCabinet:GetPlayer() ~= LocalPlayer()) or -- The player was pulled out of the cabinet somehow
        (ARCADE.Cabinet.CurrentCabinet and not IsValid(ARCADE.Cabinet.CurrentCabinet)) -- The cabinet was removed while we were in it
    then
        ARCADE.Cabinet:OnLocalPlayerLeft()
    end

    if not IsValid(ARCADE.Cabinet.CurrentCabinet) then
        local tr = util.TraceLine({
            start = LocalPlayer():EyePos(),
            endpos = LocalPlayer():EyePos() + EyeAngles():Forward() * LookDist,
            filter = function(ent)
                if ent:GetClass() == "arcade_cabinet" then return true end
            end
        })

        ToggleInfoPanel(tr.Entity)
    else
        if ShowInfoPanel then
            ToggleInfoPanel(ARCADE.Cabinet.CurrentCabinet)
        else
            if IsValid(ARCADE.Cabinet.UI.InfoPanel) then
                ARCADE.Cabinet.UI.InfoPanel:SetVisible(false)
            end
            LookingAt = nil
        end
    end

    if RealTime() < NextQueueAt then return end

    local k, v = next(ARCADE.Cabinet.QueuedSounds)

    if k then
        if #v > 0 then
            v[1].context:LoadQueued(v[1])
            table.remove(v, 1)
        else
            ARCADE.Cabinet.QueuedSounds[k] = nil
        end
    end

    NextQueueAt = RealTime() + 0.05
end)

hook.Add("PrePlayerDraw", "arcade_cabinet_hideplayers", function(ply)
    if not IsValid(ARCADE.Cabinet.CurrentCabinet) or ply == LocalPlayer() then return end

    local min, max = LocalPlayer():WorldSpaceAABB()

    return ply:GetPos():WithinAABox(min, max)
end)