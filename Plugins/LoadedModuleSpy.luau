local _main_ref, lib_ref, apps_ref, settings_ref, env_ref, theme_ref

local plugin_data = {
	name         = "LoadedModuleSpy",
	FriendlyName = "Loaded Modules",
}

local function initDeps(data)
	_main_ref    = data.Main
	lib_ref      = data.Lib
	apps_ref     = data.Apps
	settings_ref = data.Settings
	env_ref      = data.env
end

local function initAfterMain(t)
	theme_ref    = t.Theme
end

local function get_theme()
	return theme_ref or (apps_ref and apps_ref.Theme)
end

local function inst_path(obj)
	if not obj then return "?" end
	local ok, path = pcall(function()
		local parts, cur = {}, obj
		while cur and cur ~= game do
			table.insert(parts, 1, cur.Name)
			cur = cur.Parent
		end
		table.insert(parts, 1, "game")
		return table.concat(parts, ".")
	end)
	return ok and path or tostring(obj)
end

local function main()
	local plugin = {}
	plugin.PluginData = plugin_data

	local modules = {}
	local filtered_modules = {}
	local log_frames = {}
	local row_module_map = {}
	local selected_module = nil
	local filter_text = ""

	local window, list_frame, scroll_v, status_label, empty_label
	local path_box, decompile_btn, explore_btn, inspect_btn, error_label
	local rebuild_list

	local function scan_modules()
		table.clear(modules)
		
		-- Try getloadedmodules
		if env_ref and env_ref.getloadedmodules then
			local ok, loaded = pcall(env_ref.getloadedmodules)
			if ok and typeof(loaded) == "table" then
				for _, m in pairs(loaded) do
					if typeof(m) == "Instance" and m:IsA("ModuleScript") then
						table.insert(modules, m)
					end
				end
			end
		end
		
		-- Fallback/complementary: scan game descendants
		if #modules == 0 then
			local ok, descs = pcall(game.GetDescendants, game)
			if ok then
				for _, m in ipairs(descs) do
					if typeof(m) == "Instance" and m:IsA("ModuleScript") then
						table.insert(modules, m)
					end
				end
			end
			
			-- Nil instances too
			if env_ref and env_ref.getnilinstances then
				local ok2, nils = pcall(env_ref.getnilinstances)
				if ok2 and typeof(nils) == "table" then
					for _, m in pairs(nils) do
						if typeof(m) == "Instance" and m:IsA("ModuleScript") then
							table.insert(modules, m)
						end
					end
				end
			end
		end
		
		-- Sort modules by name
		table.sort(modules, function(a, b)
			return a.Name:lower() < b.Name:lower()
		end)
	end

	local function matches(m)
		if filter_text == "" then return true end
		local low = filter_text:lower()
		return m.Name:lower():find(low, 1, true) or inst_path(m):lower():find(low, 1, true)
	end

	local function update_scroll()
		if scroll_v then
			scroll_v.TotalSpace = #log_frames
			scroll_v.Index = math.max(0, #log_frames - scroll_v.VisibleSpace)
			scroll_v:Update()
		end
	end

	local function rebuild_list_highlights()
		for _, row in ipairs(log_frames) do
			local m = row_module_map[row]
			if m == selected_module then
				row.BackgroundColor3 = settings_ref.Theme.ListSelection
			else
				row.BackgroundColor3 = settings_ref.Theme.Main1
			end
		end
	end

	local function show_details(m)
		selected_module = m
		if not m then
			path_box.Text = ""
			decompile_btn.Active = false
			decompile_btn.BackgroundColor3 = settings_ref.Theme.Main1
			explore_btn.Active = false
			explore_btn.BackgroundColor3 = settings_ref.Theme.Main1
			inspect_btn.Active = false
			inspect_btn.BackgroundColor3 = settings_ref.Theme.Main1
			error_label.Text = ""
			return
		end
		
		path_box.Text = inst_path(m)
		
		decompile_btn.Active = true
		decompile_btn.BackgroundColor3 = settings_ref.Theme.Button
		explore_btn.Active = true
		explore_btn.BackgroundColor3 = settings_ref.Theme.Button
		inspect_btn.Active = true
		inspect_btn.BackgroundColor3 = settings_ref.Theme.Button
		error_label.Text = ""
	end

	local function push_row(m)
		if not list_frame then return end
		if empty_label then empty_label.Visible = false end
		
		local row = Instance.new("Frame")
		row.BackgroundColor3 = settings_ref.Theme.Main1
		row.BorderSizePixel  = 0
		row.Size             = UDim2.new(1, 0, 0, 36)
		row.ClipsDescendants = true
		
		local badge = Instance.new("Frame", row)
		badge.BackgroundColor3 = Color3.fromRGB(139, 92, 246) -- Purple badge for ModuleScript
		badge.BorderSizePixel  = 0
		badge.Size             = UDim2.new(0, 3, 1, 0)
		
		local name_lbl = Instance.new("TextLabel", row)
		name_lbl.BackgroundTransparency = 1
		name_lbl.Position  = UDim2.new(0, 8, 0, 2)
		name_lbl.Size      = UDim2.new(1, -16, 0, 16)
		name_lbl.Font      = get_theme() and get_theme().MapFont(Enum.Font.SourceSansBold) or Enum.Font.SourceSansBold
		name_lbl.TextSize  = 13
		name_lbl.TextColor3 = settings_ref.Theme.Text
		name_lbl.TextXAlignment = Enum.TextXAlignment.Left
		name_lbl.Text = m.Name
		
		local path_lbl = Instance.new("TextLabel", row)
		path_lbl.BackgroundTransparency = 1
		path_lbl.Position  = UDim2.new(0, 8, 0, 18)
		path_lbl.Size      = UDim2.new(1, -16, 0, 16)
		path_lbl.Font      = Enum.Font.Code
		path_lbl.TextSize  = 10
		path_lbl.TextColor3 = settings_ref.Theme.PlaceholderText
		path_lbl.TextXAlignment = Enum.TextXAlignment.Left
		path_lbl.TextTruncate = Enum.TextTruncate.AtEnd
		path_lbl.Text = inst_path(m)
		
		local separator = Instance.new("Frame", row)
		separator.BackgroundColor3 = settings_ref.Theme.Outline1
		separator.BorderSizePixel = 0
		separator.Size = UDim2.new(1, 0, 0, 1)
		separator.Position = UDim2.new(0, 0, 1, -1)
		
		row.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement then
				row.BackgroundColor3 = selected_module == m and settings_ref.Theme.ListSelection or settings_ref.Theme.ButtonHover
			elseif i.UserInputType == Enum.UserInputType.MouseButton1 then
				selected_module = m
				show_details(m)
				rebuild_list_highlights()
			end
		end)
		
		row.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement then
				row.BackgroundColor3 = selected_module == m and settings_ref.Theme.ListSelection or settings_ref.Theme.Main1
			end
		end)
		
		row.LayoutOrder = #log_frames + 1
		row.Parent = list_frame
		table.insert(log_frames, row)
		row_module_map[row] = m
	end

	rebuild_list = function()
		for _, f in ipairs(log_frames) do f:Destroy() end
		log_frames = {}
		table.clear(row_module_map)
		
		table.clear(filtered_modules)
		for _, m in ipairs(modules) do
			if matches(m) then
				table.insert(filtered_modules, m)
			end
		end
		
		for _, m in ipairs(filtered_modules) do
			push_row(m)
		end
		
		if empty_label then
			empty_label.Visible = #filtered_modules == 0
			empty_label.Text = #modules == 0 and "No loaded ModuleScripts found" or "No modules match filter"
		end
		
		if status_label then
			status_label.Text = #modules .. " loaded modules (" .. #filtered_modules .. " filtered)"
		end
		
		update_scroll()
		rebuild_list_highlights()
	end

	local function make_btn(parent, text, y, h)
		local btn = Instance.new("TextButton")
		btn.BorderSizePixel  = 0
		btn.Font             = Enum.Font.SourceSans
		btn.TextSize         = 14
		btn.Text             = text
		btn.AutoButtonColor  = false
		btn.Size             = UDim2.new(1, -20, 0, h)
		btn.Position         = UDim2.new(0, 10, 0, y)
		btn.Parent           = parent
		if get_theme() then
			get_theme().StyleButton(btn)
		else
			btn.BackgroundColor3 = settings_ref.Theme.Button
			btn.TextColor3       = settings_ref.Theme.Text
			local c = Instance.new("UICorner", btn)
			c.CornerRadius = UDim.new(0, 4)
			btn.MouseEnter:Connect(function() if btn.Active then btn.BackgroundColor3 = Color3.fromRGB(55, 63, 75) end end)
			btn.MouseLeave:Connect(function() if btn.Active then btn.BackgroundColor3 = settings_ref.Theme.Button end end)
		end
		return btn
	end

	plugin.Init = function()
		window = lib_ref.Window.new()
		window:SetTitle("Loaded Modules")
		window:Resize(720, 400)
		plugin.Window = window

		local toolbar = Instance.new("Frame")
		toolbar.BackgroundColor3 = settings_ref.Theme.Menu
		toolbar.BorderSizePixel  = 0
		toolbar.Size             = UDim2.new(1, 0, 0, 26)
		toolbar.Parent           = window.GuiElems.Content

		local refresh_btn = Instance.new("TextButton")
		refresh_btn.BorderSizePixel = 0
		refresh_btn.Font = Enum.Font.SourceSans
		refresh_btn.TextSize = 13
		refresh_btn.Text = "Refresh"
		refresh_btn.AutoButtonColor = false
		refresh_btn.Size = UDim2.new(0, 64, 0, 18)
		refresh_btn.Position = UDim2.new(0, 4, 0, 4)
		refresh_btn.Parent = toolbar
		if get_theme() then get_theme().StyleButton(refresh_btn) end

		status_label = Instance.new("TextLabel")
		status_label.BackgroundTransparency = 1
		status_label.Font       = get_theme() and get_theme().MapFont(Enum.Font.SourceSans) or Enum.Font.SourceSans
		status_label.TextSize   = 12
		status_label.TextColor3 = settings_ref.Theme.PlaceholderText
		status_label.TextXAlignment = Enum.TextXAlignment.Right
		status_label.Size       = UDim2.new(1, -80, 1, 0)
		status_label.Position   = UDim2.new(0, 72, 0, 0)
		status_label.Text       = "0 loaded modules"
		status_label.Parent     = toolbar

		local search_bar = Instance.new("Frame")
		search_bar.BackgroundColor3 = settings_ref.Theme.Main1
		search_bar.BorderSizePixel  = 0
		search_bar.Size             = UDim2.new(1, 0, 0, 26)
		search_bar.Position         = UDim2.new(0, 0, 0, 26)
		search_bar.Parent           = window.GuiElems.Content

		local search_box = Instance.new("TextBox", search_bar)
		search_box.BackgroundTransparency = 1
		search_box.PlaceholderText  = "Search module name or path..."
		search_box.PlaceholderColor3 = settings_ref.Theme.PlaceholderText
		search_box.Text             = ""
		search_box.Font             = Enum.Font.Code
		search_box.TextSize         = 13
		search_box.TextColor3       = settings_ref.Theme.Text
		search_box.TextXAlignment   = Enum.TextXAlignment.Left
		search_box.ClearTextOnFocus = false
		search_box.Size             = UDim2.new(1, -14, 1, 0)
		search_box.Position         = UDim2.new(0, 8, 0, 0)
		search_box:GetPropertyChangedSignal("Text"):Connect(function()
			filter_text = search_box.Text
			rebuild_list()
		end)

		local body = Instance.new("Frame")
		body.BackgroundColor3 = settings_ref.Theme.Main2
		body.BorderSizePixel = 0
		body.Position = UDim2.new(0, 0, 0, 52)
		body.Size = UDim2.new(1, 0, 1, -52)
		body.Parent = window.GuiElems.Content

		local left_panel = Instance.new("Frame")
		left_panel.BackgroundColor3 = settings_ref.Theme.Main1
		left_panel.BorderSizePixel = 0
		left_panel.Size = UDim2.new(0, 320, 1, 0)
		left_panel.Parent = body

		local list_container = Instance.new("Frame")
		list_container.BackgroundColor3 = settings_ref.Theme.Main2
		list_container.BorderSizePixel  = 0
		list_container.Size             = UDim2.new(1, -16, 1, 0)
		list_container.ClipsDescendants = true
		list_container.Parent           = left_panel

		list_frame = Instance.new("Frame")
		list_frame.BackgroundTransparency = 1
		list_frame.Size         = UDim2.new(1, 0, 0, 0)
		list_frame.AutomaticSize = Enum.AutomaticSize.Y
		list_frame.Parent       = list_container

		local layout = Instance.new("UIListLayout", list_frame)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding   = UDim.new(0, 1)

		empty_label = Instance.new("TextLabel", list_container)
		empty_label.BackgroundTransparency = 1
		empty_label.Size = UDim2.new(1, 0, 0, 48)
		empty_label.Position = UDim2.new(0, 0, 0.5, -24)
		empty_label.Font = get_theme() and get_theme().MapFont(Enum.Font.SourceSans) or Enum.Font.SourceSans
		empty_label.TextSize = 14
		empty_label.TextColor3 = settings_ref.Theme.PlaceholderText
		empty_label.Text = "No loaded ModuleScripts found"
		empty_label.Visible = true

		scroll_v = lib_ref.ScrollBar.new()
		scroll_v.WheelIncrement  = 3
		scroll_v.Gui.Position    = UDim2.new(1, -16, 0, 0)
		scroll_v.Gui.Size        = UDim2.new(0, 16, 1, 0)
		scroll_v.Gui.Parent      = left_panel
		scroll_v:SetScrollFrame(list_container)
		scroll_v.Scrolled:Connect(function()
			list_frame.Position = UDim2.new(0, 0, 0, -scroll_v.Index * 37)
		end)

		local split_line = Instance.new("Frame", body)
		split_line.BackgroundColor3 = settings_ref.Theme.Outline1
		split_line.BorderSizePixel = 0
		split_line.Position = UDim2.new(0, 320, 0, 0)
		split_line.Size = UDim2.new(0, 1, 1, 0)

		local right_panel = Instance.new("Frame")
		right_panel.BackgroundColor3 = settings_ref.Theme.Main2
		right_panel.BorderSizePixel = 0
		right_panel.Position = UDim2.new(0, 321, 0, 0)
		right_panel.Size = UDim2.new(1, -321, 1, 0)
		right_panel.Parent = body

		local detail_lbl = Instance.new("TextLabel", right_panel)
		detail_lbl.BackgroundTransparency = 1
		detail_lbl.Position = UDim2.new(0, 10, 0, 10)
		detail_lbl.Size = UDim2.new(1, -20, 0, 20)
		detail_lbl.Font = get_theme() and get_theme().MapFont(Enum.Font.SourceSansBold) or Enum.Font.SourceSansBold
		detail_lbl.TextSize = 14
		detail_lbl.TextColor3 = settings_ref.Theme.Text
		detail_lbl.TextXAlignment = Enum.TextXAlignment.Left
		detail_lbl.Text = "Module Details"

		path_box = Instance.new("TextBox", right_panel)
		path_box.BackgroundColor3 = settings_ref.Theme.Main1
		path_box.BorderSizePixel = 0
		path_box.Position = UDim2.new(0, 10, 0, 35)
		path_box.Size = UDim2.new(1, -20, 0, 32)
		path_box.Font = Enum.Font.Code
		path_box.TextSize = 11
		path_box.TextColor3 = settings_ref.Theme.Text
		path_box.TextEditable = false
		path_box.ClearTextOnFocus = false
		path_box.MultiLine = true
		path_box.TextWrapped = true
		path_box.Text = ""
		path_box.TextXAlignment = Enum.TextXAlignment.Left
		path_box.TextYAlignment = Enum.TextYAlignment.Center
		local pad = Instance.new("UIPadding", path_box)
		pad.PaddingLeft = UDim.new(0, 6)
		pad.PaddingRight = UDim.new(0, 6)
		if get_theme() then get_theme().ApplyRounding(path_box, 4) end

		decompile_btn = make_btn(right_panel, "Decompile Source", 78, 28)
		explore_btn   = make_btn(right_panel, "View in Explorer", 112, 28)
		inspect_btn   = make_btn(right_panel, "Inspect Return Value", 146, 28)

		error_label = Instance.new("TextLabel", right_panel)
		error_label.BackgroundTransparency = 1
		error_label.Position = UDim2.new(0, 10, 0, 185)
		error_label.Size = UDim2.new(1, -20, 1, -195)
		error_label.Font = get_theme() and get_theme().MapFont(Enum.Font.SourceSans) or Enum.Font.SourceSans
		error_label.TextSize = 12
		error_label.TextColor3 = Color3.fromRGB(239, 68, 68) -- red error
		error_label.TextWrapped = true
		error_label.TextXAlignment = Enum.TextXAlignment.Left
		error_label.TextYAlignment = Enum.TextYAlignment.Top
		error_label.Text = ""

		-- Click Handlers
		refresh_btn.MouseButton1Click:Connect(function()
			scan_modules()
			rebuild_list()
			show_details(nil)
		end)

		decompile_btn.MouseButton1Click:Connect(function()
			if not selected_module then return end
			local sv = apps_ref.ScriptViewer
			if sv and sv.ViewScript then
				task.spawn(function()
					sv.ViewScript(selected_module)
					sv.Window:Show()
				end)
			end
		end)

		explore_btn.MouseButton1Click:Connect(function()
			if not selected_module then return end
			local exp = apps_ref.Explorer
			if exp and exp.Nodes and exp.Selection then
				local node = exp.Nodes[selected_module]
				if node then
					exp.MakeNodeVisible(node, true)
					exp.Selection:Set(node)
					exp.ViewNode(node)
				end
			end
		end)

		inspect_btn.MouseButton1Click:Connect(function()
			if not selected_module then return end
			error_label.Text = "Requiring module..."
			error_label.TextColor3 = settings_ref.Theme.PlaceholderText
			
			task.spawn(function()
				local success, result = pcall(require, selected_module)
				if success then
					error_label.Text = "Module loaded. Opening in Table Editor..."
					error_label.TextColor3 = Color3.fromRGB(34, 197, 94) -- green success
					
					local te = apps_ref.TableEditor
					if te and te.LoadTable then
						te.LoadTable(result, selected_module.Name)
						te.Window:Show()
					else
						error_label.Text = "Table Editor plugin not found/active."
						error_label.TextColor3 = Color3.fromRGB(239, 68, 68)
					end
				else
					error_label.Text = "Failed to require module:\n" .. tostring(result)
					error_label.TextColor3 = Color3.fromRGB(239, 68, 68)
				end
			end)
		end)

		scan_modules()
		rebuild_list()
		show_details(nil)

		window.OnActivate:Connect(function()
			if scroll_v then
				scroll_v.TotalSpace   = #log_frames
				scroll_v.VisibleSpace = math.floor(list_container.AbsoluteSize.Y / 37)
				scroll_v:Update()
			end
		end)
	end

	return plugin
end

return {
	InitDeps      = initDeps,
	InitAfterMain = initAfterMain,
	Main          = main,
	PluginData    = plugin_data,
}
