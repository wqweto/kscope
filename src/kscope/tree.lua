-- tree.lua - kscope AST nodes

if decoda_output then
  local strict  = require("strict")
end

local Node = { tag = "Node" } do
  Node.__index = Node
  Node.children = { }

  -- note: only Node implements `accept` method for Visitor pattern
  function Node:accept(visitor)
    local fn = visitor["visit"..self.tag]
    if fn then
      return fn(visitor, self)
    end
  end
end

local NodeList = { tag = "NodeList" } do
  NodeList.__index = setmetatable(NodeList, Node)

  function NodeList.new(nodes)
    return setmetatable(nodes, NodeList)
  end
end

local Identifier = { tag = "Identifier" } do
  Identifier.__index = setmetatable(Identifier, Node)
  Identifier.children = { "name" }

  function Identifier.new(name)
    return setmetatable({ name = name }, Identifier)
  end
end

local Literal = { tag = "Literal" } do
  Literal.__index = setmetatable(Literal, Node)
  Literal.children = { "value" }

  function Literal.new(value)
    return setmetatable({ value = value }, Literal)
  end
end

local InvokeExpr = { tag = "InvokeExpr" } do
  InvokeExpr.__index = setmetatable(InvokeExpr, Node)
  InvokeExpr.children = { "func", "args" }

  function InvokeExpr.new(func, args)
    return setmetatable({ func = func, args = NodeList.new(args) }, InvokeExpr)
  end
end

local IfExpr = { tag = "IfExpr" } do
  IfExpr.__index = setmetatable(IfExpr, Node)
  IfExpr.children = { "test", "cons", "altn" }

  function IfExpr.new(test, cons, altn)
    return setmetatable({ test = test, cons = cons, altn = altn }, IfExpr)
  end
end

local Assign = { tag = "Assign" } do
  Assign.__index = setmetatable(Assign, Node)
  Assign.children = { "lhs", "rhs" }

  function Assign.new(lhs, rhs)
    return setmetatable({ lhs = lhs, rhs = rhs }, Assign)
  end
end

local ForExpr = { tag = "ForExpr" } do
  ForExpr.__index = setmetatable(ForExpr, Node)
  ForExpr.children = { "init", "test", "step", "body" }

  function ForExpr.new(init, test, step, body)
    if not body then
      body, step = step, nil
    end
    return setmetatable({ init = init, test = test, step = step, body = body }, ForExpr)
  end
end

local VarExpr = { tag = "VarExpr" } do
  VarExpr.__index = setmetatable(VarExpr, Node)
  VarExpr.children = { "init", "body" }

  function VarExpr.new(init, body)
    return setmetatable({ init = NodeList.new(init), body = body }, VarExpr)
  end
end

local UnExpr = { tag = "UnExpr" } do
  UnExpr.__index = setmetatable(UnExpr, Node)
  UnExpr.children = { "op", "expr" }

  function UnExpr.new(op, expr)
    return setmetatable({ op = op, expr = expr }, UnExpr)
  end
end

local FoldExpr = { tag = "FoldExpr" } do
  FoldExpr.__index = setmetatable(FoldExpr, Node)
  FoldExpr.children = { "fold" }

  function FoldExpr.new(fold)
    return setmetatable({ fold = NodeList.new(fold) }, FoldExpr)
  end
end

local UnProto = { tag = "UnProto" } do
  UnProto.__index = setmetatable(UnProto, Node)
  UnProto.children = { "op", "params" }

  function UnProto.new(op, params)
    return setmetatable({ op = op, params = NodeList.new({ params[1] }) }, UnProto)
  end
end

local BinProto = { tag = "BinProto" } do
  BinProto.__index = setmetatable(BinProto, Node)
  BinProto.children = { "op", "prec", "params" }

  function BinProto.new(op, prec, params)
    return setmetatable({ op = op, prec = prec, params = NodeList.new(params) }, BinProto)
  end
end

local FuncProto = { tag = "FuncProto" } do
  FuncProto.__index = setmetatable(FuncProto, Node)
  FuncProto.children = { "name", "params" }

  function FuncProto.new(name, params)
    return setmetatable({ name = name, params = NodeList.new(params) }, FuncProto)
  end
end

local DefStmt = { tag = "DefStmt" } do
  DefStmt.__index = setmetatable(DefStmt, Node)
  DefStmt.children = { "proto", "body" }

  function DefStmt.new(proto, body)
    return setmetatable({ proto = proto, body = body }, DefStmt)
  end
end

local ExternStmt = { tag = "ExternStmt" } do
  ExternStmt.__index = setmetatable(ExternStmt, Node)
  ExternStmt.children = { "proto" }

  function ExternStmt.new(proto)
    return setmetatable({ proto = proto }, ExternStmt)
  end
end

local ModuleStmt = { tag = "ModuleStmt" } do
  ModuleStmt.__index = setmetatable(ModuleStmt, Node)
  ModuleStmt.children = { "list" }

  function ModuleStmt.new(list)
    return setmetatable({ list = NodeList.new(list) }, ModuleStmt)
  end
end

return {
  Node = Node,
  Identifier = Identifier,
  Literal = Literal,
  InvokeExpr = InvokeExpr,
  IfExpr = IfExpr,
  Assign = Assign,
  ForExpr = ForExpr,
  VarExpr = VarExpr,
  UnExpr = UnExpr,
  FoldExpr = FoldExpr,
  UnProto = UnProto,
  BinProto = BinProto,
  FuncProto = FuncProto,
  DefStmt = DefStmt,
  ExternStmt = ExternStmt,
  ModuleStmt = ModuleStmt
}
