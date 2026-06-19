--!nocheck

local main_ref, lib_ref, apps_ref, settings_ref, env_ref, theme_ref

local plugin_data = {
	Name = "MemoryForensics",
	FriendlyName = "Memory Forensics",
}

local function initDeps(data)
	main_ref = data.Main
	lib_ref = data.Lib
	apps_ref = data.Apps
	settings_ref = data.Settings
	env_ref = data.env
end

local function initAfterMain(t)
	theme_ref = t.Theme
end

local function env_func(name)
	local env = env_ref
	if env and type(env[name]) == "function" then
		return env[name]
	end
	if type(getfenv) == "function" then
		local ok, value = pcall(function()
			return getfenv()[name]
		end)
		if ok and type(value) == "function" then
			return value
		end
	end
	return nil
end

local function get_upvalues_safe(func)
	local getupvalues_fn = env_func("getupvalues") or (debug and debug.getupvalues)
	if getupvalues_fn then
		local ok, tbl = pcall(getupvalues_fn, func)
		if ok and type(tbl) == "table" then
			return tbl
		end
	end

	local getupval = env_func("getupvalue") or (debug and debug.getupvalue)
	if getupval then
		local tbl = {}
		for i = 1, 200 do
			local ok, name, val = pcall(getupval, func, i)
			if ok and name then
				tbl[name] = val
			else
				break
			end
		end
		return tbl
	end
	return {}
end

local function set_upvalue_safe(func, name_or_idx, val)
	local setupval = env_func("setupvalue") or (debug and debug.setupvalue)
	if setupval then
		local ok, err = pcall(setupval, func, name_or_idx, val)
		return ok, err
	end
	return false, "setupvalue API not available"
end

