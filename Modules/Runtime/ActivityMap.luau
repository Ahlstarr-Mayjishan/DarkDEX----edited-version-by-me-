--!strict
--[[
	Runtime Activity Map App Module
	Shows recent live instance churn and RuntimeInspector remote activity.
]]
local Main,Lib,Apps,Settings
local Explorer, RuntimeInspector, ActivityMap, Notebook
local API,RMD,env,service,plr,create,createSimple

local function initDeps(data)
	Main, Lib, Apps, Settings = data.Main, data.Lib, data.Apps, data.Settings
	API, RMD, env, service, plr = data.API, data.RMD, data.env, data.service, data.plr
	create, createSimple = data.create, data.createSimple
end

local function initAfterMain()
	Explorer = Apps.Explorer
	RuntimeInspector = Apps.RuntimeInspector
	ActivityMap = Apps.ActivityMap
	Notebook = Apps.Notebook
end

local function main()
	local ActivityMap = {}
	local window, listFrame, statusLabel
	local running = false
	local cons = {}
	local events = {}
	local maxEvents = 160

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
	local function row(title, detail, muted)
		local item = createSimple("TextLabel",{
			BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Size = UDim2.new(1,-8,0,detail and 38 or 22),
			Text = detail and (title .. "\n" .. detail) or title,
			TextColor3 = muted and Settings.Theme.PlaceholderText or Settings.Theme.Text,
			TextSize = 14, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = listFrame
		})
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0,6)
		pad.Parent = item
	end
	local function push(kind, obj)
		events[#events + 1] = {Kind = kind, ClassName = obj.ClassName, Name = obj.Name, Path = getPath(obj), T = os.date("%H:%M:%S")}
		while #events > maxEvents do table.remove(events, 1) end
	end
	local function render()
		clearRows()
		local classCounts = {}
		for _, event in ipairs(events) do
			classCounts[event.ClassName] = (classCounts[event.ClassName] or 0) + 1
		end
		statusLabel.Text = ("Activity %s | events %d"):format(running and "ON" or "OFF", #events)
		row("Class activity", "Recent changed classes: " .. tostring(#events), true)
		local classes = {}
		for className, count in pairs(classCounts) do table.insert(classes, {Name = className, Count = count}) end
		table.sort(classes, function(a,b) return a.Count > b.Count end)
		for i = 1, math.min(8, #classes) do row(classes[i].Name .. " - " .. classes[i].Count, nil, false) end
		row("Recent events", nil, true)
		for i = #events, math.max(1, #events - 60), -1 do
			local event = events[i]
			row(event.T .. " " .. event.Kind .. " " .. event.Name .. " [" .. event.ClassName .. "]", event.Path, false)
		end
		if RuntimeInspector and RuntimeInspector.GetBuffers then
			local buffers = RuntimeInspector.GetBuffers()
			row("Runtime remote activity", (#(buffers.RemoteCall or {}) .. " captured calls"), true)
			for i, call in ipairs(buffers.RemoteCall or {}) do
				if i > 20 then break end
				row(call.Method .. " " .. call.Name, call.Path, false)
			end
		end
	end
	local function start()
		if running then return end
		running = true
		cons[#cons + 1] = Main.RegisterConnection(game.DescendantAdded:Connect(function(obj) push("added", obj) end))
		cons[#cons + 1] = Main.RegisterConnection(game.DescendantRemoving:Connect(function(obj) push("removed", obj) end))
		render()
	end
	local function stop()
		running = false
		for _, con in ipairs(cons) do pcall(function() con:Disconnect() end) end
		cons = {}
		render()
	end
	local function button(parent, text, x, w, cb)
		local b = createSimple("TextButton",{AutoButtonColor=false, BackgroundColor3=Settings.Theme.Button, BorderColor3=Settings.Theme.Outline2, Font=Enum.Font.SourceSans, Position=UDim2.new(0,x,0,4), Size=UDim2.new(0,w,0,22), Text=text, TextColor3=Settings.Theme.Text, TextSize=14, Parent=parent})
		b.MouseButton1Click:Connect(cb)
		Lib.ButtonAnim(b,{Mode=2, StartColor=Settings.Theme.Button, HoverColor=Settings.Theme.ButtonHover, PressColor=Settings.Theme.ButtonPress, OutlineColor=Settings.Theme.Outline2})
	end
	ActivityMap.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Runtime Activity Map")
		window:Resize(620,420)
		ActivityMap.Window = window
		local content = window.GuiElems.Content
		local toolbar = createSimple("Frame",{BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, Size=UDim2.new(1,0,0,56), Parent=content})
		button(toolbar,"Start",6,58,start)
		button(toolbar,"Stop",70,58,stop)
		button(toolbar,"Refresh",134,68,render)
		button(toolbar,"Clear",208,54,function() events = {}; render() end)
		statusLabel = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,6,0,30), Size=UDim2.new(1,-12,0,20), Text="Activity OFF | events 0", TextColor3=Settings.Theme.PlaceholderText, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left, Parent=toolbar})
		listFrame = createSimple("ScrollingFrame",{Active=true, AutomaticCanvasSize=Enum.AutomaticSize.Y, BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, BottomImage="", CanvasSize=UDim2.new(0,0,0,0), Position=UDim2.new(0,0,0,56), ScrollBarImageColor3=Color3.fromRGB(70,70,70), ScrollBarThickness=10, Size=UDim2.new(1,0,1,-56), TopImage="", Parent=content})
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0,4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = listFrame
		render()
	end
	ActivityMap.Start, ActivityMap.Stop = start, stop
	ActivityMap.Uninit = function()
		stop()
	end
	return ActivityMap
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
