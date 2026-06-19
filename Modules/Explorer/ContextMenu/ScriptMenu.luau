--strict
--[[
	Script Menu Module
	Registers decompilation, script relationship inspectors, and IDE sync commands.
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
		local Explorer = data.Explorer
		local env = data.env
		local ensureTool = data.ensureTool
		local Notepad = data.Notepad
		local ScriptRelations = data.ScriptRelations
		local DependencyGraph = data.DependencyGraph

		context:Register("VIEW_SCRIPT",{Name = "View Script", IconMap = Explorer.MiscIcons, Icon = "ViewScript", DisabledIcon = "Empty", OnClick = function()
			local scr = selection.List[1] and selection.List[1].Obj
			if scr then Notepad.ViewScript(scr) end
		end})

		context:Register("SAVE_SCRIPT",{Name = "Save Script", IconMap = Explorer.MiscIcons, Icon = "Save", DisabledIcon = "Empty", OnClick = function()
			for _, v in next, selection.List do
				if v.Obj:IsA("LuaSourceContainer") and env.isViableDecompileScript(v.Obj) then
					local success, source = pcall(env.decompile, v.Obj)
					if not success or not source then source = ("-- DEX - %s failed to decompile %s"):format(env.executor, v.Obj.ClassName) end
					local fileName = ("%s_%s_%i_Source.txt"):format(env.parsefile(v.Obj.Name), v.Obj.ClassName, game.PlaceId)
					Lib.SaveAsPrompt(fileName, source)

					task.wait(0.2)
				end
			end
		end})

		context:Register("SYNC_TO_IDE",{Name = "Sync Script to IDE", IconMap = Explorer.MiscIcons, Icon = "Save", DisabledIcon = "Empty", OnClick = function()
			local idesync = Apps.IDESync
			if idesync then
				local list = {}
				for _, v in ipairs(selection.List) do
					if v.Obj then
						table.insert(list, v.Obj)
					end
				end
				if #list > 0 then
					idesync.ExportWorkspace(list)
				end
			else
				warn("IDE Sync app not loaded.")
			end
		end})

		context:Register("SAVE_BYTECODE",{Name = "Save Script Bytecode", IconMap = Explorer.MiscIcons, Icon = "Save", DisabledIcon = "Empty", OnClick = function()
			for _, v in next, selection.List do
				if v.Obj:IsA("LuaSourceContainer") and env.isViableDecompileScript(v.Obj) then
					local success, bytecode = pcall(env.getscriptbytecode, v.Obj)
					if success and type(bytecode) == "string" then
						local fileName = ("%s_%s_%i_Bytecode.txt"):format(env.parsefile(v.Obj.Name), v.Obj.ClassName, game.PlaceId)
						Lib.SaveAsPrompt(fileName, bytecode)
						task.wait(0.2)
					end
				end
			end
		end})

		context:Register("VIEW_SCRIPT_RELATIONS",{Name = "Script Relations", IconMap = Explorer.MiscIcons, Icon = "SelectChildren", DisabledIcon = "Empty", OnClick = function()
			local scr = selection.List[1] and selection.List[1].Obj
			if scr and ensureTool(ScriptRelations) then ScriptRelations.ShowForScript(scr) end
		end})

		context:Register("VIEW_DEPENDENCY_GRAPH",{Name = "Script Dependency Graph", IconMap = Explorer.MiscIcons, Icon = "ExploreData", DisabledIcon = "Empty", OnClick = function()
			local scr = selection.List[1] and selection.List[1].Obj
			if scr and ensureTool(DependencyGraph) then DependencyGraph.ShowForScript(scr) end
		end})

		context:Register("DUMP_FUNCTIONS",{Name = "Dump Functions", IconMap = Explorer.MiscIcons, Icon = "SelectChildren", DisabledIcon = "Empty", OnClick = function()
			local scr = selection.List[1] and selection.List[1].Obj
			if scr then Notepad.DumpFunctions(scr) end
		end})
	end
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main
}
