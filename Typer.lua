-- Type Checker and Function Signature Assigner
-- @author Validark

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Resources = require(ReplicatedStorage:WaitForChild("Resources"))

local Debug = Resources:LoadLibrary("Debug")
local Table = Resources:LoadLibrary("Table")

local BuiltInTypes = {
	Nil = "nil";
	Boolean = "boolean";
	Number = "number";
	String = "string";
	Userdata = "userdata";
	Function = "function";
	Thread = "thread";
	Table = "table";
}

local CustomTypes = {
	Any = function()
		return true
	end;

	Array = function(Value, Type)
		if Type ~= "table" then
			return false
		end

		local Count = 0
		local Keys = {}

		for Key in next, Value do
			Count = Count + 1

			if type(Key) ~= "number" then
				return false
			end

			Keys[Count] = Key
		end

		table.sort(Keys)

		for i = 1, Count do
			if Keys[i] ~= i then
				return false
			end
		end

		return true
	end;

	NonNil = function(Value)
		return Value ~= nil
	end;

	Integer = function(Value, Type)
		return Type == "number" and Value % 1 == 0
	end;

	Enum = function(_, Type)
		return Type == "Enum" or Type == "EnumItem"
	end;

	EnumType = function(_, Type) -- For whatever reason, typeof() returns "Enum" for EnumItems
		return Type == "Enum"
	end;
}

local function TransformTableCheckerData(PotentialTypes)
	-- [0] is the Expectation string
	-- Array in the form {"number", "string", "nil"} where each value is a string matchable by typeof()
	-- Key-Value pairs in the form {[string Name] = function 123}

	if not PotentialTypes[0] then -- It was already transformed if written to 0, no haxing pls
		local Expectation = ": expected "
		PotentialTypes[0] = Expectation

		for Name in next, PotentialTypes do
			local NameType = type(Name)
			if NameType == "string" then
				Expectation = Expectation .. Name .. " or "
			elseif NameType ~= "number" then
				Debug.Error("Key-Value pairs should be in the form [string Name] = function 123, got %s", Name)
			end
		end

		local i = 0
		local AmountPotentialTypes = #PotentialTypes

		while i < AmountPotentialTypes do
			i = i + 1
			local PotentialType = PotentialTypes[i]

			if type(PotentialType) ~= "string" then
				Debug.Error("PotentialTypes in the array section must be strings in the form {\"number\", \"string\", \"nil\"}")
			end

			Expectation = Expectation .. PotentialType .. " or "
			local TypeCheck = CustomTypes[PotentialType]

			if TypeCheck then
				table.remove(PotentialTypes, i)
				i = i - 1
				AmountPotentialTypes = AmountPotentialTypes - 1
				PotentialTypes[PotentialType] = TypeCheck
			end
		end

		PotentialTypes[0] = Expectation:sub(1, -5)
	end

	return PotentialTypes
end

local function Check(PotentialTypes, Parameter, ArgumentNumber)
	local TypeOf = typeof(Parameter)

	for i = 1, #PotentialTypes do
		if PotentialTypes[i] == TypeOf then
			return Parameter or true
		end
	end

	for Key, CheckFunction in next, PotentialTypes do
		if type(Key) == "string" and CheckFunction(Parameter, TypeOf) then
			return Parameter or true
		end
	end

	local ArgumentNumberType = type(ArgumentNumber)

	return false, "bad argument"
		.. (ArgumentNumber and (ArgumentNumberType == "number" and " #" .. ArgumentNumber or ArgumentNumberType == "string" and " to " .. ArgumentNumber) or "")
		.. PotentialTypes[0] .. ", got " .. Debug.Inspect(Parameter)
end

local CallToCheck = {__call = Check}

local Typer = setmetatable({}, {
	__index = function(self, i)
		local t = {}
		self[i] = t

		if i:find("^Optional", 1, false) then
			i = i:sub(9)
			t[1] = "nil"
		end

		if i:find("^InstanceOfClass") then
			local ClassName = i:sub(16)

			t[ClassName] = function(Value, Type)
				return Type == "Instance" and Value.ClassName == ClassName
			end
		elseif i:find("^InstanceWhichIsA") then
			local ClassName = i:sub(17)

			t[ClassName] = function(Value, Type)
				return Type == "Instance" and Value:IsA(ClassName)
			end
		else
			t[#t + 1] = BuiltInTypes[i] or i
		end

		return setmetatable(TransformTableCheckerData(t), CallToCheck)
	end;
})

function Typer.AssignSignature(...)
	local StackSignature = {...}
	local Function = table.remove(StackSignature)

	local NumTypes = #StackSignature

	for a = 1, NumTypes do
		local ParameterSignature = StackSignature[a]
		local Success, Error = Check(Typer.Table, ParameterSignature, a)

		if Success then
			TransformTableCheckerData(ParameterSignature)
		else
			Debug.Error(Error)
		end
	end

	return function(...)
		local NumParameters = select("#", ...)

		for a = 1, NumParameters < NumTypes and NumTypes or NumParameters do
			local Success, Error = Check(StackSignature[a] or Typer.Nil, select(a, ...), a)

			if not Success then
				return Debug.Error(Error)
			end
		end

		return Function(...)
	end
end

Typer.Check = Typer.AssignSignature(Typer.Table, Typer.Any, {"nil", "string", "number"}, function(PotentialTypes, Parameter, ArgumentNumber)
	return Check(TransformTableCheckerData(PotentialTypes), Parameter, ArgumentNumber)
end)

local Map__call = {
	__call = function(self, Tab, TabType)
		if (TabType or type(Tab)) ~= "table" then
			return false, "|Map.__call| Must be called with a Table"
		end

		for Index in next, Tab do
			if not self[Index] then
				return false, "|Map.__call| " .. Debug.Inspect(Index) .. " is not a valid Key"
			end
		end

		for Index, Type in next, self do
			local Success, Error = Typer.Check(Type, Tab[Index], Index)

			if not Success then
				return false, "|Map.__call| " .. Error
			end
		end

		return Tab
	end;
}

Typer.MapDefinition = Typer.AssignSignature(Typer.Table, function(Template)
	for _, Type in next, Template do
		if type(Type) ~= "table" then
			return Debug.Error("Values must be tables")
		end
		TransformTableCheckerData(Type)
	end

	return setmetatable(Template, Map__call)
end)

return Table.Lock(Typer)
