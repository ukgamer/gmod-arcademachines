ARCADE.Debug = CreateClientConVar("arcade_debug", 0, true, false)

ARCADE.UI = {
    ControlsBgCol = Color(0, 0, 0, 200),
    ControlsTextCol = Color(255, 255, 255, 200)
}

function ARCADE:DebugPrint(...)
    if self.Debug:GetBool() then
        print("[ARCADE]", ...)
    end
end

hook.Add("SpawnMenuOpen", "arcade_no_spawnmenu", function()
    if not IsValid(ARCADE.Cabinet.CurrentMachine) then return end

    return false
end)

hook.Add("ScoreboardShow", "arcade_no_scoreboard", function()
    if not IsValid(ARCADE.Cabinet.CurrentMachine) then return end

    return false
end)

hook.Add("HUDDrawTargetID", "arcade_no_targetid", function()
    if not IsValid(ARCADE.Cabinet.CurrentMachine) then return end

    return false
end)

hook.Add("ContextMenuOpen", "arcade_no_contextmenu", function()
    if not IsValid(ARCADE.Cabinet.CurrentMachine) then return end

    return false
end)

local function DrawControls(strings)
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
            ARCADE.UI.ControlsBgCol,
            ARCADE.UI.ControlsTextCol
        )

        x = x + v
    end
end

-- TODO: Come up with a nicer way for arcade entities to draw stuff to HUD
hook.Add("HUDPaint", "arcade_hud", function()
    if IsValid(ARCADE.Cabinet.UI.InfoPanel) then
        ARCADE.Cabinet.UI.InfoPanel:PaintManual()
    end

    if IsValid(ARCADE.Cabinet.CurrentMachine) then
        DrawControls({
            ["[F1] Toggle Game Info"] = 0,
            ["[" .. string.upper(input.LookupBinding("+walk") or "alt") .. "] Insert Coins"] = 0,
            ["[SCROLL] Zoom"] = 0,
            ["[HOLD " .. string.upper(input.LookupBinding("+use") or "e") .. "] Exit"] = 0
        })
    end
end)