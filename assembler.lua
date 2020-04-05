-- assembler --

local shell = {
  parse = function(...)
    return {...}
  end,
  resolve = function(a)
    return a
  end
}

if _OSVERSION then
  shell = require("shell")
end

local args, opts = shell.parse(...)

if #args < 2 then
  io.stderr:write("usage: assembler FILE OUT\n")
  os.exit(1)
end

local cpu = {
  ld  = 0x0,
  mld = 0x1,
  st  = 0x2,
  add = 0x3,
  sub = 0x4,
  eq  = 0x5,
  neq = 0x6,
  gt  = 0x7,
  lt  = 0x8,
  jmp = 0x9,
  nop = 0xe,
  hlt = 0xf
}

local compiler = {
  rt      = true,
  ["end"] = true,
  jpt     = true,
  jtp     = true,
  lds     = true
}

local function format(...)
  local args = {...}
  local ret = ""
  for i=1, #args, 1 do
    assert(tonumber(args[i]), "bad argument #" .. i .. " to format: number expected, got " .. type(args[i]))
    ret = ret .. string.char(args[i])
  end
  return ret
end

local function generateLoadString(str, start)
  local ret = ""
  local cur = start
  for byte in str:gmatch(".") do
    byte = byte:byte()
    ret = ret .. format(cpu.ld, 1, byte) .. format(cpu.st, 1, cur)
    cur = cur + 1
  end
  return ret
end

local function truncateComments(line)
  local ret = ""
  for char in line:gmatch(".") do
    if char == ";" then
      break
    else
      ret = ret .. char
    end
  end
  return ret
end

local function truncateWhitespace(line)
  local w = {}
  for word in line:gmatch("[^ ]+") do
    table.insert(w, word)
  end
  return table.concat(w, " ")
end

local function split(line)
  local words = {}
  local inS = false
  local S = ""
  for word in line:gmatch("[^ ]+") do
    if word:sub(1, 1) == '"' then
      inS = true
      word = word:sub(2)
    end
    if word:sub(-1) == '"' then
      S = S .. word:sub(-1)
      inS = false
      table.insert(words, S)
    end
    if inS then
      S = S .. " " .. word
    else
      S = word
      table.insert(words, S)
    end
  end
  return words
end

local codes = {
  blank = 0,
  routine = 1,
  endroutine = 2
}

local routines = {}

local function parseLine(line)
  print(line)
  local line = truncateWhitespace(truncateComments(line))
  if line == "" then
    return nil, codes.blank
  end
  local str = split(line)
  local op, reg, arg = str[1], str[2] or "", str[3] or ""
  if cpu[op] then
    if (not tonumber(reg) or not tonumber(arg)) and op ~= "hlt" and op ~= "nop" then
      error("invalid instruction data " .. reg .. " or " .. arg .. " to CPU instruction " .. op:upper())
    end
    return format(cpu[op], tonumber(reg), tonumber(arg))
  elseif compiler[op] then
    --[[if then
      error("invalid instruction data " .. reg .. " or " .. arg .. " to compiler instruction " .. op:upper())
    end]]
    if op == "lds" then
      return generateLoadString(arg, tonumber(reg))
    elseif op == "rt" then
      return nil, codes.routine, reg
    elseif op == "end" then
      return nil, codes.endroutine
    end
  elseif routines[op] then
    return routines[op]
  else
    error("illegal instruction: " .. op:upper())
  end
end

local function parse(fdata)
  local data = ""
  local in_rt = false
  local rt = ""
  local rt_name = ""
  for line in fdata:gmatch("[^\n]+") do
    local ret, code, name = parseLine(line)
    if ret then
      --print("note: parsed instruction")
      if in_rt then
        rt = rt .. ret
      else
        data = data .. ret
      end
    elseif code == codes.blank then
      print("note: encountered blank line")
    elseif code == codes.routine then
      print("starting routine " .. name)
      rt_name = name
    elseif code == codes.endroutine then
      print("ending routine " .. rt_name)
      in_rt = false
      routines[rt_name] = rt
    end
  end
  return data
end

local handle, err = io.open(shell.resolve(args[1]))
if not handle then
  error(err)
end

local filedata = handle:read("a")
handle:close()

local data = parse(filedata)

local handle, err = io.open(shell.resolve(args[2]), "wb")
if not handle and err then
  error(err)
end
handle:write(data)
handle:close()
