AM = AM or {
    UI = {},
    QueuedSounds = {},
    FOV = CreateClientConVar("arcademachine_fov", 70, true, false),
    DisableBloom = CreateClientConVar("arcademachine_disable_bloom", 1, true, false),
    DisablePAC = CreateClientConVar("arcademachine_disable_pac", 1, true, false),
    DisableOutfitter = CreateClientConVar("arcademachine_disable_outfitter", 1, true, false),
    DisableOthers = CreateClientConVar("arcademachine_disable_others_when_active", 0, true, false),
    BloomWasDisabled = false,
    PACWasDisabled = false,
    OutfitterWasDisabled = false,
    MSBrowserWasDisabled = false
}

function AM:OnLocalPlayerLeft()
    self.CurrentMachine = nil

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

local NextQueueAt = 0

local LookDist = 100

local ControlsBgCol = Color(0, 0, 0, 200)
local ControlsTextCol = Color(255, 255, 255, 200)

AM.UI.SettingsPanel = AM.UI.SettingsPanel or nil
if not IsValid(AM.UI.SettingsPanel) then
    AM.UI.SettingsPanel = vgui.Create("DFrame")
    AM.UI.SettingsPanel:SetSize(ScrW() * 0.15, ScrH() * 0.2)
    AM.UI.SettingsPanel:SetMinimumSize(200, 200)
    AM.UI.SettingsPanel:SetTitle("Arcade Machine Settings")
    AM.UI.SettingsPanel:DockPadding(10, 30, 10, 10)
    AM.UI.SettingsPanel:SetDeleteOnClose(false)
    AM.UI.SettingsPanel:SetVisible(false)

    local scroll = vgui.Create("DScrollPanel", AM.UI.SettingsPanel)
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
    checkbox:SetText("Disable bloom when in machine")
    checkbox:SetConVar("arcademachine_disable_bloom")
    checkbox:SetValue(AM.DisableBloom:GetBool())
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
    checkbox:SetText("Disable PAC when in machine")
    checkbox:SetConVar("arcademachine_disable_pac")
    checkbox:SetValue(AM.DisablePAC:GetBool())
    checkbox:SizeToContents()

    checkbox = vgui.Create("DCheckBoxLabel", scroll)
    checkbox:Dock(TOP)
    checkbox:DockMargin(0, 0, 0, 5)
    checkbox:SetFont("AMInfoFont")
    checkbox:SetText("Disable other machines when in machine")
    checkbox:SetConVar("arcademachine_disable_others_when_active")
    checkbox:SetValue(AM.DisableOthers:GetBool())
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
        LocalPlayer():ConCommand("arcademachine_clear_cache")
    end

    button = vgui.Create("DButton", scroll)
    button:Dock(TOP)
    button:DockMargin(0, 0, 0, 5)
    button:SetFont("AMInfoFont")
    button:SetText("Reload machines")
    button.DoClick = function()
        LocalPlayer():ConCommand("arcademachine_reload_machines")
    end
end

list.Set("DesktopWindows", "ArcadeMachines", {
    title = "Arcade Machines",
    icon = "icon64/arcademachine.png",
    init = function(icon, window)
        AM.UI.SettingsPanel:SetVisible(true)
        AM.UI.SettingsPanel:Center()
        AM.UI.SettingsPanel:MakePopup()
    end
})

