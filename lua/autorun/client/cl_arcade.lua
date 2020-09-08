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
    if not IsValid(ARCADE.Cabinet.CurrentMachine) and not IsValid(ARCADE.AirHockey.CurrentMachine) then return end

    return false
end)

hook.Add("ScoreboardShow", "arcade_no_scoreboard", function()
    if not IsValid(ARCADE.Cabinet.CurrentMachine) and not IsValid(ARCADE.AirHockey.CurrentMachine) then return end

    return false
end)

hook.Add("HUDDrawTargetID", "arcade_no_targetid", function()
    if not IsValid(ARCADE.Cabinet.CurrentMachine) and not IsValid(ARCADE.AirHockey.CurrentMachine) then return end

    return false
end)

hook.Add("ContextMenuOpen", "arcade_no_contextmenu", function()
    if not IsValid(ARCADE.Cabinet.CurrentMachine) and not IsValid(ARCADE.AirHockey.CurrentMachine) then return end

    return false
end)

-- TODO: Come up with a nicer way for arcade entities to draw stuff to HUD
local DisclaimerBG = Color(0, 0, 0, 180)
hook.Add("HUDPaint", "arcade_hud", function()
    local strings = {}

    if IsValid(ARCADE.AirHockey.CurrentMachine) then
        strings = {
            ["[MOUSE] Move Striker"] = 0,
            ["[HOLD " .. string.upper(input.LookupBinding("+score") or "tab") .. "] View Score"] = 0,
            ["[HOLD " .. string.upper(input.LookupBinding("+use") or "e") .. "] Exit"] = 0
        }

        local text = "I know the physics are janky. This is probably the best it will get in GMod. If you have high ping, good luck. Sorry :("
        surface.SetFont("DermaDefault")
        local w, h = surface.GetTextSize(text)
        local x = (ScrW() * 0.5) - (w * 0.5)
        local y = ScrH() * 0.9

        draw.RoundedBox(8, x - 10, y - 10, w + 20, h + 20, DisclaimerBG)

        surface.SetTextColor(255, 255, 255, 200 + math.sin(RealTime() * 4) * 100)
        surface.SetTextPos(x, y)
        surface.DrawText(text)
    elseif IsValid(ARCADE.Cabinet.CurrentMachine) then
        strings = {
            ["[F1] Toggle Game Info"] = 0,
            ["[" .. string.upper(input.LookupBinding("+walk") or "alt") .. "] Insert Coins"] = 0,
            ["[SCROLL] Zoom"] = 0,
            ["[HOLD " .. string.upper(input.LookupBinding("+use") or "e") .. "] Exit"] = 0
        }
    else
        return
    end

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
end)