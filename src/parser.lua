local lpeg = require("lpeg")
local definitions  = require("src.definitions")
local def_ = definitions.def_
local func_ = definitions.func_

local S,R,P,V = lpeg.S, lpeg.R, lpeg.P, lpeg.V
local C, Cf, Cg, Ct = lpeg.C, lpeg.Cf, lpeg.Cg, lpeg.Ct

local expression = P({
    "expression",
		expression = V("logic_expr") + V("math_expr"),
		math_expr = Cf(V("multdiv_expr") * ((def_.token.asOp * V("multdiv_expr")) ^ 1), func_.concatConsecutiveOps) +
								 V("multdiv_expr"),
		multdiv_expr = Cf(V("factor") * ((def_.token.mdOp * V("factor")) ^ 1), func_.concatConsecutiveOps) +
										V("factor"),
		factor = (def_.token.lParen * V("math_expr") * def_.token.rParen) +
						 (def_.token.unaryOp * V("factor")) / func_.addUnaryLabel +
						 def_.token.number +
						 def_.token.label,
    logic_expr = Cf(V("fact") * ((def_.token.binaryTritOp * V("fact")) ^ 1), func_.concatConsecutiveOps) +
								 --(V("math_expr") * def_.token.comparisonTritOp * V("math_expr")) / func_.reorderOp +
								 V("fact"),
		fact = (def_.token.lParen * V("logic_expr") * def_.token.rParen) +
					 (V("math_expr") * def_.token.comparisonTritOp * V("math_expr") / func_.reorderOp) +
					 (def_.token.unaryTritOp * V("fact")) / func_.addUnaryLabel +
					 def_.token.fact +
					 def_.token.label,
})

local statement = P({
    "statement",
    statement = (def_.token.label * def_.token.assignOp * expression) / func_.reorderOp
})

local line = P({
    "line",
    line = V("logicLine") + --[[V("mixedLine") +]] V("proseLine") + def_.chunk.endSpace,
    logicLine = def_.token.lPrefix * statement * def_.chunk.endSpace,
    proseLine = def_.chunk.phrase,
    mixedLine = P(-1),
})

local parser = Ct(P({
    "input",
    input = (line * def_.chunk.endSpace^0)^1 * -1
}))

-- Testing

local test
--test = lpeg.match(parser, [[
--This is a test line featuring a number 123!
--This is another line featuring punctuation marks (so did the previous one, but ignore that).
--This is a third test line featuring an emoji using escaped symbols!    \\(\^o\^)\/
--]])

--[[
for i,v in ipairs(test) do
    print(v)
end
]]

test = lpeg.match(parser, [[
abc
def
~ bool = !(3 < 5) && (2 + 45 < 3 || [+> unknown)
]])
--~ abc = 3 + 3 * -(-45 + c) \ 5
--~ def = true && false
--~ ab = 50.3 + 3 * 1 + 2 \\ 4
--test = lpeg.match(expression, "(1 * 2 + 1) * (3 + 4) + (5 + 6) \\ (1 \\ 2)")
print(func_.deepPrint(test))

--local testFactor = chunk.number * chunk.mdOp * chunk.number + chunk.number
--print(testFactor:match("5 * 5"))