AM.UI.InfoPanel = AM.UI.InfoPanel or nil
if not IsValid(AM.UI.InfoPanel) then
    AM.UI.InfoPanel = vgui.Create("DFrame")
    AM.UI.InfoPanel:SetPaintedManually(true)
    AM.UI.InfoPanel:SetSize(ScrW() * 0.15, ScrH() * 0.2)
    AM.UI.InfoPanel:SetMinimumSize(300, 300)
    AM.UI.InfoPanel:SetPos(0, ScrH() * 0.5 - (AM.UI.InfoPanel:GetTall() * 0.5))
    AM.UI.InfoPanel:SetTitle("")
    AM.UI.InfoPanel:SetDraggable(false)
    AM.UI.InfoPanel:ShowCloseButton(false)
    AM.UI.InfoPanel:DockPadding(10, 10, 10, 20)
    AM.UI.InfoPanel.Paint = function(self, w, h)
        draw.RoundedBoxEx(20, 0, 0, w, h, ControlsBgCol, false, true, false, true)

        local text = "Open chat and mouse over to scroll (default Y)"

        surface.SetTextColor(ControlsTextCol)
        surface.SetFont("AMInfoFontBold")
        local tw, th = surface.GetTextSize(text)
        surface.SetTextPos(w * 0.5 - (tw * 0.5), h - th - 5)
        surface.DrawText(text)
    end

    local scroll = vgui.Create("DScrollPanel", AM.UI.InfoPanel)
    scroll:Dock(FILL)
    local sbar = scroll:GetVBar()
    sbar.Paint = function(self, w, h) end
    sbar.btnUp.Paint = function(self, w, h) end
    sbar.btnDown.Paint = function(self, w, h) end
    sbar.btnGrip.Paint = function(self, w, h) end

    AM.UI.GameLabel = vgui.Create("DLabel", scroll)
    AM.UI.GameLabel:Dock(TOP)
    AM.UI.GameLabel:SetWrap(true)
    AM.UI.GameLabel:SetAutoStretchVertical(true)
    AM.UI.GameLabel:DockMargin(0, 0, 0, 15)
    AM.UI.GameLabel:SetFont("DermaLarge")
    AM.UI.GameLabel:SetText("")

    AM.UI.CoinsLabel = vgui.Create("DLabel", scroll)
    AM.UI.CoinsLabel:Dock(TOP)
    AM.UI.CoinsLabel:SetWrap(true)
    AM.UI.CoinsLabel:SetAutoStretchVertical(true)
    AM.UI.CoinsLabel:DockMargin(0, 0, 0, 15)
    AM.UI.CoinsLabel:SetFont("AMInfoFontBold")
    AM.UI.CoinsLabel:SetText("")

    local label = vgui.Create("DLabel", scroll)
    label:Dock(TOP)
    label:SetWrap(true)
    label:SetAutoStretchVertical(true)
    label:DockMargin(0, 0, 0, 10)
    label:SetFont("AMInfoFontBold")
    label:SetText("Game Information")

    AM.UI.DescriptionLabel = vgui.Create("DLabel", scroll)
    AM.UI.DescriptionLabel:Dock(TOP)
    AM.UI.DescriptionLabel:SetWrap(true)
    AM.UI.DescriptionLabel:SetAutoStretchVertical(true)
    AM.UI.DescriptionLabel:DockMargin(0, 0, 0, 15)
    AM.UI.DescriptionLabel:SetFont("AMInfoFont")
    AM.UI.DescriptionLabel:SetText("")
end

local function ToggleInfoPanel(machine)
    if not IsValid(machine) or not machine.Game then
        if IsValid(AM.UI.InfoPanel) then
            AM.UI.InfoPanel:SetVisible(false)
        end
        LookingAt = nil
        return
    end

    if LookingAt == machine then return end

    LookingAt = machine

    AM.UI.InfoPanel:SetVisible(true)

    local cost = machine:GetMSCoinCost()

    if cost > 0 then
        AM.UI.CoinsLabel:SetVisible(true)
        AM.UI.CoinsLabel:SetText("This machine costs " .. cost .. " coin(s) to play.")
    else
        AM.UI.CoinsLabel:SetVisible(false)
    end

    AM.UI.GameLabel:SetText(machine.Game.Name)

    if machine.Game.Description then
        AM.UI.DescriptionLabel:SetVisible(true)
        AM.UI.DescriptionLabel:SetText(machine.Game.Description)
    else
        AM.UI.DescriptionLabel:SetVisible(false)
    end
end

