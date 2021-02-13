include("shared.lua")
include("cl_hooks.lua")

local MaxDist = 200

local ScreenWidth = 512
local ScreenHeight = 512
local MarqueeWidth = 512
local MarqueeHeight = 179

local PressedWalk = false

local LoadedLibs = {}
local IMAGE = include("arcade_cabinet_lib/image.lua") -- We need a shared copy of the library for loading cabinet art on each cabinet

concommand.Add("arcade_cabinet_reload", function()
    IMAGE:ClearImages()

    for _, v in ipairs(ents.FindByClass("arcade_cabinet")) do
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
end)

concommand.Add("arcade_cabinet_clear_cache", function()
    local paths = {
        "images",
        "files"
    }

    local base = "arcade/cache/"

    for _, v in ipairs(paths) do
        for _, fv in ipairs(file.Find(base .. v .. "/*", "DATA")) do
            file.Delete(base .. v .. "/" .. fv)
        end
    end
end)

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

local function WrappedInclusion(path, upvalues)
    local gameMeta = setmetatable(upvalues, { __index = _G, __newindex = _G })

    local gameFunc = (isfunction(path) and path or CompileFile(path))
    setfenv(gameFunc, gameMeta)
    return gameFunc()
end

ENT.Initialized = false

function ENT:Initialize()
    self.Initialized = true

    self.LastNWVars = {
        ["Player"] = self:GetPlayer(),
        ["Coins"] = self:GetCoins(),
        ["CurrentGame"] = self:GetCurrentGame(),
        ["Seat"] = self:GetSeat()
    }

    self.MarqueeHasDrawn = self.MarqueeHasDrawn or false

    local num = math.random(9999)

    self.ScreenTexture = self.ScreenTexture or GetRenderTargetEx(
        "ArcadeCabinet_Screen_" .. self:EntIndex() .. "_" .. num,
        ScreenWidth,
        ScreenHeight,
        RT_SIZE_LITERAL,
        MATERIAL_RT_DEPTH_NONE,
        1,
        CREATERENDERTARGETFLAGS_HDR,
        IMAGE_FORMAT_DEFAULT
    )
    self.ScreenMaterial = self.ScreenMaterial or CreateMaterial(
        "ArcadeCabinet_Screen_Material_" .. self:EntIndex() .. "_" .. num,
        "VertexLitGeneric",
        {
            ["$basetexture"] = self.ScreenTexture:GetName(),
            ["$model"] = 1,
            ["$selfillum"] = 1,
            ["$selfillummask"] = "dev/reflectivity_30b"
        }
    )

    self.MarqueeTexture = self.MarqueeTexture or GetRenderTargetEx(
        "ArcadeCabinet_Marquee_" .. self:EntIndex() .. "_" .. num,
        MarqueeWidth,
        256, -- Not the same as the drawable area
        RT_SIZE_LITERAL,
        MATERIAL_RT_DEPTH_NONE,
        16,
        CREATERENDERTARGETFLAGS_HDR,
        IMAGE_FORMAT_DEFAULT
    )
    self.MarqueeMaterial = self.MarqueeMaterial or CreateMaterial(
        "ArcadeCabinet_Marquee_Material_" .. self:EntIndex() .. "_" .. num,
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

    if self:GetCurrentGame() and not self.Game and not self.InLauncher then
        self:SetGame(self:GetCurrentGame())
    end

    self:UpdateMarquee()
    self:UpdateScreen()
end

function ENT:StopSounds()
    for k, v in pairs(self.LoadedSounds) do
        if IsValid(v) then
            v:Stop()
        end
    end

    table.Empty(self.LoadedSounds)
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

    -- NetworkVarNotify is unreliable so manually checking for changes here
    if self:GetPlayer() ~= self.LastNWVars.Player then
        self:OnPlayerChange("Player", self.LastNWVars.Player, self:GetPlayer())
    end
    if self:GetCoins() ~= self.LastNWVars.Coins then
        self:OnCoinsChange("Coins", self.LastNWVars.Coins, self:GetCoins())
    end
    if self:GetCurrentGame() ~= self.LastNWVars.CurrentGame then
        self:OnGameChange("CurrentGame", self.LastNWVars.CurrentGame, self:GetCurrentGame())
    end

    -- If we weren't nearby when the cabinet was spawned we won't get notified
    -- when the seat was created so manually call
    if IsValid(self:GetSeat()) and not self:GetSeat().ArcadeCabinet then
        self:OnSeatCreated("Seat", NULL, self:GetSeat())
    end

    if self.Game and self.Game.Bodygroup and Bodygroups[self.Game.Bodygroup] then
        self:SetBodygroup(0, Bodygroups[self.Game.Bodygroup][1])
        self:SetBodygroup(1, Bodygroups[self.Game.Bodygroup][2])
    end

    if ARCADE.Cabinet.DisableOthers:GetBool() and ARCADE.Cabinet.CurrentCabinet and ARCADE.Cabinet.CurrentCabinet ~= self then
        return
    end

    if LocalPlayer() and LocalPlayer():GetPos():DistToSqr(self:GetPos()) > MaxDist * MaxDist then
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
        if not self.InLauncher and IsValid(self:GetPlayer()) and self:GetPlayer() == LocalPlayer() then
            local pressed = input.LookupBinding("+walk") and self:GetPlayer():KeyDown(IN_WALK) or input.IsKeyDown(KEY_LALT)

            if pressed then
                if not PressedWalk then
                    PressedWalk = true

                    local cost = self:GetCost()

                    if cost > 0 and hook.Run("ArcadeCabinetCanPlayerAfford", cost) == false then
                        notification.AddLegacy("You can't afford to play!", NOTIFY_ERROR, 5)
                        return
                    end

                    net.Start("arcade_cabinet_insertcoin")
                    net.SendToServer()
                end
            else
                PressedWalk = false
            end
        end

        for _, v in pairs(self.LoadedSounds) do
            if IsValid(v) then
                v:SetPos(self:GetPos())
            end
        end

        self.Game:Update()
    end
end

function ENT:OnEnteredRange()
    self:UpdateScreen()

    if self.Game and self.Game.OnLocalPlayerNearby then
        self.Game:OnLocalPlayerNearby()
    end
end

function ENT:OnLeftRange()
    self:UpdateScreen()

    if self.Game and self.Game.OnLocalPlayerAway then
        self.Game:OnLocalPlayerAway()
    end
end

function ENT:Draw()
    local marqueeIndex = self:GetBodygroup(0)

    if IsValid(ARCADE.Cabinet.CurrentCabinet) and ARCADE.Cabinet.CurrentCabinet == self and not LocalPlayer():ShouldDrawLocalPlayer() then
        cam.IgnoreZ(true)
    end

    local cabinetArt = nil
    if self.CabinetArtKey then
        cabinetArt = IMAGE.Images[self.CabinetArtKey]
    end

    -- To prevent using string table slots, don't set the submaterial on the server
    -- and just override it here
    render.MaterialOverrideByIndex(marqueeIndex == 2 and 7 or 3, self.MarqueeMaterial)
    render.MaterialOverrideByIndex(4, self.ScreenMaterial)
    if cabinetArt and cabinetArt.status == IMAGE.STATUS_LOADED then
        render.MaterialOverrideByIndex(marqueeIndex == 2 and 5 or 2, cabinetArt.mat)
    end
    self:DrawModel()
    render.MaterialOverrideByIndex()

    if IsValid(ARCADE.Cabinet.CurrentCabinet) and ARCADE.Cabinet.CurrentCabinet == self and not LocalPlayer():ShouldDrawLocalPlayer() then
        cam.IgnoreZ(false)
    end

    if not self.InRange or not self.Game or (ARCADE.Cabinet.DisableOthers:GetBool() and ARCADE.Cabinet.CurrentCabinet and ARCADE.Cabinet.CurrentCabinet ~= self) then
        return
    end

    self:UpdateScreen()
end

function ENT:OnPlayerChange(name, old, new)
    ARCADE:DebugPrint(
        self:EntIndex(),
        "OnPlayerChange",
        "new", new,
        "old", old
    )

    if IsValid(new) then
        if old ~= new then
            if self.Game then
                self.Game:OnStopPlaying(old)
            end

            if self.Game then
                self.Game:OnStartPlaying(new)
            end

            if new == LocalPlayer() then
                self:OnLocalPlayerEntered()
            end
        end
    else
        if self.Game then
            self.Game:OnStopPlaying(old)
        end

        if old == LocalPlayer() then
            ARCADE.Cabinet:OnLocalPlayerLeft()
        end
    end

    self.LastNWVars.Player = new
end

function ENT:OnLocalPlayerEntered()
    ARCADE.Cabinet.CurrentCabinet = self

    if ARCADE.Cabinet.DisableBloom:GetBool() and not cvars.Bool("mat_disable_bloom") then
        LocalPlayer():ConCommand("mat_disable_bloom 1")
        ARCADE.Cabinet.BloomWasDisabled = true
    end

    if cvars.Bool("webbrowser_f1_open") then
        LocalPlayer():ConCommand("webbrowser_f1_open 0")
        ARCADE.Cabinet.MSBrowserWasDisabled = true
    end

    if ARCADE.Cabinet.DisablePAC:GetBool() and pac and pac.IsEnabled() then
        pac.Disable()
        ARCADE.Cabinet.PACWasDisabled = true
    else
        ARCADE.Cabinet.PACWasDisabled = false
    end

    --[[if ARCADE.Cabinet.DisableOutfitter:GetBool() and outfitter then
        outfitter.SetHighPerf(true, true)
        outfitter.DisableEverything()
        ARCADE.Cabinet.OutfitterWasDisabled = true
    else
        ARCADE.Cabinet.OutfitterWasDisabled = false
    end--]]
end

function ENT:UpdateMarquee()
    if self.MarqueeHasDrawn then return end

    render.PushRenderTarget(self.MarqueeTexture)
        cam.Start2D()
            surface.SetDrawColor(0, 0, 0, 255)
            surface.DrawRect(0, 0, MarqueeWidth, MarqueeHeight)

            if self.Game and self.Game.DrawMarquee then
                self.Game:DrawMarquee()
                self.MarqueeHasDrawn = true
            else
                surface.SetFont("DermaLarge")
                local w, h = surface.GetTextSize(self.Game and self.Game.Name or "Arcade Cabinet")
                surface.SetTextColor(255, 255, 255, 255)
                surface.SetTextPos((MarqueeWidth / 2) - (w / 2), (MarqueeHeight / 2) - (h / 2))
                surface.DrawText(self.Game and self.Game.Name or "Arcade Cabinet")
            end
        cam.End2D()
    render.PopRenderTarget()
end

function ENT:UpdateScreen()
    render.PushRenderTarget(self.ScreenTexture)
        cam.Start2D()
            surface.SetDrawColor(0, 0, 0, 255)
            surface.DrawRect(0, 0, ScreenWidth, ScreenHeight)

            if self.InRange and self.Game then
                self.Game:Draw()
            end
        cam.End2D()
    render.PopRenderTarget()
end

function ENT:OnCoinsChange(name, old, new)
    ARCADE:DebugPrint(
        self:EntIndex(),
        "OnCoinsChange",
        "new", new,
        "old", old
    )

    if self.Game then
        if new > old then
            if self.Game.OnCoinsInserted then
                self.Game:OnCoinsInserted(self:GetPlayer(), old, new)
            end

            self:EmitSound("ambient/levels/labs/coinslot1.wav", 50)
        end

        if new < old and self.Game.OnCoinsLost then
            self.Game:OnCoinsLost(self:GetPlayer(), old, new)
        end
    end

    self.LastNWVars.Coins = new
end

function ENT:OnGameChange(name, old, new)
    ARCADE:DebugPrint(
        self:EntIndex(),
        "OnGameChange",
        "new", new,
        "old", old
    )

    self:SetGame(new)

    self.LastNWVars.CurrentGame = new
end

function ENT:LoadLauncher(forceLibLoad)
    self.Game = WrappedInclusion("arcade_cabinet_launcher.lua", self:GetUpvalues("launcher", forceLibLoad))
    self.InLauncher = true
end

function ENT:SetGame(game, forceLibLoad)
    if self.Game then
        if self.Game.Destroy then
            self.Game:Destroy()
        end
        self.Game = nil
    end

    self:StopSounds()

    self.MarqueeHasDrawn = false

    if game and game ~= "" then
        if not isfunction(game) and not file.Exists("arcade_cabinet_games/" .. game .. ".lua", "LUA") then
            ARCADE:DebugPrint(self:EntIndex(), "Tried to load non-existent game", game)
            self:LoadLauncher(forceLibLoad)
        else
            self.Game = WrappedInclusion(isfunction(game) and game or "arcade_cabinet_games/" .. game .. ".lua", self:GetUpvalues(game, forceLibLoad))
            self.InLauncher = false
        end
    else
        self:LoadLauncher(forceLibLoad)
    end

    if self.Game then
        if self.Game.Init then
            self.Game:Init()
        end

        if IsValid(self:GetPlayer()) then
            self.Game:OnStartPlaying(self:GetPlayer())
        end
    end

    self.CabinetArtKey = nil

    if self.Game and self.Game.CabinetArtURL then
        self.CabinetArtKey = "cabinet_art_" .. tostring(game)

        IMAGE:LoadFromURL(
            self.Game.CabinetArtURL,
            self.CabinetArtKey,
            nil, -- Can't use the callback as it will only be called once per image load
            false,
            "vertexlitgeneric smooth"
        )
    end

    if not self.Game or (self.Game and not self.Game.LateUpdateMarquee) then
        self:UpdateMarquee()
    end
    self:UpdateScreen()
end

function ENT:GetUpvalues(game, forceLibLoad)
    local upvalues = {
        SCREEN_WIDTH = ScreenWidth,
        SCREEN_HEIGHT = ScreenHeight,
        MARQUEE_WIDTH = MarqueeWidth,
        MARQUEE_HEIGHT = MarqueeHeight
    }

    for k, v in pairs(BG) do
        upvalues[k] = v
    end

    if game == "launcher" then
        upvalues.LAUNCHER = WrappedInclusion("arcade_cabinet_lib/launcher.lua", { ENTITY = self })
        return upvalues
    end

    if LoadedLibs[game] and not forceLibLoad then
        upvalues.COLLISION = LoadedLibs[game].COLLISION
        upvalues.IMAGE = LoadedLibs[game].IMAGE
        upvalues.FONT = LoadedLibs[game].FONT
        upvalues.FILE = LoadedLibs[game].FILE
    else
        LoadedLibs[game] = {
            COLLISION = include("arcade_cabinet_lib/collision.lua"),
            IMAGE = include("arcade_cabinet_lib/image.lua"),
            FONT = include("arcade_cabinet_lib/font.lua"),
            FILE = include("arcade_cabinet_lib/file.lua")
        }

        upvalues.COLLISION = LoadedLibs[game].COLLISION
        upvalues.IMAGE = LoadedLibs[game].IMAGE
        upvalues.FONT = LoadedLibs[game].FONT
        upvalues.FILE = LoadedLibs[game].FILE
    end

    -- Some libraries need to be loaded per cabinet not per game - e.g. sound (in order to emit sounds from the cabinet)
    upvalues.SOUND = WrappedInclusion("arcade_cabinet_lib/sound.lua", { ENTITY = self })

    upvalues.COINS = WrappedInclusion("arcade_cabinet_lib/coins.lua", { ENTITY = self })
    upvalues.CABINET = WrappedInclusion("arcade_cabinet_lib/cabinet.lua", { ENTITY = self })

    return upvalues
end