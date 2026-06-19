--[[
	Rename Core Module
	Handles rename triggering for instances.
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
	local Rename = {}

	Rename.Execute = function(selectionList, SetRenamingNode)
		if selectionList[1] and SetRenamingNode then
			SetRenamingNode(selectionList[1])
		end
	end

	return Rename
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main
}
