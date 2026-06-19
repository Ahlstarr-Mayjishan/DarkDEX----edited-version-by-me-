--!nocheck
--[[
	Thread & Script Manager Module
	Allows inspection and management of running client scripts and active coroutines in the Luau registry.
]]
local Main, Lib, Apps, Settings, env
local Explorer, ScriptViewer

local function initDeps(data)
	Main = data.Main
	Lib = data.Lib
	Apps = data.Apps
	Settings = data.Settings
	env = data.env
end

local function initAfterMain(apps)
	Explorer = apps.Explorer
	ScriptViewer = apps.ScriptViewer
end

local function main()
	local ThreadManager = {}
	local window
	local activeTab = "Scripts" -- "Scripts" or "Threads"
	local toolbar, listFrame, statusLabel
	local searchBox
	local searchText = ""
	local scanningThreads = false
	
	local scriptList = {}
	local threadList = {}
	local threadDetails = {} -- Cache of thread details: [thread] = { Source, Line, Name, Status }

	local function reportTool(extra)
		if not Main or not Main.ReportToolState then return end
		local state = {
			State = scanningThreads and "scanning" or "idle",
			Load = scanningThreads and "medium" or "low",
			Tab = activeTab,
			Scripts = #scriptList,
			Threads = #threadList
		}
		if extra then
			for k, v in pairs(extra) do
				state[k] = v
			end
		end
		pcall(Main.ReportToolState, "Thread Manager", state)
	end

	local function clearRows()
		for _, child in ipairs(listFrame:GetChildren()) do
			if child:IsA("Frame") or child:IsA("TextLabel") or child:IsA("GuiButton") then
				child:Destroy()
			end
		end
	end

	local function button(parent, text, pos, size, cb)
		local b = Lib.createSimple("TextButton",{
			AutoButtonColor = false,
			BackgroundColor3 = Settings.Theme.Button,
			BorderColor3 = Settings.Theme.Outline2,
			Font = Enum.Font.SourceSans,
			Position = pos,
			Size = size,
			Text = text,
			TextColor3 = Settings.Theme.Text,
			TextSize = 14,
			Parent = parent
		})
		b.MouseButton1Click:Connect(cb)
		Lib.ButtonAnim(b, {
			Mode = 2,
			StartColor = Settings.Theme.Button,
			HoverColor = Settings.Theme.ButtonHover,
			PressColor = Settings.Theme.ButtonPress,
			OutlineColor = Settings.Theme.Outline2
		})
		return b
	end

	-- Retrieve active scripts
	local function refreshScripts()
		scriptList = {}
		if env and env.GetClientScripts then
			local ok, list = pcall(env.GetClientScripts, true)
			if ok and type(list) == "table" then
				scriptList = list
			end
		else
			-- Fallback to workspace descendants
			for _, v in ipairs(game:GetDescendants()) do
				if v:IsA("LocalScript") or v:IsA("ModuleScript") then
					table.insert(scriptList, v)
				end
			end
		end
		reportTool({State = "idle", Load = "low"})
	end

	-- Retrieve coroutines from registry asynchronously to prevent client hang
	local function refreshThreadsAsync()
		scanningThreads = true
		reportTool({State = "scanning", Load = "medium"})
		threadList = {}
		threadDetails = {}
		local getRegistry = env and env.getreg or getreg
		if not getRegistry then
			scanningThreads = false
			reportTool({State = "unavailable", Load = "off"})
			return
		end
		
		local ok, reg = pcall(getRegistry)
		if not ok or type(reg) ~= "table" then
			scanningThreads = false
			reportTool({State = "unavailable", Load = "off"})
			return
		end
		
		local yieldCounter = 0
		for _, v in pairs(reg) do
			if type(v) == "thread" then
				table.insert(threadList, v)
				
				-- Extract details
				local src, line, funcName = "Unknown", 0, "Anonymous"
				local status = "suspended"
				
				pcall(function()
					status = coroutine.status(v)
					local pok, s, l, n = pcall(debug.info, v, 1, "sln")
					if pok then
						src = s or "Unknown"
						line = l or 0
						funcName = n or "Anonymous"
					end
				end)
				
				threadDetails[v] = {
					Source = src,
					Line = line,
					Name = funcName,
					Status = status
				}
			end
			
			yieldCounter = yieldCounter + 1
			if yieldCounter % 150 == 0 then
				task.wait()
				reportTool({State = "scanning", Load = "medium"})
			end
		end
		scanningThreads = false
		reportTool({State = "idle", Load = "low"})
	end

	ThreadManager.Render = function()
		clearRows()
		local filter = string.lower(searchText)
		local count = 0
		
		if activeTab == "Scripts" then
			statusLabel.Text = string.format("Active Scripts: %d", #scriptList)
			for _, scr in ipairs(scriptList) do
				if not scr or not scr.Parent then continue end
				local fullName = scr:GetFullName()
				if filter ~= "" and not string.find(string.lower(fullName), filter, 1, true) then
					continue
				end
				
				local row = Lib.createSimple("Frame", {
					BackgroundColor3 = Settings.Theme.Main1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, -6, 0, 36),
					Parent = listFrame
				})
				
				local _title = Lib.createSimple("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSansBold,
					Position = UDim2.new(0, 6, 0, 2),
					Size = UDim2.new(0.6, -12, 0, 16),
					Text = scr.Name .. " [" .. scr.ClassName .. "]",
					TextColor3 = Settings.Theme.Text,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = row
				})
				
				local _pathLbl = Lib.createSimple("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSans,
					Position = UDim2.new(0, 6, 0, 18),
					Size = UDim2.new(0.6, -12, 0, 14),
					Text = fullName,
					TextColor3 = Settings.Theme.PlaceholderText,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = row
				})
				
				-- Action buttons
				local toggleText = "Disable"
				local isCurrentlyDisabled = false
				pcall(function()
					if scr:IsA("LocalScript") then
						isCurrentlyDisabled = scr.Disabled
					end
				end)
				if isCurrentlyDisabled then
					toggleText = "Enable"
				end
				
				button(row, toggleText, UDim2.new(0.6, 0, 0, 6), UDim2.new(0, 60, 0, 24), function()
					pcall(function()
						if scr:IsA("LocalScript") then
							scr.Disabled = not scr.Disabled
							ThreadManager.Render()
						end
					end)
				end)
				
				button(row, "Decompile", UDim2.new(0.6, 66, 0, 6), UDim2.new(0, 70, 0, 24), function()
					if ScriptViewer then
						ScriptViewer.ViewScript(scr)
					end
				end)
				
				button(row, "Select", UDim2.new(0.6, 142, 0, 6), UDim2.new(0, 50, 0, 24), function()
                    if Explorer and Explorer.Selection and Explorer.ViewNode and nodes[scr] then
						Explorer.Selection:Set(nodes[scr])
						Explorer.ViewNode(nodes[scr])
					end
				end)
				
				count = count + 1
			end
			listFrame.CanvasSize = UDim2.new(0, 0, 0, count * 38)
			
		elseif activeTab == "Threads" then
			statusLabel.Text = string.format("Active Coroutines: %d", #threadList)
			for _, th in ipairs(threadList) do
				local details = threadDetails[th]
				if not details then continue end
				
				local displayStr = string.format("Thread (%s) | %s:%d - %s", details.Status, details.Source, details.Line, details.Name)
				if filter ~= "" and not string.find(string.lower(displayStr), filter, 1, true) then
					continue
				end
				
				local row = Lib.createSimple("Frame", {
					BackgroundColor3 = Settings.Theme.Main1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, -6, 0, 36),
					Parent = listFrame
				})
				
				local _info = Lib.createSimple("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSans,
					Position = UDim2.new(0, 6, 0, 0),
					Size = UDim2.new(0.7, -12, 1, 0),
					Text = displayStr,
					TextColor3 = Settings.Theme.Text,
					TextSize = 13,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = row
				})
				
				-- Cancel/Kill button
				button(row, "Kill", UDim2.new(0.75, 0, 0, 6), UDim2.new(0, 60, 0, 24), function()
					local taskCancel = env and env.task and env.task.cancel or task.cancel
					local ok, _err = pcall(taskCancel, th)
					if not ok then
						pcall(coroutine.close, th)
					end
					table.remove(threadList, table.find(threadList, th))
					threadDetails[th] = nil
					reportTool()
					ThreadManager.Render()
				end)
				
				count = count + 1
			end
			listFrame.CanvasSize = UDim2.new(0, 0, 0, count * 38)
		end
	end

	ThreadManager.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Active Thread & Script Manager")
		window:Resize(650, 420)
		ThreadManager.Window = window

		local content = window.GuiElems.Content

		-- Header Toolbar
		local header = Lib.createSimple("Frame", {
			BackgroundColor3 = Settings.Theme.Main2,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 32),
			Parent = content
		})

		-- Tab Buttons
		local tabScriptsBtn, tabThreadsBtn
		
		tabScriptsBtn = button(header, "Scripts", UDim2.new(0, 6, 0, 4), UDim2.new(0, 80, 0, 24), function()
			activeTab = "Scripts"
			tabScriptsBtn.BackgroundColor3 = Settings.Theme.Highlight
			tabThreadsBtn.BackgroundColor3 = Settings.Theme.Button
			refreshScripts()
			ThreadManager.Render()
		end)
		tabScriptsBtn.BackgroundColor3 = Settings.Theme.Highlight

		tabThreadsBtn = button(header, "Coroutines", UDim2.new(0, 90, 0, 4), UDim2.new(0, 80, 0, 24), function()
			activeTab = "Threads"
			tabScriptsBtn.BackgroundColor3 = Settings.Theme.Button
			tabThreadsBtn.BackgroundColor3 = Settings.Theme.Highlight
			
			statusLabel.Text = "Scanning registry threads..."
			task.spawn(function()
				refreshThreadsAsync()
				ThreadManager.Render()
			end)
		end)

		button(header, "Refresh", UDim2.new(0, 180, 0, 4), UDim2.new(0, 70, 0, 24), function()
			if activeTab == "Scripts" then
				refreshScripts()
				ThreadManager.Render()
			else
				statusLabel.Text = "Scanning registry threads..."
				task.spawn(function()
					refreshThreadsAsync()
					ThreadManager.Render()
				end)
			end
		end)

		-- Search filter
		searchBox = Lib.createSimple("TextBox", {
			BackgroundColor3 = Settings.Theme.TextBox,
			BorderColor3 = Settings.Theme.Outline3,
			Font = Enum.Font.SourceSans,
			PlaceholderText = "Search...",
			Position = UDim2.new(1, -160, 0, 4),
			Size = UDim2.new(0, 154, 0, 24),
			Text = "",
			TextColor3 = Settings.Theme.Text,
			PlaceholderColor3 = Settings.Theme.PlaceholderText,
			TextSize = 14,
			Parent = header
		})
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			searchText = searchBox.Text
			ThreadManager.Render()
		end)

		-- Status Label Panel
		local statusPanel = Lib.createSimple("Frame", {
			BackgroundColor3 = Settings.Theme.Main1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 32),
			Size = UDim2.new(1, 0, 0, 20),
			Parent = content
		})
		
		statusLabel = Lib.createSimple("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			Position = UDim2.new(0, 6, 0, 0),
			Size = UDim2.new(1, -12, 1, 0),
			Text = "Loading running scripts...",
			TextColor3 = Settings.Theme.PlaceholderText,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = statusPanel
		})

		-- Scrollable List
		listFrame = Lib.createSimple("ScrollingFrame", {
			BackgroundColor3 = Settings.Theme.Main2,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 52),
			Size = UDim2.new(1, 0, 1, -52),
			ScrollBarThickness = 8,
			ScrollBarImageColor3 = Settings.Theme.Highlight,
			Parent = content
		})
		local listLayout = Instance.new("UIListLayout")
		listLayout.Padding = UDim.new(0, 4)
		listLayout.Parent = listFrame

		-- Initial Load
		refreshScripts()
		ThreadManager.Render()
		reportTool()
	end

	return ThreadManager
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
