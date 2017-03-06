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
	-- @author Validark

	function AlphabeticalOrder(Table)
		local Order = {}
		for i, _ in next, Table do
			Order[#Order + 1] = i
		end
		table.sort(Order)
		-- TODO: This sort is the source of errors regarding comparing incompatible types
		-- Should move to a custom function

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

	local function Parse(Object)
		local Type = typeof(Object)

		return
			Type == "table" and TableToString(Object) or
			Type == "string" and "\"" .. Object .. "\"" or
			Type == "Instance" and "<" .. DirectoryToString(Object) .. ">" or
			(Type == "function" or type(Object) == "userdata") and Type or
			tostring(Object)
	end

	function TableToString(Table, TableName, AlphabeticallyArranged)
		if type(Table) == "table" then
			local IsArrayKey = {}
			local Output = {}
			local OutputCount = 0

			for Integer, Value in ipairs(Table) do
				IsArrayKey[Integer] = true
				Output[OutputCount + 1] = Parse(Value)
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
						Output[OutputCount + 2] = Parse(Key)
						Output[OutputCount + 3] = "]"
					end

					Output[OutputCount + 4] = " = "
					Output[OutputCount + 5] = Parse(Value)
					Output[OutputCount + 6] = ", "
					OutputCount = OutputCount + 6
				end
			end

			Output[OutputCount] = nil

			local Metatable = getmetatable(Table)

			Output = "{" .. table.concat(Output) .. "}"

			if Metatable then
				Output = Output .. " <- " .. TableToString(Metatable)
			end

			if TableName then
				Output = TableName .. " = " .. Output
			end

			return Output
		end
	end
end

return {
	TableToString = TableToString;
	DirectoryToString = DirectoryToString;
	AlphabeticalOrder = AlphabeticalOrder;
}
