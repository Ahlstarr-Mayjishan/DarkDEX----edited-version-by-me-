--!strict
--[[
	Object Links App Module
	Fast reference inspector for any selected Instance.
]]
local Main,Lib,Apps,Settings
local Explorer, Notepad, ObjectLinks, RemoteUsageMap, Notebook
local API,RMD,env,service,plr,create,createSimple

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
	Notepad = Apps.Notepad
	ObjectLinks = Apps.ObjectLinks
	RemoteUsageMap = Apps.RemoteUsageMap
	Notebook = Apps.Notebook
end

local function main()
	local ObjectLinks = {}
	local window, statusLabel, listFrame
	local scanToken = 0
	local containedScanLimit = 5000
	local containedRowLimit = 16
	local runtimeConstantScriptLimit = 80
	local remoteClasses = {
		RemoteEvent = true, RemoteFunction = true, UnreliableRemoteEvent = true,
		BindableEvent = true, BindableFunction = true,
	}

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

	local function clearRows()
		if not listFrame then return end
		for _, child in pairs(listFrame:GetChildren()) do
			if child:IsA("GuiButton") or child:IsA("TextLabel") or child:IsA("Frame") then child:Destroy() end
		end
	end

	local function pad(gui, left)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, left or 6)
		padding.Parent = gui
	end

	local function divider(text)
		local label = createSimple("TextLabel",{
			BackgroundColor3 = Settings.Theme.Main1, BorderSizePixel = 0, Font = Enum.Font.SourceSansBold,
			Size = UDim2.new(1,-8,0,22), Text = text, TextColor3 = Settings.Theme.Text,
			TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = listFrame
		})
		pad(label)
	end

	local function textRow(text, muted)
		local label = createSimple("TextLabel",{
			BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Size = UDim2.new(1,-8,0,22),
			Text = text, TextColor3 = muted and Settings.Theme.PlaceholderText or Settings.Theme.Text,
			TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left,
			Parent = listFrame
		})
		pad(label)
		return label
	end

	local function objectRow(prefix, obj, muted)
		local row = createSimple("TextButton",{
			AutoButtonColor = false, BackgroundColor3 = Settings.Theme.Main2, BorderColor3 = Settings.Theme.Outline1,
			BorderSizePixel = 1, Font = Enum.Font.SourceSans, Size = UDim2.new(1,-8,0,24),
			Text = prefix .. obj.Name .. " [" .. obj.ClassName .. "]",
			TextColor3 = muted and Settings.Theme.PlaceholderText or Settings.Theme.Text,
			TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left,
			Parent = listFrame
		})
		pad(row)
		Lib.ButtonAnim(row,{Mode = 2, StartColor = Settings.Theme.Main2, HoverColor = Settings.Theme.ButtonHover, PressColor = Settings.Theme.ButtonPress, OutlineColor = Settings.Theme.Outline1})
		row.MouseButton1Click:Connect(function()
			if Explorer and Explorer.Nodes and Explorer.Selection then
				local node = Explorer.Nodes[obj]
				if node then
					if Explorer.MakeNodeVisible then Explorer.MakeNodeVisible(node, true) end
					Explorer.Selection:Set(node)
					if Explorer.ViewNode then Explorer.ViewNode(node) end
				end
			end
			if obj:IsA("LuaSourceContainer") and Notepad then
				Notepad.ViewScript(obj)
			elseif remoteClasses[obj.ClassName] and RemoteUsageMap then
				RemoteUsageMap.ShowForRemote(obj)
			elseif env.setclipboard then
				env.setclipboard(getPath(obj))
				setStatus("Copied object path and focused in Explorer.")
			end
		end)
		return row
	end

	local function scriptHitRow(scriptObj, title, detail)
		local row = createSimple("TextButton",{
			AutoButtonColor = false, BackgroundColor3 = Settings.Theme.Main2, BorderColor3 = Settings.Theme.Outline1,
			BorderSizePixel = 1, Font = Enum.Font.SourceSans, Size = UDim2.new(1,-8,0,42),
			Text = "", Parent = listFrame
		})
		createSimple("TextLabel",{
			BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Position = UDim2.new(0,8,0,2),
			Size = UDim2.new(1,-16,0,18), Text = title, TextColor3 = Settings.Theme.Text,
			TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row
		})
		createSimple("TextLabel",{
			BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Position = UDim2.new(0,8,0,21),
			Size = UDim2.new(1,-16,0,18), Text = detail, TextColor3 = Settings.Theme.PlaceholderText,
			TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row
		})
		Lib.ButtonAnim(row,{Mode = 2, StartColor = Settings.Theme.Main2, HoverColor = Settings.Theme.ButtonHover, PressColor = Settings.Theme.ButtonPress, OutlineColor = Settings.Theme.Outline1})
		row.MouseButton1Click:Connect(function()
			if scriptObj then
				if Explorer and Explorer.Nodes and Explorer.Selection then
					local node = Explorer.Nodes[scriptObj]
					if node then
						if Explorer.MakeNodeVisible then Explorer.MakeNodeVisible(node, true) end
						Explorer.Selection:Set(node)
						if Explorer.ViewNode then Explorer.ViewNode(node) end
					end
				end
				if Notepad then Notepad.ViewScript(scriptObj) end
			end
		end)
	end

	local function collectScriptsByKey()
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

	local function addStructure(obj, token)
		divider("Object")
		textRow(obj.Name .. " [" .. obj.ClassName .. "]", false)
		textRow(getPath(obj), true)
		if obj.Parent then objectRow("Parent: ", obj.Parent, true) end

		divider("Contained Links")
		local scripts, remotes, parts = {}, {}, {}
		local descendants = nil
		if env.ClientIndex and env.ClientIndex.RefreshSurface then
			local surface = env.ClientIndex.RefreshSurface(false)
			descendants = surface and surface.AllInstances
		end
		if not descendants then
			local ok, list = pcall(function() return obj:GetDescendants() end)
			descendants = ok and list or {}
		end
		local scanned = 0
		for _, child in pairs(descendants) do
			if token ~= scanToken then return end
			if obj ~= game and child ~= obj and not child:IsDescendantOf(obj) then continue end
			scanned += 1
			if child:IsA("LuaSourceContainer") then scripts[#scripts + 1] = child
			elseif remoteClasses[child.ClassName] then remotes[#remotes + 1] = child
			elseif child:IsA("BasePart") then parts[#parts + 1] = child end
			if scanned % 250 == 0 then
				setStatus(("Scanning contained links: %d object(s)..."):format(scanned))
				task.wait()
			end
			if scanned >= containedScanLimit then break end
		end
		textRow(("scripts: %d  |  remotes/bindables: %d  |  parts: %d"):format(#scripts, #remotes, #parts), true)
		for i = 1, math.min(#scripts, containedRowLimit) do objectRow("Script: ", scripts[i], false) end
		for i = 1, math.min(#remotes, containedRowLimit) do objectRow("Remote: ", remotes[i], false) end
		if scanned >= containedScanLimit then textRow("Contained scan capped to keep UI responsive.", true) end
		if #scripts + #remotes == 0 then textRow("No scripts or remotes inside this object.", true) end
	end

	local function makeTokens(obj)
		local tokens = {}
		local seen = {}
		local function add(token)
			token = tostring(token or "")
			if #token >= 2 and not seen[token:lower()] then
				seen[token:lower()] = true
				tokens[#tokens + 1] = token
			end
		end
		add(obj.Name)
		add(getPath(obj))
		if obj.Parent then add(obj.Parent.Name .. "." .. obj.Name) end
		for _, child in pairs(obj:GetChildren()) do
			if child:IsA("LuaSourceContainer") or remoteClasses[child.ClassName] then add(child.Name) end
		end
		return tokens
	end

	local function sourceHit(source, tokens)
		local lower = source:lower()
		for _, token in ipairs(tokens) do
			local needle = token:lower()
			local pos = lower:find(needle, 1, true)
			if pos then
				local snippet = source:sub(math.max(1, pos - 50), math.min(#source, pos + 120)):gsub("\r"," "):gsub("\n"," ")
				return token, snippet
			end
		end
		return nil, nil
	end

	local function scanCachedScripts(obj, token)
		if not env.DecompileCache or not env.DecompileCache.GetEntries or not env.isfile then
			divider("Cached Script References")
			textRow("Decompile cache unavailable. Run Code Search index first.", true)
			return
		end
		divider("Cached Script References")
		local tokens = makeTokens(obj)
		if env.ClientIndex and env.ClientIndex.FindCachedReferences and env.ClientIndex.GetScriptLookup then
			local scriptsByKey = env.ClientIndex.GetScriptLookup()
			local rows = env.ClientIndex.FindCachedReferences(tokens, function() return token == scanToken end, 120)
			for _, hit in ipairs(rows) do
				local scriptObj = scriptsByKey[hit.Key]
				scriptHitRow(scriptObj, tostring(hit.Entry.Path or (scriptObj and getPath(scriptObj)) or hit.Entry.Name), "mentions " .. tostring(hit.Token) .. " | " .. tostring(hit.Snippet))
			end
			if #rows == 0 then textRow("No cached scripts mention this object yet.", true) end
			setStatus(("Link scan complete: %d cached hit(s)."):format(#rows))
			return
		end
		local entries, cacheDir = env.DecompileCache.GetEntries()
		local scriptsByKey = collectScriptsByKey()
		local found, scanned = 0, 0
		for key, entry in pairs(entries) do
			if token ~= scanToken then return end
			if entry.File then
				local filePath = cacheDir .. "/" .. tostring(entry.File)
				if env.isfile(filePath) then
					local ok, source = pcall(env.readfile, filePath)
					if ok and type(source) == "string" then
						scanned += 1
						local hitToken, snippet = sourceHit(source, tokens)
						if hitToken then
							found += 1
							local scriptObj = scriptsByKey[key]
							scriptHitRow(scriptObj, tostring(entry.Path or (scriptObj and getPath(scriptObj)) or entry.Name), "mentions " .. hitToken .. " | " .. snippet)
						end
					end
				end
			end
			if scanned % 25 == 0 then
				setStatus(("Scanning cache: %d script(s), %d hit(s)..."):format(scanned, found))
				task.wait()
			end
		end
		if found == 0 then textRow("No cached scripts mention this object yet.", true) end
		setStatus(("Link scan complete: %d hit(s) in %d cached script(s)."):format(found, scanned))
	end

	local function scanRuntimeConstants(obj, token)
		if not env.GetClientScripts or not env.GetScriptConstants then return end
		divider("Runtime Constant References")
		local tokens = makeTokens(obj)
		local found = 0
		local scanned = 0
		for _, scriptObj in pairs(env.GetClientScripts(true)) do
			if token ~= scanToken then return end
			scanned += 1
			local ok, constants = pcall(env.GetScriptConstants, scriptObj)
			if ok and type(constants) == "table" then
				for _, constant in pairs(constants) do
					local text = tostring(constant)
					local hitToken = sourceHit(text, tokens)
					if hitToken then
						found += 1
						scriptHitRow(scriptObj, getPath(scriptObj), "constant mentions " .. hitToken .. " | " .. text)
						break
					end
				end
			end
			if scanned % 10 == 0 then
				setStatus(("Scanning runtime constants: %d script(s), %d hit(s)..."):format(scanned, found))
				task.wait()
			else
				task.wait()
			end
			if scanned >= runtimeConstantScriptLimit then
				textRow("Runtime constant scan capped to keep UI responsive.", true)
				break
			end
		end
		if found == 0 then textRow("No runtime constants mention this object.", true) end
	end

	ObjectLinks.ShowForObject = function(obj)
		if typeof(obj) ~= "Instance" then return end
		scanToken += 1
		local token = scanToken
		clearRows()
		window:SetTitle("Object Links - " .. obj.Name)
		setStatus("Scanning references...")
		window:Show()
		task.spawn(function()
			addStructure(obj, token)
			if token ~= scanToken then return end
			scanCachedScripts(obj, token)
			if token ~= scanToken then return end
			scanRuntimeConstants(obj, token)
		end)
	end

	ObjectLinks.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Object Links")
		window:Resize(580,420)
		ObjectLinks.Window = window
		statusLabel = createSimple("TextLabel",{
			BackgroundColor3 = Settings.Theme.Main2, BorderSizePixel = 0, Font = Enum.Font.SourceSans,
			Position = UDim2.new(0,0,0,0), Size = UDim2.new(1,0,0,24),
			Text = "Right click any object in Explorer, then choose Find Links / References.",
			TextColor3 = Settings.Theme.PlaceholderText, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = window.GuiElems.Content
		})
		pad(statusLabel)
		listFrame = createSimple("ScrollingFrame",{
			Active = true, AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundColor3 = Settings.Theme.Main2,
			BorderSizePixel = 0, BottomImage = "", CanvasSize = UDim2.new(0,0,0,0), Position = UDim2.new(0,0,0,24),
			ScrollBarImageColor3 = Color3.fromRGB(70,70,70), ScrollBarThickness = 10, Size = UDim2.new(1,0,1,-24),
			TopImage = "", Parent = window.GuiElems.Content
		})
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0,4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = listFrame
		local padding = Instance.new("UIPadding")
		padding.PaddingBottom = UDim.new(0,6)
		padding.PaddingLeft = UDim.new(0,4)
		padding.PaddingRight = UDim.new(0,4)
		padding.PaddingTop = UDim.new(0,4)
		padding.Parent = listFrame
	end
	return ObjectLinks
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
