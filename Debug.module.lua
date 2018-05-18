-- Standard RoStrap Debugging Functions
-- @author Validark

local DirectoryToString do
	--- Gets the string of the directory of an object, properly formatted
	-- string DirectoryToString(Object)
	-- @returns Objects location in proper Lua format
	-- @author Validark
	-- Corrects the built-in GetFullName function so that it returns properly formatted text.

	function DirectoryToString(Object)
		return (
			Object
				:GetFullName()
				:gsub("%.(%w*%s%w*)", "%[\"%1\"%]")
				:gsub("%.(%d+[%w%s]+)", "%[\"%1\"%]")
				:gsub("%.(%d+)", "%[%1%]")
			)
	end
end

local Stringify do
	-- Turns data into "TYPE_NAME NAME"

	function Stringify(Data)
		local DataType = typeof(Data)
		return DataType == "Instance" and Data.ClassName .. " " .. DirectoryToString(Data) or DataType .. " " .. tostring(Data)
	end
end

local GetErrorData, Warn, Error, Assert do
	-- Standard RoStrap Erroring system
	-- Prefixing errors with '!' makes Error expect the [error origin].Name as first parameter after Error string
	-- Past the initial Error string, subsequent arguments get unpacked in a string.format of the error string
	-- Arguments formmatted into the string get stringified (see above function)
	-- Assert falls back on Error
	-- Error blames the latest item on the traceback as the cause of the error
	-- Error makes it clear which Library and function are being misused
	-- @author Validark

	local Replacers = {
		["Index ?"] = "__index";
		["Newindex ?"] = "__newindex";
	}

	function GetErrorData(Err, ...)
		local t = {...}

		local Traceback = debug.traceback()
		local ErrorDepth = select(2, Traceback:gsub("\n", "")) - 2

	--	print(Traceback:gsub("([\r\n])[^\r\n]+upvalue Error[\r\n]", "%1", 1))

		local Prefix
		Err, Prefix = Err:gsub("^!", "", 1)
		local ModuleName = Prefix == 1 and table.remove(t, 1) or getfenv(ErrorDepth).script.Name
		local FunctionName

		for i = 1, #t do
			t[i] = Stringify(t[i]):gsub("table table", "table"):gsub("nil nil", "nil")
		end

		for x in Traceback:sub(1, -11):gmatch("%- [^\r\n]+[\r\n]") do
			FunctionName = x
		end

		FunctionName = FunctionName:sub(3, -2):gsub("^%l", string.upper, 1):gsub(" ([^\n\r]+)", " %1", 1)

		local i = 0
		for x in Err:gmatch("%%%l") do
			i = i + 1
			if x == "%q" then
				t[i] = t[i]:gsub(" (%S+)$", " \"%1\"", 1)
			end
		end

		return ("[%s] {%s} " .. Err:gsub("%%q", "%%s")):format(ModuleName, Replacers[FunctionName] or FunctionName, unpack(t)), ErrorDepth
	end

	function Warn(...)
		warn((GetErrorData(...)))
	end

	function Error(...)
		error(GetErrorData(...))
	end

	function Assert(Condition, ...)
		return Condition or error(GetErrorData(...))
	end
end

local AlphabeticalOrder do
	--- Iteration function that iterates over a dictionary in alphabetical order
	-- function AlphabeticalOrder(Dictionary)
	-- @param table Dictionary That which will be iterated over in alphabetical order
	-- A dictionary looks like this: {Apple = true, Noodles = 5, Soup = false}
	-- Not case-sensitive
	-- @author Validark

	local function Alphabetically(a, b)
		local typeA = type(a)
		local typeB = type(b)

		if typeA == typeB then
			if typeA == "number" then
				return a < b
			else
				return tostring(a):lower() < tostring(b):lower()
			end
		else
			return typeA < typeB
		end
	end

	function AlphabeticalOrder(Dictionary)
		local Count = 0
		local Order = {}

		for Key in next, Dictionary do
			Count = Count + 1
			Order[Count] = Key
		end

		table.sort(Order, Alphabetically)

		return function(Table, Previous)
			for i = 0, Count do
				if Order[i] == Previous then
					local Key = Order[i + 1]
					return Key, Table[Key]
				end
			end

			error(GetErrorData("invalid key to 'AlphabeticalOrder' " .. Previous))
		end, Dictionary, nil
	end
end

