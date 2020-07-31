

-- gaming
-- https://github.com/ukgamer/gmod-arcademachines
-- Made by Jule

-- Some stuff here probably could be done in better ways.
-- The game works now though (should).

--function Snake()
    if not FONT:Exists( "Snake32" ) then
        surface.CreateFont( "Snake32", {
            font = "Trebuchet MS",
            size = 32,
            weight = 500,
            antialias = 1,
            additive = 1
        } )
    end

    if not FONT:Exists( "SnakeTitle" ) then
        surface.CreateFont( "SnakeTitle", {
            font = "Trebuchet MS",
            size = 70,
            italic = true,
            weight = 500,
            antialias = 1,
            additive = 1
        } )
    end

    local function PlayLoaded( loaded )
        if IsValid( SOUND.Sounds[loaded].sound ) then
            SOUND.Sounds[loaded].sound:SetTime( 0 )
            SOUND.Sounds[loaded].sound:Play()
        end
    end

    local function StopLoaded( loaded )
        if IsValid( SOUND.Sounds[loaded].sound ) then
            SOUND.Sounds[loaded].sound:Pause()
        end
    end

    local GAME = { Name = "Snake", State = nil }
    GAME.Description = "Use WASD to control the snake.\nMade by Jule :D"

    local PLAYER = nil

    local STATE_ATTRACT = 0
    local STATE_AWAITING_COINS = 1
    local STATE_PLAYING = 2

    local Score = 0

    local CoinsTaken = false

    local SNAKE = { x = 0, y = 0, Tail = {}, Col = Color( 25, 255, 25 ) }
    SNAKE.Dead = false
    SNAKE.DiedAt = math.huge
    SNAKE.MoveInterval = 0.1 -- Amount of seconds between each movement cycle.
    SNAKE.GoldenApplesEaten = 0
    SNAKE.GoalReached = false
    SNAKE.Boosted = false
    SNAKE.TotalBoostTime = 0
    SNAKE.BoostedAt = math.huge
    SNAKE.LastMoved = RealTime()
    SNAKE.MoveX, SNAKE.MoveY = 0, 0
    SNAKE.QueuedMoves = {}
    SNAKE.OldX, SNAKE.OldY = 0, 0

    local AttractorSnake = {
        ["FRAME.1"] = {
            {
                x = SCREEN_WIDTH / 2 - 45,
                y = SCREEN_HEIGHT / 2,
            
                w = 90,
                h = 10
            }
        },
        ["FRAME.2"] = {
            {
                x = SCREEN_WIDTH / 2 - 45,
                y = SCREEN_HEIGHT / 2,

                w = 30,
                h = 10
            },
            {
                x = SCREEN_WIDTH / 2 - 30,
                y = SCREEN_HEIGHT / 2 - 7,

                w = 30,
                h = 10
            },
            {
                x = SCREEN_WIDTH / 2 - 15,
                y = SCREEN_HEIGHT / 2,

                w = 30,
                h = 10
            }
        }
    }
    AttractorSnake.ActiveFrame = "FRAME.1"
    AttractorSnake.LastFrameAdvance = RealTime()

    local APPLES = { MAX_APPLES = 4, OnScreen = {} }
    local APPLE_TYPE_NORMAL = { Col = Color( 255, 25, 25 ) }
    local APPLE_TYPE_GOLDEN = { Col = Color( 255, 223, 127) }
    local APPLE_TYPE_BOOST = { Col = Color( 50, 50, 255 ) }

    function APPLE_TYPE_NORMAL.OnEaten()
        Score = Score + 100

        PlayLoaded( "eatnormal" )
    end

    function APPLE_TYPE_GOLDEN.OnEaten()
        Score = Score + 250

        -- There's a "side quest" in the game where you need to eat 10 golden apples
        -- By completing this quest your snake turns into "gold"
        SNAKE.GoldenApplesEaten = math.min( SNAKE.GoldenApplesEaten + 1 , 10) -- Won't need to count above 10.

        if SNAKE.GoldenApplesEaten == 10 and not SNAKE.GoalReached then
            PlayLoaded( "goalreached" )
            SNAKE.GoalReached = true
        end

        SOUND:EmitSound( "garrysmod/save_load3.wav" )
    end

    function APPLE_TYPE_BOOST.OnEaten()
        Score = Score + 150

        if not SNAKE.Boosted then
            SNAKE.Boosted = true
            SNAKE.TotalBoostTime = SNAKE.TotalBoostTime + 10
            SNAKE.BoostedAt = RealTime()
        end

        SNAKE.TotalBoostTime = SNAKE.TotalBoostTime + 5

        PlayLoaded( "eatboost" )
    end

    function GAME:Init() -- Called when MACHINE:SetGame( game ) is called.
        self.State = STATE_ATTRACT

        SOUND:LoadFromURL( "https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/snake/sounds/song.ogg", "music", function( snd )
            snd:EnableLooping( true )
        end )
    end

    function SNAKE:Move()
        self.OldX, self.OldY = SNAKE.x, SNAKE.y
        SNAKE.x, SNAKE.y = SNAKE.x + self.MoveX, SNAKE.y + self.MoveY

        if self.MoveX ~= 0 or self.MoveY ~= 0 then
            SOUND:EmitSound( "garrysmod/ui_hover.wav" )
        end

        for _, TailPart in ipairs( SNAKE.Tail ) do
            local x, y = TailPart.x, TailPart.y
            TailPart.x, TailPart.y = self.OldX, self.OldY
            self.OldX, self.OldY = x, y
        end

        self.LastMoved = RealTime()
    end

    function SNAKE:HandleSpeed()
        if self.Boosted then
            self.MoveInterval = 0.05
            return
        end

        self.MoveInterval = 0.1
    end

    function SNAKE:Eat( Type )
        table.insert( SNAKE.Tail, { x = SNAKE.x, y = SNAKE.y } )

        Type.OnEaten()
    end

    function SNAKE:CheckForApplesEaten()
        for _, Apple in ipairs( APPLES.OnScreen ) do
            if SNAKE.x == Apple.x and SNAKE.y == Apple.y then
                table.RemoveByValue( APPLES.OnScreen, Apple )
                SNAKE:Eat( Apple.Type )
            end
        end
    end

    function SNAKE:Die()
        self.Dead = true
        self.DiedAt = RealTime()
        PlayLoaded( "death" )
        PlayLoaded( "gameover" )
    end

    function SNAKE:CheckForDeath()
        for _, TailPart in ipairs( SNAKE.Tail ) do
            if SNAKE.x == TailPart.x and SNAKE.y == TailPart.y then
                SNAKE:Die()
            end
        end

        if SNAKE.x >= SCREEN_WIDTH - 30 or SNAKE.y >= SCREEN_HEIGHT - 50 then
            SNAKE:Die()
        elseif SNAKE.x <= 10 or SNAKE.y <= 50 then
            SNAKE:Die()
        end
    end

    function SNAKE:CanMoveOnAxis( Axis )
        if #self.Tail >= 1 then
            if Axis ~= 0 then
                return false
            end
        end

        return true
    end

    function SNAKE:EventTimers()
        if not SNAKE.Dead then
            if SNAKE.Boosted then
                if SNAKE.BoostedAt + SNAKE.TotalBoostTime <= RealTime() then
                    SNAKE.Boosted = false
                    SNAKE.TotalBoostTime = 0
                end
            end
        else
            if SNAKE.DiedAt + 7 <= RealTime() and not CoinsTaken then
                COINS:TakeCoins( 1 )
                CoinsTaken = true -- :woozy_face:
            end
        end
    end

    function SNAKE:HandleApparel()
        if self.Boosted then
            self.Col = Color( 50, 50, 255 )
            return
        end

        if self.GoalReached then
            self.Col = Color( 255, 216, 0 )
            return
        end
        
        self.Col = Color( 25, 255, 25 )
    end

    function SNAKE:Draw()
        surface.SetDrawColor( self.Col )
        surface.DrawRect( self.x, self.y, 10, 10 )
        
        for _, TailPart in ipairs( self.Tail ) do
            surface.DrawRect( TailPart.x, TailPart.y, 10, 10 )
        end
    end

    function APPLES:CheckForSpawnReserved( x, y )
        for _, Apple in pairs( APPLES.OnScreen ) do
            if Apple.x == x and Apple.y == y then
                return true
            end
        end

        for _, TailPart in ipairs( SNAKE.Tail ) do
            if TailPart.x == x and TailPart.y == y then
                return true
            end
        end

        if SNAKE.x == x and SNAKE.y == y then
            return true
        end

        return false
    end

    function APPLES:Spawner()
        if GAME.State == STATE_PLAYING then
            if #self.OnScreen < self.MAX_APPLES then
                local AppleX = math.random( 10, ( SCREEN_WIDTH - 22 ) / 10 ) * 10
                local AppleY = math.random( 10, ( SCREEN_HEIGHT - 22 ) / 10 ) * 10
                local AppleX = math.max( math.min( SCREEN_WIDTH - 42, AppleX ), 20 )
                local AppleY = math.max( math.min( SCREEN_HEIGHT - 52, AppleY ), 50 )

                if self:CheckForSpawnReserved( AppleX, AppleY ) then
                    return -- Just halt, spawner function will be ran again instantly.
                end

                local Type = APPLE_TYPE_NORMAL

                if math.random( 1, 10 ) == 4 then
                    Type = APPLE_TYPE_GOLDEN
                elseif math.random( 1, 15 ) == 6 then -- Tfw boost apples still more common thatn golden apples
                    Type = APPLE_TYPE_BOOST
                end

                local NewApple = { x = AppleX, y = AppleY, Type = Type }
                table.insert( self.OnScreen, NewApple )
            end
        end
    end

    function APPLES:Draw()
        if GAME.State == STATE_PLAYING then
            for _, Apple in ipairs( self.OnScreen ) do
                surface.SetDrawColor( Apple.Type.Col )
                surface.DrawRect( Apple.x, Apple.y, 10, 10 )
            end
        end
    end

    function GAME:Start()
        self.State = STATE_PLAYING
        StopLoaded( "music" )

        table.Empty( SNAKE.Tail )
        SNAKE.Col = Color( 25, 255, 25 )
        SNAKE.Dead = false
        SNAKE.DiedAt = math.huge
        SNAKE.GoldenApplesEaten = 0
        SNAKE.GoalReached = false
        SNAKE.Boosted = false
        SNAKE.TotalBoostTime = 0
        SNAKE.BoostedAt = math.huge
        SNAKE.MoveInterval = 0.1
        SNAKE.MoveX = 0
        SNAKE.MoveY = 0
        table.Empty( SNAKE.QueuedMoves )

        table.Empty( APPLES.OnScreen )

        SNAKE.x = math.random( 10, ( SCREEN_WIDTH - 22 ) / 10 ) * 10
        SNAKE.y = math.random( 10, ( SCREEN_HEIGHT - 22 ) / 10 ) * 10
        SNAKE.x = math.max( math.min( SCREEN_WIDTH - 42, SNAKE.x ), 20 )
        SNAKE.y = math.max( math.min( SCREEN_HEIGHT - 52, SNAKE.y ), 50 )

        Score = 0
        CoinsTaken = false
    end

    function GAME:Stop()
        self.State = STATE_AWAITING_COINS
        PlayLoaded( "music" )
    end

    function GAME:Update()
        if self.State == STATE_PLAYING and PLAYER == LocalPlayer() then
            if not SNAKE.Dead then
                APPLES:Spawner()

                -- In order to fix a few flaws in the game, I had to handle the input in a weird way.
                -- This isn't perfect either, but the game should feel way more responsive now.
                if SNAKE:CanMoveOnAxis( SNAKE.MoveY ) then
                    if PLAYER:KeyPressed( IN_FORWARD ) then
                        table.insert( SNAKE.QueuedMoves, function()
                            SNAKE.MoveX = 0
                            SNAKE.MoveY = -10
                        end )
                    end
                    
                    if PLAYER:KeyPressed( IN_BACK ) then
                        table.insert( SNAKE.QueuedMoves, function()
                            SNAKE.MoveX = 0
                            SNAKE.MoveY = 10
                        end )
                    end
                end

                if SNAKE:CanMoveOnAxis( SNAKE.MoveX ) then
                    if PLAYER:KeyPressed( IN_MOVERIGHT ) then
                        table.insert( SNAKE.QueuedMoves, function()
                            SNAKE.MoveY = 0
                            SNAKE.MoveX = 10
                        end )
                    end
                    
                    if PLAYER:KeyPressed( IN_MOVELEFT ) then
                        table.insert( SNAKE.QueuedMoves, function()
                            SNAKE.MoveY = 0
                            SNAKE.MoveX = -10
                        end )
                    end
                end

                if SNAKE.LastMoved + SNAKE.MoveInterval < RealTime() then
                    for _, Queued in ipairs( SNAKE.QueuedMoves ) do
                        Queued()
                    end
                    table.Empty( SNAKE.QueuedMoves )

                    SNAKE:CheckForApplesEaten()
                    SNAKE:Move()
                    SNAKE:CheckForDeath()
                    SNAKE:HandleSpeed()
                    SNAKE:HandleApparel()
                end
            end

            SNAKE:EventTimers()
        end
    end

    function GAME:Draw()
        draw.SimpleText( COINS:GetCoins() .. " COIN(S)", "Trebuchet18", 25, 25, Color( 255, 255, 255 ) )

        if self.State == STATE_ATTRACT or self.State == STATE_AWAITING_COINS then
            draw.SimpleText(
                "INSERT COINS", 
                "Snake32", 
                SCREEN_WIDTH / 2, 
                SCREEN_HEIGHT - 100, 
                Color( 255, 255, 255, ( CurTime() % 1 > 0.5 and 255 or 0 ) ),
                TEXT_ALIGN_CENTER
            )

            -- Draw an animated snake during the attracting state.
            -- Also draw an apple that the snake is seemingly going after.
            surface.SetDrawColor( Color( 25, 255, 25 ) )
            if AttractorSnake.LastFrameAdvance + 0.25 < RealTime() then
                AttractorSnake.ActiveFrame = ( AttractorSnake.ActiveFrame == "FRAME.1" and "FRAME.2" or "FRAME.1" )
                AttractorSnake.LastFrameAdvance = RealTime()
            end
            
            for _, object in ipairs( AttractorSnake[AttractorSnake.ActiveFrame] ) do
                surface.DrawRect( object.x, object.y, object.w, object.h )
            end

            surface.SetDrawColor( 255, 25, 25 )
            surface.DrawRect( SCREEN_WIDTH / 2 - 120, SCREEN_HEIGHT / 2, 10, 10 )
        else
            draw.SimpleText( "Score: " .. Score, "Snake32", SCREEN_WIDTH / 2, 25, Color( 255, 255, 255 ), TEXT_ALIGN_CENTER )

            draw.SimpleText( SNAKE.GoldenApplesEaten .. "/10", "Trebuchet24", SCREEN_WIDTH - 75, 25, Color( 255, 255, 255 ) )
            surface.SetDrawColor( APPLE_TYPE_GOLDEN.Col )
            surface.DrawRect( SCREEN_WIDTH - 90, 30, 10, 10 )

            APPLES:Draw()
            SNAKE:Draw()

            -- Borders
            surface.SetDrawColor( SNAKE.Col )
            surface.DrawOutlinedRect( 20, 60, SCREEN_WIDTH - 42, SCREEN_HEIGHT - 102 )
        end
    end

    function GAME:OnStartPlaying( ply ) -- Called when the arcade machine is entered
        if ply == LocalPlayer() then
            PLAYER = ply
        else return end

        SOUND:LoadFromURL( "https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/snake/sounds/eat_normal.ogg", "eatnormal" )
        SOUND:LoadFromURL( "https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/snake/sounds/eat_boost.ogg", "eatboost" )
        -- Golden apples use a GMod sound when eaten.
        SOUND:LoadFromURL( "https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/snake/sounds/goalreached.ogg", "goalreached" )
        SOUND:LoadFromURL( "https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/snake/sounds/death.ogg", "death" )
        SOUND:LoadFromURL( "https://raw.githubusercontent.com/ukgamer/gmod-arcademachines-assets/master/snake/sounds/gameover.ogg", "gameover" )

        self.State = STATE_AWAITING_COINS

        PlayLoaded( "music" )
    end

    function GAME:OnStopPlaying( ply ) -- ^^ upon exit.
        if ply == PLAYER and ply == LocalPlayer() then
            PLAYER = nil
        else return end

        self:Stop()

        self.State = STATE_ATTRACT
        StopLoaded( "music" )
    end

    function GAME:OnCoinsInserted( ply, old, new )
        if ply ~= LocalPlayer() then return end

        if new > 0 and self.State == STATE_AWAITING_COINS then
            self:Start()
        end
    end

    function GAME:OnCoinsLost( ply, old, new )
        if ply ~= LocalPlayer() then return end

        if new <= 0 then
            self:Stop()
        elseif new > 0 then
            self:Start()
        end
    end

    function GAME:DrawMarquee()
        -- Title text
        draw.SimpleText( "SNAKE", "SnakeTitle", MARQUEE_WIDTH / 2 - 140, MARQUEE_HEIGHT / 2 - 25, Color( 255, 255, 255 ) )

        -- Snake
        surface.SetDrawColor( Color( 25, 255, 25 ) )
        surface.DrawRect( MARQUEE_WIDTH / 2 + 20, 40, 120, 20 )
        surface.DrawRect( MARQUEE_WIDTH / 2 + 140, 40, 20, 40 )

        -- Apple
        surface.SetDrawColor( Color( 255, 50, 50 ) )
        surface.DrawRect( MARQUEE_WIDTH / 2 + 140, 100, 20, 20 )
    end

    return GAME
--end
