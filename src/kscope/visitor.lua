-- visitor.lua -- base impl for AST traversal

if decoda_output then
  local strict  = require("strict")
end

local Visitor = { } do
  Visitor.__index = Visitor

  function Visitor:visitNode(node) return node end
  function Visitor:visitNodeList(node) return node end
  function Visitor:visitExpression(node) return self:visitNode(node) end
  function Visitor:visitStatement(node) return self:visitNode(node) end
  function Visitor:visitIdentifier(node) return self:visitNode(node) end
  function Visitor:visitLiteral(node) return self:visitNode(node) end
  -- note: these are delegating to `visitExpression`
  function Visitor:visitInvokeExpr(node) return self:visitExpression(node) end
  function Visitor:visitIfExpr(node) return self:visitExpression(node) end
  function Visitor:visitAssign(node) return self:visitExpression(node) end
  function Visitor:visitForExpr(node) return self:visitExpression(node) end
  function Visitor:visitVarExpr(node) return self:visitExpression(node) end
  function Visitor:visitUnExpr(node) return self:visitExpression(node) end
  function Visitor:visitFoldExpr(node) return self:visitExpression(node) end
  function Visitor:visitUnProto(node) return self:visitExpression(node) end
  function Visitor:visitBinProto(node) return self:visitExpression(node) end
  function Visitor:visitFuncProto(node) return self:visitExpression(node) end
  -- note: these are delegating to `visitStatement`
  function Visitor:visitDefStmt(node) return self:visitStatement(node) end
  function Visitor:visitExternStmt(node) return self:visitStatement(node) end
  function Visitor:visitModuleStmt(node) return self:visitStatement(node) end
end

local Dumper = { } do
  Dumper.__index = setmetatable(Dumper, Visitor)
    
  function Dumper.new()
    return setmetatable({
        buffer = { };
        level  = 0;
        line   = 0;
    }, Dumper)
  end
    
  function Dumper.dump(node)
    if node ~= nil then
        local dumper = Dumper.new()
        node:accept(dumper)
        return table.concat(dumper.buffer, "\n")
    end
  end
    
  function Dumper:set_level(level)
    self.level = level
  end

  function Dumper:writeln(frag)
    self.buffer[#self.buffer + 1] = (self.pending or string.sub(" " .. tostring(self.line) .. " ", -3) .. string.rep("  ", self.level)) .. frag
    self.pending = nil
  end
    
  function Dumper:write(frag)
    self.pending = (self.pending or string.sub(" " .. tostring(self.line) .. " ", -3) .. string.rep("  ", self.level)) .. frag
  end

  function Dumper:visitNode(node)
    if node.line then
        self.line = node.line
    end
    self:writeln("`" .. node.tag .. "{")
    self:set_level(self.level + 1)
    local hasvalue = false
    for _, key in ipairs(node.children) do
        local value = node[key]
        if value ~= nil then
            if hasvalue then
                self.buffer[#self.buffer] = self.buffer[#self.buffer] .. ','        
            end
            self:write(key .. " = ")
            if type(value) == "table" and value.accept then
                value:accept(self)
            else
                self:writeln(string.format("%q", value))
            end
            hasvalue = true
        end
    end
    self:set_level(self.level - 1)
    self:writeln("}")
  end

  function Dumper:visitNodeList(list)
    self:writeln("[")
    self:set_level(self.level + 1)
    local hasvalue = false
    for i=1, #list do
        local value = list[i]
        if value ~= nil then
            if hasvalue then
                self.buffer[#self.buffer] = self.buffer[#self.buffer] .. ','        
            end
            if value.accept then
                value:accept(self)
            else
                self:writeln(string.format("%q", value))
            end
            hasvalue = true
        end
    end
    self:set_level(self.level - 1)
    self:writeln("]")
  end

  function Dumper:visitIdentifier(node)
    if node.line then
        self.line = node.line
    end
    self:writeln(string.format("%q", node.name))
    if node.type then
        node.type:accept(self)
    end
  end

  function Dumper:visitLiteral(node)
    if node.line then
        self.line = node.line
    end
    if type(node.value) == "string" then
        self:writeln(string.format("%q", node.value))
    else
        self:writeln(node.value)
    end
  end
end

return {
  Visitor = Visitor,
  Dumper = Dumper,
}
