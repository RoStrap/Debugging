local DirectoryToString do
	--- Gets the string of the directory of an object, properly formatted
	-- string DirectoryToString(Object)
	-- @returns Objects location in proper Lua format
	-- @author Validark
	-- Corrects the built-in GetFullName function so that it returns properly formatted text.

	function DirectoryToString(Object)
		return (Object
			:GetFullName()
			:gsub("^Workspace", "workspace")
			:gsub("%.(%w*%s%w*)", "%[\"%1\"%]")
			:gsub("%.(%d+[%w%s]+)", "%[\"%1\"%]")
			:gsub("%.(%d+)", "%[%1%]")
	 	)
	end
end

local AlphabeticalOrder do
	--- Iteration function that allows for loops to be sequenced in alphabetical order
	-- function AlphabeticalOrder(Table)
	-- @param table Table That which will be iterated over in alphabetical order
	--	@constraints Currently only accepts tables with string keys
	-- Not case-sensitive
	-- @author Validark

	function AlphabeticalOrder(Table)
		local Order = {}
		for i, _ in next, Table do
			Order[#Order + 1] = i
		end
		
		table.sort(Order, function(a, b)
			return a:upper() < b:upper()
		end)
		-- TODO: This sort is the source of errors regarding comparing incompatible types
		-- Should move to a custom comparison function

		local i = 0

		local function Iterator(Table, Key)
			i = i + 1
			local v = Table[Order[i]]

			if v or type(v) == "boolean" then
				return Order[i], v
			end
		end

		return Iterator, Table, 0
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
			error("[Debug] TableToString needs a table to convert to a string! Got type" .. typeof(Table))
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

return {
	EscapeString = EscapeString;
	TableToString = TableToString;
	DirectoryToString = DirectoryToString;
	AlphabeticalOrder = AlphabeticalOrder;
}
