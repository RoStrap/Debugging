local DirectoryToString do
	-- @author Validark
	-- Gets the string of the directory of an object, properly formatted
	-- Corrects the built-in GetFullName function so that it returns properly formatted text.

	local gsub = string.gsub
	local GetFullName = workspace.GetFullName

	function DirectoryToString(Object)
		return (gsub(gsub(gsub(gsub(GetFullName(Object), "^Workspace", "workspace"), "%.(%w*%s%w*)", "%[\"%1\"%]"), "%.(%d+[%w%s]+)", "%[\"%1\"%]"), "%.(%d+)", "%[%1%]"))
	end
end

local TableToString do
	-- Converts a table into a readable string

	local function Parse(Object)
		local Type = typeof(Object)

		return
			Type == "table" and TableToString(Object) or
			Type == "string" and "\"" .. Object .. "\"" or
			Type == "Instance" and "<" .. DirectoryToString(Object) .. ">" or
			(Type == "function" or type(Object) == "userdata") and Type or
			Object
	end

	function TableToString(Table, TableName)
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

			for Key, Value in next, Table do
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
}
