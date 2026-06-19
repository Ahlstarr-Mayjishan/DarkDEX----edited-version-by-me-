--[[
	Deletion Core Module
	Handles deleting instances and clearing instance children.
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
	local Deletion = {}

	Deletion.Delete = function(selectionList, selection)
		local destroy = game.Destroy
		for i = 1, #selectionList do
			local node = selectionList[i]
			if node and node.Obj then
				pcall(destroy, node.Obj)
			end
		end
		if selection and selection.Clear then
			selection:Clear()
		end
	end

	Deletion.DeleteChildren = function(selectionList)
		for i = 1, #selectionList do
			local node = selectionList[i]
			if node and node.Obj then
				pcall(node.Obj.ClearAllChildren, node.Obj)
			end
		end
	end

	return Deletion
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main
}
