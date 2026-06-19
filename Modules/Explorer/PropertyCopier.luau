--[[
	Property Copier Core Module
	Handles copying of part and mesh properties to clipboard and pasting them in-game.
]]

-- Common Locals
local Main, Lib, Apps, Settings
local API, RMD, env, service, plr, create, createSimple

local function initDeps(data)
	Main = data.Main
	Lib = data.Lib
	Apps = data.Apps
	Settings = data.Settings

	API = data.API
	RMD = data.RMD
	env = data.env
	service = data.service
	plr = data.plr
	create = data.create
	createSimple = data.createSimple
end

local function initAfterMain()
end

local function main()
	local PropertyCopier = {}
	local copiedCache = nil

	PropertyCopier.Copy = function(instance)
		if not instance then return end
		local data = {
			ClassName = instance.ClassName,
			Properties = {}
		}
		
		local function addProp(name, value)
			data.Properties[name] = value
		end

		if instance:IsA("BasePart") then
			addProp("Material", instance.Material)
			pcall(function() addProp("MaterialVariant", instance.MaterialVariant) end)
			addProp("Color", instance.Color)
			addProp("Transparency", instance.Transparency)
			addProp("Reflectance", instance.Reflectance)
			addProp("Size", instance.Size)
			addProp("CanCollide", instance.CanCollide)
			addProp("Anchored", instance.Anchored)
			addProp("CastShadow", instance.CastShadow)
		end

		-- Special handling for MeshPart / SpecialMesh
		if instance:IsA("MeshPart") then
			pcall(function() addProp("MeshId", instance.MeshId) end)
			pcall(function() addProp("TextureID", instance.TextureID) end)
		end

		local specialMesh = instance:FindFirstChildOfClass("SpecialMesh")
		if specialMesh then
			data.SpecialMesh = {
				MeshId = specialMesh.MeshId,
				TextureId = specialMesh.TextureId,
				Scale = specialMesh.Scale,
				Offset = specialMesh.Offset,
				MeshType = specialMesh.MeshType
			}
		end

		copiedCache = data

		-- Convert to readable Luau table string and copy to system clipboard
		local lines = {"{"}
		table.insert(lines, "\tClassName = \"" .. data.ClassName .. "\",")
		table.insert(lines, "\tProperties = {")
		for k, v in pairs(data.Properties) do
			local valStr = tostring(v)
			if typeof(v) == "EnumItem" then
				valStr = tostring(v.Enum) .. "." .. v.Name
			elseif typeof(v) == "Color3" then
				valStr = "Color3.fromRGB(" .. math.round(v.R * 255) .. ", " .. math.round(v.G * 255) .. ", " .. math.round(v.B * 255) .. ")"
			elseif typeof(v) == "Vector3" then
				valStr = "Vector3.new(" .. v.X .. ", " .. v.Y .. ", " .. v.Z .. ")"
			elseif type(v) == "string" then
				valStr = "\"" .. v .. "\""
			end
			table.insert(lines, "\t\t" .. k .. " = " .. valStr .. ",")
		end
		table.insert(lines, "\t},")
		
		local specMesh = data.SpecialMesh
		if specMesh then
			table.insert(lines, "\tSpecialMesh = {")
			for k, v in pairs(specMesh) do
				local valStr = tostring(v)
				if typeof(v) == "EnumItem" then
					valStr = tostring(v.Enum) .. "." .. v.Name
				elseif typeof(v) == "Vector3" then
					valStr = "Vector3.new(" .. v.X .. ", " .. v.Y .. ", " .. v.Z .. ")"
				elseif type(v) == "string" then
					valStr = "\"" .. v .. "\""
				end
				table.insert(lines, "\t\t" .. k .. " = " .. valStr .. ",")
			end
			table.insert(lines, "\t}")
		end
		table.insert(lines, "}")
		local resultString = table.concat(lines, "\n")

		if env and env.setclipboard then
			pcall(env.setclipboard, resultString)
		end
	end

	PropertyCopier.Paste = function(targetInstance)
		if not targetInstance or not copiedCache then return end
		
		for k, v in pairs(copiedCache.Properties) do
			pcall(function()
				targetInstance[k] = v
			end)
		end

		local specMesh = copiedCache.SpecialMesh
		if specMesh then
			local specialMesh = targetInstance:FindFirstChildOfClass("SpecialMesh")
			if not specialMesh then
				specialMesh = Instance.new("SpecialMesh")
				specialMesh.Parent = targetInstance
			end
			for k, v in pairs(specMesh) do
				pcall(function()
					specialMesh[k] = v
				end)
			end
		end
	end

	PropertyCopier.HasCache = function()
		return copiedCache ~= nil
	end

	return PropertyCopier
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main
}