hook.Add("CalcVehicleView", "arcademachine_view", function(veh, ply, view)
    if not IsValid(AM.CurrentMachine) then return end

    local tp = veh.GetThirdPersonMode and veh:GetThirdPersonMode() or false

    if tp then return end

    if AM.CurrentMachine:GetBodygroup(0) == 1 then
        view.origin = veh:GetPos() + veh:GetRight() * -8 + veh:GetUp() * 72
    else
        view.origin = veh:GetPos() + veh:GetUp() * 64
    end

    view.fov = AM.FOV:GetInt()

    return view
end)

hook.Add("CreateMove", "arcademachine_scroll", function(cmd)
    if not IsValid(AM.CurrentMachine) then
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

    local fov = AM.FOV:GetInt()

    if cmd:GetMouseWheel() < 0 and fov < 100 then
        AM.FOV:SetInt(fov + 2)
    end
    if cmd:GetMouseWheel() > 0 and fov > 40 then
        AM.FOV:SetInt(fov - 2)
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
    if not IsValid(AM.CurrentMachine) then return end

    return false
end)

hook.Add("HUDPaint", "arcademachine_hud", function()
    -- Paint manually so the panel hides when the camera is out
    if IsValid(AM.UI.InfoPanel) then
        AM.UI.InfoPanel:PaintManual()
    end

    if IsValid(AM.CurrentMachine) then
        local strings = {
            ["[F1] Toggle Game Info"] = 0,
            ["[" .. string.upper(input.LookupBinding("+walk") or "alt") .. "] Insert Coins"] = 0,
            ["[SCROLL] Zoom"] = 0,
            ["[HOLD " .. string.upper(input.LookupBinding("+use") or "e") .. "] Exit"] = 0
        }
        local width = 0

        surface.SetFont("DermaLarge")
        for k, _ in pairs(strings) do
            strings[k] = (surface.GetTextSize(k) + 8 * 2 + 10)
            width = width + strings[k]
        end

        local x = ScrW() * 0.5 - (width * 0.5)

        for k, v in pairs(strings) do
            draw.WordBox(
                8,
                x,
                ScrH() * 0.95,
                k,
                "DermaLarge",
                ControlsBgCol,
                ControlsTextCol
            )

            x = x + v
        end
    end
end)

hook.Add("Think", "arcademachine_think", function()
    if
        (IsValid(AM.CurrentMachine) and AM.CurrentMachine:GetPlayer() ~= LocalPlayer()) or -- The player was pulled out of the machine somehow
        (AM.CurrentMachine and not IsValid(AM.CurrentMachine)) -- The machine was removed while we were in it
    then
        AM:OnLocalPlayerLeft()
    end

    if not IsValid(AM.CurrentMachine) then
        local tr = util.TraceLine({
            start = LocalPlayer():EyePos(),
            endpos = LocalPlayer():EyePos() + EyeAngles():Forward() * LookDist,
            filter = function(ent)
                if ent:GetClass() == "arcademachine" then return true end
            end
        })

        ToggleInfoPanel(tr.Entity)
    else
        if ShowInfoPanel then
            ToggleInfoPanel(AM.CurrentMachine)
        else
            if IsValid(AM.UI.InfoPanel) then
                AM.UI.InfoPanel:SetVisible(false)
            end
            LookingAt = nil
        end
    end

    if RealTime() < NextQueueAt then return end

    local k, v = next(AM.QueuedSounds)

    if k then
        if #v > 0 then
            v[1].context:LoadQueued(v[1])
            table.remove(v, 1)
        else
            AM.QueuedSounds[k] = nil
        end
    end

    NextQueueAt = RealTime() + 0.05
end)

hook.Add("PrePlayerDraw", "arcademachine_hideplayers", function(ply)
    if not IsValid(AM.CurrentMachine) or ply == LocalPlayer() then return end

    local min, max = LocalPlayer():WorldSpaceAABB()

    return ply:GetPos():WithinAABox(min, max)
end)

hook.Add("HUDDrawTargetID", "arcademachine_hideplayers", function()
    if not IsValid(AM.CurrentMachine) then return end

    return false
end)

hook.Add("ContextMenuOpen", "arcademachine_nocontextmenu", function()
    if not IsValid(AM.CurrentMachine) then return end

    return false
end)