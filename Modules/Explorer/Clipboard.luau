--[[
	Clipboard Core Module
	Handles copying, cutting, and pasting of instances.
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
	local Clipboard = {
		List = {}
	}

	Clipboard.Copy = function(selectionList)
		local clone = game.Clone
		local newClipboard = {}
		local count = 1
		for i = 1, #selectionList do
			local node = selectionList[i]
			if node and node.Obj then
				local inst = node.Obj
				local s, cloned = pcall(clone, inst)
				if s and cloned then
					newClipboard[count] = cloned
					count = count + 1
				end
			end
		end
		table.clear(Clipboard.List)
		for _, v in ipairs(newClipboard) do
			table.insert(Clipboard.List, v)
		end
	end

	Clipboard.Cut = function(selectionList, selection)
		local destroy, clone = game.Destroy, game.Clone
		local newClipboard = {}
		local count = 1
		for i = 1, #selectionList do
			local node = selectionList[i]
			if node and node.Obj then
				local inst = node.Obj
				local s, cloned = pcall(clone, inst)
				if s and cloned then
					newClipboard[count] = cloned
					count = count + 1
				end
				pcall(destroy, inst)
			end
		end
		table.clear(Clipboard.List)
		for _, v in ipairs(newClipboard) do
			table.insert(Clipboard.List, v)
		end
		if selection and selection.Clear then
			selection:Clear()
		end
	end

	Clipboard.Paste = function(selectionList, nodes, selection, ViewNode, MakeNodeVisible)
		if #Clipboard.List == 0 then return end
		local newSelection = {}
		local count = 1
		for i = 1, #selectionList do
			local node = selectionList[i]
			local inst = node.Obj
			if MakeNodeVisible then
				MakeNodeVisible(node, true)
			end
			for c = 1, #Clipboard.List do
				local cloned = Clipboard.List[c]:Clone()
				if cloned then
					cloned.Parent = inst
					local clonedNode = nodes[cloned]
					if clonedNode then
						newSelection[count] = clonedNode
						count = count + 1
					end
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

	Clipboard.HasItems = function()
		return #Clipboard.List > 0
	end

	return Clipboard
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main
}
