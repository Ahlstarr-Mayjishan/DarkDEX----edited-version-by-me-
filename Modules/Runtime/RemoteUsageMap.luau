--!strict
--[[
	Remote Usage Map App Module
	Finds cached scripts that mention selected remotes/bindables.
]]
-- Common Locals
local Main,Lib,Apps,Settings -- Main Containers
local Explorer, Properties, ScriptViewer, RemoteUsageMap, Notebook -- Major Apps
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
	RemoteUsageMap = Apps.RemoteUsageMap
	Notebook = Apps.Notebook
end
local function main()
	local RemoteUsageMap = {}
	local window, statusLabel, listFrame
	local scanToken = 0
	local remoteClasses = {
		RemoteEvent = true,
		RemoteFunction = true,
		UnreliableRemoteEvent = true,
		BindableEvent = true,
		BindableFunction = true,
	}
	local classMethods = {
		RemoteEvent = {"FireServer","OnClientEvent","OnServerEvent"},
		RemoteFunction = {"InvokeServer","OnClientInvoke","OnServerInvoke"},
		UnreliableRemoteEvent = {"FireServer","OnClientEvent","OnServerEvent"},
		BindableEvent = {"Fire","Event"},
		BindableFunction = {"Invoke","OnInvoke"},
	}
	local function setStatus(text)
		if statusLabel then statusLabel.Text = text end
	end
	local function isRemote(obj)
		return typeof(obj) == "Instance" and remoteClasses[obj.ClassName] == true
	end
	local function getPath(obj)
        if Main and Main.SafeGetInstancePath then return Main.SafeGetInstancePath(obj) end
		local success, path = pcall(function()
			if Explorer and Explorer.GetInstancePath then return Explorer.GetInstancePath(obj) end
			return obj:GetFullName()
		end)
		return success and tostring(path) or tostring(obj)
	end
	local function clearRows()
		if not listFrame then return end
		for _, child in pairs(listFrame:GetChildren()) do
			if child:IsA("GuiButton") or child:IsA("TextLabel") then child:Destroy() end
		end
	end
	local function addPadded(gui)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0,6)
		padding.Parent = gui
	end
	local function addDivider(text)
		local label = createSimple("TextLabel",{
			BackgroundColor3 = Settings.Theme.Main1, BorderSizePixel = 0, Font = Enum.Font.SourceSansBold,
			Size = UDim2.new(1,-8,0,22), Text = text, TextColor3 = Settings.Theme.Text,
			TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = listFrame
		})
		addPadded(label)
	end
	local function addText(text, muted)
		local label = createSimple("TextLabel",{
			BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Size = UDim2.new(1,-8,0,22),
			Text = text, TextColor3 = muted and Settings.Theme.PlaceholderText or Settings.Theme.Text,
			TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left,
			Parent = listFrame
		})
		addPadded(label)
		return label
	end
	local function addScriptResult(scriptObj, entry, reason, snippet)
		local row = createSimple("TextButton",{
			AutoButtonColor = false, BackgroundColor3 = Settings.Theme.Main2, BorderColor3 = Settings.Theme.Outline1,
			Font = Enum.Font.SourceSans, Size = UDim2.new(1,-8,0,42), Text = "",
			TextColor3 = Settings.Theme.Text, TextSize = 14, Parent = listFrame
		})
		local title = createSimple("TextLabel",{
			BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Position = UDim2.new(0,8,0,2),
			Size = UDim2.new(1,-16,0,18), Text = tostring(entry.Path or (scriptObj and getPath(scriptObj)) or entry.Name),
			TextColor3 = Settings.Theme.Text, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = row
		})
		local detail = createSimple("TextLabel",{
			BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Position = UDim2.new(0,8,0,21),
			Size = UDim2.new(1,-16,0,18), Text = reason .. " | " .. snippet,
			TextColor3 = Settings.Theme.PlaceholderText, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = row
		})
		Lib.ButtonAnim(row,{Mode = 2, StartColor = Settings.Theme.Main2, HoverColor = Settings.Theme.ButtonHover, PressColor = Settings.Theme.ButtonPress, OutlineColor = Settings.Theme.Outline1})
		row.MouseButton1Click:Connect(function()
			if scriptObj and ScriptViewer and ScriptViewer.ViewScript then ScriptViewer.ViewScript(scriptObj) end
		end)
		return row
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
				local success, key = pcall(env.DecompileCache.GetScriptKey, obj)
				if success and key then map[key] = obj end
			end
		end
		return map
	end
	local function summarizeHit(source, remote)
		local lowerSource = source:lower()
		local name = remote.Name:lower()
		local remotePath = getPath(remote):lower()
		local reasons = {}
		for _, method in ipairs(classMethods[remote.ClassName] or {}) do
			if lowerSource:find(method:lower(), 1, true) then table.insert(reasons, method) end
		end
		if #name >= 2 and lowerSource:find(name, 1, true) then table.insert(reasons, "name") end
		if #remotePath >= 6 and lowerSource:find(remotePath, 1, true) then table.insert(reasons, "path") end
		if #reasons == 0 then return nil, nil end
		local hitAt = (#name >= 2 and lowerSource:find(name, 1, true)) or lowerSource:find((reasons[1] or ""):lower(), 1, true) or 1
		local snippet = source:sub(math.max(1, hitAt - 48), math.min(#source, hitAt + 110)):gsub("\r"," "):gsub("\n"," ")
		return table.concat(reasons, ", "), snippet
	end
	local function scanCache(remote, token)
		if not env.DecompileCache or not env.DecompileCache.GetEntries or not env.isfile then
			setStatus("Decompile cache is unavailable.")
			return
		end
		local entries, cacheDir = env.DecompileCache.GetEntries()
		local scriptByKey = collectScriptsByKey()
		local found, scanned = 0, 0
		addDivider("Cached Script Hits")
		for key, entry in pairs(entries) do
			if token ~= scanToken then return end
			if entry.File then
				local path = cacheDir .. "/" .. tostring(entry.File)
				if env.isfile(path) then
					local success, source = pcall(env.readfile, path)
					if success and type(source) == "string" then
						scanned += 1
						local reason, snippet = summarizeHit(source, remote)
						if reason then
							found += 1
							addScriptResult(scriptByKey[key], entry, reason, snippet or "")
						end
					end
				end
			end
			if scanned % 20 == 0 then
				setStatus(("Scanning cache: %d script(s), %d hit(s)..."):format(scanned, found))
				task.wait()
			end
		end
		if found == 0 then addText("No cached scripts mention this remote yet.", true) end
		setStatus(("Remote usage scan complete: %d hit(s) in %d cached script(s)."):format(found, scanned))
	end
	local function scanConstants(remote, token)
		if not env.GetClientScripts or not env.GetScriptConstants then return end
		local nameToken = remote.Name:lower()
		if #nameToken < 2 then return end
		local hits = 0
		addDivider("Runtime Constants Hits")
		local scripts = env.ClientIndex and env.ClientIndex.RefreshSurface and env.ClientIndex.RefreshSurface(false).AllScripts or env.GetClientScripts(true)
		for _, scriptObj in pairs(scripts) do
			if token ~= scanToken then return end
			local constants = env.GetScriptConstants(scriptObj)
			for _, constant in pairs(constants) do
				local text = tostring(constant)
				if text:lower():find(nameToken, 1, true) then
					hits += 1
					addScriptResult(scriptObj, {Path = scriptObj:GetFullName(), Name = scriptObj.Name}, "constant", text)
					break
				end
			end
			task.wait()
		end
		if hits == 0 then addText("No runtime constants mention this remote.", true) end
	end
	RemoteUsageMap.ShowForRemote = function(remote)
		if not isRemote(remote) then setStatus("Select a RemoteEvent/RemoteFunction/Bindable first."); return end
		scanToken += 1
		local token = scanToken
		clearRows()
		window:SetTitle("Remote Usage - " .. remote.Name)
		addDivider("Selected Remote")
		addText(remote.Name .. " [" .. remote.ClassName .. "]", false)
		addText(getPath(remote), true)
		addText("Tip: run Code Search > Index Scripts first for fuller results.", true)
		setStatus("Scanning cached decompiled scripts...")
		window:Show()
		task.spawn(function()
			scanCache(remote, token)
			scanConstants(remote, token)
		end)
	end
	RemoteUsageMap.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Remote Usage")
		window:Resize(560,380)
		RemoteUsageMap.Window = window
		statusLabel = createSimple("TextLabel",{
			BackgroundColor3 = Settings.Theme.Main2, BorderSizePixel = 0, Font = Enum.Font.SourceSans,
			Position = UDim2.new(0,0,0,0), Size = UDim2.new(1,0,0,24),
			Text = "Right click a remote/bindable in Explorer, then choose Remote Usage Map.",
			TextColor3 = Settings.Theme.PlaceholderText, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = window.GuiElems.Content
		})
		addPadded(statusLabel)
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
	return RemoteUsageMap
end
-- TODO: Remove when open source
if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
