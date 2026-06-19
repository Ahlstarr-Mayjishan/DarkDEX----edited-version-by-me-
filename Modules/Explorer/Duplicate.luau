--[[
	Duplicate Core Module
	Handles duplicating selected instances in the Explorer.
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
	local Duplicate = {}

	Duplicate.Execute = function(selectionList, nodes, selection, ViewNode, MakeNodeVisible)
		local clone = game.Clone
		local newSelection = {}
		local count = 1
		for i = 1, #selectionList do
			local node = selectionList[i]
			local inst = node.Obj
			local instPar = node.Parent and node.Parent.Obj
			if MakeNodeVisible then
				MakeNodeVisible(node)
			end
			local s, cloned = pcall(clone, inst)
			if s and cloned then
				cloned.Parent = instPar
				local clonedNode = nodes[cloned]
				if clonedNode then
					newSelection[count] = clonedNode
					count = count + 1
				end
			end
		end

		if selection and selection.SetTable then
			selection:SetTable(newSelection)
		end
		if #newSelection > 0 and ViewNode then
			ViewNode(newSelection[1])
		end
	end

	return Duplicate
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main
}
