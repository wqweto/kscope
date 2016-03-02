-- main.lua - kscope compiler
--
-- sample usage:
--     c:> luajit.exe main.lua -d -l mandel.ks

local kparser   = require("kscope.parser")
local dump      = require("kscope.visitor").Dumper.dump
local emit      = require("kscope.emitter").emit
local bcsave    = require("jit.bcsave").start
if decoda_output then
  local strict  = require("strict")
end

local VERSION = "0.1.0"

local function readfile(name)
  local f = io.open(name, "rb")
  local ret = f:read("*all")
  f:close()
  return ret
end

local function writefile(name, content)
  local f = io.open(name, "wb")
  f:write(content)
  f:close()
end

local function locate(file, path)
  for _, v in ipairs(path) do
    local name = v .. file
    if os.rename(name, name) then
      return name
    end
  end
end

local map_hasfile = { i = true, od = true, ol = true, ob = true, o = true, n = true, a = true, ocore = true }
local map_arch = { x86 = "win32", x64 = "win64" }

local function parsearg(arg)
  local t = { }
  local i = 1
  while i <= #arg do
    if arg[i]:sub(1, 1) == "-" then
      local opt = arg[i]:sub(2)
      if map_hasfile[opt] then
        t[opt] = arg[i + 1]
        i = i + 1
      else
        t[opt] = true
      end
    elseif not t['i'] then
      t['i'] = arg[i]
    elseif not t['o'] then
      t['o'] = arg[i]
    end
    i = i + 1
  end
  return t
end

local function main(arg)
  local options = parsearg(arg)
  if not options['i'] then
    io.stderr:write(string.format([[
Kaleidoscope Toy Language to Lua Transpiler, version %s (%s)
Copyright (c) 2016 by wqweto@gmail.com (MIT License)

usage: kscope [options] input.ks

  -d          dump AST
  -l          Lua source code
  -a  ARCH    architecture (x86/x64)
  -od FILE    output AST
  -ol FILE    output Lua source
  -ob FILE    output LuaJIT bytecode
  -o  FILE    output executable
]], VERSION, jit.arch))
    --io.stderr:write(string.format("version: %s, %s\n\n", VERSION, jit.arch))
    os.exit(1)
  end

  local bcopt = { "-n", options['n'] or "main" }
  if options['a'] then
    bcopt[#bcopt + 1] = "-a"
    bcopt[#bcopt + 1] = options['a']
  end
  if options['ocore'] then
    bcopt[#bcopt + 1] = assert(loadstring(readfile(options['i'])))
    bcopt[#bcopt + 1] = options['ocore']
    bcsave(unpack(bcopt))
    os.exit(0)
  end
  
  -- parse AST
  local ast, err, src
  ast, err = kparser(readfile(options['i']))
  if not ast then
    io.stderr:write("kscope: " .. tostring(err) .. "\n")
    os.exit(2)
  end
  if options['od'] then
    writefile(options['od'], dump(ast))
  end
  if options['d'] then
    print(dump(ast))
  end

  -- emit Lua
  src, err = emit(ast)
  if not src then
    io.stderr:write("kscope: " .. tostring(err) .. "\n")
    os.exit(3)
  end
  if options['ol'] then
    writefile(options['ol'], src)
  end
  if options['l'] then
    print(src)
  end
  
  -- output obj/exe
  bcopt[#bcopt + 1] = assert(loadstring(src))
  if options['ob'] then
    bcopt[#bcopt + 1] = options['ob']
    bcsave(unpack(bcopt))
  elseif options['o'] then
    local link = locate("link.bat", { "lib\\", "..\\lib\\" })
    if not link then
      io.stderr:write("kscope: link.bat not found\n")
      os.exit(4)
    end
    local path, file, ext = options['o']:match("(.-)([^\\/]-)%.?([^%.\\/]*)$")
    bcopt[#bcopt + 1] = string.format("%s%s.o", path, file)
    bcsave(unpack(bcopt))
    local platform = map_arch[options['a'] or jit.arch]
    os.execute(string.format("%s %s %q %q", link, platform, bcopt[#bcopt], options['o']))
  else
    local result = bcopt[#bcopt]()
    print(string.format("Evaluated to %s", result))
  end
end

main(arg)
