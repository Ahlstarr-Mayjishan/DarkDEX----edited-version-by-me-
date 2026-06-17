local main_ref, lib_ref, apps_ref, settings_ref
local explorer_ref, properties_ref
 
local plugin_data = {
	name         = "RemoteSpy",
	FriendlyName = "Remote Spy",
}
 
local function initDeps(data)
	main_ref     = data.Main
	lib_ref      = data.Lib
	apps_ref     = data.Apps
	settings_ref = data.Settings
end
 
local function initAfterMain(t)
	explorer_ref   = t.Explorer
	properties_ref = t.Properties
end
 
local function safe_str(v)
	local t = typeof(v)
	if t == "Instance" then
		local parts, cur = {}, v
		while cur and cur ~= game do
			table.insert(parts, 1, cur.Name)
			cur = cur.Parent
		end
		table.insert(parts, 1, "game")
		return table.concat(parts, ".")
	elseif t == "string" then
		local s = #v > 100 and v:sub(1, 100) .. "…" or v
		return '"' .. s:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n') .. '"'
	elseif t == "table" then
		local out, n = {}, 0
		for k, val in pairs(v) do
			n = n + 1
			if n > 6 then out[n] = "…" break end
			out[n] = tostring(k) .. "=" .. safe_str(val)
		end
		return "{" .. table.concat(out, ", ") .. "}"
	else
		return tostring(v)
	end
end
 
local function args_str(args)
	local n = args.n or #args
	if n == 0 then return "()" end
	local out = {}
	for i = 1, n do out[i] = safe_str(args[i]) end
	return table.concat(out, ", ")
end
 
local function inst_path(obj)
	if not obj then return "?" end
	local parts, cur = {}, obj
	while cur and cur ~= game do
		table.insert(parts, 1, cur.Name)
		cur = cur.Parent
	end
	table.insert(parts, 1, "game")
	return table.concat(parts, ".")
end
 
