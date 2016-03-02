-- emitter.lua - kscope AST to Lua source code emitter

local Visitor   = require("kscope.visitor").Visitor
if decoda_output then
  local strict  = require("strict")
end

local function tableappend(dst, src)
  if type(src) ~= "table" then
    src = { }
  end
  for _, v in ipairs(src) do
    dst[#dst + 1] = v
  end
  return dst
end

local function ropetostring(t, level, firstlevel)
  if not t then
    return ""
  elseif type(t) == "table"  then
    local r = { }
    if t.sep == "\n" then
      local prefix = ("  "):rep(level or 0)
      local firstprefix = ("  "):rep(firstlevel or level or 0)
      for i, v in ipairs(t) do
        r[#r + 1] = (i == 1 and firstprefix or prefix) .. ropetostring(v, (level or 0) + 1, 1)
      end
    else
      for i, v in ipairs(t) do
        r[#r + 1] = ropetostring(v, (level or 0) + 1, 0)
      end
    end
    return table.concat(r, t.sep or "")
  else
    return tostring(t)
  end
end

local function tohex(str)
  local t = { }
  for i = 1, #str do
    t[#t + 1] = string.format('%02X', str:byte(i))
  end
  return table.concat(t)
end

local Scope = { } do
  Scope.__index = Scope

  function Scope.new(outer)
    return setmetatable({
        entries = { },
        hoist = { },
        level = 0,
        outer = outer
    }, Scope)
  end

  function Scope:define(name, value)
    value.name = name
    self.entries[name] = value
  end

  function Scope:lookup(name)
    local ret = self.entries[name]
    if ret then
      return ret
    elseif self.outer then
      return self.outer:lookup(name)
    end
  end
end

local Emitter = { } do
  Emitter.__index = setmetatable(Emitter, Visitor)
    
  function Emitter.new(name)
    return setmetatable({
        scope = Scope.new(),
        line = 1,
        name = name or "(eval)"
    }, Emitter)
  end

  function Emitter.emit(node, name)
    if node ~= nil then
      local emitter = Emitter.new(name)
      emitter:enter("global")
      emitter:define("printd", { type = "extern", fname = "std.printd" })
      emitter:define("putchard", { type = "extern", fname = "std.putchard" })
      local ret, err
      _, ret, err = pcall(function() return emitter:visitNode(node) end)
      if not ret then
        return nil, err .. "\n    at line " .. emitter.line
      end
      local t = { "local std = require(\"kscope.core\")", "", sep = "\n" }
      return ropetostring(tableappend(emitter:leave(t), ret))
    end
  end

  function Emitter:enter(type)
    local level = self.scope.level or 0
    self.scope = Scope.new(self.scope)
    self.scope.type = type
    self.scope.level = level + (type == "function" and 1 or 0)
    return self.scope.block
  end

  function Emitter:leave(block)
    self:unhoist(block or { })
    self.scope = self.scope.outer
    return block
  end

  function Emitter:hoist(stmt)
    self.scope.hoist[#self.scope.hoist + 1] = stmt
  end

  function Emitter:unhoist(block)
    for i=#self.scope.hoist, 1, -1 do
      table.insert(block, 1, self.scope.hoist[i])
    end
    self.scope.hoist = { }
  end

  function Emitter:define(name, value)
    value = value or { line = self.line }
    self.scope:define(name, value)
  end

  function Emitter:lookup(name)
    return self.scope:lookup(name)
  end

  function Emitter:visitNode(node)
    if type(node) == "table" then
      if node.line then
        self.line = node.line
      end
      return assert(node:accept(self))
    else
      return tostring(node)
    end
  end

  function Emitter:visitNodeList(list)
    local t = { }
    if list then
      for _, v in ipairs(list) do
        t[#t + 1] = self:visitNode(v)
      end
    end
    return t
  end

  function Emitter:visitExpression(node)
    local t = self:visitNode(node)
    if type(t) ~= "table" or t.type ~= "stmt" then
      return t
    end
    return { "(function()", t, "end)()", sep = "\n" }
  end

  function Emitter:visitStatement(node)
    local t = self:visitNode(node)
    if type(t) == "table" and t.type == "stmt" then
      return t
    end
    return { "(function()", { { "return ", t }, sep = "\n" }, "end)()", type = "stmt", sep = "\n" }
  end

  function Emitter:visitIdentifier(node)
    local def = self:lookup(node.name)
    if not def then
      error("Identifier '" .. node.name .. "' not defined")
    end
    return def.fname or tostring(node.name)
  end

  function Emitter:visitLiteral(node)
    return tostring(node.value)
  end

  function Emitter:visitInvokeExpr(node)
    local t = { sep = "\n" }
    for i, v in ipairs(self:visitNodeList(node.args)) do
      t[#t + 1] = i > 1 and { ", " , v } or v
    end
    return { self:visitNode(node.func), "(", t, ")" }
  end

  function Emitter:visitIfExpr(node)
    local t = { { "if std.__toboolean__(", self:visitExpression(node.test), ") then" },
                  { "  return ", self:visitExpression(node.cons) }, sep = "\n" }
    if node.altn then
      t[#t + 1] = "else"
      t[#t + 1] = { "  return ", self:visitExpression(node.altn) }
    end
    t[#t + 1] = "end"
    return { "(function ()", t, "end)()", sep = "\n" }
  end

  function Emitter:visitAssign(node)
    return { self:visitNode(node.lhs), " = ", self:visitExpression(node.rhs), type = "stmt" }
  end

  local function declvar(v)
    if type(v) == "table" and v.type == "stmt" then
      table.insert(v, 1, "local ")
      return v
    else
      return { "local ", v }
    end
  end

  function Emitter:visitForExpr(node)
    assert(node.init.tag == "Assign")
    assert(node.init.lhs.tag == "Identifier")
    local iter = node.init.lhs.name
    self:enter("for")
    self:define(iter, { type = "var" })
    local init = self:visitNode(node.init)
    local test = { "std.__toboolean__(", self:visitExpression(node.test), ")" }
    local body = self:visitStatement(node.body)
    local step = node.step and { "(", self:visitExpression(node.step), ")"} or "1"
    local t = {
      { declvar(init) },
      { "while ", test, " do" },
      { body, sep = "\n" },
      { { iter, " = ", iter, " + ", step }, sep = "\n" },
      "end" }
    t = tableappend(self:leave({ sep = "\n" }), t)
    return { "do", t, "end", type = "stmt", sep = "\n" }
  end

  function Emitter:visitVarExpr(node)
    self:enter("var")
    for _, v in ipairs(node.init) do
      assert(v.tag == "Identifier" or v.tag == "Assign")
      if v.name then
        self:define(v.name, { type = "var" })
      elseif v.lhs.name then
        assert(v.lhs.tag == "Identifier")
        self:define(v.lhs.name, { type = "var" })
      end
    end
    local t = { }
    for _, v in ipairs(self:visitNodeList(node.init)) do
      t[#t + 1] = declvar(v)
    end
    t[#t + 1] = self:visitStatement(node.body)
    t = tableappend(self:leave({ sep = "\n" }), t)
    return { "do", t, "end", type = "stmt", sep = "\n" }
  end

  local stdop = {
    ['=']  = { prec = 2, assign = true },
    ['<']  = { prec = 10, infix = '<' },
    ['>']  = { prec = 10, infix = '>' },
    ['<='] = { prec = 10, infix = '<=' },
    ['>='] = { prec = 10, infix = '>=' },
    ['=='] = { prec = 10, infix = '==' },
    ['!='] = { prec = 10, infix = '~=' },
    ['+']  = { prec = 20, infix = '+' },
    ['-']  = { prec = 20, infix = '-' },
    ['*']  = { prec = 40, infix = '*' },
    ['/']  = { prec = 40, infix = '/' },
    ['u-'] = { prefix = '-' },
    ['u+'] = { prefix = '+' },
  }

  function Emitter:visitUnExpr(node)
    local op = self:lookup(node.op) or stdop['u' .. node.op]
    if op.type and op.type ~= "unop" then
      error("Operator '" .. node.op .. "' not an unary op")
    end
    if op.prefix then
      return { op.prefix, self:visitExpression(node.expr) }
    end
    return { op.fname, "(", self:visitExpression(node.expr), ")" }
  end

  local function foldexpr(self, list, i, max)
    local left = self:visitExpression(list[i])
    while i < #list do
      local op = self:lookup(list[i + 1]) or stdop[list[i + 1]] or { prec = -1 }
      if op.type and op.type ~= "binop" then
        error("Operator '" .. list[i + 1] .. "' not a binary op")
      end
      if op.prec <= max then
        return left, i
      end
      local right
      right, i = foldexpr(self, list, i + 2, op.prec)
      if op.assign then
        left = {
          "(function(__v__)",
          { { left, " = __v__" },
            "return __v__", sep = "\n" },
          { "end)(", right, ")" }, sep = "\n" }
      elseif op.infix then
        if type(left) == "table" then
          table.insert(left, 1, "(")
          left[#left + 1] = ")"
        end
        if type(right) == "table" then
          table.insert(right, 1, "(")
          right[#right + 1] = ")"
        end
        left = { left, " " .. op.infix .. " ", right }
      else
        left = { op.fname, "(", left, ", ", right, ")" }
      end
    end
    return left, i
  end

  function Emitter:visitFoldExpr(node)
    return foldexpr(self, node.fold, 1, 0)
  end

  local function declfunc(self, name, params)
    self:hoist({ "local ", name })
    local t = { name, " = function(" }
    for i, v in ipairs(params) do
      assert(v.tag == "Identifier")
      local param = v.name
      self:define(param, { type = "param" })
      t[#t + 1] = i > 1 and { ", " , param } or param
    end
    t[#t + 1] = ")"
    return t
  end

  function Emitter:visitUnProto(node)
    local name = "__un__" .. tohex(node.op)
    self:define(node.op, { type = "unop", fname = name })
    return declfunc(self, name, node.params)
  end

  function Emitter:visitBinProto(node)
    local name = "__bin__" .. tohex(node.op)
    self:define(node.op, { type = "binop", fname = name, prec = node.prec })
    return declfunc(self, name, node.params)
  end

  function Emitter:visitFuncProto(node)
    assert(node.name.tag == "Identifier")
    local name = node.name.name
    self:define(name, { type = "func", numparams = #node.params })
    return declfunc(self, name, node.params)
  end

  function Emitter:visitDefStmt(node)
    local proto = self:visitNode(node.proto)
    self:enter("function")
    local body = self:visitExpression(node.body)
    return tableappend(self:leave({ type = "stmt", sep = "\n" }), 
      { proto, { { "return ", body }, sep = "\n" }, "end" })
  end

  function Emitter:visitExternStmt(node)
    local name = self:visitNode(node.name)
    self:define(name, { type = "extern", numparams = #node.params })
    return { }
  end

  function Emitter:visitModuleStmt(node)
    local t = { type = "stmt", sep = "\n" }
    self:enter("module")
    local list = { }
    for _, v in ipairs(node.list) do
      list[#list + 1] = self:visitStatement(v)
    end
    return tableappend(self:leave(t), list)
  end
end

return Emitter
