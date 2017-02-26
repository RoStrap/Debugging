local TableToString do
	local function Parse(Object)
		local Type = typeof(Object)

		return
			Type == "table" and TableToString(Object) or
			Type == "string" and "\"" .. Object .. "\"" or
			(Type == "function" or type(Object) == "userdata") and Type or
			Object
	end

	local function TableToString(t)
		if type(t) == "table" then
			local IsArrayKey = {}
			local Output = {}
			local OutputCount = 0

			for Integer, Value in ipairs(t) do
				IsArrayKey[Integer] = true
				Output[OutputCount + 1] = Parse(Value)
				Output[OutputCount + 2] = ", "
				OutputCount = OutputCount + 2
			end

			for Key, Value in next, t do
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

			local metatable = getmetatable(t)

			Output = "{" .. table.concat(Output) .. "}"

			if metatable then
				Output = Output .. " <- " .. TableToString(metatable)
			end

			return Output
		end
	end
end

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

return {
	TableToString = TableToString;
	DirectoryToString = DirectoryToString;
}
