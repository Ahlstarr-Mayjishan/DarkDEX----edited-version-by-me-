--!strict
--[[
	Inspector Hub
	Centralizes high-signal client inspection: surface snapshot, hot remotes,
	risk queue, and an exportable brief for handoff.
]]
local Main, Lib, Apps, Settings
local Explorer, ScriptViewer, RuntimeInspector, RemoteUsageMap, ClientIndex, InspectorHub
local API, RMD, env, service, plr, create, createSimple

local function initDeps(data)
	Main, Lib, Apps, Settings = data.Main, data.Lib, data.Apps, data.Settings
	API, RMD, env, service, plr = data.API, data.RMD, data.env, data.service, data.plr
	create, createSimple = data.create, data.createSimple
end

local function initAfterMain()
	Explorer = Apps.Explorer
	ScriptViewer = Apps.ScriptViewer
	RuntimeInspector = Apps.RuntimeInspector
	RemoteUsageMap = Apps.RemoteUsageMap
	ClientIndex = Apps.ClientIndex
	InspectorHub = Apps.InspectorHub
end

local function main()
	local InspectorHub = {}
	local window, listFrame, statusLabel
	local scanToken = 0
	local remoteClasses = {RemoteEvent=true, RemoteFunction=true, UnreliableRemoteEvent=true, BindableEvent=true, BindableFunction=true}
	local riskyRemoteWords = {"admin","ban","kick","cash","money","give","kill","rank","save","load","purchase","buy","set","fire"}
	local riskyScriptWords = {"backdoor","loader","webhook","require","loadstring","httpget","httppost","getfenv","setfenv"}

	local function setStatus(text)
		if statusLabel then statusLabel.Text = text end
	end
	local function getPath(obj)
		if Main and Main.SafeGetInstancePath then return Main.SafeGetInstancePath(obj) end
		local ok, path = pcall(function()
			if Explorer and Explorer.GetInstancePath then return Explorer.GetInstancePath(obj) end
			return obj:GetFullName()
		end)
		return ok and tostring(path) or tostring(obj)
	end
	local function getSurface(force)
		if ClientIndex and ClientIndex.RefreshSurface then
			return ClientIndex.RefreshSurface(force == true)
		end
		if env.RefreshClientSurface then
			return env.RefreshClientSurface(force == true, false)
		end
		local all, scripts, remotes = {}, {}, {}
		for _, obj in ipairs(game:GetDescendants()) do
			all[#all + 1] = obj
			if obj:IsA("LuaSourceContainer") then scripts[#scripts + 1] = obj end
			if remoteClasses[obj.ClassName] then remotes[#remotes + 1] = obj end
		end
		return {AllInstances=all, AllScripts=scripts, ViableScripts=scripts, Remotes=remotes}
	end
	local function clearRows()
		if not listFrame then return end
		for _, child in ipairs(listFrame:GetChildren()) do
			if child:IsA("GuiButton") or child:IsA("TextLabel") or child:IsA("Frame") then child:Destroy() end
		end
	end
	local function pad(gui)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 8)
		padding.Parent = gui
	end
	local function section(title)
		local label = createSimple("TextLabel",{BackgroundColor3=Settings.Theme.Main1, BorderSizePixel=0, Font=Enum.Font.SourceSansBold, Size=UDim2.new(1,-8,0,24), Text=title, TextColor3=Settings.Theme.Text, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left, Parent=listFrame})
		pad(label)
	end
	local function textRow(text, muted)
		local label = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Size=UDim2.new(1,-8,0,22), Text=text, TextColor3=muted and Settings.Theme.PlaceholderText or Settings.Theme.Text, TextSize=14, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=listFrame})
		pad(label)
	end
	local function actionRow(title, detail, callback)
		local row = createSimple("TextButton",{AutoButtonColor=false, BackgroundColor3=Settings.Theme.Main2, BorderColor3=Settings.Theme.Outline1, BorderSizePixel=1, Font=Enum.Font.SourceSans, Size=UDim2.new(1,-8,0,44), Text="", Parent=listFrame})
		createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSansBold, Position=UDim2.new(0,8,0,3), Size=UDim2.new(1,-16,0,18), Text=title, TextColor3=Settings.Theme.Text, TextSize=14, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
		createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,8,0,23), Size=UDim2.new(1,-16,0,18), Text=detail, TextColor3=Settings.Theme.PlaceholderText, TextSize=13, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
		Lib.ButtonAnim(row,{Mode=2, StartColor=Settings.Theme.Main2, HoverColor=Settings.Theme.ButtonHover, PressColor=Settings.Theme.ButtonPress, OutlineColor=Settings.Theme.Outline1})
		if callback then row.MouseButton1Click:Connect(callback) end
	end
	local function containsAny(text, words)
		local lower = tostring(text or ""):lower()
		for _, word in ipairs(words) do
			if lower:find(word, 1, true) then return word end
		end
		return nil
	end
	local function runtimeCounts()
		local counts, callers = {}, {}
		if not RuntimeInspector or not RuntimeInspector.GetBuffers then return counts, callers end
		local buffers = RuntimeInspector.GetBuffers()
		for _, call in ipairs(buffers.RemoteCall or {}) do
			local path = tostring(call.Path or "")
			counts[path] = (counts[path] or 0) + 1
			if call.Caller and tostring(call.Caller) ~= "unknown" then callers[path] = tostring(call.Caller) end
		end
		return counts, callers
	end
	local function getCacheEntries()
		if ClientIndex and ClientIndex.GetCacheEntries then
			local entries, cacheDir = ClientIndex.GetCacheEntries()
			return entries or {}, cacheDir
		end
		return {}, nil
	end
	local function sortedServices(surface)
		local services = {}
		for _, obj in ipairs(surface.AllInstances or {}) do
			local root = obj
			while root.Parent and root.Parent ~= game do root = root.Parent end
			services[root.Name] = (services[root.Name] or 0) + 1
		end
		local rows = {}
		for name, count in pairs(services) do rows[#rows + 1] = {Name=name, Count=count} end
		table.sort(rows, function(a,b) return a.Count > b.Count end)
		return rows
	end
	function InspectorHub.BuildSnapshot(force)
		local surface = getSurface(force == true)
		local partCount, guiCount = 0, 0
		for _, obj in ipairs(surface.AllInstances or {}) do
			if obj:IsA("BasePart") then partCount += 1 end
			if obj:IsA("GuiObject") then guiCount += 1 end
		end
		local cacheCount = 0
		local entries = getCacheEntries()
		for _ in pairs(entries) do cacheCount += 1 end
		return {
			Surface = surface,
			Instances = #(surface.AllInstances or {}),
			Scripts = #(surface.AllScripts or {}),
			ViableScripts = #(surface.ViableScripts or {}),
			Remotes = #(surface.Remotes or {}),
			Parts = partCount,
			GuiObjects = guiCount,
			CacheEntries = cacheCount,
			Services = sortedServices(surface),
		}
	end
	function InspectorHub.GetRemoteHotspots()
		local surface = getSurface(false)
		local counts, callers = runtimeCounts()
		local rows = {}
		for _, remote in ipairs(surface.Remotes or {}) do
			local path = getPath(remote)
			local word = containsAny(remote.Name, riskyRemoteWords)
			local score = (counts[path] or 0) * 2 + (word and 4 or 0) + (remote:IsA("RemoteFunction") and 2 or 0)
			rows[#rows + 1] = {Object=remote, Path=path, Name=remote.Name, ClassName=remote.ClassName, Calls=counts[path] or 0, Caller=callers[path] or "unknown", RiskWord=word or "", Score=score}
		end
		table.sort(rows, function(a,b)
			if a.Score == b.Score then return a.Path < b.Path end
			return a.Score > b.Score
		end)
		return rows
	end
	function InspectorHub.GetRiskQueue(limit)
		local queue, surface = {}, getSurface(false)
		for _, remote in ipairs(surface.Remotes or {}) do
			local word = containsAny(remote.Name, riskyRemoteWords)
			if word then queue[#queue + 1] = {Kind="Remote", Object=remote, Score=70, Title="Risky remote name: " .. remote.Name, Detail=word .. " | " .. getPath(remote)} end
		end
		local entries, cacheDir = getCacheEntries()
		local byKey = ClientIndex and ClientIndex.GetScriptLookup and ClientIndex.GetScriptLookup() or {}
		local scanned = 0
		for key, entry in pairs(entries) do
			if limit and #queue >= limit then break end
			if entry.File and cacheDir and env.isfile and env.isfile(cacheDir .. "/" .. tostring(entry.File)) then
				local ok, source = pcall(env.readfile, cacheDir .. "/" .. tostring(entry.File))
				if ok and type(source) == "string" then
					local word = containsAny(source, riskyScriptWords)
					if word then
						queue[#queue + 1] = {Kind="Script", Object=byKey[key], Score=60, Title="Cached source signal: " .. word, Detail=tostring(entry.Path or entry.Name or key)}
					end
				end
			end
			scanned += 1
			if scanned % 25 == 0 then task.wait() end
		end
		table.sort(queue, function(a,b) return a.Score > b.Score end)
		return queue
	end
	function InspectorHub.BuildBrief()
		local snap = InspectorHub.BuildSnapshot(false)
		local hot = InspectorHub.GetRemoteHotspots()
		local lines = {
			"DEX++ Inspector Brief",
			("surface: %d instances | %d scripts | %d viable | %d remotes"):format(snap.Instances, snap.Scripts, snap.ViableScripts, snap.Remotes),
			("objects: %d parts | %d gui objects | %d cached scripts"):format(snap.Parts, snap.GuiObjects, snap.CacheEntries),
			"top services:",
		}
		for i = 1, math.min(5, #snap.Services) do lines[#lines + 1] = ("- %s: %d descendants"):format(snap.Services[i].Name, snap.Services[i].Count) end
		lines[#lines + 1] = "hot/risky remotes:"
		for i = 1, math.min(10, #hot) do lines[#lines + 1] = ("- score %d | calls %d | %s"):format(hot[i].Score, hot[i].Calls, hot[i].Path) end
		return table.concat(lines, "\n")
	end
	local function focusObject(obj)
		if typeof(obj) ~= "Instance" then return end
		if obj:IsA("LuaSourceContainer") and ScriptViewer then pcall(ScriptViewer.ViewScript, obj) end
		if remoteClasses[obj.ClassName] and RemoteUsageMap then pcall(RemoteUsageMap.ShowForRemote, obj) end
		if Explorer and Explorer.Selection then pcall(function() Explorer.Selection:Set(obj) end) end
	end
	function InspectorHub.ShowSnapshot()
		scanToken += 1
		clearRows()
		local snap = InspectorHub.BuildSnapshot(true)
		section("Surface Snapshot")
		textRow(("instances %d | scripts %d | viable %d | remotes %d"):format(snap.Instances, snap.Scripts, snap.ViableScripts, snap.Remotes), false)
		textRow(("parts %d | gui %d | cached sources %d"):format(snap.Parts, snap.GuiObjects, snap.CacheEntries), true)
		section("Largest Services")
		for i = 1, math.min(10, #snap.Services) do textRow(snap.Services[i].Name .. " - " .. snap.Services[i].Count .. " descendants", false) end
		setStatus("Snapshot refreshed.")
		window:Show()
	end
	function InspectorHub.ShowHotRemotes()
		scanToken += 1
		clearRows()
		section("Hot / Risky Remotes")
		local rows = InspectorHub.GetRemoteHotspots()
		for i = 1, math.min(80, #rows) do
			local row = rows[i]
			actionRow(("score %d | %s [%s]"):format(row.Score, row.Name, row.ClassName), ("calls %d | %s | caller %s"):format(row.Calls, row.Path, row.Caller), function() focusObject(row.Object) end)
		end
		if #rows == 0 then textRow("No remotes found.", true) end
		setStatus("Remote hotspots ready.")
		window:Show()
	end
	function InspectorHub.ShowRiskQueue()
		scanToken += 1
		local token = scanToken
		clearRows()
		section("Risk Queue")
		textRow("Scanning cached source and remote names...", true)
		setStatus("Building risk queue...")
		window:Show()
		task.spawn(function()
			local queue = InspectorHub.GetRiskQueue(120)
			if token ~= scanToken then return end
			clearRows()
			section("Risk Queue")
			for i = 1, math.min(100, #queue) do
				local item = queue[i]
				actionRow(item.Kind .. " | " .. item.Title, item.Detail, function() focusObject(item.Object) end)
			end
			if #queue == 0 then textRow("No risk signals found in quick scan.", true) end
			setStatus(("Risk queue ready: %d signal(s)."):format(#queue))
		end)
	end
	function InspectorHub.ExportBrief()
		local brief = InspectorHub.BuildBrief()
		if env.setclipboard then env.setclipboard(brief) elseif setclipboard then setclipboard(brief) end
		setStatus("Brief copied to clipboard.")
	end
	local function makeButton(text, x, w, callback)
		local button = createSimple("TextButton",{AutoButtonColor=false, BackgroundColor3=Settings.Theme.Button, BorderColor3=Settings.Theme.Outline2, Font=Enum.Font.SourceSans, Position=UDim2.new(0,x,0,4), Size=UDim2.new(0,w,0,22), Text=text, TextColor3=Settings.Theme.Text, TextSize=14})
		button.MouseButton1Click:Connect(callback)
		Lib.ButtonAnim(button,{Mode=2, StartColor=Settings.Theme.Button, HoverColor=Settings.Theme.ButtonHover, PressColor=Settings.Theme.ButtonPress, OutlineColor=Settings.Theme.Outline2})
		return button
	end
	function InspectorHub.Init()
		window = Lib.Window.new()
		window:SetTitle("Inspector Hub")
		window:Resize(680, 430)
		InspectorHub.Window = window
		local content = window.GuiElems.Content
		local toolbar = createSimple("Frame",{BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, Size=UDim2.new(1,0,0,34), Parent=content})
		makeButton("Snapshot", 6, 74, InspectorHub.ShowSnapshot).Parent = toolbar
		makeButton("Remotes", 86, 70, InspectorHub.ShowHotRemotes).Parent = toolbar
		makeButton("Risk Queue", 162, 86, InspectorHub.ShowRiskQueue).Parent = toolbar
		makeButton("Copy Brief", 254, 82, InspectorHub.ExportBrief).Parent = toolbar
		statusLabel = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,344,0,6), Size=UDim2.new(1,-350,0,20), Text="Ready.", TextColor3=Settings.Theme.PlaceholderText, TextSize=13, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=toolbar})
		listFrame = createSimple("ScrollingFrame",{Active=true, AutomaticCanvasSize=Enum.AutomaticSize.Y, BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, BottomImage="", CanvasSize=UDim2.new(0,0,0,0), Position=UDim2.new(0,0,0,34), ScrollBarImageColor3=Color3.fromRGB(70,70,70), ScrollBarThickness=10, Size=UDim2.new(1,0,1,-34), TopImage="", Parent=content})
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0,4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = listFrame
		local padding = Instance.new("UIPadding")
		padding.PaddingBottom, padding.PaddingLeft, padding.PaddingRight, padding.PaddingTop = UDim.new(0,6), UDim.new(0,4), UDim.new(0,4), UDim.new(0,4)
		padding.Parent = listFrame
	end
	return InspectorHub
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
