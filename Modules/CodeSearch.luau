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
	local window, searchBox, statusLabel, resultsFrame
	local indexing = false
	local currentScriptsByKey = {}
	local indexedKeys = {}

	local function setStatus(text)
		if statusLabel then
			statusLabel.Text = text
		end
	end

	local function canUseCache()
		return env.DecompileCache and env.DecompileCache.IsReady and env.DecompileCache.IsReady()
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

	local function addResult(entryKey, entry, query, source)
		local row = Instance.new("TextButton")
		row.AutoButtonColor = false
		row.BackgroundColor3 = Settings.Theme.Main1
		row.BorderColor3 = Settings.Theme.Outline1
		row.Size = UDim2.new(1,-8,0,44)
		row.Text = ""
		row.Parent = resultsFrame

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.SourceSans
		name.Position = UDim2.new(0,8,0,3)
		name.Size = UDim2.new(1,-16,0,18)
		name.Text = tostring(entry.Path or entry.Name or entryKey)
		name.TextColor3 = Settings.Theme.Text
		name.TextSize = 14
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Parent = row

		local lowerSource = source:lower()
		local startIndex = lowerSource:find(query, 1, true) or 1
		local snippetStart = math.max(1, startIndex - 45)
		local snippet = source:sub(snippetStart, math.min(#source, startIndex + 95)):gsub("\r", " "):gsub("\n", " ")

		local detail = Instance.new("TextLabel")
		detail.BackgroundTransparency = 1
		detail.Font = Enum.Font.SourceSans
		detail.Position = UDim2.new(0,8,0,22)
		detail.Size = UDim2.new(1,-16,0,18)
		detail.Text = snippet
		detail.TextColor3 = Settings.Theme.PlaceholderText
		detail.TextSize = 13
		detail.TextTruncate = Enum.TextTruncate.AtEnd
		detail.TextXAlignment = Enum.TextXAlignment.Left
		detail.Parent = row

		Lib.ButtonAnim(row,{Mode = 2, StartColor = Settings.Theme.Main1, HoverColor = Settings.Theme.ButtonHover, PressColor = Settings.Theme.ButtonPress, OutlineColor = Settings.Theme.Outline1})

		row.MouseButton1Click:Connect(function()
			local scriptInstance = currentScriptsByKey[entryKey]
			if scriptInstance and ScriptViewer and ScriptViewer.ViewScript then
				ScriptViewer.ViewScript(scriptInstance)
			else
				setStatus("Cached result found, but the live script instance is unavailable.")
			end
		end)
	end

	CodeSearch.Search = function()
		if not canUseCache() then
			clearResults()
			setStatus("Filesystem cache APIs are unavailable.")
			return
		end

		local query = tostring(searchBox.Text or ""):lower()
		clearResults()
		if query == "" then
			setStatus("Enter a keyword to search cached code.")
			return
		end

		rebuildScriptLookup()

		local entries, cacheDir = env.DecompileCache.GetEntries()
		local found = 0
		local scanned = 0

		for key, entry in pairs(entries) do
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

		setStatus(("Found %d result(s) in %d cached script(s)."):format(found, scanned))
	end

	CodeSearch.IndexScripts = function()
		if indexing then
			setStatus("Indexing is already running.")
			return
		end

		if not canUseCache() then
			setStatus("Filesystem cache APIs are unavailable.")
			return
		end

		indexing = true
		task.spawn(function()
			local scripts = collectScripts()
			local total = #scripts
			local decompiled = 0
			local cached = 0
			local failed = 0
			local batchCount = 0

			if total == 0 then
				indexing = false
				setStatus("No decompilable scripts found.")
				return
			end

			for i, scriptInstance in ipairs(scripts) do
				if not indexing then break end

				local percent = math.floor((i / total) * 1000) / 10
				
				-- Throttle UI updates to prevent layout/redraw stutters
				if i % 20 == 0 or i == total then
					setStatus(("Indexing: %d / %d (%.1f%%) | cached %d | new %d | failed %d"):format(i, total, percent, cached, decompiled, failed))
				end

				local key = getScriptKey(scriptInstance)
				if key and indexedKeys[key] and hasCachedFile(scriptInstance) then
					cached += 1
					batchCount += 1
					if batchCount % 100 == 0 then
						task.wait()
					end
					continue
				end

				if hasCachedFile(scriptInstance) then
					if key then indexedKeys[key] = true end
					cached += 1
					batchCount += 1
					if batchCount % 100 == 0 then
						task.wait()
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
				else
					failed += 1
				end

				task.wait(0.08)
			end

			indexing = false
			rebuildScriptLookup()
			if env.GetClientSurfaceCoverage then
				local coverage = env.GetClientSurfaceCoverage()
				setStatus(("Index complete: %d cached, %d decompiled, %d failed. Surface: %d scripts, %d remotes."):format(cached, decompiled, failed, coverage.AllScripts, coverage.Remotes))
			else
				setStatus(("Index complete: %d cached, %d decompiled, %d failed."):format(cached, decompiled, failed))
			end
		end)
	end

	CodeSearch.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Code Search")
		window:Resize(520,360)
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
		searchBox.Size = UDim2.new(1,-188,0,22)
		searchBox.Text = ""
		searchBox.TextColor3 = Settings.Theme.Text
		searchBox.TextSize = 14
		searchBox.TextXAlignment = Enum.TextXAlignment.Left
		searchBox.Parent = toolbar

		local indexButton = makeButton(toolbar, "Index Scripts", UDim2.new(1,-176,0,6), UDim2.new(0,92,0,22))
		local searchButton = makeButton(toolbar, "Search", UDim2.new(1,-78,0,6), UDim2.new(0,72,0,22))

		statusLabel = Instance.new("TextLabel")
		statusLabel.BackgroundTransparency = 1
		statusLabel.Font = Enum.Font.SourceSans
		statusLabel.Position = UDim2.new(0,6,0,32)
		statusLabel.Size = UDim2.new(1,-12,0,20)
		statusLabel.Text = "Index scripts to populate the decompile cache."
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
