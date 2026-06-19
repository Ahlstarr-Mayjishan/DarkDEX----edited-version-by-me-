--!strict
--[[
	Smart Search App Module
	Ranked search across live instances, remotes, paths, classes, and cached source.
]]
local Main,Lib,Apps,Settings
local Explorer, ScriptViewer, SmartSearch
local API,RMD,env,service,plr,create,createSimple

local function initDeps(data)
	Main, Lib, Apps, Settings = data.Main, data.Lib, data.Apps, data.Settings
	API, RMD, env, service, plr = data.API, data.RMD, data.env, data.service, data.plr
	create, createSimple = data.create, data.createSimple
end

local function initAfterMain()
	Explorer = Apps.Explorer
	ScriptViewer = Apps.ScriptViewer
	SmartSearch = Apps.SmartSearch
end

local function main()
	local SmartSearch = {}
	local window, queryBox, statusLabel, resultsFrame
	local searchToken = 0
	local maxResults = 180
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
	local function clearResults()
		for _, child in pairs(resultsFrame:GetChildren()) do
			if child:IsA("GuiButton") or child:IsA("TextLabel") then child:Destroy() end
		end
	end
	local function normalize(text) return tostring(text or ""):lower() end
	local function scoreLive(obj, query)
		local name, className, path = normalize(obj.Name), normalize(obj.ClassName), normalize(getPath(obj))
		local score = 0
		if name == query then score += 80 elseif name:find(query,1,true) then score += 45 end
		if className == query then score += 35 elseif className:find(query,1,true) then score += 18 end
		if path:find(query,1,true) then score += 10 end
		if remoteClasses[obj.ClassName] then score += 12 end
		if obj:IsA("LuaSourceContainer") then score += 8 end
		return score
	end
	local function scriptLookup()
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
	local function addRow(title, detail, kind, score, callback)
		local row = createSimple("TextButton",{AutoButtonColor=false, BackgroundColor3=Settings.Theme.Main1, BorderColor3=Settings.Theme.Outline1, BorderSizePixel=1, Font=Enum.Font.SourceSans, Size=UDim2.new(1,-8,0,46), Text="", Parent=resultsFrame})
		createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,8,0,3), Size=UDim2.new(1,-92,0,18), Text=title, TextColor3=Settings.Theme.Text, TextSize=14, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
		createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,8,0,23), Size=UDim2.new(1,-16,0,18), Text=detail, TextColor3=Settings.Theme.PlaceholderText, TextSize=13, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
		createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSansBold, Position=UDim2.new(1,-78,0,3), Size=UDim2.new(0,70,0,18), Text=kind .. " " .. tostring(score), TextColor3=Settings.Theme.PlaceholderText, TextSize=12, TextXAlignment=Enum.TextXAlignment.Right, Parent=row})
		Lib.ButtonAnim(row,{Mode=2, StartColor=Settings.Theme.Main1, HoverColor=Settings.Theme.ButtonHover, PressColor=Settings.Theme.ButtonPress, OutlineColor=Settings.Theme.Outline1})
		if callback then row.MouseButton1Click:Connect(callback) end
	end
	local function render(rows)
		clearResults()
		table.sort(rows, function(a,b) return a.Score > b.Score end)
		for i, item in ipairs(rows) do
			if i > maxResults then break end
			addRow(item.Title, item.Detail, item.Kind, item.Score, item.Callback)
		end
		if #rows == 0 then
			addRow("No results", "Try a class, remote name, path segment, or code keyword.", "info", 0, nil)
		end
	end
	local function search()
		searchToken += 1
		local token = searchToken
		local query = normalize(queryBox.Text)
		if query == "" then setStatus("Enter a keyword first."); clearResults(); return end
		clearResults()
		setStatus("Searching live client surface...")
		window:Show()
		task.spawn(function()
			local rows = {}
			local index = env.ClientIndex
			local indexedSurface = index and index.RefreshSurface and index.RefreshSurface(false)
			local liveObjects = indexedSurface and indexedSurface.AllInstances or game:GetDescendants()
			for i, obj in ipairs(liveObjects) do
				if token ~= searchToken then return end
				local s = scoreLive(obj, query)
				if s > 0 then
					local path = getPath(obj)
					rows[#rows + 1] = {Title=obj.Name .. " [" .. obj.ClassName .. "]", Detail=path, Kind="live", Score=s, Callback=function()
						if env.setclipboard then env.setclipboard(path) end
					end}
				end
				if i % 250 == 0 then task.wait() end
			end
			if index and index.SearchCached and index.GetScriptLookup then
				setStatus("Searching cached source...")
				local byKey = index.GetScriptLookup()
				for _, hit in ipairs(index.SearchCached(query, function() return token == searchToken end, 120)) do
					local entry, scr = hit.Entry, byKey[hit.Key]
					local hitScore = normalize(entry.Path):find(query,1,true) and 42 or 22
					rows[#rows + 1] = {Title=tostring(entry.Path or entry.Name), Detail=hit.Snippet or "cached code hit", Kind="code", Score=hitScore, Callback=function()
						if scr and ScriptViewer then ScriptViewer.ViewScript(scr) end
					end}
				end
			elseif env.DecompileCache and env.DecompileCache.GetEntries and env.isfile then
				setStatus("Searching cached source...")
				local byKey = scriptLookup()
				local entries, cacheDir = env.DecompileCache.GetEntries()
				for key, entry in pairs(entries) do
					if token ~= searchToken then return end
					if entry.File and env.isfile(cacheDir .. "/" .. tostring(entry.File)) then
						local ok, source = pcall(env.readfile, cacheDir .. "/" .. tostring(entry.File))
						if ok and type(source) == "string" and (source:lower():find(query,1,true) or normalize(entry.Path):find(query,1,true)) then
							local scr = byKey[key]
							rows[#rows + 1] = {Title=tostring(entry.Path or entry.Name), Detail="cached code hit", Kind="code", Score=22, Callback=function()
								if scr and ScriptViewer then ScriptViewer.ViewScript(scr) end
							end}
						end
					end
					task.wait()
				end
			end
			render(rows)
			setStatus(("Smart Search ready: %d result(s)."):format(math.min(#rows, maxResults)))
		end)
	end
	local function button(parent, text, x, w, cb)
		local b = createSimple("TextButton",{AutoButtonColor=false, BackgroundColor3=Settings.Theme.Button, BorderColor3=Settings.Theme.Outline2, Font=Enum.Font.SourceSans, Position=UDim2.new(0,x,0,4), Size=UDim2.new(0,w,0,22), Text=text, TextColor3=Settings.Theme.Text, TextSize=14, Parent=parent})
		b.MouseButton1Click:Connect(cb)
		Lib.ButtonAnim(b,{Mode=2, StartColor=Settings.Theme.Button, HoverColor=Settings.Theme.ButtonHover, PressColor=Settings.Theme.ButtonPress, OutlineColor=Settings.Theme.Outline2})
	end
	SmartSearch.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Smart Search")
		window:Resize(660,430)
		SmartSearch.Window = window
		local content = window.GuiElems.Content
		local toolbar = createSimple("Frame",{BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, Size=UDim2.new(1,0,0,60), Parent=content})
		queryBox = createSimple("TextBox",{BackgroundColor3=Settings.Theme.TextBox, BorderColor3=Settings.Theme.Outline3, ClearTextOnFocus=false, Font=Enum.Font.SourceSans, PlaceholderColor3=Settings.Theme.PlaceholderText, PlaceholderText="name / class / path / remote / code keyword", Position=UDim2.new(0,6,0,32), Size=UDim2.new(1,-12,0,22), Text="", TextColor3=Settings.Theme.Text, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left, Parent=toolbar})
		button(toolbar,"Search",6,64,search)
		button(toolbar,"Clear",76,54,function() clearResults(); setStatus("Cleared.") end)
		statusLabel = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,140,0,4), Size=UDim2.new(1,-146,0,22), Text="Ranked search across live objects and cached code.", TextColor3=Settings.Theme.PlaceholderText, TextSize=14, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=toolbar})
		resultsFrame = createSimple("ScrollingFrame",{Active=true, AutomaticCanvasSize=Enum.AutomaticSize.Y, BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, BottomImage="", CanvasSize=UDim2.new(0,0,0,0), Position=UDim2.new(0,0,0,60), ScrollBarImageColor3=Color3.fromRGB(70,70,70), ScrollBarThickness=10, Size=UDim2.new(1,0,1,-60), TopImage="", Parent=content})
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0,4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = resultsFrame
		local pad = Instance.new("UIPadding")
		pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop = UDim.new(0,6), UDim.new(0,4), UDim.new(0,4), UDim.new(0,4)
		pad.Parent = resultsFrame
		queryBox.FocusLost:Connect(function(enterPressed) if enterPressed then search() end end)
	end
	SmartSearch.Search = search
	return SmartSearch
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
