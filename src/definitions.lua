local definitions = {}
definitions.def_ = {}
definitions.func_ = {}

local def_ = definitions.def_
local func_ = definitions.func_

local lpeg = require("lpeg")

-- utility functions
func_.concat = function(acc, newValue) return acc..newValue end
func_.addLabel = function(labelName, ...) return {labelName, ...} end
func_.addUnaryLabel = function(op, value)
	local result = {}
	if op == "-" then
		result = {"minus", value, unary = true}
	elseif  op == "#" then
		result = {"length", value, unary = true}
	elseif op == "!" then
		result = {"not", value, unary = true}
	elseif op == "[+>" then
		result = {"glass_full", value, unary = true}
	elseif op == "[->" then
		result = {"glass_empty", value, unary = true}
	end
	print(func_.deepPrint(result))
	return result
end
func_.flatten_or_addLabel = function(name)
    return function (table_)
        if #table_ == 1 then
            return table_[1]
        end
        table.insert(table_, 1, name)
        return table_
    end
end
func_.reorderOp = function(left, op, right) return {op, left, right} end
func_.concatConsecutiveOps = function(left, right)
	local result
	print("left="..func_.deepPrint(left).."\nright="..func_.deepPrint(right))
	if type(left) ~= "table" then
		result = {right, left}
	elseif left.unary then
		left.unary = nil
		result = {right, left}
	else
		if #left == 2 then
			if type(right) == "table" and right.unary then
				right.unary  = nil
			end
			result = {left[1], left[2], right}
		else
			result = {right, left}
		end
	end
	return result
end
func_.deepPrint = function(e, depth)
	local depth = depth or 0
	local str = ""
	local prefix = ""
	for i=1,depth do
			prefix=prefix.."\t"
	end
	-- if e is a table, we should iterate over its elements
	if type(e) == "table" then
			str = str.."{\t"
			for k,v in pairs(e) do -- for every element in the table
					-- recursively repeat the same procedure
					str=str.."\n"..prefix.."\t["..tostring(k).."] = "..func_.deepPrint(v, depth+1)
			end
			str = str.."  }".."\n"..prefix
	else -- if not, we can just print it
			str = str..tostring(e)
	end
	return str
end



-- terminals
def_.char = {}
local char = def_.char
char.letter = lpeg.R("az","AZ")
char.punct = lpeg.S(".?!,;:-()\'\"")
char.space = lpeg.S(" \t")
char.digit = lpeg.R("09")
char.symbol = lpeg.S("*_=\\/$<>[]+%&@#^`~|")
char.newline = lpeg.S("\r\n")^1
char.allWhitespace = lpeg.S(" \t\r\n")
char.quotationMark= lpeg.S("\"")

char.tilde_ = lpeg.P("~")
char.escapedSymbol = lpeg.S("\\") * lpeg.C(char.symbol)

char.lParen = lpeg.P("(")
char.rParen = lpeg.P(")")

-- operators
def_.op = {}
local op = def_.op
op.minus = lpeg.P("-")
op.floor = lpeg.P("_")
op.length = lpeg.P("#")
op.multDiv  = lpeg.S("*\\")
op.addSub = lpeg.S("+-")
op.assign = lpeg.P("=")

op.not_ = lpeg.P("!")
op.andOr = lpeg.P("&&") + lpeg.P("||")
-- glass half-full vs glass half-empty
-- [+> <trit> => true if true or unclear; false otherwise
-- [-> <trit> => true if true; false otherwise
op.glass = lpeg.P("[+>") + lpeg.P("[->")
-- true if both inputs are true; false if both inputs are false,
-- unclear otherwise
op.consensus = lpeg.P("<&>")
-- only unclear if both inputs are either unclear or conflict;
-- pick any other option otherwise
op.assume = lpeg.P("<|>")
op.ltGt = lpeg.S("<>")
op.lteGte = lpeg.P("<=") + lpeg.P(">=")
op.ne = lpeg.P("~=")
op.eq = lpeg.P("==")
op.concat = lpeg.P("..")

def_.chunk = {}
local chunk = def_.chunk
-- prose chunks
chunk.word = ((char.letter + char.punct + char.digit) ^1) / "%0" + (char.escapedSymbol / "%1") ^1
chunk.whitespace = lpeg.C(char.space ^0)
chunk.lSpace = char.space ^0
chunk.endSpace = char.space ^0 * char.newline
chunk.phrase = lpeg.Cf((chunk.whitespace * chunk.word) ^1, func_.concat)

def_.literal = {}
local literal = def_.literal
literal.true_ = lpeg.P("true")
literal.false_ = lpeg.P("false")
literal.unclear_ = lpeg.P("unclear")
literal.fact = lpeg.C(literal.true_ + literal.false_ + literal.unclear_)

literal.integer = (char.digit ^1)
literal.float = (char.digit ^0 * lpeg.S(".") * char.digit ^1)
literal.number = ((literal.float + literal.integer) / tonumber)

def_.token = {}
-- logical tokens
local token = def_.token
token.local_ = lpeg.P("local")
token.label = chunk.lSpace * lpeg.C((char.letter + lpeg.S("_")) ^1)
token.lPrefix = chunk.lSpace * char.tilde_

token.comparisonTritOp = chunk.lSpace + lpeg.C(op.lteGte + op.ltGt + op.ne + op.eq)
token.binaryTritOp = chunk.lSpace + lpeg.C(op.andOr + op.consensus + op.assume)
token.unaryTritOp = chunk.lSpace * lpeg.C(op.glass + op.not_)
token.mdOp = chunk.lSpace * lpeg.C(op.multDiv)
token.asOp = chunk.lSpace * lpeg.C(op.addSub)
token.unaryOp = chunk.lSpace * lpeg.C(op.length + op.minus + op.floor)
token.assignOp = chunk.lSpace * lpeg.C(op.assign)
token.lParen = chunk.lSpace * char.lParen
token.rParen = chunk.lSpace * char.rParen

token.unaryValue = (token.unaryOp * (literal.number)) / func_.addUnaryLabel
token.number = chunk.lSpace * literal.number
token.unaryFact = (token.unaryTritOp * (literal.fact)) / func_.addUnaryLabel
token.fact = chunk.lSpace * literal.fact

return definitions