local function main()
	local spy = {}
	spy.PluginData = plugin_data
 
	local logs        = {}
	local log_frames  = {}
	local filter_text = ""
	local paused      = false
	local log_limit   = 400
	local active      = false
 
	local namecall_orig = nil
	local hook_cons   = {}
	local seen        = {}
	setmetatable(seen, { __mode = "k" })
 
	local colors = {
		out_remote   = Color3.fromRGB(100, 200, 255),
		in_remote    = Color3.fromRGB(120, 255, 120),
		out_bindable = Color3.fromRGB(255, 200, 80),
		in_bindable  = Color3.fromRGB(255, 140, 60),
	}
 
	local remote_classes = {
		RemoteEvent           = true,
		RemoteFunction        = true,
		UnreliableRemoteEvent = true,
		BindableEvent         = true,
		BindableFunction      = true,
	}
 
	local out_methods = {
		FireServer = true, InvokeServer = true,
		fireServer = true, invokeServer = true,
		Fire = true, Invoke = true,
		fire = true, invoke = true,
	}
 
	local in_signals = {
		RemoteEvent           = "OnClientEvent",
		UnreliableRemoteEvent = "OnClientEvent",
		BindableEvent         = "Event",
	}
 
	local window, list_frame, scroll_v, status_label
 
	local function color_for(dir, class_name)
		local is_bind = class_name == "BindableEvent" or class_name == "BindableFunction"
		if dir == "out" then
			return is_bind and colors.out_bindable or colors.out_remote
		else
			return is_bind and colors.in_bindable or colors.in_remote
		end
	end
 
	local function matches(entry)
		if filter_text == "" then return true end
		local low = filter_text:lower()
		return entry.path:lower():find(low, 1, true)
			or entry.method:lower():find(low, 1, true)
			or entry.args:lower():find(low, 1, true)
	end
 
	local function push_row(entry)
		if not list_frame then return end
		local col = color_for(entry.dir, entry.class)
 
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
		row.BorderSizePixel  = 0
		row.Size             = UDim2.new(1, 0, 0, 36)
		row.ClipsDescendants = true
 
		local badge = Instance.new("Frame", row)
		badge.BackgroundColor3 = col
		badge.BorderSizePixel  = 0
		badge.Size             = UDim2.new(0, 3, 1, 0)
 
		local tl = Instance.new("TextLabel", row)
		tl.BackgroundTransparency = 1
		tl.Position  = UDim2.new(0, 8, 0, 0)
		tl.Size      = UDim2.new(0, 55, 0, 18)
		tl.Font      = Enum.Font.Code
		tl.TextSize  = 11
		tl.TextColor3 = Color3.fromRGB(130, 130, 130)
		tl.TextXAlignment = Enum.TextXAlignment.Left
		tl.Text = entry.time
 
		local dl = Instance.new("TextLabel", row)
		dl.BackgroundTransparency = 1
		dl.Position  = UDim2.new(0, 66, 0, 0)
		dl.Size      = UDim2.new(0, 150, 0, 18)
		dl.Font      = Enum.Font.SourceSansBold
		dl.TextSize  = 13
		dl.TextColor3 = col
		dl.TextXAlignment = Enum.TextXAlignment.Left
		dl.Text = (entry.dir == "out" and "outgoing" or "incoming") .. "  [" .. entry.class .. "]"
 
		local ml = Instance.new("TextLabel", row)
		ml.BackgroundTransparency = 1
		ml.Position  = UDim2.new(0, 220, 0, 0)
		ml.Size      = UDim2.new(0, 120, 0, 18)
		ml.Font      = Enum.Font.Code
		ml.TextSize  = 12
		ml.TextColor3 = Color3.fromRGB(200, 200, 200)
		ml.TextXAlignment = Enum.TextXAlignment.Left
		ml.Text = ":" .. entry.method .. "()"
 
		local pl = Instance.new("TextLabel", row)
		pl.BackgroundTransparency = 1
		pl.Position  = UDim2.new(0, 8, 0, 19)
		pl.Size      = UDim2.new(0.5, -10, 0, 15)
		pl.Font      = Enum.Font.Code
		pl.TextSize  = 11
		pl.TextColor3 = Color3.fromRGB(160, 160, 160)
		pl.TextXAlignment = Enum.TextXAlignment.Left
		pl.TextTruncate = Enum.TextTruncate.AtEnd
		pl.Text = entry.path
 
		local al = Instance.new("TextLabel", row)
		al.BackgroundTransparency = 1
		al.Position  = UDim2.new(0.5, 0, 0, 19)
		al.Size      = UDim2.new(0.5, -6, 0, 15)
		al.Font      = Enum.Font.Code
		al.TextSize  = 11
		al.TextColor3 = Color3.fromRGB(210, 210, 140)
		al.TextXAlignment = Enum.TextXAlignment.Right
		al.TextTruncate = Enum.TextTruncate.AtEnd
		al.Text = entry.args
 
		row.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement then
				row.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			elseif i.UserInputType == Enum.UserInputType.MouseButton2 and setclipboard then
				setclipboard(entry.path)
			end
		end)
		row.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement then
				row.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
			end
		end)
 
		row.LayoutOrder = #log_frames + 1
		row.Parent = list_frame
		table.insert(log_frames, row)
	end
 
	local function add_log(dir, inst, method, raw_args)
		if not active or paused then return end
 
		local entry = {
			time   = os.date("%H:%M:%S"),
			dir    = dir,
			path   = inst_path(inst),
			class  = inst.ClassName,
			method = method,
			args   = args_str(raw_args),
		}
 
		logs[#logs + 1] = entry
		if #logs > log_limit then
			table.remove(logs, 1)
		end
 
		if window and not window.Closed and matches(entry) then
			push_row(entry)
			if scroll_v then
				scroll_v.Index = math.max(0, #log_frames - scroll_v.VisibleSpace)
				scroll_v:Update()
			end
		end
 
		if status_label then
			status_label.Text = #logs .. " logs"
		end
	end
 
	local function rebuild_list()
		for _, f in ipairs(log_frames) do f:Destroy() end
		log_frames = {}
		for _, e in ipairs(logs) do
			if matches(e) then push_row(e) end
		end
	end
 
	local function hook_instance(inst)
		if seen[inst] then return end
		local sig = in_signals[inst.ClassName]
		if not sig then return end
		seen[inst] = true
 
		local ok, con = pcall(function()
			return inst[sig]:Connect(function(...)
				add_log("in", inst, sig, table.pack(...))
			end)
		end)
		if ok and con then
			hook_cons[#hook_cons + 1] = con
		end
	end
 
	local function start()
		if active then return end
		active = true
 
		if hookmetamethod and not namecall_orig then
			local ok, orig = pcall(hookmetamethod, game, "__namecall", function(self, ...)
				local method = getnamecallmethod and getnamecallmethod() or ""
				if active
					and typeof(self) == "Instance"
					and remote_classes[self.ClassName]
					and out_methods[method]
				then
					add_log("out", self, method, table.pack(...))
				end
				return namecall_orig(self, ...)
			end)
			if ok then namecall_orig = orig end
		end
 
		local ok, descs = pcall(game.GetDescendants, game)
		if ok then
			for _, inst in ipairs(descs) do
				hook_instance(inst)
			end
		end
 
		if getnilinstances then
			local ok2, nil_insts = pcall(getnilinstances)
			if ok2 then
				for _, inst in ipairs(nil_insts) do
					hook_instance(inst)
				end
			end
		end
 
		local da_con = game.DescendantAdded:Connect(function(inst)
			if active then hook_instance(inst) end
		end)
		hook_cons[#hook_cons + 1] = da_con
	end
 
	local function stop()
		if not active then return end
		active = false
 
		for _, con in ipairs(hook_cons) do
			pcall(function() con:Disconnect() end)
		end
		hook_cons = {}
 
		seen = {}
		setmetatable(seen, { __mode = "k" })
	end
 
	local function make_btn(parent, text, x, w)
		local btn = Instance.new("TextButton")
		btn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
		btn.BorderSizePixel  = 0
		btn.Font             = Enum.Font.SourceSans
		btn.TextSize         = 13
		btn.TextColor3       = Color3.new(1, 1, 1)
		btn.Text             = text
		btn.AutoButtonColor  = false
		btn.Size             = UDim2.new(0, w, 0, 18)
		btn.Position         = UDim2.new(0, x, 0, 2)
		btn.Parent           = parent
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
		btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(68, 68, 68) end)
		btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(55, 55, 55) end)
		return btn
	end
 
	spy.Init = function()
		window = lib_ref.Window.new()
		window:SetTitle("Remote Spy")
		window:Resize(600, 400)
		spy.Window = window
 
		local toolbar = Instance.new("Frame")
		toolbar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
		toolbar.BorderSizePixel  = 0
		toolbar.Size             = UDim2.new(1, 0, 0, 22)
		toolbar.Parent           = window.GuiElems.Content
 
		local start_btn = make_btn(toolbar, "▶ start",  2,  58)
		local stop_btn  = make_btn(toolbar, "■ stop",   64, 50)
		local clear_btn = make_btn(toolbar, "clear",   118, 42)
		local pause_btn = make_btn(toolbar, "pause",   164, 42)
		local copy_btn  = make_btn(toolbar, "copy all",210, 58)
 
		status_label = Instance.new("TextLabel")
		status_label.BackgroundTransparency = 1
		status_label.Font       = Enum.Font.SourceSans
		status_label.TextSize   = 12
		status_label.TextColor3 = Color3.fromRGB(110, 110, 110)
		status_label.TextXAlignment = Enum.TextXAlignment.Right
		status_label.Size       = UDim2.new(1, -274, 1, 0)
		status_label.Position   = UDim2.new(0, 272, 0, 0)
		status_label.Text       = "0 logs"
		status_label.Parent     = toolbar
 
		local search_bar = Instance.new("Frame")
		search_bar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		search_bar.BorderSizePixel  = 0
		search_bar.Size             = UDim2.new(1, 0, 0, 20)
		search_bar.Position         = UDim2.new(0, 0, 0, 22)
		search_bar.Parent           = window.GuiElems.Content
 
		local search_box = Instance.new("TextBox", search_bar)
		search_box.BackgroundTransparency = 1
		search_box.PlaceholderText  = "filter…"
		search_box.PlaceholderColor3 = Color3.fromRGB(80, 80, 80)
		search_box.Text             = ""
		search_box.Font             = Enum.Font.Code
		search_box.TextSize         = 13
		search_box.TextColor3       = Color3.new(1, 1, 1)
		search_box.TextXAlignment   = Enum.TextXAlignment.Left
		search_box.ClearTextOnFocus = false
		search_box.Size             = UDim2.new(1, -8, 1, 0)
		search_box.Position         = UDim2.new(0, 4, 0, 0)
		search_box:GetPropertyChangedSignal("Text"):Connect(function()
			filter_text = search_box.Text
			rebuild_list()
		end)
 
		local list_container = Instance.new("Frame")
		list_container.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
		list_container.BorderSizePixel  = 0
		list_container.Size             = UDim2.new(1, -16, 1, -42)
		list_container.Position         = UDim2.new(0, 0, 0, 42)
		list_container.ClipsDescendants = true
		list_container.Parent           = window.GuiElems.Content
 
		list_frame = Instance.new("Frame")
		list_frame.BackgroundTransparency = 1
		list_frame.Size         = UDim2.new(1, 0, 0, 0)
		list_frame.AutomaticSize = Enum.AutomaticSize.Y
		list_frame.Parent       = list_container
 
		local layout = Instance.new("UIListLayout", list_frame)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding   = UDim.new(0, 1)
 
		scroll_v = lib_ref.ScrollBar.new()
		scroll_v.WheelIncrement  = 3
		scroll_v.Gui.Position    = UDim2.new(1, -16, 0, 42)
		scroll_v.Gui.Size        = UDim2.new(0, 16, 1, -42)
		scroll_v.Gui.Parent      = window.GuiElems.Content
		scroll_v:SetScrollFrame(list_container)
		scroll_v.Scrolled:Connect(function()
			list_frame.Position = UDim2.new(0, 0, 0, -scroll_v.Index * 37)
		end)
 
		start_btn.MouseButton1Click:Connect(function()
			start()
			start_btn.BackgroundColor3 = Color3.fromRGB(28, 95, 48)
			start_btn.Text = "▶ active"
			stop_btn.BackgroundColor3  = Color3.fromRGB(55, 55, 55)
			stop_btn.Text  = "■ stop"
		end)
 
		stop_btn.MouseButton1Click:Connect(function()
			stop()
			start_btn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
			start_btn.Text = "▶ start"
			stop_btn.BackgroundColor3  = Color3.fromRGB(100, 38, 38)
			stop_btn.Text  = "■ stopped"
		end)
 
		clear_btn.MouseButton1Click:Connect(function()
			logs = {}
			for _, f in ipairs(log_frames) do f:Destroy() end
			log_frames = {}
			status_label.Text = "0 logs"
		end)
 
		pause_btn.MouseButton1Click:Connect(function()
			paused = not paused
			pause_btn.Text = paused and "resume" or "pause"
			pause_btn.BackgroundColor3 = paused
				and Color3.fromRGB(95, 75, 20)
				or  Color3.fromRGB(55, 55, 55)
		end)
 
		copy_btn.MouseButton1Click:Connect(function()
			if not setclipboard then return end
			local lines = {}
			for _, e in ipairs(logs) do
				lines[#lines + 1] = string.format("[%s] %s %s:%s() | %s",
					e.time, e.dir, e.path, e.method, e.args)
			end
			setclipboard(table.concat(lines, "\n"))
		end)
 
		window.OnActivate:Connect(function()
			if scroll_v then
				scroll_v.TotalSpace   = #log_frames
				scroll_v.VisibleSpace = math.floor(list_container.AbsoluteSize.Y / 37)
				scroll_v:Update()
			end
		end)
	end
 
	return spy
end
 
return {
	InitDeps      = initDeps,
	InitAfterMain = initAfterMain,
	Main          = main,
	PluginData    = plugin_data,
}
 
