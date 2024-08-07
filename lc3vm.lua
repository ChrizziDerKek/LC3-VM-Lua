-- register enum
local eRegisters = {}
eRegisters.R0 = 0
eRegisters.R1 = 1
eRegisters.R2 = 2
eRegisters.R3 = 3
eRegisters.R4 = 4
eRegisters.R5 = 5
eRegisters.R6 = 6
eRegisters.R7 = 7
eRegisters.PC = 8
eRegisters.COND = 9
eRegisters.COUNT = 10

-- instruction enum
local eInstructions = {}
eInstructions.BR = 0
eInstructions.ADD = 1
eInstructions.LD = 2
eInstructions.ST = 3
eInstructions.JSR = 4
eInstructions.AND = 5
eInstructions.LDR = 6
eInstructions.STR = 7
eInstructions.RTI = 8
eInstructions.NOT = 9
eInstructions.LDI = 10
eInstructions.STI = 11
eInstructions.JMP = 12
eInstructions.RES = 13
eInstructions.LEA = 14
eInstructions.TRAP = 15

-- flags enum
local eFlags = {}
eFlags.POS = 1
eFlags.ZRO = 2
eFlags.NEG = 4

-- trap enum
local eTraps = {}
eTraps.GETC = 0x20
eTraps.OUT = 0x21
eTraps.PUTS = 0x22
eTraps.IN = 0x23
eTraps.PUTSP = 0x24
eTraps.HALT = 0x25

-- reserved memory enum
local eMemory = {}
eMemory.KBSR = 0xFE00
eMemory.KBDR = 0xFE02

-- vm memory and register storages
local memory = {}
local reg = {}
-- init them with zeros
for i = 0, eRegisters.COUNT + 1, 1 do
	reg[i] = 0
end
for i = 0, 0x10000 + 1, 1 do
	memory[i] = 0
end

-- writes a value to a register
function reg_write(register, value)
	reg[register] = value
end

-- reads a value from a register
function reg_read(register)
	local value = reg[register]
    -- if this somehow happens
    if value == nil then
    	return 0
    end
    -- fix for signed short values
    if value > 0x7FFF then
    	value = value - 0x10000
    end
    return value
end

-- updates the flag register
function update_flags(r)
	local val = reg_read(r)
    -- if this somehow happens
    if val == nil then
    	return
    end
    -- if the value is zero, we set the zero flag
    -- otherwise set the positive or negative flag
	if val == 0 then
    	reg_write(eRegisters.COND, eFlags.ZRO)
    elseif (val >> 15) ~= 0 then
    	reg_write(eRegisters.COND, eFlags.NEG)
    else
    	reg_write(eRegisters.COND, eFlags.POS)
    end
end

-- writes a value to an address in memory
function mem_write(address, value)
	memory[address] = value
end

-- reads a value from an address in memory
function mem_read(address)
	-- handle the keyboard input memory address
	if address == eMemory.KBSR then
    	-- check for inputs
    	if lc3.checkkey() then
        	-- set a flag to indicate that we're using a keyboard
        	memory[eMemory.KBSR] = 1 << 15
            -- set the keyboard input to the kbdr register
            memory[eMemory.KBDR] = lc3.getchar()
        else
        	-- reset the keyboard flag again
        	memory[eMemory.KBSR] = 0
        end
    end
    return memory[address]
end

-- extends a number to a certain bit count
function sign_extend(x, bits)
	if ((x >> (bits - 1)) & 1) ~= 0 then
    	x = (x | (0xFFFF << bits)) & 0xFFFF
    end
    -- fix for signed short values
    if x > 0x7FFF then
    	x = x - 0x10000
    end
    return x
end

-- reads a single short value from a file
function read16(file)
	-- read 2 bytes
	local str = file:read(2)
    -- return nil if there is nothing to read
    if not str or #str < 2 then
    	return nil
    end
    -- extract the 2 bytes from the string
    local lo = string.byte(str, 1)
    local hi = string.byte(str, 2)
    -- combine them in a big endian format
    local value = (lo << 8) | hi
    return value
end

-- reads an assembly file and loads it into memory
function image_read(image)
	-- open the file
	local file = io.open(image)
    -- get the start address
    local origin = read16(file)
    -- read everything else into memory
    for i = 0, 0x10000 - origin - 1, 1 do
    	local value = read16(file)
        if not value then
        	break
        end
        memory[origin + i] = value
    end
    -- close the file again
    file:close()
    return true
end