local UnionIteratorFunctions do
	-- Takes in functions ..., and returns a function which unions them, which can be called on a table
	-- Will iterate through a table, using the iterator functions passed in from left to right
	-- Will pass the CurrentIteratorFunction index in the stack as the last variable
	-- UnionIteratorFunctions(Get0, ipairs, AlphabeticalOrder)(Table)

	function UnionIteratorFunctions(...)
		local IteratorFunctions = {...}
		for i = 1, #IteratorFunctions do
			if type(IteratorFunctions[i]) ~= "function" then
				error(GetErrorData("Cannot union Iterator functions which aren't functions"))
			end
		end

		return function(Table)
			local Count = 0
			local Order = {[0] = {}}
			local KeysSeen = {}

			for i = 1, #IteratorFunctions do
				local Function, TableToIterateThrough, Next = IteratorFunctions[i](Table)

				if type(Function) ~= "function" or type(TableToIterateThrough) ~= "table" then
					error(GetErrorData("Iterator function " .. i .. " must return a stack of types as follows: Function, Table, Variant"))
				end

				while true do
					local Data = {Function(TableToIterateThrough, Next)}
					Next = Data[1]
					if Next == nil then break end
					if not KeysSeen[Next] then
						KeysSeen[Next] = true
						Count = Count + 1
						Data[#Data + 1] = i
						Order[Count] = Data
					end
				end
			end

			return function(_, Previous)
				for i = 0, Count do
					if Order[i][1] == Previous then
						local Data = Order[i + 1]
						if Data then
							return unpack(Data)
						else
							return nil
						end
					end
				end

				error(GetErrorData("invalid key to unioned iterator function: " .. Previous))
			end, Table, nil
		end
	end
end

local EachOrder do
	-- TODO: Write a function that takes multiple iterator functions and iterates through each passed in function
	-- EachOrder(Get0(Table), ipairs(Table), AlphabeticalOrder(Table))
end

local TableToString do
	--- Converts a table into a readable string
	-- string TableToString(Table, TableName, Multiline)
	-- @param table Table The Table to convert into a readable string
	-- @param string TableName Optional Name parameter that puts a "[TableName] = " at the beginning
	-- @returns a readable string version of the table

	local function Get0(t)
		return function(t2, val)
			if val == nil and t2[0] ~= nil then
				return 0, t2[0]
			end
		end, t, nil
	end

	local typeof = typeof or type
	local ArrayOrderThenAlphabetically = UnionIteratorFunctions(Get0, ipairs, AlphabeticalOrder)
	local ConvertTableIntoString

	local function Parse(Object, Multiline, Depth, EncounteredTables)
		local Type = typeof(Object)

		if Type == "table" then
			for TableName, Table in next, EncounteredTables do
				if Table == Object then
					if TableName == 1 then
						return "[self]"
					else
						return "[table " .. TableName .. "]"
					end
				end
			end
			return ConvertTableIntoString(Object, nil, Multiline, (Depth or 1) + 1, EncounteredTables)
		end

		return
			Type == "string" and "\"" .. Object .. "\"" or
			Type == "Instance" and "<" .. DirectoryToString(Object) .. ">" or
			(Type == "function" or Type == "userdata") and Type or
			tostring(Object)
	end

	function ConvertTableIntoString(Table, TableName, Multiline, Depth, EncounteredTables)
		if type(Table) == "table" then
			Depth = Depth or 1
			EncounteredTables = EncounteredTables or {}
			EncounteredTables[#EncounteredTables + 1] = Table

			local Output = {}
			local OutputCount = 0

			for Key, Value, Iter in ArrayOrderThenAlphabetically(Table) do
				if Iter < 3 then
					Output[OutputCount + 1] = (Iter == 1 and "[0] = " or "") .. Parse(Value, Multiline, Depth, EncounteredTables)
					Output[OutputCount + 2] = ", "
					OutputCount = OutputCount + 2
				else
					Output[OutputCount + 1] = Multiline and "\n" .. ("\t"):rep(Depth) or ""

					if type(Key) == "string" and not Key:find("^%d") then
						Output[OutputCount + 2] = Key
						OutputCount = OutputCount - 2
					else
						Output[OutputCount + 2] = "["
						Output[OutputCount + 3] = Parse(Key, Multiline, Depth, EncounteredTables)
						Output[OutputCount + 4] = "]"
					end

					Output[OutputCount + 5] = " = "
					Output[OutputCount + 6] = Parse(Value, Multiline, Depth, EncounteredTables)
					Output[OutputCount + 7] = Multiline and ";" or ", "
					OutputCount = OutputCount + 7
				end
			end

			if Multiline then
				Output[OutputCount + 1] = "\n" .. ("\t"):rep(Depth - 1)
			else
				Output[OutputCount] = nil
			end

			local Metatable = getmetatable(Table)

			Output = "{" .. table.concat(Output) .. "}"

			if Metatable then
				if type(Metatable) == "table" then
					Output = Output .. " <- " .. ConvertTableIntoString(Metatable, nil, Multiline, nil, EncounteredTables)
				else
					warn((GetErrorData((TableName or "Table") .. "'s metatable cannot be accessed. Got:\n" .. tostring(Metatable))))
				end
			end

			if TableName then
				Output = TableName .. " = " .. Output
			end

			return Output
		else
			error(GetErrorData("[Debug] TableToString needs a table to convert to a string! Got type" .. typeof(Table)))
		end
	end

	function TableToString(Table, TableName, Multiline)
		return ConvertTableIntoString(Table, TableName, Multiline)
	end
end

local EscapeString do
	--- Turns strings into Lua-readble format
	-- string Debug.EscapeString(String)
	-- @returns Objects location in proper Lua format
	-- @author Validark
	-- Useful for when you are doing string-intensive coding
	-- Those minus signs always get me when I'm not using this function!

	local EscapedCharacters = {"%", "^", "$", "(", ")", ".", "[", "]", "*", "+", "-", "?"}
	local Escapable = "([%" .. table.concat(EscapedCharacters, "%") .. "])"

	function EscapeString(String)
		return (
			String
				:gsub(Escapable, "%%%1")
				:gsub("([\"'])", "\\%1")
		)
	end
end

return {
	Warn = Warn;
	Error = Error;
	Assert = Assert;
	Stringify = Stringify;
	EscapeString = EscapeString;
	TableToString = TableToString;
	DirectoryToString = DirectoryToString;
	AlphabeticalOrder = AlphabeticalOrder;
	UnionIteratorFunctions = UnionIteratorFunctions;
}
