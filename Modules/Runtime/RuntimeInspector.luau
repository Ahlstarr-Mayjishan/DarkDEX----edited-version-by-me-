--!strict
--[[
	Runtime Inspector App Module
	Correlates Remote calls with RakNet outbound packet activity.
]]
local Main,Lib,Apps,Settings
local Explorer, Properties, ScriptViewer, RuntimeInspector, RemoteUsageMap, Notebook
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
	Properties = Apps.Properties
	ScriptViewer = Apps.ScriptViewer
	RuntimeInspector = Apps.RuntimeInspector
	RemoteUsageMap = Apps.RemoteUsageMap
	Notebook = Apps.Notebook
end
local function main()
	local RuntimeInspector = {}
	local window, listFrame, statusLabel
	local activeTab = "Remote Calls"
	local refreshQueued = false
	local remoteHookInstalled = false
	local raknetRunning = false
	local buffers = {RemoteCall = {}, Packet = {}, Correlation = {}}
	local packetStats = {}
	local limits = {RemoteCall = 120, Packet = 80, Correlation = 120}
	local state = {RemoteEnabled = false, RakNetEnabled = false, CaptureArgs = false, PacketSample = false}
	local remoteMethods = {FireServer = true, InvokeServer = true, Fire = true, Invoke = true}
	local function now()
		return os.clock()
	end
	local function push(kind, data)
		local bucket = buffers[kind]
		if not bucket then return end
		data.Time = data.Time or now()
		table.insert(bucket, 1, data)
		while #bucket > (limits[kind] or 300) do
			table.remove(bucket)
		end
	end
	local function getPath(obj)
        if Main and Main.SafeGetInstancePath then return Main.SafeGetInstancePath(obj) end
		local success, path = pcall(function()
			if Explorer and Explorer.GetInstancePath then return Explorer.GetInstancePath(obj) end
			return obj:GetFullName()
		end)
		return success and tostring(path) or tostring(obj)
	end
	local function summarizeValue(value, depth)
		depth = depth or 0
		if depth > 1 then return "..." end
		local kind = typeof(value)
		if kind == "Instance" then return value.ClassName .. ":" .. getPath(value) end
		if kind == "string" then return (#value > 80 and value:sub(1,80) .. "...(" .. #value .. ")" or value) end
		if kind == "table" then
			local parts, count = {}, 0
			for key, val in pairs(value) do
				count += 1
				if count > 5 then table.insert(parts, "..."); break end
				table.insert(parts, tostring(key) .. "=" .. summarizeValue(val, depth + 1))
			end
			return "{" .. table.concat(parts, ", ") .. "}"
		end
		return tostring(value)
	end
	local function summarizeArgs(...)
		if not state.CaptureArgs then return "args hidden" end
		local parts = {}
		for i = 1, math.min(select("#", ...), 6) do
			local value = select(i, ...)
			table.insert(parts, typeof(value) .. "=" .. summarizeValue(value))
		end
		if select("#", ...) > 6 then table.insert(parts, "...") end
		return table.concat(parts, " | ")
	end
	local function getCaller()
		local callerFunc = getcallingscript
		if type(callerFunc) == "function" then
			local success, caller = pcall(callerFunc)
			if success and typeof(caller) == "Instance" then return caller end
		end
		return nil
	end
	local function addCorrelation(packet)
		local t = packet.Time
		for _, call in ipairs(buffers.RemoteCall) do
			local delta = t - call.Time
			if delta < -0.05 then break end
			if delta <= 0.35 then
				push("Correlation", {
					RemotePath = call.Path,
					Method = call.Method,
					PacketId = packet.PacketId,
					Bytes = packet.Size,
					Delta = delta,
				})
				break
			end
		end
	end
	local function installRemoteHook()
		if remoteHookInstalled or not env.hookmetamethod then return end
		local old
		old = env.hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			local method = getnamecallmethod()
			if state.RemoteEnabled and remoteMethods[method] and typeof(self) == "Instance" then
				local className = self.ClassName
				if className == "RemoteEvent" or className == "RemoteFunction" or className == "BindableEvent" or className == "BindableFunction" or className == "UnreliableRemoteEvent" then
					local caller = getCaller()
					push("RemoteCall", {
						Method = method,
						Name = self.Name,
						ClassName = className,
						Path = getPath(self),
						ArgCount = select("#", ...),
						Args = summarizeArgs(...),
						Caller = caller and getPath(caller) or "unknown",
						Remote = self,
						CallerScript = caller,
					})
				end
			end
			return old(self, ...)
		end))
		remoteHookInstalled = true
	end
	local function startRemoteLogger()
		state.RemoteEnabled = true
		installRemoteHook()
	end
	local function stopRemoteLogger()
		state.RemoteEnabled = false
	end
	local function startRakNet()
		local rk = rawget(getgenv and getgenv() or _G, "raknet") or rawget(_G, "raknet")
		if raknetRunning or type(rk) ~= "table" or type(rk.add_send_hook) ~= "function" then return false end
		pcall(function() if type(rk.remove_send_hook) == "function" then rk.remove_send_hook() end end)
		rk.add_send_hook(function(packet)
			if not state.RakNetEnabled then return end
			local id, size = packet.PacketId or -1, packet.Size or 0
			local stat = packetStats[id] or {Count = 0, Bytes = 0, LastPriority = 0, LastReliability = 0, LastChannel = 0}
			stat.Count += 1
			stat.Bytes += size
			stat.LastPriority = packet.Priority or 0
			stat.LastReliability = packet.Reliability or 0
			stat.LastChannel = packet.OrderingChannel or 0
			packetStats[id] = stat
			local event = {PacketId = id, Size = size, Priority = stat.LastPriority, Reliability = stat.LastReliability, Channel = stat.LastChannel, Time = now()}
			if state.PacketSample then
				local ok, sample = pcall(function() return packet.AsString end)
				event.Sample = ok and type(sample) == "string" and sample:sub(1,80) or ""
			end
			push("Packet", event)
			addCorrelation(event)
		end)
		raknetRunning = true
		state.RakNetEnabled = true
		return true
	end
	local function stopRakNet()
		state.RakNetEnabled = false
		local rk = rawget(getgenv and getgenv() or _G, "raknet") or rawget(_G, "raknet")
		if type(rk) == "table" and type(rk.remove_send_hook) == "function" then pcall(rk.remove_send_hook) end
		raknetRunning = false
	end
	local function clearData()
		buffers.RemoteCall, buffers.Packet, buffers.Correlation = {}, {}, {}
		packetStats = {}
	end
	local function setStatus()
		if not statusLabel then return end
		statusLabel.Text = ("Remote %s | RakNet %s | calls %d | packets %d | corr %d"):format(
			state.RemoteEnabled and "ON" or "OFF",
			state.RakNetEnabled and "ON" or "OFF",
			#buffers.RemoteCall,
			#buffers.Packet,
			#buffers.Correlation
		)
	end
	local function clearRows()
		if not listFrame then return end
		for _, child in pairs(listFrame:GetChildren()) do
			if child:IsA("GuiButton") or child:IsA("TextLabel") then child:Destroy() end
		end
	end
	local function addRow(text, subText, onClick)
		local row = createSimple("TextButton",{AutoButtonColor=false, BackgroundColor3=Settings.Theme.Main2, BorderColor3=Settings.Theme.Outline1, Font=Enum.Font.SourceSans, Size=UDim2.new(1,-8,0,subText and 42 or 24), Text="", Parent=listFrame})
		local title = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,6,0,2), Size=UDim2.new(1,-12,0,18), Text=text, TextColor3=Settings.Theme.Text, TextSize=14, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
		if subText then
			createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,6,0,21), Size=UDim2.new(1,-12,0,18), Text=subText, TextColor3=Settings.Theme.PlaceholderText, TextSize=13, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
		end
		Lib.ButtonAnim(row,{Mode=2, StartColor=Settings.Theme.Main2, HoverColor=Settings.Theme.ButtonHover, PressColor=Settings.Theme.ButtonPress, OutlineColor=Settings.Theme.Outline1})
		if onClick then row.MouseButton1Click:Connect(onClick) end
	end
	local function renderRemoteCalls()
		local rendered = 0
		for _, call in ipairs(buffers.RemoteCall) do
			rendered += 1
			if rendered > 120 then break end
			addRow(call.Method .. " " .. call.Path, call.Caller .. " | argc " .. tostring(call.ArgCount) .. " | " .. call.Args, function()
				if call.Remote and RemoteUsageMap then RemoteUsageMap.ShowForRemote(call.Remote) end
			end)
		end
	end
	local function renderPacketStats()
		local rows = {}
		for id, stat in pairs(packetStats) do table.insert(rows, {Id=id, Count=stat.Count, Bytes=stat.Bytes, Stat=stat}) end
		table.sort(rows, function(a,b) return a.Bytes > b.Bytes end)
		for _, row in ipairs(rows) do
			addRow(("Packet %s | %d packets | %d bytes"):format(tostring(row.Id), row.Count, row.Bytes), ("priority %d | reliability %d | channel %d"):format(row.Stat.LastPriority, row.Stat.LastReliability, row.Stat.LastChannel))
		end
	end
	local function renderCorrelations()
		local rendered = 0
		for _, item in ipairs(buffers.Correlation) do
			rendered += 1
			if rendered > 120 then break end
			addRow(("%s -> packet %s (%d bytes)"):format(item.Method, tostring(item.PacketId), item.Bytes), ("%0.3fs | %s"):format(item.Delta or 0, item.RemotePath))
		end
	end
	local function renderPackets()
		local rendered = 0
		for _, packet in ipairs(buffers.Packet) do
			rendered += 1
			if rendered > 80 then break end
			addRow(("Packet %s | %d bytes"):format(tostring(packet.PacketId), packet.Size), ("priority %d | reliability %d | channel %d"):format(packet.Priority, packet.Reliability, packet.Channel))
		end
	end
	local function render()
		clearRows()
		setStatus()
		if activeTab == "Remote Calls" then renderRemoteCalls()
		elseif activeTab == "Packet Stats" then renderPacketStats()
		elseif activeTab == "Correlations" then renderCorrelations()
		else renderPackets() end
	end
	local function queueRefresh()
		if refreshQueued then return end
		refreshQueued = true
		task.spawn(function()
			while window and not window.Closed do
				render()
				task.wait(1)
			end
			refreshQueued = false
		end)
	end
	local function makeButton(text, x, w, callback)
		local button = createSimple("TextButton",{AutoButtonColor=false, BackgroundColor3=Settings.Theme.Button, BorderColor3=Settings.Theme.Outline2, Font=Enum.Font.SourceSans, Position=UDim2.new(0,x,0,4), Size=UDim2.new(0,w,0,22), Text=text, TextColor3=Settings.Theme.Text, TextSize=14})
		button.MouseButton1Click:Connect(callback)
		Lib.ButtonAnim(button,{Mode=2, StartColor=Settings.Theme.Button, HoverColor=Settings.Theme.ButtonHover, PressColor=Settings.Theme.ButtonPress, OutlineColor=Settings.Theme.Outline2})
		return button
	end
	RuntimeInspector.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Runtime Inspector")
		window:Resize(640,430)
		RuntimeInspector.Window = window
		local content = window.GuiElems.Content
		local toolbar = createSimple("Frame",{BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, Size=UDim2.new(1,0,0,58), Parent=content})
		makeButton("Remote", 6, 64, function() if state.RemoteEnabled then stopRemoteLogger() else startRemoteLogger() end; render() end).Parent = toolbar
		makeButton("RakNet", 76, 64, function() if state.RakNetEnabled then stopRakNet() else startRakNet() end; render() end).Parent = toolbar
		makeButton("Clear", 146, 54, function() clearData(); render() end).Parent = toolbar
		local tabs = {"Remote Calls","Packet Stats","Correlations","Packets"}
		local x = 210
		for _, tab in ipairs(tabs) do
			local width = tab == "Correlations" and 86 or 82
			makeButton(tab, x, width, function() activeTab = tab; render() end).Parent = toolbar
			x += width + 6
		end
		statusLabel = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,6,0,32), Size=UDim2.new(1,-12,0,20), TextColor3=Settings.Theme.PlaceholderText, TextSize=14, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=toolbar})
		listFrame = createSimple("ScrollingFrame",{Active=true, AutomaticCanvasSize=Enum.AutomaticSize.Y, BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, BottomImage="", CanvasSize=UDim2.new(0,0,0,0), Position=UDim2.new(0,0,0,58), ScrollBarImageColor3=Color3.fromRGB(70,70,70), ScrollBarThickness=10, Size=UDim2.new(1,0,1,-58), TopImage="", Parent=content})
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
		window.OnActivate:Connect(queueRefresh)
		render()
	end
	RuntimeInspector.StartRemoteLogger, RuntimeInspector.StopRemoteLogger = startRemoteLogger, stopRemoteLogger
	RuntimeInspector.StartRakNet, RuntimeInspector.StopRakNet = startRakNet, stopRakNet
	RuntimeInspector.Clear, RuntimeInspector.GetBuffers = clearData, function() return buffers end
	RuntimeInspector.Uninit = function()
		stopRemoteLogger()
		stopRakNet()
	end
	return RuntimeInspector
end
if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
