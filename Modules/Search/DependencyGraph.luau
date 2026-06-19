--!strict
--[[
	Script Dependency Graph App Module
	Builds a cache-backed graph of require links and remote mentions.
]]
local Main,Lib,Apps,Settings
local Explorer, ScriptViewer, DependencyGraph
local API,RMD,env,service,plr,create,createSimple

local function initDeps(data)
	Main, Lib, Apps, Settings = data.Main, data.Lib, data.Apps, data.Settings
	API, RMD, env, service, plr = data.API, data.RMD, data.env, data.service, data.plr
	create, createSimple = data.create, data.createSimple
end

local function initAfterMain()
	Explorer = Apps.Explorer
	ScriptViewer = Apps.ScriptViewer
	DependencyGraph = Apps.DependencyGraph
end

local function main()
	local DependencyGraph = {}
	local window, listFrame, statusLabel
	local scanToken = 0
	local remoteClasses = {RemoteEvent=true, RemoteFunction=true, UnreliableRemoteEvent=true, BindableEvent=true, BindableFunction=true}

	local function getPath(obj)
        if Main and Main.SafeGetInstancePath then return Main.SafeGetInstancePath(obj) end
		local ok, path = pcall(function()
			if Explorer and Explorer.GetInstancePath then return Explorer.GetInstancePath(obj) end
			return obj:GetFullName()
		end)
		return ok and tostring(path) or tostring(obj)
	end
	local function clearRows()
		for _, child in pairs(listFrame:GetChildren()) do
			if child:IsA("GuiButton") or child:IsA("TextLabel") then child:Destroy() end
		end
	end
	local function textRow(text, muted)
		local label = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Size=UDim2.new(1,-8,0,22), Text=text, TextColor3=muted and Settings.Theme.PlaceholderText or Settings.Theme.Text, TextSize=14, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=listFrame})
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0,6)
		pad.Parent = label
	end
	local function divider(text)
		local label = createSimple("TextLabel",{BackgroundColor3=Settings.Theme.Main1, BorderSizePixel=0, Font=Enum.Font.SourceSansBold, Size=UDim2.new(1,-8,0,22), Text=text, TextColor3=Settings.Theme.Text, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left, Parent=listFrame})
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0,6)
		pad.Parent = label
	end
	local function scriptRow(title, detail, scriptObj)
		local row = createSimple("TextButton",{AutoButtonColor=false, BackgroundColor3=Settings.Theme.Main2, BorderColor3=Settings.Theme.Outline1, BorderSizePixel=1, Font=Enum.Font.SourceSans, Size=UDim2.new(1,-8,0,42), Text="", Parent=listFrame})
		createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,8,0,2), Size=UDim2.new(1,-16,0,18), Text=title, TextColor3=Settings.Theme.Text, TextSize=14, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
		createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,8,0,21), Size=UDim2.new(1,-16,0,18), Text=detail, TextColor3=Settings.Theme.PlaceholderText, TextSize=13, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
		Lib.ButtonAnim(row,{Mode=2, StartColor=Settings.Theme.Main2, HoverColor=Settings.Theme.ButtonHover, PressColor=Settings.Theme.ButtonPress, OutlineColor=Settings.Theme.Outline1})
		row.MouseButton1Click:Connect(function()
			if scriptObj and ScriptViewer then ScriptViewer.ViewScript(scriptObj) end
		end)
	end
	local function scriptByKey()
		if env.ClientIndex and env.ClientIndex.GetScriptLookup then
			return env.ClientIndex.GetScriptLookup()
		end
		local map = {}
		if not env.DecompileCache or not env.DecompileCache.GetScriptKey then return map end
		local scripts = env.GetClientScripts and env.GetClientScripts(true) or game:GetDescendants()
		for _, obj in pairs(scripts) do
			if typeof(obj) == "Instance" and obj:IsA("LuaSourceContainer") then
				local ok, key = pcall(env.DecompileCache.GetScriptKey, obj)
				if ok and key then map[key] = obj end
			end
		end
		return map
	end
	local function collectRemotes()
		if env.ClientIndex and env.ClientIndex.RefreshSurface then
			return env.ClientIndex.RefreshSurface(false).Remotes
		end
		local remotes = {}
		local list = env.GetClientRemotes and env.GetClientRemotes() or game:GetDescendants()
		for _, obj in pairs(list) do
			if typeof(obj) == "Instance" and remoteClasses[obj.ClassName] then table.insert(remotes, obj) end
		end
		return remotes
	end
	local function scan()
		scanToken += 1
		local token = scanToken
		clearRows()
		window:SetTitle("Script Dependency Graph")
		if not env.DecompileCache or not env.DecompileCache.GetEntries or not env.isfile then
			textRow("Cache unavailable. Run Code Search > Index Scripts first.", true)
			return
		end
		statusLabel.Text = "Scanning cached scripts..."
		divider("Require Links")
		window:Show()
		task.spawn(function()
			local entries, cacheDir = env.DecompileCache.GetEntries()
			local byKey, remotes = scriptByKey(), collectRemotes()
			local scanned, requires, remoteHits = 0, 0, 0
			local remoteRows = {}
			for key, entry in pairs(entries) do
				if token ~= scanToken then return end
				if entry.File then
					local filePath = cacheDir .. "/" .. tostring(entry.File)
					if env.isfile(filePath) then
						local ok, source = pcall(env.readfile, filePath)
						if ok and type(source) == "string" then
							scanned += 1
							for block in source:gmatch("require%s*%b()") do
								requires += 1
								scriptRow(tostring(entry.Path or entry.Name), "requires: " .. block:gsub("\n"," "), byKey[key])
								if requires >= 80 then break end
							end
							local lower = source:lower()
							for _, remote in ipairs(remotes) do
								if #remote.Name >= 2 and lower:find(remote.Name:lower(), 1, true) then
									remoteHits += 1
									remoteRows[#remoteRows + 1] = {Entry = entry, Key = key, Remote = remote}
									break
								end
							end
						end
					end
				end
				if scanned % 20 == 0 then statusLabel.Text = ("Scanned %d cached scripts..."):format(scanned); task.wait() end
			end
			divider("Remote Mentions")
			for i, hit in ipairs(remoteRows) do
				if i > 80 then textRow("More remote hits omitted.", true); break end
				scriptRow(tostring(hit.Entry.Path or hit.Entry.Name), "mentions remote: " .. hit.Remote.Name .. " | " .. getPath(hit.Remote), byKey[hit.Key])
			end
			if requires == 0 and remoteHits == 0 then textRow("No graph hints found yet.", true) end
			statusLabel.Text = ("Graph ready: %d scripts, %d require links, %d remote mentions."):format(scanned, requires, remoteHits)
		end)
	end
	local function button(parent, text, x, w, cb)
		local b = createSimple("TextButton",{AutoButtonColor=false, BackgroundColor3=Settings.Theme.Button, BorderColor3=Settings.Theme.Outline2, Font=Enum.Font.SourceSans, Position=UDim2.new(0,x,0,4), Size=UDim2.new(0,w,0,22), Text=text, TextColor3=Settings.Theme.Text, TextSize=14, Parent=parent})
		b.MouseButton1Click:Connect(cb)
		Lib.ButtonAnim(b,{Mode=2, StartColor=Settings.Theme.Button, HoverColor=Settings.Theme.ButtonHover, PressColor=Settings.Theme.ButtonPress, OutlineColor=Settings.Theme.Outline2})
	end
	DependencyGraph.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Script Dependency Graph")
		window:Resize(640,420)
		DependencyGraph.Window = window
		local content = window.GuiElems.Content
		local toolbar = createSimple("Frame",{BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, Size=UDim2.new(1,0,0,56), Parent=content})
		button(toolbar,"Scan Graph",6,86,scan)
		statusLabel = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,100,0,4), Size=UDim2.new(1,-106,0,22), Text="Run Code Search index, then scan graph.", TextColor3=Settings.Theme.PlaceholderText, TextSize=14, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=toolbar})
		listFrame = createSimple("ScrollingFrame",{Active=true, AutomaticCanvasSize=Enum.AutomaticSize.Y, BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, BottomImage="", CanvasSize=UDim2.new(0,0,0,0), Position=UDim2.new(0,0,0,56), ScrollBarImageColor3=Color3.fromRGB(70,70,70), ScrollBarThickness=10, Size=UDim2.new(1,0,1,-56), TopImage="", Parent=content})
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0,4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = listFrame
		local pad = Instance.new("UIPadding")
		pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop = UDim.new(0,6), UDim.new(0,4), UDim.new(0,4), UDim.new(0,4)
		pad.Parent = listFrame
	end
	DependencyGraph.Scan = scan
	return DependencyGraph
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
