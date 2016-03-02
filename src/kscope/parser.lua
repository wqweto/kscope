-- parser.lua - LPeg based kscope parser

local lpeg      = require("lpeg")
local re        = require("kscope.re")
local tree      = require("kscope.tree")
if decoda_output then
  local strict  = require("strict")
end

local P, Cmt, Carg, Cc = lpeg.P, lpeg.Cmt, lpeg.Carg, lpeg.Cc

local patt = [=[
    toplevel    <- (
        semi* {| (s <stmt> semi*)* |} s (!. / <panic>)
    ) -> module

--    newline     <- %nl %1 -> incrline
--    comment     <- '#' (!%nl .)*
    s           <- (('#' (!%nl .)*) / (%nl %Carg'1' -> incrline) / !%nl %s)*
    semi        <- s ';'
    ns          <- ![_%w] s
    number      <- ((%d+ '.'? %d*) / (%d* '.' %d+)) -> number
    word        <- [_%a] [_%w]*
    keyword     <- ("def" / "extern" / "if" / "then" / "unary" /
                    "for" / "binary" / "in" / "else" / "var") ![_%w]
    ident       <- ((%Carg'1' -> curline) (!<keyword> { <word> }) -> identifier) -> setline
    unop        <- { [-+!] }
    binop       <- { [-+*/<>=:|&] [=]? }
    var_decl    <- <assign> / <ident>
    var_list    <- <var_decl> (s (',' s)? <var_decl>)*
    expr_list   <- <expr> (s (',' s)? <expr>)*
    arg_list    <- <ident> (s (',' s)? <ident>)*
    panic       <- %Carg'1' => syntax_error

    numberexpr  <- (
        (%Carg'1' -> curline) (
            <number>
        ) -> numberexpr
    ) -> setline

    identifierexpr <- (
        (%Carg'1' -> curline) (
            <ident> s '(' s {| <expr_list>? |} s %expect')'
        ) -> invokeexpr
    ) -> setline / <ident>

    parenexpr   <- '(' s (<expr> / <panic>) s %expect')'

    ifexpr      <- (
        "if" ns <expr>
            s %expect"then" ns (<expr> / <panic>)
            (s "else" ns (<expr> / <panic>))?
    ) -> ifexpr

    assign      <- (
        <ident> s '=' s (<expr> / <panic>)
    ) -> assign

    forexpr     <- (
        "for" ns (<assign> / <panic>)
            s %expect',' s (<expr> / <panic>)
            (s ',' s (<expr> / <panic>))?
            s %expect"in" ns (<expr> / <panic>)
    ) -> forexpr

    varexpr     <- (
        "var" ns {| (<var_list> / <panic>) |}
            s %expect"in" ns (<expr> / <panic>)
    ) -> varexpr

    primary     <- <numberexpr> / <identifierexpr> / <parenexpr> / <ifexpr> / <forexpr> / <varexpr>

    unary       <- (
        <unop> s <unary>
    ) -> unary / <primary>

    expr        <- (
        (%Carg'1' -> curline) (
            {| <unary> (s <binop> s <unary>)* |}
        ) -> foldexpr
    ) -> setline

    prototype   <- (
        (%Carg'1' -> curline) (
            (   (<ident> s '(')
                / ("binary" ns {| {:binop: (<binop> / <panic>) :} s {:prec: <number>? :} |} s %expect'(')
                / ("unary" ns {| {:unop: (<unop> / <panic>) :} |} s %expect'(')
            )
            s {| <arg_list> |} s %expect')'
        ) -> prototype
    ) -> setline

    definition  <- (
        "def" ns <prototype> s <expr>
    ) -> definition

    extern      <- (
        "extern" ns <prototype>
    ) -> extern

    stmt        <- (
        (%Carg'1' -> curline) (<definition> / <extern> / <expr>)
    ) -> setline

]=]

local function incrline(state)
  state.line = state.line + 1
end

local function curline(state)
  return state.line
end

local function setline(line, node)
  if type(node) == "table" then
    node.line = line
  end
  return node
end

local function foldexpr(expr)
  if not expr[2] then
    return expr[1]
  end
  return tree.FoldExpr.new(expr)
end

local function prototype(id, params)
  if id.unop then
    return tree.UnProto.new(id.unop, params)
  end
  if id.binop then
    return tree.BinProto.new(id.binop, id.prec ~= "" and id.prec or nul, params)
  end
  return tree.FuncProto.new(id, params)
end

local function syntax_error(src, pos, state, expect)
  -- figure out line and column of pos in src
  local line, col = 1, 0
  while true do
    local ofs = src:find("\n", col)
    if ofs and ofs < pos then
      col = ofs + 1
      line = line + 1
    else
      break
    end
  end
  col = pos - col + 1
  -- construct error
  local tok = src:match('^%s*([_%w]+)', pos) or src:match('^%s*(%S[^%w%s]*)', pos) or src:sub(pos, pos)
  if not state.err then
    local err = (#src <= pos and "Unexpected end of input" 
        or expect and "Syntax error: expecting '"..expect.."'"
        or "Syntax error near '"..tok.."'")
    state.err = { tostring(state.name or "line")..'('..tostring(line).."): "..err.." at position "..tostring(col) }
  else
    state.err[#state.err + 1] = "    while compiling '"..tok.."' at line "..tostring(line)
  end
end

local function expect(m)
  return P(m) + Cmt(Carg(1) * Cc(m), syntax_error)
end

local defs = {
  incrline = incrline,
  curline = curline,
  setline = setline, 
  number = tonumber,
  numberexpr = tree.Literal.new,
  identifier = tree.Identifier.new,
  invokeexpr = tree.InvokeExpr.new,
  ifexpr = tree.IfExpr.new,
  forexpr = tree.ForExpr.new,
  assign = tree.Assign.new,
  varexpr = tree.VarExpr.new,
  unary = tree.UnExpr.new,
  foldexpr = foldexpr,
  prototype = prototype,
  definition = tree.DefStmt.new,
  extern = tree.ExternStmt.new,
  module = tree.ModuleStmt.new,
  expect = expect,
  syntax_error = syntax_error,
}

local grammar
local function parse(src, name, line)
  if not grammar then
    grammar = re.compile(patt, defs) -- , re.trace)
  end
  local state = { 
    name = name,
    line = line or 1 
  }
  return grammar:match(src, nil, state), state.err and table.concat(state.err, "\n")
end

return parse
