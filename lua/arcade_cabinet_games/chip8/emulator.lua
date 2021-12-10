return function(program)
    local CHIP8 = {}

    -- Clock Settings
    local CLOCK_SPEED = 500
    local TIMER_CLOCK = 60
    local SCREEN_W = 64
    local SCREEN_H = 32
    -- Bitmasks
    local MASK_12 = 0x0FFF
    local MASK_8 = 0xFF
    local MASK_4 = 0x0F
    -------------------------------------------
    --Register Setup
    local RAM = {} -- RAM
    local STK = {} -- Stack
    CHIP8.DISPLAY = {}
    local pc = 0x200  -- Program Counter
    local rI = 0  -- I register
    local SP = 0 -- Stack Pointer
    local REG = {} -- Registers
    local KEYS = {}
    for I = 0,0xF do
        REG[I] = 0  -- zero registers
    end
    -- Timers
    CHIP8.tS = 0
    local tD = 0
    --
    local tS_C, tD_C = 0,0
    local FontSet = {
        0xF0, 0x90, 0x90, 0x90, 0xF0, -- 0 
        0x20, 0x60, 0x20, 0x20, 0x70, -- 1
        0xF0, 0x10, 0xF0, 0x80, 0xF0, -- 2 
        0xF0, 0x10, 0xF0, 0x10, 0xF0, -- 3
        0x90, 0x90, 0xF0, 0x10, 0x10, -- 4
        0xF0, 0x80, 0xF0, 0x10, 0xF0, -- 5
        0xF0, 0x80, 0xF0, 0x90, 0xF0, -- 6
        0xF0, 0x10, 0x20, 0x40, 0x40, -- 7 
        0xF0, 0x90, 0xF0, 0x90, 0xF0, -- 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, -- 9 
        0xF0, 0x90, 0xF0, 0x90, 0x90, -- A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, -- B
        0xF0, 0x80, 0x80, 0x80, 0xF0, -- C
        0xE0, 0x90, 0x90, 0x90, 0xE0, -- D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, -- E 
        0xF0, 0x80, 0xF0, 0x80, 0x80, -- F
    }

    --IVariables
    local last_clock = SysTime()

    --- RESET Functions
    local function resetRegisters()
        for I = 0,0xF do
            REG[I] = 0  -- zero registers
        end
        tD,CHIP8.tS,tS_C,tD_C = 0,0,0,0 -- reset timers
        pc = 0x200 -- reset pc
        rI = 0
        for I = 0,0xF do
            KEYS[I] = false  -- zero registers
        end
    end

    local function resetScreen()
        for I = 0, SCREEN_W * SCREEN_H do
            CHIP8.DISPLAY[I] = 0
        end
    end

    local function resetRAM()
        local addr = 0
        -- print("Filling arena [PROGRAM]")
        while (addr < 0x1FF) do
            RAM[addr] = 0
            addr = addr + 1
        end

        -- Filling fontset 
        for I = 0, #FontSet do
            RAM[I - 1] = FontSet[I]
        end

        -- print("Filling arena [ETI-660]")
        while (addr < 0x600) do
            RAM[addr] = 0
            addr = addr + 1
        end

        -- print("Filling arena [DATA]")
        while (addr < 0xFFF) do
            RAM[addr] = 0
            addr = addr + 1
        end

        addr = 0x200
        local I = 0
        while (addr < 0xFFF) do
            RAM[addr - 1] = string.byte(program[I]) or 0
            I = I + 1
            addr = addr + 1
        end
        -- print("Last Offs " .. addr)
    end

    function CHIP8:resetAll()
        resetRAM()
        resetRegisters()
        resetScreen()
    end

    local function DPLWrite(x,y)
        local pixel_address = x + (SCREEN_W * y)
        local current_state = CHIP8.DISPLAY[pixel_address] or 0
        CHIP8.DISPLAY[pixel_address] = bit.bxor(current_state, 1)

        return CHIP8.DISPLAY[current_state]
    end

    local function clm(v)
        local carry = 0
        if (v > 0xFF) then
            v = v - 0x100
            carry = 1
        end
        if (v < 0) then
            v = v + 0x100
            carry = 1
        end
        return v,carry
    end

    local function ramGet16(addr)
        local val = bit.bor( bit.lshift(RAM[addr] , 8), RAM[addr + 1])
        return val
    end

    local lpc = 0

    local function emulate()
        --- Timers
        if (CHIP8.tS > 0) then
            tS_C = tS_C + 1
            if (tS_C > TIMER_CLOCK) then
                CHIP8.tS = CHIP8.tS -1
            end
        end
        if (tD > 0) then
            tD_C = tD_C + 1
            if (tD_C > TIMER_CLOCK) then
                tD = tD -1
            end
        end
        --- Instructions 
        local cIF = ramGet16(pc)  -- entire instruction
        local cMS = bit.rshift(cIF,12) --  last nybble
        local cLS = bit.band(cIF,MASK_4) -- first nybble
        local cFB = bit.band(cIF,MASK_8) -- first byte

        if (lpc != pc) then
            lpc = pc
            -- print( string.format("%X - %X",pc,cIF) .. " - " .. (int or "") )
        end

        if (cIF == 0x00E0) then
            resetScreen()
            -- int = "CLS"
        elseif (cIF == 0x00EE) then
            pc = STK[SP] + 2
            STK[SP] = nil
            SP = SP - 1
            -- int = "RET"
            return
        elseif (cMS == 1) then
            pc = bit.band(cIF,MASK_12)
            -- int = "JP " .. string.format("%X",pc)
            return
        elseif (cMS == 2) then
            SP = SP + 1
            STK[SP] = pc
            pc = bit.band(cIF,MASK_12)
            -- int = "CALL " .. string.format("%X",pc) .. "@" .. SP
            return
        elseif (cMS == 3) then
            local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
            -- int = "SEi " .. rt .. "," .. cFB
            if REG[rt] == cFB then
                pc = pc + 2
                -- int = "SEi " .. rt .. "," .. cFB .. " SKP"
            end
        elseif (cMS == 4) then
            local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
            -- int = "SNEi " .. rt .. "," .. cFB
            if REG[rt] != cFB then
                pc = pc + 2
                -- int = "SNEi " .. rt .. "," .. cFB .. " SKP"
            end
        elseif (cMS == 5) then
            local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
            local rl = bit.rshift(bit.band(cIF, 0x00F0), 4)
            -- int = "SNEr " .. rt .. "," .. rl
            if REG[rt] == REG[rl] then
                pc = pc + 2
                -- int = "SNEr " .. rt .. "," .. rl .. " SKP"
            end
        elseif (cMS == 6) then
            local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
            REG[rt] = cFB
            -- int = "LD " .. rt .. "," .. cFB
        elseif (cMS == 7) then
            local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
            REG[rt] = clm(REG[rt] + cFB)
            -- int = "ADD " .. rt .. "," .. cFB
        elseif (cMS == 8) then
            if (cLS == 0) then
                local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
                local rl = bit.rshift(bit.band(cIF, 0x00F0), 4)
                -- int = "LD " .. rt .. "," .. rl
                REG[rt] = REG[rl]
            elseif (cLS == 1) then
                local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
                local rl = bit.rshift(bit.band(cIF, 0x00F0), 4)
                -- int = "OR " .. rt .. "," .. rl
                REG[rt] = bit.bor(REG[rt],REG[rl])
            elseif (cLS == 2) then
                local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
                local rl = bit.rshift(bit.band(cIF, 0x00F0), 4)
                -- int = "AND " .. rt .. "," .. rl
                REG[rt] = bit.band(REG[rt],REG[rl])
            elseif (cLS == 3) then
                local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
                local rl = bit.rshift(bit.band(cIF, 0x00F0), 4)
                -- int = "XOR " .. rt .. "," .. rl
                REG[rt] = bit.bxor(REG[rt],REG[rl])
            elseif (cLS == 4) then
                local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
                local rl = bit.rshift(bit.band(cIF, 0x00F0), 4)
                local vr1,vf = clm(REG[rt] + REG[rl])
                -- int = "ADDn " .. rt .. "," .. rl
                REG[rt] = vr1
                REG[0xF] = vf
            elseif (cLS == 5) then
                local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
                local rl = bit.rshift(bit.band(cIF, 0x00F0), 4)
                local rtv = REG[rt]
                local rtl = REG[rl]
                if rtv > rtl then
                    REG[0xF] = 1
                else
                    REG[0xF] = 0
                end
                -- int = "SUB " .. rt .. "," .. rl
                local vr1 = clm(REG[rt] - REG[rl])
                REG[rt] = vr1
            elseif (cLS == 6) then
                local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
                -- local rl = bit.rshift(bit.band(cIF, 0x00F0),4)
                if (bit.band(REG[rt], 1) > 0)  then
                    REG[0xF] = 1
                else
                    REG[0xF] = 0
                end
                -- int = "SHR " .. rt .. "," .. rl
                REG[rt] = bit.rshift(REG[rt], 1)
            elseif (cLS == 7) then
                local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
                local rl = bit.rshift(bit.band(cIF, 0x00F0), 4)
                local rtv = REG[rt]
                local rtl = REG[rl]
                if rtl >  rtv then
                    REG[0xF] = 1
                else
                    REG[0xF] = 0
                end
                local vr1 = clm(REG[rl] - REG[rt])
                -- int = "SUBN " .. rt .. "," .. rl
                REG[rt] = vr1
            elseif (cLS == 0xE) then
                local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
                -- local rl = bit.rshift(bit.band(cIF, 0x00F0),4)
                if (bit.band(REG[rt],0xFF) > 0) then
                    REG[0xF] = 1
                else
                    REG[0xF] = 0
                end
                -- int = "SHL " .. rt .. "," .. rl
                REG[rt] = bit.lshift(REG[rt], 1)
            end
        elseif (cMS == 9) then
            local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
            local rl = bit.rshift(bit.band(cIF, 0x00F0),4)
            if REG[rt] != REG[rl] then
                pc = pc + 2
            end
        elseif (cMS == 0xA) then
            rI = bit.band(cIF, 0x0FFF)
            -- int = "LD(I)  " .. rI
        elseif (cMS == 0xB) then
            pc = bit.band(cIF, 0x0FFF) + REG[0]
            -- int = "JP1 " .. pc
        elseif (cMS == 0xC) then
            local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
            REG[rt] = bit.band(math.Rand(0,0xFF),cFB)
            -- int = "RND " .. rt
        elseif (cMS == 0xD) then
            local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
            local rl = bit.rshift(bit.band(cIF, 0x00F0), 4)
            local rtv = REG[rt]
            local rtl = REG[rl]
            local height = cLS

            REG[0xF] = 0
            for Y = 0, height - 1 do
                local spr = RAM[rI + Y] or 0
                for X = 0,8 do
                    if (bit.band(spr, 0x80) > 0) and (DPLWrite(rtv + X, rtl + Y) > 0) then
                        REG[0xF] = 1
                    end
                    spr = bit.lshift(spr, 1)
                end
            end

        elseif (cMS == 0xE) then
            if (cFB == 0x9E) then
                local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
                local rtv = REG[rt]
                    -- int = "SKP V" .. rtv
                if KEYS[rtv] == true then
                    pc = pc + 2
                        -- int = "SKP V" .. rtv .. " [!!]"
                end
            elseif (cFB == 0xA1) then
                local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
                local rtv = REG[rt]
                -- int = "SKP V" .. rtv
                if KEYS[rtv] == false then
                    pc = pc + 2
                    -- int = "SKNP V" .. rtv .. " [!!]"
                end
            end
        elseif (cMS == 0xF) then
            if (cFB == 0x0A) then
                local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
                local pressed = false
                for I = 0,#KEYS do
                    if (KEYS[I] == true ) then
                        pressed = true
                        REG[rt] = I
                        break
                    end
                end
                -- int = "LD V" .. rt .. ",K"
                if not pressed then
                    return -- doesn't advance next opcode 
                end
            elseif (cFB == 0x07) then
                local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
                REG[rt] = tD
            elseif (cFB == 0x15) then
                local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
                local rtv = REG[rt]
                tD = rtv -- doesn't advance next opcode 
                -- int = "LD DT," .. rt .. ""
            elseif (cFB == 0x18) then
                local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
                local rtv = REG[rt]
                CHIP8.tS = rtv -- doesn't advance next opcode 
                -- int = "LD ST," .. rt .. ""
            elseif (cFB == 0x1E) then
                local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
                local rtv = REG[rt]
                rI = rI + rtv
                -- int = "LDA I,V" .. rt .. ""
            elseif (cFB == 0x29) then
                local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
                local rtv = REG[rt]
                rI = rtv * 5
                -- int = "LD I,DD" .. rt .. ""
            elseif (cFB == 0x33) then
                local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
                local rtv = REG[rt]
                local hun = math.floor(rtv / 100)
                local ten = math.floor(rtv / 10) - hun * 100
                local one = (math.floor(rtv)  - (hun * 100)) - (ten * 10)
                RAM[rI] = hun
                RAM[rI + 1] = ten
                RAM[rI + 2] = one
                -- int = "LD BCD," .. rt .. "," .. rI
            elseif (cFB == 0x55) then
                local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)
                for I = 0, rt do
                    RAM[rI + I] = REG[I]
                end
                -- int = "SAVE"
            elseif (cFB == 0x65) then
                local rt = bit.rshift(bit.band(cIF, 0x0F00), 8)

                for I = 0, rt do
                    REG[I] = RAM[rI + I]
                end
                -- int = "RESTORE"
            end
        end
        pc = pc + 2
    end

    local ts = 0
    function CHIP8:tick(keys)
        KEYS = keys

        -- KEYS[1] = input.IsKeyDown(KEY_1)
        -- KEYS[2] = input.IsKeyDown(KEY_2)
        -- KEYS[3] = input.IsKeyDown(KEY_3)
        -- KEYS[4] = input.IsKeyDown(KEY_4)
        -- KEYS[5] = input.IsKeyDown(KEY_5)
        -- KEYS[6] = input.IsKeyDown(KEY_6)
        -- KEYS[7] = input.IsKeyDown(KEY_7)
        -- KEYS[8] = input.IsKeyDown(KEY_8)
        -- KEYS[9] = input.IsKeyDown(KEY_9)
        -- KEYS[0] = input.IsKeyDown(KEY_0)
        -- KEYS[0xA] = input.IsKeyDown(KEY_A)
        -- KEYS[0xB] = input.IsKeyDown(KEY_B)
        -- KEYS[0xC] = input.IsKeyDown(KEY_C)
        -- KEYS[0xD] = input.IsKeyDown(KEY_D)
        -- KEYS[0xE] = input.IsKeyDown(KEY_E)
        -- KEYS[0xF] = input.IsKeyDown(KEY_F)

        local clock_count = math.ceil((SysTime() - last_clock) * CLOCK_SPEED)

        last_clock = SysTime()

        if (clock_count > 3000) then
            return
        end

        ts = ts + 1
        for I = 0, clock_count do
            emulate()
            ts = 0
        end
    end

    return CHIP8
end