local function main()
	local forensics = {}
	forensics.PluginData = plugin_data

	local window, status_label
	local active_tab = "gc" -- "gc" or "connections"
	
	-- UI Elements
	local tab_gc_btn, tab_conn_btn
	local gc_panel, conn_panel
	
	-- GC Panel UI Elements
	local gc_query_box, gc_scroll
	local gc_results = {}
	local gc_rows = {}
	
	-- Connection Panel UI Elements
	local conn_target_label, conn_event_box, conn_scroll
	local conn_results = {}
	local conn_rows = {}
	local selected_instance = nil
	
	-- Detail Inspector (Right Panel)
	local inspector_frame, inspector_title, inspector_scroll
	local inspector_rows = {}

	local function theme()
		return settings_ref.Theme
	end

	local function set_status(text)
		if status_label then
			status_label.Text = tostring(text)
		end
	end

	local function label(parent, text, pos, size, color, bold)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = bold and Enum.Font.SourceSansBold or Enum.Font.SourceSans
		l.Position = pos
		l.Size = size
		l.Text = text
		l.TextColor3 = color or theme().Text
		l.TextSize = bold and 14 or 13
		l.TextWrapped = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextYAlignment = Enum.TextYAlignment.Center
		l.Parent = parent
		return l
	end

	local function button(parent, text, pos, size, callback)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.BackgroundColor3 = theme().Button
		b.BorderColor3 = theme().Outline2
		b.Font = Enum.Font.SourceSans
		b.Position = pos
		b.Size = size
		b.Text = text
		b.TextColor3 = theme().Text
		b.TextSize = 13
		b.Parent = parent
		b.MouseButton1Click:Connect(callback)
		if theme_ref and theme_ref.StyleButton then
			theme_ref.StyleButton(b)
		elseif lib_ref and lib_ref.ButtonAnim then
			lib_ref.ButtonAnim(b, {
				Mode = 2,
				StartColor = theme().Button,
				HoverColor = theme().ButtonHover,
				PressColor = theme().ButtonPress,
				OutlineColor = theme().Outline2,
			})
		end
		return b
	end

	local function clear_gc_rows()
		for _, row in ipairs(gc_rows) do
			row:Destroy()
		end
		gc_rows = {}
	end

	local function clear_conn_rows()
		for _, row in ipairs(conn_rows) do
			row:Destroy()
		end
		conn_rows = {}
	end

	local function clear_inspector_rows()
		for _, row in ipairs(inspector_rows) do
			row:Destroy()
		end
		inspector_rows = {}
	end

	local function inspect_function(entry)
		clear_inspector_rows()
		inspector_title.Text = "Inspect: " .. entry.Name .. "()"
		
		-- Fetch Upvalues
		local upvalues = get_upvalues_safe(entry.Object)
		local y = 4
		
		-- Display Metadata
		local meta_label = label(inspector_scroll, "Source: " .. entry.Source .. "\nLine: " .. tostring(entry.Line), UDim2.new(0, 6, 0, y), UDim2.new(1, -12, 0, 36), theme().PlaceholderText, false)
		meta_label.TextYAlignment = Enum.TextYAlignment.Top
		inspector_rows[#inspector_rows + 1] = meta_label
		y += 42
		
		-- Display Upvalues
		local up_title = label(inspector_scroll, "Upvalues:", UDim2.new(0, 6, 0, y), UDim2.new(1, -12, 0, 18), theme().Text, true)
		inspector_rows[#inspector_rows + 1] = up_title
		y += 22
		
		local count = 0
		for name, val in pairs(upvalues) do
			count += 1
			local val_str = tostring(val)
			if type(val) == "string" then
				val_str = '"' .. val_str .. '"'
			end
			
			local row = Instance.new("Frame")
			row.BackgroundColor3 = theme().Main1
			row.BorderColor3 = theme().Outline1
			row.Position = UDim2.new(0, 6, 0, y)
			row.Size = UDim2.new(1, -12, 0, 48)
			row.Parent = inspector_scroll
			inspector_rows[#inspector_rows + 1] = row
			
			label(row, tostring(name) .. " (" .. type(val) .. ")", UDim2.new(0, 6, 0, 4), UDim2.new(1, -84, 0, 16), theme().Highlight, true)
			
			local val_box = Instance.new("TextBox")
			val_box.BackgroundColor3 = theme().TextBox
			val_box.BorderColor3 = theme().Outline3
			val_box.ClearTextOnFocus = false
			val_box.Font = Enum.Font.Code
			val_box.Position = UDim2.new(0, 6, 0, 22)
			val_box.Size = UDim2.new(1, -84, 0, 20)
			val_box.Text = val_str
			val_box.TextColor3 = theme().Text
			val_box.TextSize = 11
			val_box.TextXAlignment = Enum.TextXAlignment.Left
			val_box.Parent = row
			
			button(row, "Set", UDim2.new(1, -72, 0, 20), UDim2.new(0, 64, 0, 22), function()
				local text = val_box.Text
				local compile_fn, err = loadstring("return " .. text)
				if not compile_fn then
					set_status("Compile error: " .. tostring(err))
					return
				end
				local success, new_val = pcall(compile_fn)
				if not success then
					set_status("Evaluation error: " .. tostring(new_val))
					return
				end
				local ok, set_err = set_upvalue_safe(entry.Object, name, new_val)
				if ok then
					set_status("Set upvalue " .. tostring(name) .. " successfully.")
					inspect_function(entry)
				else
					set_status("Failed to set: " .. tostring(set_err))
				end
			end)
			
			y += 52
		end
		
		if count == 0 then
			local no_up = label(inspector_scroll, "No upvalues found.", UDim2.new(0, 12, 0, y), UDim2.new(1, -24, 0, 18), theme().PlaceholderText, false)
			inspector_rows[#inspector_rows + 1] = no_up
			y += 22
		end
		
		inspector_scroll.CanvasSize = UDim2.new(0, 0, 0, y + 10)
	end

	local function inspect_table(entry)
		clear_inspector_rows()
		inspector_title.Text = "Inspect: Table"
		
		local y = 4
		local count = 0
		for k, v in pairs(entry.Object) do
			count += 1
			if count > 100 then
				local cap = label(inspector_scroll, "... (truncated after 100 entries)", UDim2.new(0, 6, 0, y), UDim2.new(1, -12, 0, 18), theme().PlaceholderText, false)
				inspector_rows[#inspector_rows + 1] = cap
				y += 22
				break
			end
			
			local row = Instance.new("Frame")
			row.BackgroundColor3 = theme().Main1
			row.BorderColor3 = theme().Outline1
			row.Position = UDim2.new(0, 6, 0, y)
			row.Size = UDim2.new(1, -12, 0, 38)
			row.Parent = inspector_scroll
			inspector_rows[#inspector_rows + 1] = row
			
			local k_str = tostring(k)
			local v_str = tostring(v)
			if type(v) == "string" then v_str = '"' .. v_str .. '"' end
			
			label(row, k_str .. "  =", UDim2.new(0, 6, 0, 2), UDim2.new(0.4, -12, 1, -4), theme().Highlight, true).TextTruncate = Enum.TextTruncate.AtEnd
			
			local val_box = Instance.new("TextBox")
			val_box.BackgroundColor3 = theme().TextBox
			val_box.BorderColor3 = theme().Outline3
			val_box.ClearTextOnFocus = false
			val_box.Font = Enum.Font.Code
			val_box.Position = UDim2.new(0.4, 0, 0, 8)
			val_box.Size = UDim2.new(0.6, -56, 0, 22)
			val_box.Text = v_str
			val_box.TextColor3 = theme().Text
			val_box.TextSize = 11
			val_box.TextXAlignment = Enum.TextXAlignment.Left
			val_box.Parent = row
			
			button(row, "Set", UDim2.new(1, -48, 0, 8), UDim2.new(0, 42, 0, 22), function()
				local text = val_box.Text
				local compile_fn, err = loadstring("return " .. text)
				if not compile_fn then
					set_status("Compile error: " .. tostring(err))
					return
				end
				local success, new_val = pcall(compile_fn)
				if not success then
					set_status("Evaluation error: " .. tostring(new_val))
					return
				end
				local ok, set_err = pcall(function()
					entry.Object[k] = new_val
				end)
				if ok then
					set_status("Updated table field " .. k_str)
					inspect_table(entry)
				else
					set_status("Write failed: " .. tostring(set_err))
				end
			end)
			
			y += 42
		end
		
		if count == 0 then
			local empty = label(inspector_scroll, "Empty table.", UDim2.new(0, 12, 0, y), UDim2.new(1, -24, 0, 18), theme().PlaceholderText, false)
			inspector_rows[#inspector_rows + 1] = empty
			y += 22
		end
		
		inspector_scroll.CanvasSize = UDim2.new(0, 0, 0, y + 10)
	end

	local function render_gc()
		clear_gc_rows()
		local y = 4
		for i, entry in ipairs(gc_results) do
			if i > 150 then break end
			local row = Instance.new("Frame")
			row.BackgroundColor3 = theme().Main1
			row.BorderColor3 = theme().Outline1
			row.Position = UDim2.new(0, 4, 0, y)
			row.Size = UDim2.new(1, -8, 0, 42)
			row.Parent = gc_scroll
			gc_rows[#gc_rows + 1] = row

			if entry.Type == "function" then
				label(row, entry.Name .. "()", UDim2.new(0, 8, 0, 2), UDim2.new(1, -88, 0, 18), theme().Text, true)
				local src = label(row, entry.Source .. ":" .. tostring(entry.Line), UDim2.new(0, 8, 0, 20), UDim2.new(1, -88, 0, 18), theme().PlaceholderText, false)
				src.TextTruncate = Enum.TextTruncate.AtEnd
				
				button(row, "Inspect", UDim2.new(1, -74, 0, 10), UDim2.new(0, 68, 0, 22), function()
					inspect_function(entry)
				end)
			elseif entry.Type == "table" then
				label(row, "Table with " .. tostring(entry.FieldsCount) .. " fields", UDim2.new(0, 8, 0, 12), UDim2.new(1, -88, 0, 18), Color3.fromRGB(34, 197, 94), true)
				
				button(row, "Inspect", UDim2.new(1, -74, 0, 10), UDim2.new(0, 68, 0, 22), function()
					inspect_table(entry)
				end)
			elseif entry.Type == "thread" then
				label(row, "Thread - " .. entry.Status, UDim2.new(0, 8, 0, 12), UDim2.new(1, -88, 0, 18), Color3.fromRGB(168, 85, 247), true)
			end

			y += 46
		end
		gc_scroll.CanvasSize = UDim2.new(0, 0, 0, y + 10)
	end

	local function scan_gc(kind)
		set_status("Scanning Garbage Collector...")
		local getgc_fn = env_func("getgc")
		if not getgc_fn then
			set_status("getgc API is not supported by your executor.")
			return
		end

		local query = gc_query_box.Text
		local ok, list = pcall(getgc_fn, true)
		if not ok then
			ok, list = pcall(getgc_fn)
		end
		if not ok or type(list) ~= "table" then
			set_status("Failed to read Garbage Collector.")
			return
		end

		table.clear(gc_results)
		local q_lower = query:lower()

		for _, obj in ipairs(list) do
			if kind == "function" and type(obj) == "function" then
				local name = "anonymous"
				local source = "unknown"
				local line = 0
				
				if debug and debug.info then
					local s, n = pcall(debug.info, obj, "n")
					if s and n and #n > 0 then name = n end
					local s2, src, l = pcall(debug.info, obj, "sl")
					if s2 then source, line = src, l end
				end
				
				if #query == 0 or name:lower():find(q_lower, 1, true) or source:lower():find(q_lower, 1, true) then
					table.insert(gc_results, {
						Type = "function",
						Object = obj,
						Name = name,
						Source = source,
						Line = line
					})
				end
			elseif kind == "table" and type(obj) == "table" then
				local match = (#query == 0)
				if not match then
					for k, v in pairs(obj) do
						if tostring(k):lower():find(q_lower, 1, true) or tostring(v):lower():find(q_lower, 1, true) then
							match = true
							break
						end
					end
				end
				
				if match then
					local fields = 0
					for _ in pairs(obj) do fields += 1 end
					table.insert(gc_results, {
						Type = "table",
						Object = obj,
						FieldsCount = fields
					})
				end
			elseif kind == "thread" and type(obj) == "thread" then
				local status = coroutine.status(obj)
				if #query == 0 or status:lower():find(q_lower, 1, true) then
					table.insert(gc_results, {
						Type = "thread",
						Object = obj,
						Status = status
					})
				end
			end
		end

		set_status("Scan complete: found " .. tostring(#gc_results) .. " entries.")
		render_gc()
	end

	local function load_selected_instance()
		selected_instance = nil
		local explorer = apps_ref and apps_ref.Explorer
		if explorer and explorer.Selection and explorer.Selection.List and #explorer.Selection.List > 0 then
			local node = explorer.Selection.List[1]
			if typeof(node.Obj) == "Instance" then
				selected_instance = node.Obj
			end
		end
		
		if conn_target_label then
			conn_target_label.Text = selected_instance and ("Target: " .. selected_instance:GetFullName()) or "Target: None (Select in Explorer)"
		end
	end

	local function render_connections()
		clear_conn_rows()
		local y = 4
		for i, entry in ipairs(conn_results) do
			local row = Instance.new("Frame")
			row.BackgroundColor3 = theme().Main1
			row.BorderColor3 = theme().Outline1
			row.Position = UDim2.new(0, 4, 0, y)
			row.Size = UDim2.new(1, -8, 0, 48)
			row.Parent = conn_scroll
			conn_rows[#conn_rows + 1] = row

			local state_color = entry.State == "enabled" and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(239, 68, 68)
			label(row, "Connection #" .. tostring(entry.Index) .. " [" .. entry.State .. "]", UDim2.new(0, 8, 0, 2), UDim2.new(1, -196, 0, 18), state_color, true)
			local owner = label(row, "Owner: " .. entry.ScriptName, UDim2.new(0, 8, 0, 22), UDim2.new(1, -196, 0, 18), theme().PlaceholderText, false)
			owner.TextTruncate = Enum.TextTruncate.AtEnd
			
			button(row, "Disable", UDim2.new(1, -190, 0, 12), UDim2.new(0, 58, 0, 22), function()
				local ok, err = pcall(function() entry.Object:Disable() end)
				if ok then
					set_status("Disabled connection #" .. tostring(entry.Index))
					entry.State = "disabled"
					render_connections()
				else
					set_status("Disable failed: " .. tostring(err))
				end
			end)
			
			button(row, "Enable", UDim2.new(1, -128, 0, 12), UDim2.new(0, 56, 0, 22), function()
				local ok, err = pcall(function() entry.Object:Enable() end)
				if ok then
					set_status("Enabled connection #" .. tostring(entry.Index))
					entry.State = "enabled"
					render_connections()
				else
					set_status("Enable failed: " .. tostring(err))
				end
			end)
			
			button(row, "Fire", UDim2.new(1, -68, 0, 12), UDim2.new(0, 60, 0, 22), function()
				local ok, err = pcall(function() entry.Object:Fire() end)
				if ok then
					set_status("Fired connection #" .. tostring(entry.Index))
				else
					set_status("Fire failed: " .. tostring(err))
				end
			end)

			y += 52
		end
		conn_scroll.CanvasSize = UDim2.new(0, 0, 0, y + 10)
	end

	local function scan_connections()
		if not selected_instance then
			set_status("Select an instance first.")
			return
		end
		
		local getconnections_fn = env_func("getconnections")
		if not getconnections_fn then
			set_status("getconnections API not available on this executor.")
			return
		end

		local event_name = conn_event_box.Text
		if #event_name == 0 then
			set_status("Enter an event name (e.g. Changed, AncestorChanged, MouseButton1Click).")
			return
		end

		local event
		local ok, err = pcall(function()
			event = selected_instance[event_name]
		end)
		if not ok or not event then
			ok, event = pcall(selected_instance.GetPropertyChangedSignal, selected_instance, event_name)
		end

		if not ok or not event then
			set_status("Failed to locate event '" .. event_name .. "' on target.")
			return
		end

		local ok_conns, list = pcall(getconnections_fn, event)
		if not ok_conns or type(list) ~= "table" then
			set_status("Failed to get connections: " .. tostring(list))
			return
		end

		table.clear(conn_results)
		for i, conn in ipairs(list) do
			local state = "enabled"
			if conn.Enabled == false then state = "disabled" end
			
			local script_name = "unknown"
			local func = conn.Function
			if func then
				local fenv = getfenv(func)
				if fenv and fenv.script then
					script_name = fenv.script:GetFullName()
				end
			end

			table.insert(conn_results, {
				Index = i,
				Object = conn,
				State = state,
				ScriptName = script_name,
				Function = func
			})
		end

		set_status("Found " .. tostring(#conn_results) .. " active connections.")
		render_connections()
	end

	local function select_tab(tab)
		active_tab = tab
		if tab == "gc" then
			tab_gc_btn.BackgroundColor3 = theme().Main1
			tab_conn_btn.BackgroundColor3 = theme().Button
			gc_panel.Visible = true
			conn_panel.Visible = false
		else
			tab_gc_btn.BackgroundColor3 = theme().Button
			tab_conn_btn.BackgroundColor3 = theme().Main1
			gc_panel.Visible = false
			conn_panel.Visible = true
			load_selected_instance()
		end
	end

	function forensics.Init()
		window = lib_ref.Window.new()
		window:SetTitle("Memory Forensics")
		window:Resize(650, 430)
		forensics.Window = window

		local content = window.GuiElems.Content
		local t = theme()

		-- Top tabs
		local tab_bar = Instance.new("Frame")
		tab_bar.BackgroundColor3 = t.Main2
		tab_bar.BorderSizePixel = 0
		tab_bar.Size = UDim2.new(1, 0, 0, 32)
		tab_bar.Parent = content

		tab_gc_btn = button(tab_bar, "Garbage Collector Scanner", UDim2.new(0, 4, 0, 4), UDim2.new(0, 160, 0, 28), function() select_tab("gc") end)
		tab_conn_btn = button(tab_bar, "Event Connections Monitor", UDim2.new(0, 168, 0, 4), UDim2.new(0, 160, 0, 28), function() select_tab("connections") end)

		-- Main Panel Left (Results list)
		local left_frame = Instance.new("Frame")
		left_frame.BackgroundColor3 = t.Main2
		left_frame.BorderSizePixel = 0
		left_frame.Position = UDim2.new(0, 0, 0, 32)
		left_frame.Size = UDim2.new(0.6, 0, 1, -64)
		left_frame.Parent = content

		-- GC Panel
		gc_panel = Instance.new("Frame", left_frame)
		gc_panel.BackgroundTransparency = 1
		gc_panel.Size = UDim2.new(1, 0, 1, 0)

		gc_query_box = Instance.new("TextBox")
		gc_query_box.BackgroundColor3 = t.TextBox
		gc_query_box.BorderColor3 = t.Outline3
		gc_query_box.ClearTextOnFocus = false
		gc_query_box.Font = Enum.Font.SourceSans
		gc_query_box.PlaceholderColor3 = t.PlaceholderText
		gc_query_box.PlaceholderText = "Search by name/source/key..."
		gc_query_box.Position = UDim2.new(0, 6, 0, 6)
		gc_query_box.Size = UDim2.new(1, -12, 0, 24)
		gc_query_box.Text = ""
		gc_query_box.TextColor3 = t.Text
		gc_query_box.TextSize = 13
		gc_query_box.TextXAlignment = Enum.TextXAlignment.Left
		gc_query_box.Parent = gc_panel

		button(gc_panel, "Scan Functions", UDim2.new(0, 6, 0, 36), UDim2.new(0.33, -8, 0, 22), function() scan_gc("function") end)
		button(gc_panel, "Scan Tables", UDim2.new(0.33, 2, 0, 36), UDim2.new(0.33, -4, 0, 22), function() scan_gc("table") end)
		button(gc_panel, "Scan Threads", UDim2.new(0.66, 2, 0, 36), UDim2.new(0.34, -8, 0, 22), function() scan_gc("thread") end)

		gc_scroll = Instance.new("ScrollingFrame")
		gc_scroll.Active = true
		gc_scroll.BackgroundColor3 = t.Main2
		gc_scroll.BorderSizePixel = 0
		gc_scroll.Position = UDim2.new(0, 0, 0, 64)
		gc_scroll.Size = UDim2.new(1, 0, 1, -64)
		gc_scroll.ScrollBarThickness = 6
		gc_scroll.Parent = gc_panel

		-- Connections Panel
		conn_panel = Instance.new("Frame", left_frame)
		conn_panel.BackgroundTransparency = 1
		conn_panel.Size = UDim2.new(1, 0, 1, 0)
		conn_panel.Visible = false

		conn_target_label = label(conn_panel, "Target: None (Select in Explorer)", UDim2.new(0, 6, 0, 4), UDim2.new(1, -12, 0, 18), t.PlaceholderText, false)
		conn_target_label.TextTruncate = Enum.TextTruncate.AtEnd
		
		conn_event_box = Instance.new("TextBox")
		conn_event_box.BackgroundColor3 = t.TextBox
		conn_event_box.BorderColor3 = t.Outline3
		conn_event_box.ClearTextOnFocus = false
		conn_event_box.Font = Enum.Font.SourceSans
		conn_event_box.PlaceholderColor3 = t.PlaceholderText
		conn_event_box.PlaceholderText = "Event Name (MouseButton1Click, Changed...)"
		conn_event_box.Position = UDim2.new(0, 6, 0, 26)
		conn_event_box.Size = UDim2.new(1, -122, 0, 24)
		conn_event_box.Text = "Changed"
		conn_event_box.TextColor3 = t.Text
		conn_event_box.TextSize = 13
		conn_event_box.TextXAlignment = Enum.TextXAlignment.Left
		conn_event_box.Parent = conn_panel

		button(conn_panel, "Use Selected", UDim2.new(1, -112, 0, 2), UDim2.new(0, 106, 0, 20), load_selected_instance)
		button(conn_panel, "Scan Connections", UDim2.new(1, -112, 0, 26), UDim2.new(0, 106, 0, 24), scan_connections)

		conn_scroll = Instance.new("ScrollingFrame")
		conn_scroll.Active = true
		conn_scroll.BackgroundColor3 = t.Main2
		conn_scroll.BorderSizePixel = 0
		conn_scroll.Position = UDim2.new(0, 0, 0, 56)
		conn_scroll.Size = UDim2.new(1, 0, 1, -56)
		conn_scroll.ScrollBarThickness = 6
		conn_scroll.Parent = conn_panel

		-- Inspector Frame (Right Panel)
		inspector_frame = Instance.new("Frame")
		inspector_frame.BackgroundColor3 = t.Main1
		inspector_frame.BorderSizePixel = 0
		inspector_frame.Position = UDim2.new(0.6, 0, 0, 32)
		inspector_frame.Size = UDim2.new(0.4, 0, 1, -64)
		inspector_frame.Parent = content

		inspector_title = label(inspector_frame, "Detail Inspector", UDim2.new(0, 8, 0, 6), UDim2.new(1, -16, 0, 20), t.Text, true)
		
		local line = Instance.new("Frame", inspector_frame)
		line.BackgroundColor3 = t.Outline1
		line.BorderSizePixel = 0
		line.Position = UDim2.new(0, 0, 0, 30)
		line.Size = UDim2.new(1, 0, 0, 1)

		inspector_scroll = Instance.new("ScrollingFrame")
		inspector_scroll.Active = true
		inspector_scroll.BackgroundTransparency = 1
		inspector_scroll.BorderSizePixel = 0
		inspector_scroll.Position = UDim2.new(0, 0, 0, 32)
		inspector_scroll.Size = UDim2.new(1, 0, 1, -32)
		inspector_scroll.ScrollBarThickness = 6
		inspector_scroll.Parent = inspector_frame

		local no_select = label(inspector_scroll, "Select an element to inspect it.", UDim2.new(0, 12, 0, 8), UDim2.new(1, -24, 0, 18), t.PlaceholderText, false)
		inspector_rows[#inspector_rows + 1] = no_select

		-- Footer
		local footer = Instance.new("Frame")
		footer.BackgroundColor3 = t.Menu
		footer.BorderSizePixel = 0
		footer.Position = UDim2.new(0, 0, 1, -32)
		footer.Size = UDim2.new(1, 0, 0, 32)
		footer.Parent = content

		status_label = label(footer, "Ready. Use Garbage Collector Scanner to find in-memory objects.", UDim2.new(0, 10, 0, 7), UDim2.new(1, -20, 0, 18), t.PlaceholderText, false)

		select_tab("gc")
	end

	return forensics
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main,
	PluginData = plugin_data,
}
