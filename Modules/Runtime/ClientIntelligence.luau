--!strict
--[[
	Client Intelligence App Module
	Aggregates client-side snapshots, dependency hints, smart queries, timeline, and perf hints.
]]
local Main,Lib,Apps,Settings
local Explorer, ScriptViewer, RuntimeInspector, ClientIntelligence, InspectorHub
local API,RMD,env,service,plr,create,createSimple

local function initDeps(data)
	Main, Lib, Apps, Settings = data.Main, data.Lib, data.Apps, data.Settings
	API, RMD, env, service, plr = data.API, data.RMD, data.env, data.service, data.plr
	create, createSimple = data.create, data.createSimple
end

local function initAfterMain()
	Explorer = Apps.Explorer
	ScriptViewer = Apps.ScriptViewer
	RuntimeInspector = Apps.RuntimeInspector
	ClientIntelligence = Apps.ClientIntelligence
	InspectorHub = Apps.InspectorHub
end

local function main()
	local ClientIntelligence = {}
	local window, listFrame, statusLabel, queryBox
	local scanToken = 0
	local remoteClasses = {RemoteEvent=true, RemoteFunction=true, UnreliableRemoteEvent=true, BindableEvent=true, BindableFunction=true}

	local function setStatus(text) if statusLabel then statusLabel.Text = text end end
	local function getPath(obj)
        if Main and Main.SafeGetInstancePath then return Main.SafeGetInstancePath(obj) end
		local ok, path = pcall(function()
			if Explorer and Explorer.GetInstancePath then return Explorer.GetInstancePath(obj) end
			return obj:GetFullName()
		end)
		return ok and tostring(path) or tostring(obj)
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
	local function formatAge(epoch)
		local stamp = tonumber(epoch or 0)
		if not stamp or stamp <= 0 then return "unknown" end
		local age = math.max(0, os.time() - stamp)
		if age < 60 then return ("%ds ago"):format(age) end
		if age < 3600 then return ("%dm ago"):format(math.floor(age / 60)) end
		if age < 86400 then return ("%dh ago"):format(math.floor(age / 3600)) end
		return ("%dd ago"):format(math.floor(age / 86400))
	end
	local function formatCachedHit(row)
		local parts = {}
		if row.Source then parts[#parts + 1] = tostring(row.Source) end
		if row.MatchType then parts[#parts + 1] = tostring(row.MatchType) end
		if row.Score and row.Score > 0 then parts[#parts + 1] = "score " .. tostring(row.Score) end
		if row.Confidence and row.Confidence > 0 then parts[#parts + 1] = ("%d%%"):format(math.floor(row.Confidence * 100 + 0.5)) end
		if row.UpdatedAt and row.UpdatedAt > 0 then parts[#parts + 1] = "updated " .. formatAge(row.UpdatedAt) end
		if row.Snippet and tostring(row.Snippet) ~= "" then parts[#parts + 1] = tostring(row.Snippet) end
		return table.concat(parts, " | ")
	end
	local function getHelperIndexStatus()
		if env.ClientIndex and env.ClientIndex.GetIndexStatus then
			local status = env.ClientIndex.GetIndexStatus()
			if status then return status end
		end
		if not env.HelperServer or not env.HelperServer.IndexStatus then return nil end
		if env.HelperServer.IsActive and not env.HelperServer.IsActive(false) then return nil end
		return decodeJson(env.HelperServer.IndexStatus())
	end
	local function clearRows()
		if not listFrame then return end
		for _, child in pairs(listFrame:GetChildren()) do
			if child:IsA("GuiButton") or child:IsA("TextLabel") then child:Destroy() end
		end
	end
	local function pad(gui)
		local p = Instance.new("UIPadding")
		p.PaddingLeft = UDim.new(0,6)
		p.Parent = gui
	end
	local function divider(text)
		local label = createSimple("TextLabel",{BackgroundColor3=Settings.Theme.Main1, BorderSizePixel=0, Font=Enum.Font.SourceSansBold, Size=UDim2.new(1,-8,0,22), Text=text, TextColor3=Settings.Theme.Text, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left, Parent=listFrame})
		pad(label)
	end
	local function textRow(text, muted)
		local label = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Size=UDim2.new(1,-8,0,22), Text=text, TextColor3=muted and Settings.Theme.PlaceholderText or Settings.Theme.Text, TextSize=14, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=listFrame})
		pad(label)
	end
	local function actionRow(title, detail, callback)
		local row = createSimple("TextButton",{AutoButtonColor=false, BackgroundColor3=Settings.Theme.Main2, BorderColor3=Settings.Theme.Outline1, BorderSizePixel=1, Font=Enum.Font.SourceSans, Size=UDim2.new(1,-8,0,42), Text="", Parent=listFrame})
		createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,8,0,2), Size=UDim2.new(1,-16,0,18), Text=title, TextColor3=Settings.Theme.Text, TextSize=14, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
		createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,8,0,21), Size=UDim2.new(1,-16,0,18), Text=detail, TextColor3=Settings.Theme.PlaceholderText, TextSize=13, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
		Lib.ButtonAnim(row,{Mode=2, StartColor=Settings.Theme.Main2, HoverColor=Settings.Theme.ButtonHover, PressColor=Settings.Theme.ButtonPress, OutlineColor=Settings.Theme.Outline1})
		if callback then row.MouseButton1Click:Connect(callback) end
	end
	local function collectScripts()
		if env.ClientIndex and env.ClientIndex.RefreshSurface then return env.ClientIndex.RefreshSurface(false).AllScripts end
		if env.GetClientScripts then return env.GetClientScripts(true) end
		local out = {}
		for _, obj in pairs(game:GetDescendants()) do if obj:IsA("LuaSourceContainer") then table.insert(out, obj) end end
		return out
	end
	local function collectRemotes()
		if env.ClientIndex and env.ClientIndex.RefreshSurface then return env.ClientIndex.RefreshSurface(false).Remotes end
		if env.GetClientRemotes then return env.GetClientRemotes() end
		local out = {}
		for _, obj in pairs(game:GetDescendants()) do if remoteClasses[obj.ClassName] then table.insert(out, obj) end end
		return out
	end
	local function scriptByCacheKey()
		if env.ClientIndex and env.ClientIndex.GetScriptLookup then return env.ClientIndex.GetScriptLookup() end
		local map = {}
		if not env.DecompileCache or not env.DecompileCache.GetScriptKey then return map end
		for _, scr in pairs(collectScripts()) do
			local ok, key = pcall(env.DecompileCache.GetScriptKey, scr)
			if ok and key then map[key] = scr end
		end
		return map
	end
	local function showSnapshot()
		scanToken += 1
		clearRows()
		window:SetTitle("Client Intelligence - Snapshot")
		local scripts, remotes = collectScripts(), collectRemotes()
		local parts, guis, services = 0, 0, {}
		local liveObjects = (env.RefreshClientSurface and env.RefreshClientSurface(false, false).AllInstances) or game:GetDescendants()
		for _, obj in pairs(liveObjects) do
			if obj:IsA("BasePart") then parts += 1 end
			if obj:IsA("GuiObject") then guis += 1 end
			local root = obj
			while root.Parent and root.Parent ~= game do root = root.Parent end
			services[root.Name] = (services[root.Name] or 0) + 1
		end
		divider("Client Surface")
		textRow(("scripts: %d | remotes: %d | parts: %d | gui objects: %d"):format(#scripts,#remotes,parts,guis), false)
		local indexStatus = getHelperIndexStatus()
		if indexStatus and indexStatus.ok == true then
			textRow(("helper index: %d scripts | %d bytes | fresh %s"):format(tonumber(indexStatus.scripts or 0), tonumber(indexStatus.bytes or 0), formatAge(indexStatus.newestUpdatedAt)), false)
		else
			textRow("helper index: offline or empty", true)
		end
		divider("Largest Services")
		local rows = {}
		for name, count in pairs(services) do table.insert(rows, {Name=name, Count=count}) end
		table.sort(rows, function(a,b) return a.Count > b.Count end)
		for i = 1, math.min(10,#rows) do textRow(rows[i].Name .. " - " .. rows[i].Count .. " descendants", true) end
		if RuntimeInspector and RuntimeInspector.GetBuffers then
			local buffers = RuntimeInspector.GetBuffers()
			local counts = {}
			for _, call in ipairs(buffers.RemoteCall or {}) do counts[call.Path] = (counts[call.Path] or 0) + 1 end
			divider("Hot Runtime Remotes")
			local hot = {}
			for path, count in pairs(counts) do table.insert(hot, {Path=path, Count=count}) end
			table.sort(hot, function(a,b) return a.Count > b.Count end)
			for i = 1, math.min(12,#hot) do textRow(hot[i].Count .. " calls | " .. hot[i].Path, false) end
			if #hot == 0 then textRow("No runtime remote calls captured yet.", true) end
		end
		setStatus("Snapshot ready.")
		window:Show()
	end
	local function showDependencies()
		scanToken += 1
		local token = scanToken
		clearRows()
		window:SetTitle("Client Intelligence - Dependencies")
		divider("Dependency Graph Hints")
		setStatus("Scanning cached scripts...")
		window:Show()
		task.spawn(function()
			if not env.DecompileCache or not env.DecompileCache.GetEntries or not env.isfile then textRow("Cache unavailable. Run Code Search > Index Scripts first.", true); return end
			local entries, cacheDir = env.DecompileCache.GetEntries()
			local byKey, remotes = scriptByCacheKey(), collectRemotes()
			local scanned, shown = 0, 0
			for key, entry in pairs(entries) do
				if token ~= scanToken then return end
				if entry.File and env.isfile(cacheDir .. "/" .. tostring(entry.File)) then
					local ok, source = pcall(env.readfile, cacheDir .. "/" .. tostring(entry.File))
					if ok and type(source) == "string" then
						scanned += 1
						local lower = source:lower()
						for block in source:gmatch("require%s*%b()") do
							shown += 1
							actionRow("require link | " .. tostring(entry.Path or entry.Name), block:gsub("\n"," "), function() local scr = byKey[key]; if scr and ScriptViewer then ScriptViewer.ViewScript(scr) end end)
							if shown >= 60 then break end
						end
						for _, remote in ipairs(remotes) do
							if #remote.Name >= 2 and lower:find(remote.Name:lower(), 1, true) then
								shown += 1
								actionRow("remote mention | " .. remote.Name, tostring(entry.Path or entry.Name), function() local scr = byKey[key]; if scr and ScriptViewer then ScriptViewer.ViewScript(scr) end end)
								break
							end
						end
					end
				end
				if shown >= 80 then textRow("More results omitted.", true); break end
				if scanned % 20 == 0 then setStatus(("Scanned %d cached scripts..."):format(scanned)); task.wait() end
			end
			if shown == 0 then textRow("No cached dependency hints found yet.", true) end
			setStatus(("Dependency scan complete: %d cached scripts."):format(scanned))
		end)
	end
	local function showSmartQuery()
		scanToken += 1
		local token = scanToken
		clearRows()
		local query = tostring(queryBox and queryBox.Text or ""):lower()
		window:SetTitle("Client Intelligence - Smart Query")
		if query == "" then textRow("Enter a keyword/path/class/remote name first.", true); window:Show(); return end
		setStatus("Querying client surface and cache...")
		window:Show()
		task.spawn(function()
			local found = 0
			divider("Live Instance Hits")
			local liveObjects = (env.RefreshClientSurface and env.RefreshClientSurface(false, false).AllInstances) or game:GetDescendants()
			for _, obj in pairs(liveObjects) do
				if token ~= scanToken then return end
				if obj.Name:lower():find(query,1,true) or obj.ClassName:lower():find(query,1,true) then
					found += 1
					actionRow(obj.Name .. " [" .. obj.ClassName .. "]", getPath(obj), function() if env.setclipboard then env.setclipboard(getPath(obj)) end end)
					if found >= 40 then break end
				end
			end
			if env.DecompileCache and env.DecompileCache.GetEntries and env.isfile then
				divider("Cached Code Hits")
				local byKey = scriptByCacheKey()
				if env.ClientIndex and env.ClientIndex.SearchCached then
					local rows = env.ClientIndex.SearchCached(query, function() return token == scanToken end, 80)
					for _, row in ipairs(rows) do
						local key, entry = row.Key, row.Entry or {}
						found += 1
						actionRow(tostring(entry.Path or entry.Name or key), formatCachedHit(row), function() local scr = byKey[key]; if scr and ScriptViewer then ScriptViewer.ViewScript(scr) end end)
					end
				else
					local entries, cacheDir = env.DecompileCache.GetEntries()
					for key, entry in pairs(entries) do
						if token ~= scanToken then return end
						if entry.File and env.isfile(cacheDir .. "/" .. tostring(entry.File)) then
							local ok, source = pcall(env.readfile, cacheDir .. "/" .. tostring(entry.File))
							if ok and type(source) == "string" and (source:lower():find(query,1,true) or tostring(entry.Path or ""):lower():find(query,1,true)) then
								found += 1
								actionRow(tostring(entry.Path or entry.Name), "cached source hit", function() local scr = byKey[key]; if scr and ScriptViewer then ScriptViewer.ViewScript(scr) end end)
								if found >= 80 then break end
							end
						end
						task.wait()
					end
				end
			end
			setStatus(("Smart query complete: %d result(s)."):format(found))
		end)
	end
	local function showIndexHealth()
		clearRows()
		window:SetTitle("Client Intelligence - Index")
		divider("Semantic Index")
		local status = getHelperIndexStatus()
		if status and status.ok == true then
			textRow(("helper scripts: %d | bytes: %d"):format(tonumber(status.scripts or 0), tonumber(status.bytes or 0)), false)
			textRow(("oldest: %s | newest: %s"):format(formatAge(status.oldestUpdatedAt), formatAge(status.newestUpdatedAt)), true)
		else
			textRow("Helper index unavailable. Run the helper and Code Search > Index Scripts.", true)
		end
		if env.DecompileCache and env.DecompileCache.GetEntries then
			local entries = env.DecompileCache.GetEntries()
			local count = 0
			for _ in pairs(entries) do count += 1 end
			textRow("local cache entries: " .. count, false)
		end
		local surface = env.ClientIndex and env.ClientIndex.RefreshSurface and env.ClientIndex.RefreshSurface(false)
		if surface then
			textRow(("client surface: %d instances | %d scripts | %d remotes"):format(#surface.AllInstances, #surface.AllScripts, #surface.Remotes), false)
		end
		setStatus("Index health ready.")
		window:Show()
	end
	local function showTimeline()
		clearRows()
		window:SetTitle("Client Intelligence - Timeline")
		if not RuntimeInspector or not RuntimeInspector.GetBuffers then textRow("Runtime Inspector data unavailable.", true); return end
		local buffers = RuntimeInspector.GetBuffers()
		divider("Recent Remote Calls")
		for i, call in ipairs(buffers.RemoteCall or {}) do if i > 40 then break end; textRow(call.Method .. " | " .. call.Path, false) end
		divider("Recent Correlations")
		for i, item in ipairs(buffers.Correlation or {}) do if i > 40 then break end; textRow(("%s -> packet %s | %.3fs"):format(item.Method, tostring(item.PacketId), item.Delta or 0), true) end
		setStatus("Timeline uses Runtime Inspector buffers.")
		window:Show()
	end
	local function showPerf()
		clearRows()
		window:SetTitle("Client Intelligence - Performance")
		divider("Performance Hints")
		local guiCount = 0
		pcall(function() for _, _ in pairs(Main.GetSecureContainer():GetDescendants()) do guiCount += 1 end end)
		textRow("DEX++ UI descendants: " .. guiCount, guiCount > 2500)
		if env.DecompileCache and env.DecompileCache.GetEntries then
			local entries = env.DecompileCache.GetEntries()
			local count = 0
			for _ in pairs(entries) do count += 1 end
			textRow("Cached decompiled scripts: " .. count, false)
		end
		textRow("RemoteSpy and Runtime Inspector now rate-limit UI updates; keep raw packet samples off unless needed.", true)
		setStatus("Performance summary ready.")
		window:Show()
	end
	local function showHub()
		if InspectorHub and InspectorHub.ShowSnapshot then
			InspectorHub.ShowSnapshot()
			setStatus("Opened Inspector Hub snapshot.")
		else
			setStatus("Inspector Hub is unavailable.")
		end
	end
	local function makeButton(parent, text, x, w, callback)
		local b = createSimple("TextButton",{AutoButtonColor=false, BackgroundColor3=Settings.Theme.Button, BorderColor3=Settings.Theme.Outline2, Font=Enum.Font.SourceSans, Position=UDim2.new(0,x,0,4), Size=UDim2.new(0,w,0,22), Text=text, TextColor3=Settings.Theme.Text, TextSize=14, Parent=parent})
		b.MouseButton1Click:Connect(callback)
		Lib.ButtonAnim(b,{Mode=2, StartColor=Settings.Theme.Button, HoverColor=Settings.Theme.ButtonHover, PressColor=Settings.Theme.ButtonPress, OutlineColor=Settings.Theme.Outline2})
	end
	ClientIntelligence.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Client Intelligence")
		window:Resize(660,430)
		ClientIntelligence.Window = window
		local content = window.GuiElems.Content
		local toolbar = createSimple("Frame",{BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, Size=UDim2.new(1,0,0,60), Parent=content})
		queryBox = createSimple("TextBox",{BackgroundColor3=Settings.Theme.TextBox, BorderColor3=Settings.Theme.Outline3, ClearTextOnFocus=false, Font=Enum.Font.SourceSans, PlaceholderColor3=Settings.Theme.PlaceholderText, PlaceholderText="keyword / remote / class / path", Position=UDim2.new(0,6,0,32), Size=UDim2.new(1,-12,0,22), Text="", TextColor3=Settings.Theme.Text, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left, Parent=toolbar})
		makeButton(toolbar,"Snapshot",6,72,showSnapshot)
		makeButton(toolbar,"Deps",84,54,showDependencies)
		makeButton(toolbar,"Query",144,54,showSmartQuery)
		makeButton(toolbar,"Timeline",204,72,showTimeline)
		makeButton(toolbar,"Perf",282,50,showPerf)
		makeButton(toolbar,"Index",338,52,showIndexHealth)
		makeButton(toolbar,"Hub",396,46,showHub)
		statusLabel = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,450,0,4), Size=UDim2.new(1,-456,0,22), Text="Client-side intelligence dashboard.", TextColor3=Settings.Theme.PlaceholderText, TextSize=14, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=toolbar})
		listFrame = createSimple("ScrollingFrame",{Active=true, AutomaticCanvasSize=Enum.AutomaticSize.Y, BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, BottomImage="", CanvasSize=UDim2.new(0,0,0,0), Position=UDim2.new(0,0,0,60), ScrollBarImageColor3=Color3.fromRGB(70,70,70), ScrollBarThickness=10, Size=UDim2.new(1,0,1,-60), TopImage="", Parent=content})
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0,4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = listFrame
		local p = Instance.new("UIPadding")
		p.PaddingBottom, p.PaddingLeft, p.PaddingRight, p.PaddingTop = UDim.new(0,6), UDim.new(0,4), UDim.new(0,4), UDim.new(0,4)
		p.Parent = listFrame
		queryBox.FocusLost:Connect(function(enterPressed) if enterPressed then showSmartQuery() end end)
	end
	ClientIntelligence.ShowSnapshot = showSnapshot
	ClientIntelligence.ShowIndexHealth = showIndexHealth
	return ClientIntelligence
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
