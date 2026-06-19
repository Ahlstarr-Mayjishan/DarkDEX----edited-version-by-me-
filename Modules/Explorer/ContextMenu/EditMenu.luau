--!strict
--[[
	Edit Menu Module
	Registers clipboard and item mutation commands (Cut, Copy, Paste, Duplicate, Delete, Rename).
]]
local Main, Lib, Apps, Settings
local function initDeps(data)
	Main, Lib, Apps, Settings = data.Main, data.Lib, data.Apps, data.Settings
end

local function initAfterMain()
end

local function main()
	return function(context, data)
		local selection = data.selection
		local clipboard = data.clipboard
		local nodes = data.nodes
		local Explorer = data.Explorer

		context:Register("CUT",{Name = "Cut", IconMap = Explorer.MiscIcons, Icon = "Cut", DisabledIcon = "Cut_Disabled", Shortcut = "Ctrl+Z", OnClick = function()
			if Apps.Clipboard then
				Apps.Clipboard.Cut(selection.List, selection)
			end
		end})

		context:Register("COPY",{Name = "Copy", IconMap = Explorer.MiscIcons, Icon = "Copy", DisabledIcon = "Copy_Disabled", Shortcut = "Ctrl+C", OnClick = function()
			if Apps.Clipboard then
				Apps.Clipboard.Copy(selection.List)
			end
		end})

		context:Register("PASTE",{Name = "Paste Into", IconMap = Explorer.MiscIcons, Icon = "Paste", DisabledIcon = "Paste_Disabled", Shortcut = "Ctrl+Shift+V", OnClick = function()
			if Apps.Clipboard then
				Apps.Clipboard.Paste(selection.List, nodes, selection, Explorer.ViewNode, Explorer.MakeNodeVisible)
			end
		end})

		context:Register("DUPLICATE",{Name = "Duplicate", IconMap = Explorer.MiscIcons, Icon = "Copy", DisabledIcon = "Copy_Disabled", Shortcut = "Ctrl+D", OnClick = function()
			if Apps.Duplicate then
				Apps.Duplicate.Execute(selection.List, nodes, selection, Explorer.ViewNode, Explorer.MakeNodeVisible)
			end
		end})

		context:Register("DELETE",{Name = "Delete", IconMap = Explorer.MiscIcons, Icon = "Delete", DisabledIcon = "Delete_Disabled", Shortcut = "Del", OnClick = function()
			if Apps.Deletion then
				Apps.Deletion.Delete(selection.List, selection)
			end
		end})

		context:Register("DELETE_CHILDREN",{Name = "Delete Children", IconMap = Explorer.MiscIcons, Icon = "Delete", DisabledIcon = "Delete_Disabled", Shortcut = "Shift+Del", OnClick = function()
			if Apps.Deletion then
				Apps.Deletion.DeleteChildren(selection.List)
			end
			selection:Clear()
		end})

		context:Register("RENAME",{Name = "Rename", IconMap = Explorer.MiscIcons, Icon = "Rename", DisabledIcon = "Rename_Disabled", Shortcut = "F2", OnClick = function()
			if Apps.Rename then
				Apps.Rename.Execute(selection.List, Explorer.SetRenamingNode)
			end
		end})
	end
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main
}
