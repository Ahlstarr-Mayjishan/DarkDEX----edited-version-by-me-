--!nocheck
--[[
	Property Tracker Module
	Listens to real-time property changes on selected instances and logs changes.
]]
local Main, Lib, Apps, Settings, env
local Explorer

local function initDeps(data)
	Main = data.Main
	Lib = data.Lib
	Apps = data.Apps
	Settings = data.Settings
	env = data.env
end

local function initAfterMain(apps)
	Explorer = apps.Explorer
end

local function main()
	local PropertyTracker = {}
	local window
	local instListFrame, propListFrame, logListFrame
	local selectedInstance: Instance? = nil
	local searchText = ""
	local logs = {}
	local helperLogWindow = 0
	local helperLogCount = 0
	
	local trackedInstances = {}
	-- Struct:
	-- [Instance] = {
	--     Connections = { [propName] = RBXScriptConnection },
	--     ActiveProps = { [propName] = boolean },
	--     LastValues = { [propName] = any }
	-- }

	local commonProps = {
		Name = true, Parent = true, Visible = true, Enabled = true,
		Transparency = true, Color = true, Text = true, Value = true,
		CFrame = true, Position = true, Anchored = true, Size = true,
		CanCollide = true, PlaybackState = true, Volume = true, SoundId = true
	}

	local function countTracked()
		local instances = 0
		local props = 0
		for _, data in pairs(trackedInstances) do
			instances += 1
			for _ in pairs(data.ActiveProps) do
				props += 1
			end
		end
		return instances, props
	end

	local function reportTool(extra)
		if not Main or not Main.ReportToolState then return end
		local instances, props = countTracked()
		local state = {
			State = instances > 0 and "tracking" or "idle",
			Load = Settings.Decompiler and Settings.Decompiler.HelperLogChanges == true and "medium" or "low",
			Tracked = instances,
			Properties = props,
			Logs = #logs,
			HelperLogging = Settings.Decompiler and Settings.Decompiler.HelperLogChanges == true or false,
			HelperLogRateLimit = Settings.Decompiler and Settings.Decompiler.HelperLogRateLimit or 0
		}
		if extra then
			for k, v in pairs(extra) do
				state[k] = v
			end
		end
		pcall(Main.ReportToolState, "Property Tracker", state)
	end

	-- Retrieves all readable/writable properties of an instance
	local function getProperties(obj: Instance)
		local propsList = {}
		local seen = {}
		local className = obj.ClassName
		local apiClass = Main.GetInitDeps().API.Classes[className]
		while apiClass do
			for _, prop in ipairs(apiClass.Properties) do
				if not seen[prop.Name] then
					seen[prop.Name] = true
					local s, _ = pcall(function() return obj[prop.Name] end)
					if s and not prop.Tags.ReadOnly then
						table.insert(propsList, prop.Name)
					end
				end
			end
			apiClass = apiClass.Superclass
		end
		table.sort(propsList)
		return propsList
	end

	local function addLog(inst: Instance, propName: string, oldVal: any, newVal: any)
		local timestamp = os.date("%H:%M:%S")
		local instPath = inst.Name
		pcall(function()
			instPath = inst:GetFullName()
		end)
		
		local logEntry = {
			Time = timestamp,
			Path = instPath,
			Property = propName,
			Old = tostring(oldVal),
			New = tostring(newVal)
		}
		table.insert(logs, 1, logEntry)
		if #logs > 500 then
			table.remove(logs, 501)
		end
		reportTool({LastChange = instPath .. "." .. propName})
		
		PropertyTracker.RenderLogs()

		-- Forward change logs only when explicitly enabled; high-frequency property
		-- changes can otherwise spam local HTTP and make the client stutter.
		if not Settings.Decompiler or Settings.Decompiler.HelperLogChanges ~= true then
			return
		end
		local now = os.clock()
		if now - helperLogWindow >= 1 then
			helperLogWindow = now
			helperLogCount = 0
		end
		helperLogCount += 1
		local helperLimit = tonumber(Settings.Decompiler.HelperLogRateLimit or 5) or 5
		if helperLogCount > math.max(0, helperLimit) then
			return
		end

		local logStr = string.format("[%s] %s.%s: %s -> %s", timestamp, instPath, propName, tostring(oldVal), tostring(newVal))
		if env.HelperServer and env.HelperServer.Log then
			local spawnFunc = (task and task.spawn) or function(f) coroutine.wrap(f)() end
			spawnFunc(function()
				pcall(env.HelperServer.Log, logStr)
			end)
			return
		end

		local req = env.request or (syn and syn.request) or (http and http.request) or http_request or request
		if req then
			local spawnFunc = (task and task.spawn) or function(f) coroutine.wrap(f)() end
			spawnFunc(function()
				pcall(function()
					req({
						Url = "http://localhost:8080/log",
						Method = "POST",
						Headers = {
							["Content-Type"] = "text/plain"
						},
						Body = logStr
					})
				end)
			end)
		end
	end

	local function getTrackData(inst: Instance)
		if not trackedInstances[inst] then
			trackedInstances[inst] = {
				Connections = {},
				ActiveProps = {},
				LastValues = {}
			}
		end
		return trackedInstances[inst]
	end

	local function stopTrackingProp(inst: Instance, propName: string)
		local data = trackedInstances[inst]
		if not data then return end
		if data.Connections[propName] then
			pcall(function() data.Connections[propName]:Disconnect() end)
			data.Connections[propName] = nil
		end
		data.ActiveProps[propName] = nil
		data.LastValues[propName] = nil
		reportTool()
	end

	local function startTrackingProp(inst: Instance, propName: string)
		local data = getTrackData(inst)
		if data.ActiveProps[propName] then return end
		
		local ok, initialVal = pcall(function() return inst[propName] end)
		if not ok then return end
		
		data.LastValues[propName] = initialVal
		data.ActiveProps[propName] = true
		
		local con
		ok, con = pcall(function()
			return inst:GetPropertyChangedSignal(propName):Connect(function()
				local success, newVal = pcall(function() return inst[propName] end)
				if success then
					local oldVal = data.LastValues[propName]
					if oldVal ~= newVal then
						data.LastValues[propName] = newVal
						addLog(inst, propName, oldVal, newVal)
					end
				end
			end)
		end)
		
		if ok and con then
			data.Connections[propName] = con
			reportTool()
		else
			data.ActiveProps[propName] = nil
			data.LastValues[propName] = nil
		end
	end

	local function clearRows(frame)
		for _, child in ipairs(frame:GetChildren()) do
			if child:IsA("GuiButton") or child:IsA("TextLabel") or child:IsA("Frame") then
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

	PropertyTracker.RenderInstances = function()
		clearRows(instListFrame)
		local index = 0
		for inst, data in pairs(trackedInstances) do
			local name = inst.Name .. " [" .. inst.ClassName .. "]"
			local btn = Lib.createSimple("TextButton", {
				BackgroundTransparency = (selectedInstance == inst) and 0 or 1,
				BackgroundColor3 = Settings.Theme.ButtonHover,
				BorderSizePixel = 0,
				Font = Enum.Font.SourceSans,
				Size = UDim2.new(1, -6, 0, 24),
				Text = "  " .. name,
				TextColor3 = Settings.Theme.Text,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = instListFrame
			})
			btn.MouseButton1Click:Connect(function()
				selectedInstance = inst
				PropertyTracker.RenderInstances()
				PropertyTracker.RenderProperties()
			end)
			index = index + 1
		end
		instListFrame.CanvasSize = UDim2.new(0, 0, 0, index * 26)
	end

	PropertyTracker.RenderProperties = function()
		clearRows(propListFrame)
		if not selectedInstance then return end
		local props = getProperties(selectedInstance)
		local data = getTrackData(selectedInstance)

		for i, propName in ipairs(props) do
			local row = Lib.createSimple("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, -6, 0, 24),
				Parent = propListFrame
			})
			
			local cb = Lib.Checkbox.new(data.ActiveProps[propName] and 1 or 0)
			cb.Gui.Position = UDim2.new(0, 4, 0, 4)
			cb.Gui.Parent = row
			
			cb.OnInput:Connect(function()
				if selectedInstance then
					if cb.Toggled then
						startTrackingProp(selectedInstance, propName)
					else
						stopTrackingProp(selectedInstance, propName)
					end
				end
			end)

			local _lbl = Lib.createSimple("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSans,
				Position = UDim2.new(0, 26, 0, 0),
				Size = UDim2.new(1, -26, 1, 0),
				Text = propName,
				TextColor3 = Settings.Theme.Text,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row
			})
		end
		propListFrame.CanvasSize = UDim2.new(0, 0, 0, #props * 26)
	end

	PropertyTracker.RenderLogs = function()
		clearRows(logListFrame)
		local index = 0
		local filter = string.lower(searchText)
		for _, log in ipairs(logs) do
			local match = (filter == "") or
				string.find(string.lower(log.Path), filter, 1, true) or
				string.find(string.lower(log.Property), filter, 1, true) or
				string.find(string.lower(log.Old), filter, 1, true) or
				string.find(string.lower(log.New), filter, 1, true)
				
			if match then
				local entryStr = string.format("[%s] %s.%s: %s -> %s", log.Time, log.Path:match("[^%.]+$") or log.Path, log.Property, log.Old, log.New)
				local lbl = Lib.createSimple("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSans,
					Size = UDim2.new(1, -6, 0, 36),
					Text = entryStr,
					TextColor3 = Settings.Theme.Text,
					TextSize = 13,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Parent = logListFrame
				})
				local pad = Instance.new("UIPadding")
				pad.PaddingLeft = UDim.new(0, 6)
				pad.Parent = lbl
				index = index + 1
			end
		end
		logListFrame.CanvasSize = UDim2.new(0, 0, 0, index * 38)
	end

	PropertyTracker.TrackInstance = function(inst: Instance)
		if not inst then return end
		getTrackData(inst)
		selectedInstance = inst
		
		-- Enable common properties by default
		local props = getProperties(inst)
		for _, propName in ipairs(props) do
			if commonProps[propName] then
				startTrackingProp(inst, propName)
			end
		end
		
		if window then
			window:Show()
			PropertyTracker.RenderInstances()
			PropertyTracker.RenderProperties()
		end
		reportTool()
	end

	PropertyTracker.UntrackInstance = function(inst: Instance)
		local data = trackedInstances[inst]
		if data then
			for propName in pairs(data.Connections) do
				stopTrackingProp(inst, propName)
			end
			trackedInstances[inst] = nil
		end
		if selectedInstance == inst then
			selectedInstance = nil
		end
		reportTool()
		PropertyTracker.RenderInstances()
		PropertyTracker.RenderProperties()
	end

	PropertyTracker.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Property Tracker")
		window:Resize(700, 450)
		PropertyTracker.Window = window

		local content = window.GuiElems.Content

		-- Toolbar
		local toolbar = Lib.createSimple("Frame", {
			BackgroundColor3 = Settings.Theme.Main2,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 32),
			Parent = content
		})

		button(toolbar, "Add Selected", UDim2.new(0, 6, 0, 4), UDim2.new(0, 100, 0, 24), function()
			if Explorer and Explorer.Selection and Explorer.Selection.List then
				for _, node in ipairs(Explorer.Selection.List) do
					if node.Obj then
						PropertyTracker.TrackInstance(node.Obj)
					end
				end
			end
		end)

		button(toolbar, "Remove Selected", UDim2.new(0, 112, 0, 4), UDim2.new(0, 110, 0, 24), function()
			if selectedInstance then
				PropertyTracker.UntrackInstance(selectedInstance)
			end
		end)

		button(toolbar, "Clear Logs", UDim2.new(0, 228, 0, 4), UDim2.new(0, 80, 0, 24), function()
			table.clear(logs)
			PropertyTracker.RenderLogs()
		end)

		button(toolbar, "Export Logs", UDim2.new(0, 314, 0, 4), UDim2.new(0, 90, 0, 24), function()
			if env.setclipboard then
				local logLines = {}
				for _, log in ipairs(logs) do
					table.insert(logLines, string.format("[%s] %s.%s: %s -> %s", log.Time, log.Path, log.Property, log.Old, log.New))
				end
				env.setclipboard(table.concat(logLines, "\n"))
				print("Logs copied to clipboard.")
			else
				warn("Clipboard API not supported!")
			end
		end)

		-- Search Bar
		local searchBox = Lib.createSimple("TextBox", {
			BackgroundColor3 = Settings.Theme.TextBox,
			BorderColor3 = Settings.Theme.Outline3,
			Font = Enum.Font.SourceSans,
			PlaceholderText = "Search logs...",
			Position = UDim2.new(1, -180, 0, 4),
			Size = UDim2.new(0, 174, 0, 24),
			Text = "",
			TextColor3 = Settings.Theme.Text,
			PlaceholderColor3 = Settings.Theme.PlaceholderText,
			TextSize = 14,
			Parent = toolbar
		})
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			searchText = searchBox.Text
			PropertyTracker.RenderLogs()
		end)

		-- Main Layout Panels
		local mainArea = Lib.createSimple("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0, 32),
			Size = UDim2.new(1, 0, 1, -32),
			Parent = content
		})

		-- Left panel: Tracked Instances
		local _leftTitle = Lib.createSimple("TextLabel", {
			BackgroundColor3 = Settings.Theme.Main1,
			BorderSizePixel = 0,
			Font = Enum.Font.SourceSansBold,
			Size = UDim2.new(0.3, -4, 0, 20),
			Text = " Tracked Instances",
			TextColor3 = Settings.Theme.PlaceholderText,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = mainArea
		})
		instListFrame = Lib.createSimple("ScrollingFrame", {
			BackgroundColor3 = Settings.Theme.Main2,
			BorderColor3 = Settings.Theme.Outline1,
			Position = UDim2.new(0, 0, 0, 20),
			Size = UDim2.new(0.3, -4, 1, -20),
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Settings.Theme.Highlight,
			Parent = mainArea
		})
		local instLayout = Instance.new("UIListLayout")
		instLayout.Padding = UDim.new(0, 2)
		instLayout.Parent = instListFrame

		-- Middle panel: Properties
		local midTitle = Lib.createSimple("TextLabel", {
			BackgroundColor3 = Settings.Theme.Main1,
			BorderSizePixel = 0,
			Font = Enum.Font.SourceSansBold,
			Position = UDim2.new(0.3, 0, 0, 0),
			Size = UDim2.new(0.3, -4, 0, 20),
			Text = " Properties Checklist",
			TextColor3 = Settings.Theme.PlaceholderText,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = mainArea
		})
		-- Watch Presets on Middle Title Panel
		local presetCommon = button(midTitle, "Common", UDim2.new(1, -120, 0, 2), UDim2.new(0, 56, 0, 16), function()
			if selectedInstance then
				local props = getProperties(selectedInstance)
				for _, propName in ipairs(props) do
					if commonProps[propName] then
						startTrackingProp(selectedInstance, propName)
					else
						stopTrackingProp(selectedInstance, propName)
					end
				end
				PropertyTracker.RenderProperties()
			end
		end)
		presetCommon.TextSize = 11
		
		local presetAll = button(midTitle, "All", UDim2.new(1, -60, 0, 2), UDim2.new(0, 26, 0, 16), function()
			if selectedInstance then
				local props = getProperties(selectedInstance)
				for _, propName in ipairs(props) do
					startTrackingProp(selectedInstance, propName)
				end
				PropertyTracker.RenderProperties()
			end
		end)
		presetAll.TextSize = 11
		
		local presetNone = button(midTitle, "None", UDim2.new(1, -30, 0, 2), UDim2.new(0, 28, 0, 16), function()
			if selectedInstance then
				local props = getProperties(selectedInstance)
				for _, propName in ipairs(props) do
					stopTrackingProp(selectedInstance, propName)
				end
				PropertyTracker.RenderProperties()
			end
		end)
		presetNone.TextSize = 11

		propListFrame = Lib.createSimple("ScrollingFrame", {
			BackgroundColor3 = Settings.Theme.Main2,
			BorderColor3 = Settings.Theme.Outline1,
			Position = UDim2.new(0.3, 0, 0, 20),
			Size = UDim2.new(0.3, -4, 1, -20),
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Settings.Theme.Highlight,
			Parent = mainArea
		})
		local propLayout = Instance.new("UIListLayout")
		propLayout.Padding = UDim.new(0, 2)
		propLayout.Parent = propListFrame

		-- Right panel: Change logs
		local _rightTitle = Lib.createSimple("TextLabel", {
			BackgroundColor3 = Settings.Theme.Main1,
			BorderSizePixel = 0,
			Font = Enum.Font.SourceSansBold,
			Position = UDim2.new(0.6, 0, 0, 0),
			Size = UDim2.new(0.4, 0, 0, 20),
			Text = " Property Change Logs",
			TextColor3 = Settings.Theme.PlaceholderText,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = mainArea
		})
		logListFrame = Lib.createSimple("ScrollingFrame", {
			BackgroundColor3 = Settings.Theme.Main2,
			BorderColor3 = Settings.Theme.Outline1,
			Position = UDim2.new(0.6, 0, 0, 20),
			Size = UDim2.new(0.4, 0, 1, -20),
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Settings.Theme.Highlight,
			Parent = mainArea
		})
		local logLayout = Instance.new("UIListLayout")
		logLayout.Padding = UDim.new(0, 2)
		logLayout.Parent = logListFrame

		PropertyTracker.RenderInstances()
		PropertyTracker.RenderLogs()
		reportTool()
	end

	return PropertyTracker
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