-- runs the specified assembly file
function run_virtual_machine(image)
	-- load the data into memory
    if not image_read(image) then
    	return false
    end
    
    -- disable input buffering
    lc3.setinputbuffering(false)
    
    -- reset the flag register and set pc to the start address
    reg_write(eRegisters.COND, eFlags.ZRO)
    reg_write(eRegisters.PC, 0x3000)
    
    -- handle the instructions while the vm in running
    local running = true
    while running do
    
    	-- get the current instruction and increment pc
    	local pc = reg_read(eRegisters.PC)
    	local instr = mem_read(pc)
        reg_write(eRegisters.PC, pc + 1)
        
        -- get the 3 possible registers that might appear in an instruction
        local r0 = (instr >> 9) & 7
        local r1 = (instr >> 6) & 7
        local r2 = instr & 7
        
        -- get the opcode, the trap and condition that might appear in an instruction
        local op = instr >> 12
        local trap = instr & 0xFF
        local cond = r0
        
        -- get the immediate flag and value that might appear in an instruction
        local imm = (instr >> 5) & 1
        local immval = sign_extend(instr & 0x1F, 5)
        
        -- get the far flag, pc offset, offset and far offset that might appear in an instruction
        local far = (instr >> 11) & 1
        local pcoffset = sign_extend(instr & 0x1FF, 9)
        local offset = sign_extend(instr & 0x3F, 6)
        local faroffset = sign_extend(instr & 0x7FF, 11)
        
        -- handle the instructions
        if op == eInstructions.ADD then
        	if imm ~= 0 then
            	-- handle immediate addition
            	reg_write(r0, reg_read(r1) + immval)
            else
            	-- handle register addition
            	reg_write(r0, reg_read(r1) + reg_read(r2))
            end
            update_flags(r0)
        elseif op == eInstructions.AND then
        	if imm ~= 0 then
            	-- handle immediate bitwise and
            	reg_write(r0, reg_read(r1) & immval)
            else
            	-- handle register bitwise and
            	reg_write(r0, reg_read(r1) & reg_read(r2))
            end
            update_flags(r0)
        elseif op == eInstructions.NOT then
        	-- bitwise negate the specified register
        	reg_write(r0, ~reg_read(r0))
            update_flags(r0)
        elseif op == eInstructions.BR then
        	-- check the condition register
        	if (cond & reg_read(eRegisters.COND)) ~= 0 then
            	-- increment pc by an offset if the condition is met
            	reg_write(eRegisters.PC, reg_read(eRegisters.PC) + pcoffset)
            end
        elseif op == eInstructions.JMP then
        	-- set pc to a specified value to jump to the address
            -- also handles a return by jumping to r7
        	reg_write(eRegisters.PC, reg_read(r1))
        elseif op == eInstructions.JSR then
        	-- handle register jump, first copy the return address to r7
        	reg_write(eRegisters.R7, reg_read(eRegisters.PC))
            if far ~= 0 then
            	-- far mode increments pc by a larger offset
            	reg_write(eRegisters.PC, reg_read(eRegisters.PC) + faroffset)
            else
            	-- near mode sets pc to a value in a specified register
            	reg_write(eRegisters.PC, reg_read(r1))
            end
            update_flags(r0)
        elseif op == eInstructions.LD then
        	-- loads a relative memory offset into a register
        	reg_write(r0, mem_read(reg_read(eRegisters.PC) + pcoffset))
            update_flags(r0)
        elseif op == eInstructions.LDI then
        	-- indirectly loads a relative memory offset into a register
            -- here we read the relative memory address to get a pointer
            -- to the memory address we actually want to read
        	reg_write(r0, mem_read(mem_read(reg_read(eRegisters.PC) + pcoffset)))
            update_flags(r0)
        elseif op == eInstructions.LDR then
        	-- loads a relative memory offset from a register value into a register
        	reg_write(r0, mem_read(reg_read(r1) + offset))
            update_flags(r0)
        elseif op == eInstructions.LEA then
        	-- load effective address does the same as load but loads the offset instead of the value
        	reg_write(r0, reg_read(eRegisters.PC) + pcoffset)
            update_flags(r0)
        elseif op == eInstructions.ST then
        	-- stores a register value in a relative offset
        	mem_write(reg_read(eRegisters.PC) + pcoffset, reg_read(r0))
        elseif op == eInstructions.STI then
        	-- indirectly stores a register value in a relative offset, see load indirect for more info
        	mem_write(mem_read(reg_read(eRegisters.PC) + pcoffset), reg_read(r0))
        elseif op == eInstructions.STR then
        	-- stores a register value in a relative memory offset
        	mem_write(reg_read(r1) + offset, reg_read(r0))
        elseif op == eInstructions.TRAP then
        	-- executes a trap routine, similar to a syscall
            -- first store the return address in r7
        	reg_write(eRegisters.R7, reg_read(eRegisters.PC))
            -- handle the trap routine
            if trap == eTraps.GETC then
            	-- getc accepts an input and stores it in r0
            	reg_write(eRegisters.R0, lc3.getchar())
                update_flags(eRegisters.R0)
            elseif trap == eTraps.OUT then
            	-- out prints a register value as a char
            	lc3.putc(reg_read(eRegisters.R0))
                lc3.flushout()
            elseif trap == eTraps.PUTS then
            	-- puts prints a string starting from the address in r0
            	local it = reg_read(eRegisters.R0)
            	local c = memory[it]
                while c ~= 0 do
                	lc3.putc(c)
                    it = it + 1
                    c = memory[it]
                end
                lc3.flushout()
            elseif trap == eTraps.IN then
            	-- in accepts an input and stores it in r0
                -- similar to getc but with a console output
            	lc3.printf("Enter a character: ")
                local c = lc3.getchar()
                lc3.putc(c)
                lc3.flushout()
                reg_write(eRegisters.R0, c)
                update_flags(eRegisters.R0)
            elseif trap == eTraps.PUTSP then
            	-- putsp prints a byte string that might contain non ascii characters
            	local it = reg_read(eRegisters.R0)
                local c = memory[it]
                while c ~= 0 do
                	local c1 = c & 0xFF
                    lc3.putc(c1)
                    local c2 = c >> 8
                    if c2 ~= 0 then
                    	lc3.putc(c2)
                    end
                    it = it + 1
                    c = memory[it]
                end
                lc3.flushout()
            elseif trap == eTraps.HALT then
            	-- halt ends the program
            	lc3.printf("HALT")
                lc3.flushout()
                running = false
            end
        else
        	running = false
        end
    end
    return true
end

-- run 2048.obj as an example
run_virtual_machine("2048.obj")
