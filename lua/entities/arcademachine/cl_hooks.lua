local NextQueueAt = 0

local LookDist = 100

local ControlsBgCol = Color(0, 0, 0, 200)
local ControlsTextCol = Color(255, 255, 255, 200)

AMSettingsPanel = AMSettingsPanel or nil
local function ShowSettingsPanel()
    if not IsValid(AMSettingsPanel) then
        AMSettingsPanel = vgui.Create("DFrame")
        AMSettingsPanel:SetSize(ScrW() * 0.15, ScrH() * 0.2)
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

        local label = vgui.Create("DLabel", scroll)
        label:Dock(TOP)
        label:SetWrap(true)
        label:SetAutoStretchVertical(true)
        label:DockMargin(0, 0, 0, 10)
        label:SetFont("AMInfoFontBold")
        label:SetText("Performance")

        if pac then
            local checkbox = vgui.Create("DCheckBoxLabel", scroll)
            checkbox:Dock(TOP)
            checkbox:DockMargin(0, 0, 0, 5)
            checkbox:SetFont("AMInfoFont")
            checkbox:SetText("Disable PAC when in machine")
            checkbox:SetConVar("arcademachine_disable_pac")
            checkbox:SetValue(AM.DisablePAC:GetBool())
            checkbox:SizeToContents()
        end

        local checkbox = vgui.Create("DCheckBoxLabel", scroll)
        checkbox:Dock(TOP)
        checkbox:DockMargin(0, 0, 0, 5)
        checkbox:SetFont("AMInfoFont")
        checkbox:SetText("Disable other machines when in machine")
        checkbox:SetConVar("arcademachine_disable_others_when_active")
        checkbox:SetValue(AM.DisableOthers:GetBool())
        checkbox:SizeToContents()

        local label = vgui.Create("DLabel", scroll)
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

        local button = vgui.Create("DButton", scroll)
        button:Dock(TOP)
        button:DockMargin(0, 0, 0, 5)
        button:SetFont("AMInfoFont")
        button:SetText("Reload machines")
        button.DoClick = function()
            LocalPlayer():ConCommand("arcademachine_reload_machines")
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
        draw.RoundedBoxEx(20, 0, 0, w, h, ControlsBgCol, false, true, false, true)

        local text = "Open chat and mouse over to scroll (default Y)"

        surface.SetTextColor(ControlsTextCol)
        surface.SetFont("AMInfoFontBold")
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
        label:SetFont("AMInfoFontBold")
        label:SetText("This machine costs " .. cost .. " coin(s) to play.")
    end

    if machine.Game and machine.Game.Description then
        local label = vgui.Create("DLabel", scroll)
        label:Dock(TOP)
        label:SetWrap(true)
        label:SetAutoStretchVertical(true)
        label:DockMargin(0, 0, 0, 10)
        label:SetFont("AMInfoFontBold")
        label:SetText("Game Information")

        local label = vgui.Create("DLabel", scroll)
        label:Dock(TOP)
        label:SetWrap(true)
        label:SetAutoStretchVertical(true)
        label:DockMargin(0, 0, 0, 15)
        label:SetFont("AMInfoFont")
        label:SetText(machine.Game.Description)
    end
end

hook.Add("CalcVehicleView", "arcademachine_view", function(veh, ply, view)
    if not IsValid(AM.CurrentMachine) then
        return
    end

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
        return
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
    if IsValid(AMInfoPanel) then
        AMInfoPanel:PaintManual()
    end

    if IsValid(AM.CurrentMachine) then
        local strings = {
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
    -- In case the player gets pulled out of the machine somehow
    if IsValid(AM.CurrentMachine) and AM.CurrentMachine:GetPlayer() ~= LocalPlayer() then
        AM.CurrentMachine = nil
    end

    if not IsValid(AM.CurrentMachine) then
        local tr = util.TraceLine(util.GetPlayerTrace(LocalPlayer(), EyeAngles():Forward()))

        if
            IsValid(tr.Entity) and
            tr.Entity:GetClass() == "arcademachine" and
            tr.Entity:GetPos():DistToSqr(LocalPlayer():GetPos()) < LookDist * LookDist and
            tr.Entity.Game
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