-- core.lua -- implements kscope language runtime

if decoda_output then
  local strict  = require("strict")
end

local function printd(d)
  print(d)
  return d
end

local function putchard(d)
  io.write(string.char(d))
  return d
end

local function toboolean(v)
  if type(v) == "boolean" then
    return v
  end
  return tonumber(v) ~= 0
end

return {
  printd = printd,
  putchard = putchard,
  __toboolean__ = toboolean
}
