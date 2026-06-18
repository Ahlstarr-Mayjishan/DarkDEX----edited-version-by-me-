--!nocheck
--[[
	Code Search App Module

	Indexes decompiled script cache and searches cached source files.
]]

-- Common Locals
local Main,Lib,Apps,Settings -- Main Containers
local Explorer, Properties, ScriptViewer, CodeSearch, Notebook -- Major Apps
local API,RMD,env,service,plr,create,createSimple -- Main Locals

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
	Explorer = Apps.Explorer
	Properties = Apps.Properties
	ScriptViewer = Apps.ScriptViewer
	CodeSearch = Apps.CodeSearch
	Notebook = Apps.Notebook
end

local function main()
	local CodeSearch = {}
	local window, searchBox, statusLabel, resultsFrame, sidePanel, sideTitle, sidePath, sideMeta, sidePreview, sideBadges, lowImpactButton, resultContextMenu
	local indexing = false
	local searching = false
	local cancelRequested = false
	local operationId = 0
	local currentScriptsByKey = {}
	local resultRecords = {}
	local resultRows = {}
	local selectedRecord = nil
	local selectedRow = nil
	local pinnedKeys = {}
	local reviewedKeys = {}
	local indexedKeys = {}
	local helperIndexedKeys = {}

	local function setStatus(text)
		if statusLabel then
			statusLabel.Text = text
		end
	end

	local function reportTool(state)
		if Main and Main.ReportToolState then
			state.StatusText = statusLabel and statusLabel.Text or state.StatusText
			pcall(Main.ReportToolState, "Code Search", state)
		end
	end

	local function beginOperation()
		operationId += 1
		cancelRequested = false
		return operationId
	end

	local function shouldCancel(token)
		return cancelRequested or token ~= operationId
	end

	local function canUseCache()
		return env.DecompileCache and env.DecompileCache.IsReady and env.DecompileCache.IsReady()
	end

	local function isLowImpactIndex()
		return not Settings.Decompiler or Settings.Decompiler.CodeSearchLowImpact ~= false
	end

	local function updateLowImpactButton()
		if not lowImpactButton then return end
		if isLowImpactIndex() then
			lowImpactButton.Text = "Low ON"
			lowImpactButton.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
		else
			lowImpactButton.Text = "Full"
			lowImpactButton.BackgroundColor3 = Color3.fromRGB(234, 179, 8)
		end
	end

	local function decodeJson(body)
		local httpService = service and service.HttpService
		if not httpService then
			local ok, resolved = pcall(game.GetService, game, "HttpService")
			if ok then httpService = resolved end
		end
		if not httpService or type(body) ~= "string" then return nil end
		local ok, decoded = pcall(function()
			return httpService:JSONDecode(body)
		end)
		return ok and decoded or nil
	end

	local function isSearchableScript(obj)
		return typeof(obj) == "Instance" and env.isViableDecompileScript and env.isViableDecompileScript(obj)
	end

	local function collectScripts()
		if env.ClientIndex and env.ClientIndex.RefreshSurface then
			return env.ClientIndex.RefreshSurface(false).ViableScripts
		end
		if env.GetClientScripts then
			return env.GetClientScripts(false)
		end

		local scripts = {}
		for _, obj in pairs(game:GetDescendants()) do
			if isSearchableScript(obj) then
				table.insert(scripts, obj)
			end
		end

		if env.getnilinstances then
			local success, nilInstances = pcall(env.getnilinstances)
			if success and type(nilInstances) == "table" then
				for _, obj in pairs(nilInstances) do
					if isSearchableScript(obj) then
						table.insert(scripts, obj)
					end
				end
			end
		end

		return scripts
	end

	local function rebuildScriptLookup()
		table.clear(currentScriptsByKey)
		if env.ClientIndex and env.ClientIndex.GetScriptLookup then
			for key, scriptInstance in pairs(env.ClientIndex.GetScriptLookup()) do
				currentScriptsByKey[key] = scriptInstance
			end
			return
		end
		if not env.DecompileCache or not env.DecompileCache.GetScriptKey then return end

		for _, scriptInstance in pairs(collectScripts()) do
			local success, key = pcall(env.DecompileCache.GetScriptKey, scriptInstance)
			if success and key then
				currentScriptsByKey[key] = scriptInstance
			end
		end
	end

	local function getScriptKey(scriptInstance)
		if not env.DecompileCache or not env.DecompileCache.GetScriptKey then return nil end
		local success, key = pcall(env.DecompileCache.GetScriptKey, scriptInstance)
		return success and key or nil
	end

	local function hasFreshCache(scriptInstance)
		if not env.DecompileCache or not env.DecompileCache.HasFresh then return false end
		local success, fresh = pcall(env.DecompileCache.HasFresh, scriptInstance)
		return success and fresh == true
	end

	local function hasCachedFile(scriptInstance)
		if not env.DecompileCache or not env.DecompileCache.HasCachedFile then
			return hasFreshCache(scriptInstance)
		end
		local success, cachedFile = pcall(env.DecompileCache.HasCachedFile, scriptInstance)
		return success and cachedFile == true
	end

	local function clearResults()
		if not resultsFrame then return end
		for _, child in pairs(resultsFrame:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		table.clear(resultRecords)
		table.clear(resultRows)
		selectedRecord = nil
		selectedRow = nil
		updateInspector(nil)
	end

	local function makeButton(parent, text, position, size)
		local button = Instance.new("TextButton")
		button.AutoButtonColor = false
		button.BackgroundColor3 = Settings.Theme.Button
		button.BorderColor3 = Settings.Theme.Outline2
		button.Font = Enum.Font.SourceSans
		button.Position = position
		button.Size = size
		button.Text = text
		button.TextColor3 = Settings.Theme.Text
		button.TextSize = 14
		button.Parent = parent
		Lib.ButtonAnim(button,{Mode = 2, StartColor = Settings.Theme.Button, HoverColor = Settings.Theme.ButtonHover, PressColor = Settings.Theme.ButtonPress, OutlineColor = Settings.Theme.Outline2})
		return button
	end

	local function ensureTool(tool)
		if not tool then return false end
		if tool.EnsureInit then
			return tool.EnsureInit()
		end
		return true
	end

	local function sanitizeFilePart(text)
		text = tostring(text or "script")
		text = text:gsub("[\r\n\t]", " "):gsub("[<>:\"/\\|%?%*]", "_"):gsub("%s+", "_")
		if #text > 90 then text = text:sub(#text - 89) end
		if text == "" then text = "script" end
		return text
	end

	local function ensureFolder(path)
		if not env.makefolder or not env.isfolder then return false end
		local cur = ""
		for part in tostring(path):gmatch("[^/]+") do
			cur = cur == "" and part or (cur .. "/" .. part)
			if not env.isfolder(cur) then
				pcall(env.makefolder, cur)
			end
		end
		return true
	end

	local function resolveScript(record)
		if not record then return nil end
		return currentScriptsByKey[record.Key]
	end

	local function getRecordPath(record)
		local inst = resolveScript(record)
		if inst and Main and Main.SafeGetInstancePath then
			local ok, path = pcall(Main.SafeGetInstancePath, inst)
			if ok and path then return tostring(path) end
		end
		if inst and Explorer and Explorer.GetInstancePath then
			local ok, path = pcall(Explorer.GetInstancePath, inst)
			if ok and path then return tostring(path) end
		end
		if record and record.Entry then
			return tostring(record.Entry.Path or record.Entry.Name or record.Key)
		end
		return "?"
	end

	local function readRecordSource(record)
		if not record then return nil end
		local inst = resolveScript(record)
		if inst and env.DecompileCache and env.DecompileCache.Read then
			local ok, source = pcall(env.DecompileCache.Read, inst)
			if ok and type(source) == "string" then return source end
		end
		if record.Source and record.Source ~= "" then return record.Source end
		if env.DecompileCache and env.DecompileCache.GetEntries and env.readfile and env.isfile then
			local entries, cacheDir = env.DecompileCache.GetEntries()
			local entry = entries and entries[record.Key]
			local file = entry and entry.File
			if file then
				local path = cacheDir .. "/" .. tostring(file)
				if env.isfile(path) then
					local ok, source = pcall(env.readfile, path)
					if ok and type(source) == "string" then return source end
				end
			end
		end
		return nil
	end

	local function copyText(text, okMessage)
		if not env.setclipboard then
			setStatus("Clipboard API is unavailable.")
			return false
		end
		env.setclipboard(tostring(text or ""))
		setStatus(okMessage or "Copied to clipboard.")
		return true
	end

	local function buildAIContext(record)
		local source = readRecordSource(record) or "-- source unavailable"
		local path = getRecordPath(record)
		local entry = record.Entry or {}
		local query = tostring(record.Query or searchBox.Text or "")
		local lines = {
			"DEX++ Code Search context",
			"Script: " .. path,
			"Class: " .. tostring(entry.ClassName or "LuaSourceContainer"),
			"Name: " .. tostring(entry.Name or path:match("[^%.%[%]]+$") or record.Key),
			"Search query: " .. query,
			"Matched snippet:",
			tostring(record.Snippet or ""),
			"",
			"Task for AI:",
			"Explain what this script likely does, why this match matters, and what other scripts/remotes I should inspect next.",
			"",
			"Source:",
			source,
		}
		return table.concat(lines, "\n")
	end

	local function analyzeSource(source)
		source = tostring(source or "")
		local checks = {
			{"Remote", "FireServer%(", "InvokeServer%(", "OnClientEvent"},
			{"Require", "require%s*%("},
			{"HTTP", "HttpGet", "HttpPost", "request%s*%("},
			{"Dynamic", "loadstring", "getfenv", "setfenv"},
			{"Hook", "hookmetamethod", "hookfunction", "getrawmetatable"},
			{"FS", "writefile", "readfile", "appendfile"},
			{"GC", "getgc", "getconnections"},
		}
		local badges = {}
		for _, check in ipairs(checks) do
			for i = 2, #check do
				if source:find(check[i]) then
					badges[#badges + 1] = check[1]
					break
				end
			end
		end
		return badges
	end

	local function saveRecordToFile(record)
		if not env.writefile or not env.makefolder then
			setStatus("writefile/makefolder is unavailable.")
			return nil
		end
		local source = readRecordSource(record)
		if not source then
			setStatus("Source is unavailable for this result.")
			return nil
		end
		ensureFolder("dex/code_search")
		local path = getRecordPath(record)
		local filePath = "dex/code_search/" .. sanitizeFilePart(path) .. ".luau"
		local ok, err = pcall(env.writefile, filePath, source)
		if not ok then
			setStatus("Save failed: " .. tostring(err))
			return nil
		end
		setStatus("Saved source to " .. filePath)
		return filePath
	end

	local function formatAge(epoch)
		local stamp = tonumber(epoch or 0)
		if not stamp or stamp <= 0 then return nil end
		local age = math.max(0, os.time() - stamp)
		if age < 60 then return ("%ds ago"):format(age) end
		if age < 3600 then return ("%dm ago"):format(math.floor(age / 60)) end
		if age < 86400 then return ("%dh ago"):format(math.floor(age / 3600)) end
		return ("%dd ago"):format(math.floor(age / 86400))
	end

	local function formatHelperMeta(metadata)
		if type(metadata) ~= "table" then return "" end
		local parts = {}
		local score = tonumber(metadata.Score or metadata.score or 0)
		if score > 0 then parts[#parts + 1] = ("score %d"):format(score) end
		local matchType = tostring(metadata.MatchType or metadata.matchType or "")
		if matchType ~= "" then parts[#parts + 1] = matchType end
		local confidence = tonumber(metadata.Confidence or metadata.confidence or 0)
		if confidence > 0 then
			parts[#parts + 1] = ("%d%%"):format(math.floor(confidence * 100 + 0.5))
		end
		local updated = formatAge(metadata.UpdatedAt or metadata.updatedAt)
		if updated then parts[#parts + 1] = "updated " .. updated end

		local analysis = metadata.Analysis or metadata.analysis
		if type(analysis) == "table" then
			local stats = {}
			if analysis.lines then stats[#stats + 1] = tostring(analysis.lines) .. " lines" end
			if analysis.functions then stats[#stats + 1] = tostring(analysis.functions) .. " fn" end
			if analysis.remoteCalls then stats[#stats + 1] = tostring(analysis.remoteCalls) .. " remotes" end
			if analysis.riskySignals then stats[#stats + 1] = tostring(analysis.riskySignals) .. " risky" end
			if #stats > 0 then parts[#parts + 1] = table.concat(stats, " | ") end
			if type(analysis.topIdentifiers) == "table" and #analysis.topIdentifiers > 0 then
				local preview = {}
				for i = 1, math.min(#analysis.topIdentifiers, 3) do
					preview[#preview + 1] = tostring(analysis.topIdentifiers[i])
				end
				parts[#parts + 1] = "ids: " .. table.concat(preview, ", ")
			end
		end

		local matched = tostring(metadata.MatchedToken or metadata.matchedToken or "")
		if matched ~= "" then parts[#parts + 1] = 'token "' .. matched .. '"' end
		return table.concat(parts, " | ")
	end

	local function updateRowState(row, record)
		if not row or not record then return end
		local selected = selectedRecord == record
		row.BackgroundColor3 = selected and Settings.Theme.ButtonHover or Settings.Theme.Main1
		local marker = row:FindFirstChild("Marker")
		if marker then
			marker.Visible = selected or pinnedKeys[record.Key] == true or reviewedKeys[record.Key] == true
			if selected then
				marker.BackgroundColor3 = Settings.Theme.Highlight
			elseif pinnedKeys[record.Key] then
				marker.BackgroundColor3 = Color3.fromRGB(234, 179, 8)
			else
				marker.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
			end
		end
	end

	local function updateInspector(record)
		if not sidePanel then return end
		if not record then
			sideTitle.Text = "Result inspector"
			sidePath.Text = "Right-click a result to inspect actions."
			sideMeta.Text = "No result selected."
			sidePreview.Text = ""
			sideBadges.Text = ""
			return
		end

		local entry = record.Entry or {}
		local path = getRecordPath(record)
		local source = readRecordSource(record)
		local badges = analyzeSource(source or "")
		local badgeText = #badges > 0 and table.concat(badges, "  ") or "No risk badges"

		sideTitle.Text = tostring(entry.Name or path:match("[^%.%[%]]+$") or "Script")
		sidePath.Text = path
		sideMeta.Text = tostring(entry.ClassName or "LuaSourceContainer") .. " | key " .. tostring(record.Key)
			.. (pinnedKeys[record.Key] and " | pinned" or "")
			.. (reviewedKeys[record.Key] and " | reviewed" or "")
		sideBadges.Text = badgeText
		sidePreview.Text = tostring(record.Snippet or "") .. (source and ("\n\n" .. source:sub(1, 1600)) or "\n\nSource unavailable.")
	end

	local function selectRecord(record, row)
		if selectedRow and selectedRecord then
			updateRowState(selectedRow, selectedRecord)
		end
		selectedRecord = record
		selectedRow = row
		updateRowState(row, record)
		updateInspector(record)
	end

	local function openScript(record)
		local scriptInstance = resolveScript(record)
		if scriptInstance and ScriptViewer and ScriptViewer.ViewScript then
			ScriptViewer.ViewScript(scriptInstance)
			setStatus("Opened in Script Viewer.")
		else
			setStatus("Live script instance is unavailable.")
		end
	end

	local function showInExplorer(record)
		local scriptInstance = resolveScript(record)
		if not scriptInstance or not Explorer then
			setStatus("Live script instance is unavailable.")
			return
		end
		local ok = false
		if Explorer.SelectObject then
			ok = Explorer.SelectObject(scriptInstance)
		elseif Explorer.ViewObj then
			Explorer.ViewObj(scriptInstance)
			ok = true
		end
		setStatus(ok and "Focused result in Explorer." or "Explorer node is unavailable.")
	end

	local function findReferences(record)
		local path = getRecordPath(record)
		local name = tostring((record.Entry and record.Entry.Name) or path:match("[^%.%[%]]+$") or "")
		searchBox.Text = name ~= "" and name or path
		CodeSearch.Search()
	end

	local function openRelations(record)
		local scriptInstance = resolveScript(record)
		local relations = Apps.ScriptRelations
		if scriptInstance and relations and ensureTool(relations) and relations.ShowForScript then
			relations.ShowForScript(scriptInstance)
		else
			setStatus("Script Relations is unavailable for this result.")
		end
	end

	local function openDependencyGraph()
		local graph = Apps.DependencyGraph
		if graph and ensureTool(graph) then
			if graph.Window then graph.Window:Show() end
			if graph.Scan then graph.Scan() end
			setStatus("Dependency Graph opened.")
		else
			setStatus("Dependency Graph is unavailable.")
		end
	end

	local function inspectModuleReturn(record)
		local scriptInstance = resolveScript(record)
		if not scriptInstance or not scriptInstance:IsA("ModuleScript") then
			setStatus("Selected result is not a live ModuleScript.")
			return
		end
		local ok, value = pcall(require, scriptInstance)
		if not ok then
			setStatus("require() failed: " .. tostring(value))
			return
		end
		local editor = Apps.TableEditor
		if editor and ensureTool(editor) and editor.LoadTable then
			editor.LoadTable(value, getRecordPath(record))
			if editor.Window then editor.Window:Show() end
			setStatus("Module return loaded into Table Editor.")
		else
			copyText(tostring(value), "Table Editor unavailable; copied return tostring().")
		end
	end

	local function exportAllResults()
		if not env.writefile or not env.makefolder then
			setStatus("writefile/makefolder is unavailable.")
			return
		end
		ensureFolder("dex/code_search")
		local lines = {"# DEX++ Code Search Results", "", "Query: `" .. tostring(searchBox.Text or "") .. "`", ""}
		for _, record in pairs(resultRecords) do
			lines[#lines + 1] = "## " .. getRecordPath(record)
			lines[#lines + 1] = "- Class: " .. tostring(record.Entry and record.Entry.ClassName or "?")
			lines[#lines + 1] = "- Key: `" .. tostring(record.Key) .. "`"
			lines[#lines + 1] = "- Snippet: `" .. tostring(record.Snippet or "") .. "`"
			lines[#lines + 1] = ""
		end
		local filePath = "dex/code_search/results_" .. tostring(os.time()) .. ".md"
		local ok, err = pcall(env.writefile, filePath, table.concat(lines, "\n"))
		setStatus(ok and ("Exported results to " .. filePath) or ("Export failed: " .. tostring(err)))
	end

	local function addResult(entryKey, entry, query, source, snippetOverride, metadata)
		local row = Instance.new("TextButton")
		row.AutoButtonColor = false
		row.BackgroundColor3 = Settings.Theme.Main1
		row.BorderColor3 = Settings.Theme.Outline1
		row.Size = UDim2.new(1,-8,0,52)
		row.Text = ""
		row.Parent = resultsFrame

		local marker = Instance.new("Frame")
		marker.Name = "Marker"
		marker.BackgroundColor3 = Settings.Theme.Highlight
		marker.BorderSizePixel = 0
		marker.Position = UDim2.new(0,0,0,0)
		marker.Size = UDim2.new(0,3,1,0)
		marker.Visible = false
		marker.Parent = row

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.SourceSans
		name.Position = UDim2.new(0,10,0,3)
		name.Size = UDim2.new(1,-18,0,18)
		name.Text = tostring(entry.Path or entry.Name or entryKey)
		name.TextColor3 = Settings.Theme.Text
		name.TextSize = 14
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Parent = row

		local snippet = snippetOverride
		if not snippet then
			local lowerSource = source:lower()
			local startIndex = lowerSource:find(query, 1, true) or 1
			local snippetStart = math.max(1, startIndex - 45)
			snippet = source:sub(snippetStart, math.min(#source, startIndex + 95)):gsub("\r", " "):gsub("\n", " ")
		end

		local metaText = formatHelperMeta(metadata)
		if metaText ~= "" then
			snippet = snippet ~= "" and (snippet .. " | " .. metaText) or metaText
		end

		local detail = Instance.new("TextLabel")
		detail.BackgroundTransparency = 1
		detail.Font = Enum.Font.SourceSans
		detail.Position = UDim2.new(0,10,0,22)
		detail.Size = UDim2.new(1,-18,0,18)
		detail.Text = snippet
		detail.TextColor3 = Settings.Theme.PlaceholderText
		detail.TextSize = 13
		detail.TextTruncate = Enum.TextTruncate.AtEnd
		detail.TextXAlignment = Enum.TextXAlignment.Left
		detail.Parent = row

		Lib.ButtonAnim(row,{Mode = 2, StartColor = Settings.Theme.Main1, HoverColor = Settings.Theme.ButtonHover, PressColor = Settings.Theme.ButtonPress, OutlineColor = Settings.Theme.Outline1})

		local record = {
			Key = entryKey,
			Entry = entry,
			Query = query,
			Source = source,
			Snippet = snippet,
			Metadata = metadata,
		}
		resultRecords[entryKey] = record
		resultRows[entryKey] = row
		updateRowState(row, record)

		row.MouseButton1Click:Connect(function()
			selectRecord(record, row)
			openScript(record)
		end)
		row.MouseButton2Click:Connect(function()
			selectRecord(record, row)
			
			local menu = getResultContextMenu()
			menu:Clear()
			menu:Add({
				Name = "Open",
				OnClick = function() openScript(record) end
			})
			menu:Add({
				Name = "Focus in Explorer",
				OnClick = function() showInExplorer(record) end
			})
			menu:AddDivider()
			menu:Add({
				Name = "Copy Path",
				OnClick = function() copyText(getRecordPath(record), "Copied path.") end
			})
			menu:Add({
				Name = "Copy Source",
				OnClick = function()
					local source = readRecordSource(record)
					if source then copyText(source, "Copied source.") else setStatus("Source is unavailable.") end
				end
			})
			menu:Add({
				Name = "Copy AI Context",
				OnClick = function() copyText(buildAIContext(record), "Copied AI context.") end
			})
			menu:AddDivider()
			menu:Add({
				Name = "Save to File",
				OnClick = function() saveRecordToFile(record) end
			})
			menu:Add({
				Name = "Direct File Path",
				OnClick = function()
					local filePath = saveRecordToFile(record)
					if filePath then copyText(filePath, "Saved and copied file path.") end
				end
			})
			menu:AddDivider()
			menu:Add({
				Name = "Find References",
				OnClick = function() findReferences(record) end
			})
			menu:Add({
				Name = "Show Relations",
				OnClick = function() openRelations(record) end
			})
			menu:Add({
				Name = "Dependency Graph",
				OnClick = function() openDependencyGraph(record) end
			})
			menu:Add({
				Name = "Inspect Return",
				OnClick = function() inspectModuleReturn(record) end
			})
			menu:AddDivider()
			menu:Add({
				Name = pinnedKeys[record.Key] and "Unpin" or "Pin",
				OnClick = function()
					pinnedKeys[record.Key] = not pinnedKeys[record.Key]
					setStatus(pinnedKeys[record.Key] and "Pinned result." or "Unpinned result.")
					updateRowState(row, record)
				end
			})
			menu:Add({
				Name = reviewedKeys[record.Key] and "Mark Unreviewed" or "Mark Reviewed",
				OnClick = function()
					reviewedKeys[record.Key] = not reviewedKeys[record.Key]
					setStatus(reviewedKeys[record.Key] and "Marked as reviewed." or "Marked as not reviewed.")
					updateRowState(row, record)
				end
			})
			menu:AddDivider()
			menu:Add({
				Name = "Export All Results",
				OnClick = function() exportAllResults() end
			})
			menu:Show()
		end)
	end

	local function searchWithHelper(query)
		if not env.HelperServer or not env.HelperServer.SearchSource then return false end
		if env.HelperServer.IsActive and not env.HelperServer.IsActive(false) then return false end

		local body = env.HelperServer.SearchSource(query, 120)
		local decoded = decodeJson(body)
		if not decoded or decoded.ok ~= true or type(decoded.results) ~= "table" then
			return false
		end
		if tonumber(decoded.indexed or 0) <= 0 then
			return false
		end

		rebuildScriptLookup()
		local found = 0
		for _, item in ipairs(decoded.results) do
			local key = tostring(item.key or "")
			if key ~= "" then
				found += 1
				addResult(key, {
					Path = item.path,
					Name = item.name,
					ClassName = item.className,
				}, query, "", tostring(item.snippet or "helper source hit"), {
					Score = item.score,
					MatchType = item.matchType,
					MatchedToken = item.matchedToken,
					Confidence = item.confidence,
					UpdatedAt = item.updatedAt,
					Analysis = item.analysis,
				})
			end
		end
		setStatus(("Helper search: %d result(s) from %d indexed script(s)."):format(found, tonumber(decoded.indexed or 0)))
		return true
	end

	local function pushToHelperIndex(scriptInstance, key)
		if not key or not env.HelperServer or not env.HelperServer.IndexSource then return false end
		if helperIndexedKeys[key] then return false end
		if env.HelperServer.IsActive and not env.HelperServer.IsActive(false) then return false end
		if not env.DecompileCache or not env.DecompileCache.Read then return false end

		local okSource, source = pcall(env.DecompileCache.Read, scriptInstance)
		if not okSource or type(source) ~= "string" then return false end

		local okPath, path = pcall(function()
            if Main and Main.SafeGetInstancePath then return Main.SafeGetInstancePath(scriptInstance) end
			if Explorer and Explorer.GetInstancePath then return Explorer.GetInstancePath(scriptInstance) end
			return scriptInstance:GetFullName()
		end)
		local result = env.HelperServer.IndexSource(
			key,
			okPath and tostring(path) or scriptInstance:GetFullName(),
			scriptInstance.Name,
			scriptInstance.ClassName,
			source
		)
		if type(result) == "string" then
			helperIndexedKeys[key] = true
			return true
		end
		return false
	end

	CodeSearch.Search = function()
		if indexing then
			setStatus("Indexing is running. Press Stop before searching.")
			return
		end
		if searching then
			setStatus("Search is already running.")
			return
		end
		if not canUseCache() then
			clearResults()
			setStatus("Filesystem cache APIs are unavailable.")
			return
		end

		searching = true
		local token = beginOperation()
		local query = tostring(searchBox.Text or ""):lower()
		clearResults()
		if query == "" then
			setStatus("Enter a keyword to search cached code.")
			searching = false
			return
		end

		if searchWithHelper(query) then
			searching = false
			return
		end

		rebuildScriptLookup()

		local entries, cacheDir = env.DecompileCache.GetEntries()
		local found = 0
		local scanned = 0

		for key, entry in pairs(entries) do
			if shouldCancel(token) then
				searching = false
				setStatus(("Search stopped after scanning %d cached script(s)."):format(scanned))
				return
			end
			local file = entry.File
			if file then
				local path = cacheDir .. "/" .. tostring(file)
				if env.isfile(path) then
					local success, source = pcall(env.readfile, path)
					if success and type(source) == "string" then
						scanned += 1
						local lowerPath = tostring(entry.Path or ""):lower()
						if source:lower():find(query, 1, true) or lowerPath:find(query, 1, true) then
							found += 1
							addResult(key, entry, query, source)
						end
					end
				end
			end

			if scanned % 25 == 0 then
				task.wait()
			end
		end

		searching = false
		setStatus(("Found %d result(s) in %d cached script(s)."):format(found, scanned))
	end

	CodeSearch.IndexScripts = function()
		if indexing then
			setStatus("Indexing is already running.")
			reportTool({State = "indexing", Load = "high"})
			return
		end

		if not canUseCache() then
			setStatus("Filesystem cache APIs are unavailable.")
			reportTool({State = "unavailable", Load = "off"})
			return
		end

		indexing = true
		local token = beginOperation()
		reportTool({
			State = "indexing",
			Load = isLowImpactIndex() and "medium" or "high",
			LowImpact = isLowImpactIndex(),
			Progress = 0
		})
		task.spawn(function()
			local scripts = collectScripts()
			local total = #scripts
			local decompiled = 0
			local cached = 0
			local failed = 0
			local helperIndexed = 0
			local skipped = 0
			local batchCount = 0
			local lowImpact = isLowImpactIndex()

			if total == 0 then
				indexing = false
				setStatus("No decompilable scripts found.")
				reportTool({State = "idle", Load = "low", Progress = 1, Total = 0})
				return
			end

			for i, scriptInstance in ipairs(scripts) do
				if not indexing or shouldCancel(token) then
					indexing = false
					setStatus(("Index stopped: %d cached, %d decompiled, %d failed, %d helper."):format(cached, decompiled, failed, helperIndexed))
					reportTool({
						State = "stopped",
						Load = "low",
						Progress = total > 0 and (i / total) or 0,
						Total = total,
						Cached = cached,
						Decompiled = decompiled,
						Failed = failed,
						HelperIndexed = helperIndexed,
						Skipped = skipped
					})
					rebuildScriptLookup()
					return
				end

				local percent = math.floor((i / total) * 1000) / 10

				-- Throttle UI updates to prevent layout/redraw stutters
				if i % 20 == 0 or i == total then
					local mode = lowImpact and "Low impact" or "Full"
					setStatus(("%s indexing: %d / %d (%.1f%%) | cached %d | new %d | skipped %d | failed %d"):format(mode, i, total, percent, cached, decompiled, skipped, failed))
					reportTool({
						State = "indexing",
						Load = lowImpact and "medium" or "high",
						LowImpact = lowImpact,
						Progress = i / total,
						Total = total,
						Cached = cached,
						Decompiled = decompiled,
						Failed = failed,
						HelperIndexed = helperIndexed,
						Skipped = skipped
					})
				end

				local key = getScriptKey(scriptInstance)
				if key and indexedKeys[key] and hasCachedFile(scriptInstance) then
					cached += 1
					if pushToHelperIndex(scriptInstance, key) then helperIndexed += 1 end
					batchCount += 1
					if batchCount % 100 == 0 then
						task.wait()
					end
					continue
				end

				if hasCachedFile(scriptInstance) then
					if key then indexedKeys[key] = true end
					cached += 1
					if pushToHelperIndex(scriptInstance, key) then helperIndexed += 1 end
					batchCount += 1
					if batchCount % 100 == 0 then
						task.wait()
					end
					continue
				end

				if lowImpact then
					skipped += 1
					batchCount += 1
					if batchCount % 20 == 0 then
						task.wait(0.03)
					end
					continue
				end

				local success
				if env.DecompileQueue and env.DecompileQueue.Submit then
					success = pcall(env.DecompileQueue.Submit, scriptInstance, {Priority = 10})
				else
					success = pcall(env.decompile, scriptInstance)
				end
				if success then
					decompiled += 1
					if key then indexedKeys[key] = true end
					if key and pushToHelperIndex(scriptInstance, key) then helperIndexed += 1 end
				else
					failed += 1
				end

				task.wait(0.08)
			end

			indexing = false
			if shouldCancel(token) then
				setStatus(("Index stopped: %d cached, %d decompiled, %d failed, %d helper."):format(cached, decompiled, failed, helperIndexed))
				reportTool({
					State = "stopped",
					Load = "low",
					Progress = 1,
					Total = total,
					Cached = cached,
					Decompiled = decompiled,
					Failed = failed,
					HelperIndexed = helperIndexed,
					Skipped = skipped
				})
				rebuildScriptLookup()
				return
			end
			if helperIndexed > 0 and env.HelperServer and env.HelperServer.SaveSourceIndex then
				pcall(env.HelperServer.SaveSourceIndex)
			end
			rebuildScriptLookup()
			if env.GetClientSurfaceCoverage then
				local coverage = env.GetClientSurfaceCoverage()
				setStatus(("Index complete: %d cached, %d decompiled, %d skipped, %d failed, %d helper. Surface: %d scripts, %d remotes."):format(cached, decompiled, skipped, failed, helperIndexed, coverage.AllScripts, coverage.Remotes))
			else
				setStatus(("Index complete: %d cached, %d decompiled, %d skipped, %d failed, %d helper."):format(cached, decompiled, skipped, failed, helperIndexed))
			end
			reportTool({
				State = "idle",
				Load = "low",
				Progress = 1,
				Total = total,
				Cached = cached,
				Decompiled = decompiled,
				Failed = failed,
				HelperIndexed = helperIndexed,
				Skipped = skipped
			})
		end)
	end

	CodeSearch.Stop = function()
		if not indexing and not searching then
			setStatus("Nothing to stop.")
			reportTool({State = "idle", Load = "low"})
			return
		end
		cancelRequested = true
		operationId += 1
		indexing = false
		searching = false
		setStatus("Stopping current Code Search task...")
		reportTool({State = "stopping", Load = "low"})
	end

	CodeSearch.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Code Search")
		window:Resize(780,460)
		CodeSearch.Window = window

		local content = window.GuiElems.Content

		local toolbar = Instance.new("Frame")
		toolbar.BackgroundColor3 = Settings.Theme.Main2
		toolbar.BorderSizePixel = 0
		toolbar.Position = UDim2.new(0,0,0,0)
		toolbar.Size = UDim2.new(1,0,0,58)
		toolbar.Parent = content

		searchBox = Instance.new("TextBox")
		searchBox.BackgroundColor3 = Settings.Theme.TextBox
		searchBox.BorderColor3 = Settings.Theme.Outline3
		searchBox.ClearTextOnFocus = false
		searchBox.Font = Enum.Font.SourceSans
		searchBox.PlaceholderColor3 = Settings.Theme.PlaceholderText
		searchBox.PlaceholderText = "Search cached code"
		searchBox.Position = UDim2.new(0,6,0,6)
		searchBox.Size = UDim2.new(1,-246,0,22)
		searchBox.Text = ""
		searchBox.TextColor3 = Settings.Theme.Text
		searchBox.TextSize = 14
		searchBox.TextXAlignment = Enum.TextXAlignment.Left
		searchBox.Parent = toolbar

		local indexButton = makeButton(toolbar, "Index", UDim2.new(1,-234,0,6), UDim2.new(0,86,0,22))
		local searchButton = makeButton(toolbar, "Search", UDim2.new(1,-144,0,6), UDim2.new(0,66,0,22))
		local stopButton = makeButton(toolbar, "Stop", UDim2.new(1,-74,0,6), UDim2.new(0,68,0,22))
		lowImpactButton = makeButton(toolbar, "Low ON", UDim2.new(1,-82,0,32), UDim2.new(0,76,0,20))

		statusLabel = Instance.new("TextLabel")
		statusLabel.BackgroundTransparency = 1
		statusLabel.Font = Enum.Font.SourceSans
		statusLabel.Position = UDim2.new(0,6,0,32)
		statusLabel.Size = UDim2.new(1,-94,0,20)
		statusLabel.Text = "Low Impact is ON: Index uses cache/helper and skips new decompile."
		reportTool({State = "idle", Load = "low", LowImpact = isLowImpactIndex()})
		statusLabel.TextColor3 = Settings.Theme.PlaceholderText
		statusLabel.TextSize = 14
		statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
		statusLabel.TextXAlignment = Enum.TextXAlignment.Left
		statusLabel.Parent = toolbar

		resultsFrame = Instance.new("ScrollingFrame")
		resultsFrame.Active = true
		resultsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		resultsFrame.BackgroundColor3 = Settings.Theme.Main2
		resultsFrame.BorderSizePixel = 0
		resultsFrame.BottomImage = ""
		resultsFrame.CanvasSize = UDim2.new(0,0,0,0)
		resultsFrame.Position = UDim2.new(0,0,0,58)
		resultsFrame.ScrollBarImageColor3 = Color3.fromRGB(70,70,70)
		resultsFrame.ScrollBarThickness = 10
		resultsFrame.Size = UDim2.new(1,0,1,-58)
		resultsFrame.TopImage = ""
		resultsFrame.Parent = content

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0,4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = resultsFrame

		local padding = Instance.new("UIPadding")
		padding.PaddingBottom = UDim.new(0,6)
		padding.PaddingLeft = UDim.new(0,4)
		padding.PaddingRight = UDim.new(0,4)
		padding.PaddingTop = UDim.new(0,4)
		padding.Parent = resultsFrame

		indexButton.MouseButton1Click:Connect(CodeSearch.IndexScripts)
		searchButton.MouseButton1Click:Connect(CodeSearch.Search)
		stopButton.MouseButton1Click:Connect(CodeSearch.Stop)
		lowImpactButton.MouseButton1Click:Connect(function()
			Settings.Decompiler.CodeSearchLowImpact = not isLowImpactIndex()
			updateLowImpactButton()
			if isLowImpactIndex() then
				setStatus("Low Impact is ON: Index skips new decompile to reduce client stutter.")
			else
				setStatus("Full index is ON: Index may decompile uncached scripts and cause lag.")
			end
		end)
		updateLowImpactButton()
		searchBox.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				CodeSearch.Search()
			end
		end)
	end

	return CodeSearch
end

-- TODO: Remove when open source
if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
