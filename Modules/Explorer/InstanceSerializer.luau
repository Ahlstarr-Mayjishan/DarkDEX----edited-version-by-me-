--!nocheck
--[[
	Instance Serializer Module
	Serializes a selected instance and its descendants into verbose Luau instantiation code.
]]
local Main, Lib, Apps, Settings
local Explorer, ScriptViewer

local function initDeps(data)
	Main = data.Main
	Lib = data.Lib
	Apps = data.Apps
	Settings = data.Settings
end

local function initAfterMain(apps)
	Explorer = apps.Explorer
	ScriptViewer = apps.ScriptViewer
end

local function main()
	local InstanceSerializer = {}

	local varNames = {}

	local function formatValue(val)
		local t = typeof(val)
		if t == "string" then
			if Lib and Lib.FormatLuaString then
				return Lib.FormatLuaString(val)
			else
				return '"' .. val:gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
			end
		elseif t == "number" then
			if val == math.huge then
				return "math.huge"
			elseif val == -math.huge then
				return "-math.huge"
			elseif val ~= val then
				return "0/0"
			else
				return tostring(val)
			end
		elseif t == "boolean" then
			return tostring(val)
		elseif t == "nil" then
			return "nil"
		elseif t == "Vector3" then
			return string.format("Vector3.new(%f, %f, %f)", val.X, val.Y, val.Z)
		elseif t == "Vector2" then
			return string.format("Vector2.new(%f, %f)", val.X, val.Y)
		elseif t == "CFrame" then
			local comps = {val:GetComponents()}
			return "CFrame.new(" .. table.concat(comps, ", ") .. ")"
		elseif t == "Color3" then
			return string.format("Color3.fromRGB(%d, %d, %d)", math.round(val.R * 255), math.round(val.G * 255), math.round(val.B * 255))
		elseif t == "UDim2" then
			return string.format("UDim2.new(%f, %d, %f, %d)", val.X.Scale, val.X.Offset, val.Y.Scale, val.Y.Offset)
		elseif t == "UDim" then
			return string.format("UDim.new(%f, %d)", val.Scale, val.Offset)
		elseif t == "BrickColor" then
			return "BrickColor.new(\"" .. val.Name .. "\")"
		elseif t == "EnumItem" then
			return "Enum." .. tostring(val.EnumType) .. "." .. val.Name
		elseif t == "NumberRange" then
			return string.format("NumberRange.new(%f, %f)", val.Min, val.Max)
		elseif t == "NumberSequence" then
			local kps = {}
			for _, kp in ipairs(val.Keypoints) do
				table.insert(kps, string.format("NumberSequenceKeypoint.new(%f, %f, %f)", kp.Time, kp.Value, kp.Envelope))
			end
			return "NumberSequence.new({" .. table.concat(kps, ", ") .. "})"
		elseif t == "ColorSequence" then
			local kps = {}
			for _, kp in ipairs(val.Keypoints) do
				local col = kp.Value
				local colStr = string.format("Color3.fromRGB(%d, %d, %d)", math.round(col.R * 255), math.round(col.G * 255), math.round(col.B * 255))
				table.insert(kps, string.format("ColorSequenceKeypoint.new(%f, %s)", kp.Time, colStr))
			end
			return "ColorSequence.new({" .. table.concat(kps, ", ") .. "})"
		elseif t == "Rect" then
			return string.format("Rect.new(%f, %f, %f, %f)", val.Min.X, val.Min.Y, val.Max.X, val.Max.Y)
		elseif t == "Instance" then
			if varNames[val] then
				return varNames[val]
			end
			return "nil"
		else
			return "nil --[[ Unsupported type: " .. t .. " ]]"
		end
	end

	local function getWritableProperties(obj: Instance)
		local className = obj.ClassName
		local apiClass = Main.GetInitDeps().API.Classes[className]
		local propsList = {}
		local seen = {}
		while apiClass do
			for _, prop in ipairs(apiClass.Properties) do
				if not seen[prop.Name] then
					seen[prop.Name] = true
					if prop.Name ~= "Parent" and prop.Name ~= "ClassName" then
						local s, _ = pcall(function() return obj[prop.Name] end)
						if s and not prop.Tags.ReadOnly and not prop.Tags.Hidden then
							table.insert(propsList, prop)
						end
					end
				end
			end
			apiClass = apiClass.Superclass
		end
		return propsList
	end

	InstanceSerializer.Serialize = function(root: Instance)
		if not root then return end
		table.clear(varNames)

		-- Traverse hierarchy
		local hierarchy = {root}
		for _, desc in ipairs(root:GetDescendants()) do
			table.insert(hierarchy, desc)
		end

		-- Generate unique variables
		local classCounters = {}
		for _, inst in ipairs(hierarchy) do
			local className = inst.ClassName
			local count = (classCounters[className] or 0) + 1
			classCounters[className] = count
			local safeClassName = className:gsub("[^%w_]", "")
			varNames[inst] = safeClassName .. "_" .. tostring(count)
		end

		local code = {}
		table.insert(code, "-- Auto-generated Instance Serialization")
		table.insert(code, "-- Root Object: " .. root.Name .. " [" .. root.ClassName .. "]")
		table.insert(code, "-- Total Instances: " .. #hierarchy .. "\n")

		-- Variable instantiation and property assignment
		for _, inst in ipairs(hierarchy) do
			local varName = varNames[inst]
			table.insert(code, "local " .. varName .. " = Instance.new(\"" .. inst.ClassName .. "\")")
			
			local props = getWritableProperties(inst)
			for _, prop in ipairs(props) do
				local ok, val = pcall(function() return inst[prop.Name] end)
				if ok then
					local formatted = formatValue(val)
					table.insert(code, varName .. "." .. prop.Name .. " = " .. formatted)
				end
			end
			table.insert(code, "") -- empty line separator
		end

		-- Tree hierarchy wiring (parenting)
		table.insert(code, "-- Wire parent relationships")
		for _, inst in ipairs(hierarchy) do
			local varName = varNames[inst]
			local parent = inst.Parent
			if parent and varNames[parent] then
				table.insert(code, varName .. ".Parent = " .. varNames[parent])
			elseif inst == root then
				table.insert(code, varName .. ".Parent = workspace -- Root object parented to workspace")
			end
		end

		-- Return root variable
		table.insert(code, "\nreturn " .. varNames[root])

		local finalCode = table.concat(code, "\n")
		if ScriptViewer and ScriptViewer.ViewRawCode then
			ScriptViewer.ViewRawCode(finalCode, root.Name .. " Serialized")
		else
			warn("ScriptViewer not available or missing ViewRawCode!")
		end
	end

	-- Launcher app interface click
	InstanceSerializer.Init = function()
		if Explorer and Explorer.Selection and Explorer.Selection.List and #Explorer.Selection.List > 0 then
			local selected = Explorer.Selection.List[1].Obj
			if selected then
				InstanceSerializer.Serialize(selected)
			end
		else
			warn("Select an instance in the Explorer first to serialize!")
		end
	end

	return InstanceSerializer
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
