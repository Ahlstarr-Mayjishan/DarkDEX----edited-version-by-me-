--!strict
--[[
	Object Menu Module
	Registers asset-related tools, exporters, serializers, and general object metadata options.
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
		local service = data.service
		local ensureTool = data.ensureTool
		local ImageViewer = data.ImageViewer
		local SoundViewer = data.SoundViewer
		local AnimationViewer = data.AnimationViewer
		local ModelViewer = data.ModelViewer
		local ObjectLinks = data.ObjectLinks
		local nodes = data.nodes

		local clth = function(str)
			if str:sub(1, 28) == "game:GetService(\"Workspace\")" then str = str:gsub("game:GetService%(\"Workspace\"%)", "workspace", 1) end
			local plr = data.plr
			if str:sub(1, 27 + #plr.Name) == "game:GetService(\"Players\")." .. plr.Name then str = str:gsub("game:GetService%(\"Players\"%)." .. plr.Name, "game:GetService(\"Players\").LocalPlayer", 1) end
			return str
		end

		local function summarizeForAI(obj)
			local lines = {}
			local function push(text)
				lines[#lines + 1] = text
			end
			local function compactSourceAnalysis(analysis)
				if type(analysis) ~= "string" or analysis == "" then return nil end
				local httpService = service and service.HttpService
				if not httpService then
					local ok, resolved = pcall(game.GetService, game, "HttpService")
					if ok then httpService = resolved end
				end
				if not httpService then return analysis end
				local ok, decoded = pcall(function()
					return httpService:JSONDecode(analysis)
				end)
				if not ok or type(decoded) ~= "table" then return analysis end

				local parts = {}
				if decoded.lines then parts[#parts + 1] = tostring(decoded.lines) .. " lines" end
				if decoded.functions then parts[#parts + 1] = tostring(decoded.functions) .. " functions" end
				if decoded.requires then parts[#parts + 1] = tostring(decoded.requires) .. " requires" end
				if decoded.remoteCalls then parts[#parts + 1] = tostring(decoded.remoteCalls) .. " remote calls" end
				if decoded.riskySignals then parts[#parts + 1] = tostring(decoded.riskySignals) .. " risky signals" end
				if type(decoded.topIdentifiers) == "table" and #decoded.topIdentifiers > 0 then
					local ids = {}
					for i = 1, math.min(#decoded.topIdentifiers, 5) do
						ids[#ids + 1] = tostring(decoded.topIdentifiers[i])
					end
					parts[#parts + 1] = "top identifiers: " .. table.concat(ids, ", ")
				end
				return table.concat(parts, " | ")
			end
			local okPath, path = pcall(function()
				return Explorer.GetInstancePath(obj)
			end)
			push("- " .. (okPath and clth(tostring(path)) or obj:GetFullName()) .. " [" .. obj.ClassName .. "]")
			push("  Parent: " .. (obj.Parent and clth(tostring(Explorer.GetInstancePath(obj.Parent))) or "nil"))

			local children = obj:GetChildren()
			local scriptCount, remoteCount, partCount = 0, 0, 0
			local notable = {}
			for _, child in ipairs(children) do
				if child:IsA("LuaSourceContainer") then
					scriptCount += 1
					if #notable < 5 then notable[#notable + 1] = child.Name .. " [" .. child.ClassName .. "]" end
				elseif child:IsA("BasePart") then
					partCount += 1
				elseif child:IsA("RemoteEvent") or child:IsA("RemoteFunction") or child:IsA("UnreliableRemoteEvent") or child:IsA("BindableEvent") or child:IsA("BindableFunction") then
					remoteCount += 1
					if #notable < 5 then notable[#notable + 1] = child.Name .. " [" .. child.ClassName .. "]" end
				end
			end
			push(("  Children: %d | scripts: %d | remotes/bindables: %d | parts: %d"):format(#children, scriptCount, remoteCount, partCount))
			if #notable > 0 then
				push("  Notable children: " .. table.concat(notable, ", "))
			end

			if obj:IsA("BasePart") then
				push(("  BasePart: Anchored=%s CanCollide=%s Transparency=%s"):format(tostring(obj.Anchored), tostring(obj.CanCollide), tostring(obj.Transparency)))
			end
			if obj:IsA("Model") then
				push("  Model: PrimaryPart=" .. tostring(obj.PrimaryPart and obj.PrimaryPart.Name or "nil"))
			end
			if obj:IsA("LuaSourceContainer") then
				if obj:IsA("Script") or obj:IsA("LocalScript") then
					push("  RunContext: " .. tostring(obj.RunContext))
				end
				if env.isViableDecompileScript then
					push("  Decompileable: " .. tostring(env.isViableDecompileScript(obj)))
				end
				if env.DecompileCache and env.DecompileCache.Read and env.HelperServer and env.HelperServer.AnalyzeSource then
					local cacheOk, cachedSource = pcall(env.DecompileCache.Read, obj)
					if cacheOk and type(cachedSource) == "string" then
						local helperOk, analysis = pcall(env.HelperServer.AnalyzeSource, cachedSource)
						if helperOk and type(analysis) == "string" and #analysis > 0 then
							push("  Cached source analysis: " .. (compactSourceAnalysis(analysis) or analysis))
						end
					end
				end
			end
			return table.concat(lines, "\n")
		end

		local function buildAIPrompt()
			local sList = selection and selection.List or {}
			local lines = {
				"You are helping me inspect Roblox objects in DEX++.",
				"I am a beginner, so explain in simple language and keep jargon low.",
				"",
				"Goal:",
				"- Tell me what this selection likely does.",
				"- Point out which scripts, remotes, or nearby objects matter most.",
				"- If edits are needed, give short step-by-step guidance I can follow.",
				"",
				"Selection summary:",
				("Count: %d"):format(#sList),
			}
			for i = 1, math.min(#sList, 6) do
				if sList[i] and sList[i].Obj then
					lines[#lines + 1] = summarizeForAI(sList[i].Obj)
				end
			end
			if #sList > 6 then
				lines[#lines + 1] = ("... and %d more selected object(s)."):format(#sList - 6)
			end
			local taskText = table.concat(lines, "\n")
			if Apps.TaskRouter and Apps.TaskRouter.RouteTask then
				local ok, decision, sourceKind = pcall(Apps.TaskRouter.RouteTask, taskText)
				if ok and decision and decision.primary then
					local primary = decision.primary
					local secondary = decision.secondary or {}
					lines[#lines + 1] = ""
					lines[#lines + 1] = "Role recommendation:"
					lines[#lines + 1] = ("- Primary: %s [%s] -> %s"):format(
						tostring(primary.label or "Unknown"),
						tostring(primary.language or "Unknown"),
						tostring(primary.module or "Unknown")
					)
					lines[#lines + 1] = ("- Confidence: %s%% | Source: %s"):format(tostring(primary.confidence or 0), tostring(sourceKind or "local"))
					lines[#lines + 1] = ("- Why: %s"):format(tostring(primary.summary or ""))
					if secondary.label then
						lines[#lines + 1] = ("- Fallback: %s [%s] -> %s"):format(
							tostring(secondary.label or "Unknown"),
							tostring(secondary.language or "Unknown"),
							tostring(secondary.module or "Unknown")
						)
					end
					if decision.workflow then
						for i = 1, math.min(3, #decision.workflow) do
							lines[#lines + 1] = "- " .. tostring(decision.workflow[i])
						end
					end
				end
			end
			lines[#lines + 1] = ""
			lines[#lines + 1] = "Helpful DEX++ tools already available:"
			lines[#lines + 1] = "- Object Links / Reference Inspector"
			lines[#lines + 1] = "- Script Relations / Dependency Graph"
			lines[#lines + 1] = "- Remote Usage Map / Runtime Inspector"
			lines[#lines + 1] = "- Code Search / Smart Search"
			lines[#lines + 1] = ""
			lines[#lines + 1] = "Answer with the best next actions first, then any useful details."
			return table.concat(lines, "\n")
		end

		context:Register("COPY_PATH",{Name = "Copy Path", IconMap = Explorer.LegacyClassIcons, Icon = 50, OnClick = function()
			local sList = selection.List
			if #sList == 1 then
				env.setclipboard(clth(Explorer.GetInstancePath(sList[1].Obj)))
			elseif #sList > 1 then
				local resList = {"{"}
				local count = 2
				for i = 1,#sList do
					local path = "\t"..clth(Explorer.GetInstancePath(sList[i].Obj))..","
					if #path > 0 then
						resList[count] = path
						count = count+1
					end
				end
				resList[count] = "}"
				env.setclipboard(table.concat(resList,"\n"))
			end
		end})

		context:Register("COPY_TO_AI",{Name = "Copy to AI", IconMap = Explorer.MiscIcons, Icon = "Reference", OnClick = function()
			if env.setclipboard then
				env.setclipboard(buildAIPrompt())
			end
		end})

		context:Register("INSERT_OBJECT",{Name = "Insert Object", IconMap = Explorer.MiscIcons, Icon = "InsertObject", OnClick = function()
			local mouse = Main.Mouse
			local x,y = Explorer.LastRightClickX or mouse.X, Explorer.LastRightClickY or mouse.Y
			Explorer.InsertObjectContext:Show(x,y)
		end})

		context:Register("SAVE_INST",{Name = "Save to File", IconMap = Explorer.MiscIcons, Icon = "Save", OnClick = function()
			local sList = selection.List
			if #sList == 1 then
				Lib.SaveAsPrompt("Place_"..game.PlaceId.."_"..sList[1].Obj.ClassName.."_"..sList[1].Obj.Name.."_"..os.time(), function(filename)
					env.saveinstance(sList[1].Obj, filename, {
						Decompile = true,
						RemovePlayerCharacters = false
					})
				end)
			elseif #sList > 1 then
				for i = 1,#sList do
					Lib.SaveAsPrompt("Place_"..game.PlaceId.."_"..sList[i].Obj.ClassName.."_"..sList[i].Obj.Name.."_"..os.time(), function(filename)
						env.saveinstance(sList[i].Obj, filename, {
							Decompile = true,
							RemovePlayerCharacters = false
						})
					end)

					task.wait(0.1)
				end
			end
		end})

		context:Register("VIEW_IMAGE_ASSETS",{Name = "View Images", IconMap = Explorer.MiscIcons, Icon = "ViewScript", DisabledIcon = "Empty", OnClick = function()
			local obj = selection.List[1] and selection.List[1].Obj
			if obj and ensureTool(ImageViewer) then ImageViewer.ShowForObject(obj) end
		end})

		context:Register("VIEW_SOUND_ASSETS",{Name = "Preview Sound", IconMap = Explorer.MiscIcons, Icon = "Play", DisabledIcon = "Empty", OnClick = function()
			local obj = selection.List[1] and selection.List[1].Obj
			if obj and ensureTool(SoundViewer) then SoundViewer.ShowForObject(obj) end
		end})

		context:Register("VIEW_ANIMATION_ASSETS",{Name = "Preview Animation", IconMap = Explorer.MiscIcons, Icon = "Play", DisabledIcon = "Empty", OnClick = function()
			local obj = selection.List[1] and selection.List[1].Obj
			if obj and ensureTool(AnimationViewer) then AnimationViewer.ShowForObject(obj) end
		end})

		context:Register("3DVIEW_MODEL",{Name = "3D Preview Object", IconMap = Explorer.LegacyClassIcons, Icon = 54, OnClick = function()
			local sList = selection.List
			local isa = game.IsA

			if #sList == 1 then
				if (isa(sList[1].Obj,"BasePart") or isa(sList[1].Obj,"Model")) and ensureTool(ModelViewer) then
					ModelViewer.ViewModel(sList[1].Obj)
					return
				end
			end
		end})

		context:Register("COPY_API_PAGE",{Name = "Copy Roblox API Page URL", IconMap = Explorer.MiscIcons, Icon = "Reference", OnClick = function()
			local sList = selection.List
			if #sList == 1 then
				env.setclipboard(
					"https://create.roblox.com/docs/reference/engine/classes/"..sList[1].Obj.ClassName
				)
			end
		end})

		context:Register("FIND_OBJECT_LINKS",{Name = "Find Links / References", IconMap = Explorer.MiscIcons, Icon = "ExploreData", DisabledIcon = "Empty", OnClick = function()
			local obj = selection.List[1] and selection.List[1].Obj
			if obj and ensureTool(ObjectLinks) then
				ObjectLinks.ShowForObject(obj)
			end
		end})

		context:Register("TRACK_PROPERTIES",{Name = "Track Properties", IconMap = Explorer.MiscIcons, Icon = "CallFunction", DisabledIcon = "Empty", OnClick = function()
			local obj = selection.List[1] and selection.List[1].Obj
			local PropertyTracker = Apps.PropertyTracker
			if obj and ensureTool(PropertyTracker) then PropertyTracker.TrackInstance(obj) end
		end})

		context:Register("SERIALIZE_INSTANCE",{Name = "Serialize Instance", IconMap = Explorer.MiscIcons, Icon = "Reference", DisabledIcon = "Empty", OnClick = function()
			local obj = selection.List[1] and selection.List[1].Obj
			local InstanceSerializer = Apps.InstanceSerializer
			if obj and ensureTool(InstanceSerializer) then InstanceSerializer.ShowForObject(obj) end
		end})

		context:Register("COPY_PROPERTIES",{Name = "Copy Properties", IconMap = Explorer.MiscIcons, Icon = "Copy", DisabledIcon = "Empty", OnClick = function()
			local obj = selection.List[1] and selection.List[1].Obj
			local PropertyCopier = Apps.PropertyCopier
			if obj and PropertyCopier then PropertyCopier.Copy(obj) end
		end})

		context:Register("PASTE_PROPERTIES",{Name = "Paste Properties", IconMap = Explorer.MiscIcons, Icon = "Paste", DisabledIcon = "Empty", OnClick = function()
			local PropertyCopier = Apps.PropertyCopier
			if PropertyCopier and PropertyCopier.HasCache() then
				for i = 1,#selection.List do
					local obj = selection.List[i].Obj
					if obj then PropertyCopier.Paste(obj) end
				end
			end
		end})
	end
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main
}
