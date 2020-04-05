-- cpu emulator. numbers are big endian. 255 bytes of accessible memory, write to address 255 to display a character on screen. 8 registers, 8th gets set to last key event. --

local gpu = component.proxy(component.list("gpu")())
local screen = component.proxy(component.list("screen")())
local fs = component.proxy(computer.getBootAddress())

if not fs.exists("rom.bin") then
  error("no rom.bin found")
end

local mem = {}
local prg = {}
local reg = {[0]=0, [1]=0, [2]=0, [3]=0, [4]=0, [5]=0, [6]=0, [7]=0}
for i=0, 255, 1 do
  mem[i] = 0
end

local pgc = 0

local x, y = 1, 1
gpu.setResolution(50, 16)
local function char(v)
  local c = string.char(v)
  if c == "\n" or x == 50 then
    x = 1
    if y == 16 then
      gpu.copy(1, 1, 50, 16, 0, -1)
      gpu.fill(1, 16, 50, 1, " ")
    else
      y = y + 1
    end
  end
  if c ~= "\n" then
    gpu.set(x, y, c)
    x = x + 1
  end
end

local insts = {
  [0x0] = function(r, d) -- load
    if r > 7 then
      error("invalid register")
    end
    reg[r] = d
  end,
  [0x1] = function(r, _r) -- memload
    if r > 7 or _r > 7 then
      error("invalid register")
    end
    if reg[_r] > 254 then
      error("invalid memory address")
    end
    reg[r] = mem[reg[_r]]
  end,
  [0x2] = function(r, a) -- store
    if r > 7 then
      error("invalid register")
    end
    if a > 255 then
      error("invalid memory address")
    end
    if a == 255 then
      char(reg[r])
    else
      mem[a] = reg[r]
    end
  end,
  [0x3] = function(r, _r) -- add
    if r > 7 or _r > 7 then
      error("invalid register")
    end
    local rst = reg[r] + reg[_r]
    if rst > 255 then
      rst = rst - 255
    end
    reg[r] = rst
  end,
  [0x4] = function(r, _r) -- sub
    if r > 7 or _r > 7 then
      error("invalid register")
    end
    local rst = reg[r] - reg[_r]
    if rst < 0 then
      rst = 255 - rst
    end
    reg[r] = rst
  end,
  [0x5] = function(r, _r) -- equal
    if r > 7 or _r > 7 then
      error("invalid register")
    end
    reg[7] = (reg[r] == reg[_r] and 0) or 1
  end,
  [0x6] = function(r, _r) -- not equal
    if r > 7 or _r > 7 then
      error("invalid register")
    end
    reg[7] = (reg[r] ~= reg[_r] and 0) or 1
  end,
  [0x7] = function(r, _r) -- greater
    if r > 7 or _r > 7 then
      error("invalid register")
    end
    reg[7] = (reg[r] > reg[_r] and 0) or 1
  end,
  [0x8] = function(r, _r) -- less
    if r > 7 or _r > 7 then
      error("invalid register")
    end
    reg[7] = (reg[r] < reg[_r] and 0) or 1
  end,
  [0x9] = function(c, o) -- jump
    if c == 0 or c > 5 then -- absolute unconditional
      pgc = o
    elseif c == 1 then -- absolute if zero
      if reg[7] == 0 then
        pgc = o
      end
    elseif c == 2 then -- absolute if not zero
      if reg[7] ~= 0 then
        pgc = o
      end
    elseif c == 3 then -- relative unconditional
      pgc = o
    elseif c == 4 then -- relative if zero
      if reg[7] == 0 then
        pgc = pgc + o
      end
    elseif c == 5 then -- relative if not zero
      if reg[7] ~= 0 then
        pgc = pgc + o
      end
    end
  end,
  [0xE] = function() -- noop
  end,
  [0xF] = function() -- halt
    while true do
      computer.pullSignal()
    end
  end
}

local _tmp = fs.open("/rom.bin")
for i=0, 85, 1 do
  prg[i] = (fs.read(_tmp, 3) or string.char(0xE):rep(3))
end
fs.close(_tmp)

while true do
  if pgc >= 86 then pgc = 0 end
  local cur = prg[pgc]
  local op, r, d = string.unpack(">I1I1I1", cur)
  component.proxy(component.list("sandbox")()).log(op, r, d)
  if insts[op] then
    insts[op](r, d)
  else
    error("invalid instruction")
  end
  local e, _, code = computer.pullSignal(0)
  if e == "key_down" then
    reg[6] = code
  else
    reg[6] = 0
  end
  pgc = pgc + 1
end
