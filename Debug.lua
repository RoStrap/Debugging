-- Debugging Utilities
-- @author Validark

local Resources = require(game:GetService("ReplicatedStorage"):WaitForChild("Resources"))
local Table = Resources:LoadLibrary("Table")
local Typer = Resources:LoadLibrary("Typer")

local Debug = {}
local TAB = (" "):rep(4)

local Services = setmetatable({}, { -- Memoize GetService calls
	__index = function(self, i)
		local Success, Object = pcall(game.GetService, game, i)
		local Service = Success and Object
		self[i] = Service
		return Service
	end;
})

Debug.DirectoryToString = Typer.AssignSignature(Typer.Instance, function(Object)
	--- Gets the string of the directory of an object, properly formatted
	-- string DirectoryToString(Object)
	-- @returns Objects location in proper Lua format
	-- @author Validark
	-- My implementation of the built-in GetFullName function which returns properly formatted text.

	local FullName = {}
	local Count = 0

	while Object.Parent ~= game and Object.Parent ~= nil do
		local ObjectName = Object.Name:gsub("([\\\"])", "\\%1")

		if ObjectName:find("^[_%a][_%w]+$") then
			FullName[Count] = "." .. ObjectName
		else
			FullName[Count] = "[\"" .. ObjectName .. "\"]"
		end
		Count = Count - 1
		Object = Object.Parent
	end

	if Services[Object.ClassName] == Object then
		FullName[Count] = "game:GetService(\"" .. Object.ClassName .. "\")"
	else
		FullName[Count] = "." .. "[\"" .. Object.Name .. "\"]" -- A dot at the beginning indicates a rootless Object
	end

	return table.concat(FullName, "", Count, 0)
end)

local GetErrorData do
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

	local function Format(String, ...)
		return String:format(...)
	end

	local CommandBar = {Name = "Command bar"}

	function GetErrorData(Err, ...) -- Make sure if you don't intend to format arguments in, you do %%f instead of %f
		if type(Err) ~= "string" then
			error(GetErrorData("!The first parameter of error formatting must be a string", "Debug"))
		end

		local t = {...}

		local Traceback = debug.traceback()
		local ErrorDepth = select(2, Traceback:gsub("\n", "")) - 2

		local Prefix
		Err, Prefix = Err:gsub("^!", "", 1)
		local ModuleName = Prefix == 1 and table.remove(t, 1) or (getfenv(ErrorDepth).script or CommandBar).Name
		local FunctionName

		for i = 1, select("#", ...) do
			t[i] = Debug.Inspect(t[i])
		end

		for x in Traceback:sub(1, -11):gmatch("%- [^\r\n]+[\r\n]") do
			FunctionName = x
		end

		FunctionName = FunctionName:sub(3, -2):gsub("%l+ (%S+)$", "%1"):gsub(" ([^\n\r]+)", " %1", 1)

		local i = 0
		for x in Err:gmatch("%%%l") do
			i = i + 1
			if x == "%q" then
				t[i] = t[i]:gsub(" (%S+)$", " \"%1\"", 1)
			end
		end

		local Success, ErrorString = pcall(Format, "[%s] {%s} " .. Err:gsub("%%q", "%%s"), ModuleName, Replacers[FunctionName] or FunctionName, unpack(t))

		if Success then
			return ErrorString, ErrorDepth
		else
			error(GetErrorData("!Error formatting failed, perhaps try escaping non-formattable tags like so: %%%%f\n(Error Message): " .. ErrorString, "Debug"))
		end
	end

	function Debug.Warn(...)
		warn((GetErrorData(...)))
	end

	function Debug.Error(...)
		error(GetErrorData(...))
	end

	function Debug.Assert(Condition, ...)
		return Condition or error(GetErrorData(...))
	end
end

do
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

	Debug.AlphabeticalOrder = Typer.AssignSignature(Typer.Table, function(Dictionary)
		--- Iteration function that iterates over a dictionary in alphabetical order
		-- function AlphabeticalOrder(Dictionary)
		-- @param table Dictionary That which will be iterated over in alphabetical order
		-- A dictionary looks like this: {Apple = true, Noodles = 5, Soup = false}
		-- Not case-sensitive
		-- @author Validark

		local Count = 0
		local Order = {}

		for Key in next, Dictionary do
			Count = Count + 1
			Order[Count] = Key
		end

		Resources:LoadLibrary("SortedArray").new(Order, Alphabetically)

		return function(Table, Previous)
			local Key = Order[Previous == nil and 1 or ((Order:Find(Previous) or error("invalid key to 'AlphabeticalOrder' " .. tostring(Previous))) + 1)]
			return Key, Table[Key]
		end, Dictionary, nil
	end)
end

function Debug.UnionIteratorFunctions(...)
	-- Takes in functions ..., and returns a function which unions them, which can be called on a table
	-- Will iterate through a table, using the iterator functions passed in from left to right
	-- Will pass the CurrentIteratorFunction index in the stack as the last variable
	-- UnionIteratorFunctions(Get0, ipairs, Debug.AlphabeticalOrder)(Table)

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

local EachOrder do
	-- TODO: Write a function that takes multiple iterator functions and iterates through each passed in function
	-- EachOrder(Get0(Table), ipairs(Table), AlphabeticalOrder(Table))
