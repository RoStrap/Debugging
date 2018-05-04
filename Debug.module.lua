-- Standard RoStrap Debugging Functions

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
		local Order = {}
		local Count = 0

		for Key in next, Dictionary do
			Count = Count + 1
			Order[Count] = Key
		end

		table.sort(Order, Alphabetically)

		return coroutine.wrap(function()
			for a = 1, Count do
				local Key = Order[a]
				coroutine.yield(Key, Dictionary[Key])
			end
		end)
	end
end

local TableToString do
	--- Converts a table into a readable string
	-- string TableToString(Table, TableName, AlphabeticallyArranged)
	-- @param table Table The Table to convert into a readable string
	-- @param string TableName Optional Name parameter that puts a "[TableName] = " at the beginning
	-- @param AlphabeticallyArranged Whether the table should be alphabetically sorted: still in-dev, little support
	-- @returns a readable string version of the table

	local function Parse(Object, AlphabeticallyArranged, EncounteredTables)
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
			return TableToString(Object, nil, AlphabeticallyArranged, EncounteredTables)
		end

		return
			Type == "string" and "\"" .. Object .. "\"" or
			Type == "Instance" and "<" .. DirectoryToString(Object) .. ">" or
			(Type == "function" or Type == "userdata") and Type or
			tostring(Object)
	end

	function TableToString(Table, TableName, AlphabeticallyArranged, EncounteredTables)
		if type(Table) == "table" then
			local EncounteredTables = EncounteredTables or {}
			EncounteredTables[TableName or #EncounteredTables + 1] = Table
			local IsArrayKey = {}
			local Output = {}
			local OutputCount = 0

			for Integer, Value in ipairs(Table) do
				IsArrayKey[Integer] = true
				Output[OutputCount + 1] = Parse(Value, AlphabeticallyArranged, EncounteredTables)
				Output[OutputCount + 2] = ", "
				OutputCount = OutputCount + 2
			end

			for Key, Value in (AlphabeticallyArranged and AlphabeticalOrder or pairs)(Table) do
				if not IsArrayKey[Key] then
					if type(Key) == "string" and not Key:find("^%d") then
						Output[OutputCount + 1] = Key
						OutputCount = OutputCount - 2
					else
						Output[OutputCount + 1] = "["
						Output[OutputCount + 2] = Parse(Key, AlphabeticallyArranged, EncounteredTables)
						Output[OutputCount + 3] = "]"
					end

					Output[OutputCount + 4] = " = "
					Output[OutputCount + 5] = Parse(Value, AlphabeticallyArranged, EncounteredTables)
					Output[OutputCount + 6] = ", "
					OutputCount = OutputCount + 6
				end
			end

			Output[OutputCount] = nil

			local Metatable = getmetatable(Table)

			Output = "{" .. table.concat(Output) .. "}"

			if Metatable then
				if type(Metatable) == "table" then
					Output = Output .. " <- " .. TableToString(Metatable)
				else
					warn((TableName or "Table") .. "'s metatable cannot be accessed. Got:\n" .. tostring(Metatable))
				end				
			end

			if TableName then
				Output = TableName .. " = " .. Output
			end

			return Output
		else
			error("[Debug] TableToString needs a table to convert to a string! Got type" .. typeof(Table), 2)
		end
	end
end

local EscapeString do
	--- Turns strings into Lua-readble format
	-- string Debug.EscapeString(String)
	-- @returns Objects location in proper Lua format
	-- @author Validark
	-- Useful for when you are doing string-intensive coding
	-- Those minus signs always get me when I'm not using this function!
	
	function EscapeString(String)		
		return (
			String
				:gsub("([().%+-*?[^$])", "%%%1")
				:gsub("([\"'])", "\\%1")
		)
	end
end

local Stringify do
	-- Turns data into "TYPE_NAME NAME"
	
	function Stringify(Data)
		return typeof(Data) .. " " .. tostring(Data)
	end
end

local Warn, Error, Assert do
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
	
	local function GetErrorData(Err, ...)
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

return {
	Warn = Warn;
	Error = Error;
	Assert = Assert;
	Stringify = Stringify;
	EscapeString = EscapeString;
	TableToString = TableToString;
	DirectoryToString = DirectoryToString;
	AlphabeticalOrder = AlphabeticalOrder;
}