end

do
	local function Get0(t)
		return function(t2, val)
			if val == nil and t2[0] ~= nil then
				return 0, t2[0]
			end
		end, t, nil
	end

	local typeof = typeof or type
	local ArrayOrderThenAlphabetically = Debug.UnionIteratorFunctions(Get0, ipairs, Debug.AlphabeticalOrder)
	local ConvertTableIntoString

	local function Parse(Object, Multiline, Depth, EncounteredTables)
		local Type = typeof(Object)

		return
			Type == "table" and (EncounteredTables[Object] and "[table " .. EncounteredTables[Object] .. "]" or ConvertTableIntoString(Object, nil, Multiline, (Depth or 1) + 1, EncounteredTables))
			or Type == "string" and "\"" .. Object .. "\""
			or Type == "Instance" and "<" .. Debug.DirectoryToString(Object) .. ">"
			or (Type == "function" or Type == "userdata") and Type
			or tostring(Object)
	end

	function ConvertTableIntoString(Table, TableName, Multiline, Depth, EncounteredTables)
		local n = EncounteredTables.n + 1
		EncounteredTables[Table] = n
		EncounteredTables.n = n

		local Output = {}
		local OutputCount = 0

		for Key, Value, Iter in ArrayOrderThenAlphabetically(Table) do
			if not Multiline and Iter < 3 then
				Output[OutputCount + 1] = (Iter == 1 and "[0] = " or "") .. Parse(Value, Multiline, Depth, EncounteredTables)
				Output[OutputCount + 2] = ", "
				OutputCount = OutputCount + 2
			else
				if Multiline then
					OutputCount = OutputCount + 1
					Output[OutputCount] = "\n"
					Output[OutputCount + 1] = (TAB):rep(Depth)
				else
					OutputCount = OutputCount - 1
				end

				if type(Key) == "string" and not Key:find("^%d") and not Key:find("%s") then
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

		local OutputStart = 1

		if Output[OutputCount] == ", " then
			if Multiline then
				OutputStart = OutputStart + 2
			end
			OutputCount = OutputCount - 1
		elseif Multiline then
			Output[OutputCount + 1] = "\n"
			Output[OutputCount + 2] = (TAB):rep(Depth)
			OutputCount = OutputCount + 2
		end

		local Metatable = getmetatable(Table)

		OutputStart = OutputStart - 1

		if not Multiline or Output[OutputCount - 1] ~= "\n" then
			OutputCount = OutputCount + 1
		end

		Output[OutputStart] = "{"
		Output[OutputCount] = "}"

		if Metatable then
			Output[OutputCount + 1] = " <- "
			Output[OutputCount + 2] = type(Metatable) == "table" and ConvertTableIntoString(Metatable, nil, Multiline, 1, EncounteredTables) or Debug.Inspect(Metatable)
			OutputCount = OutputCount + 2
		end

		if TableName then
			Output[OutputStart - 1] = " = "
			Output[OutputStart - 2] = TableName
			OutputStart = OutputStart - 2
		end

		return table.concat(Output, "", OutputStart, OutputCount)
	end

	Debug.TableToString = Typer.AssignSignature(Typer.Table, Typer.OptionalBoolean, Typer.OptionalString, function(Table, Multiline, TableName)
		--- Converts a table into a readable string
		-- string TableToString(Table, TableName, Multiline)
		-- @param table Table The Table to convert into a readable string
		-- @param string TableName Optional Name parameter that puts a "[TableName] = " at the beginning
		-- @returns a readable string version of the table

		return ConvertTableIntoString(Table, TableName, Multiline, 1, {n = 0})
	end)
end

do
	local EscapedCharacters = {"%", "^", "$", "(", ")", ".", "[", "]", "*", "+", "-", "?"}
	local Escapable = "([%" .. table.concat(EscapedCharacters, "%") .. "])"

	Debug.EscapeString = Typer.AssignSignature(Typer.String, function(String)
		--- Turns strings into Lua-readble format
		-- string Debug.EscapeString(String)
		-- @returns Objects location in proper Lua format
		-- @author Validark
		-- Useful for when you are doing string-intensive coding
		-- Those minus signs always get me when I'm not using this function!

		return (
			String
				:gsub(Escapable, "%%%1")
				:gsub("([\"\'\\])", "\\%1")
		)
	end)
end

function Debug.Inspect(...)
	--- Returns a string representation of anything
	-- @param any Object The object you wish to represent as a string
	-- @returns a readable string representation of the object
	
	local List = ""
	
	for i = 1, select("#", ...) do
		local Data = select(i, ...)
		local DataType = typeof(Data)
		local DataString
	
		if DataType == "Instance" then
			DataType = Data.ClassName
			DataString = Debug.DirectoryToString(Data)
		else
			DataString = DataType == "table" and Debug.TableToString(Data)
				or DataType == "string" and "\"" .. Data .. "\""
				or tostring(Data)
		end
	
		List = List .. ", " .. ((DataType .. " " .. DataString):gsub("^" .. DataType .. " " .. DataType, DataType, 1))
	end
	
	if List == "" then
		return "NONE"
	else
		return List:sub(3)
	end
end

return Table.Lock(Debug)
