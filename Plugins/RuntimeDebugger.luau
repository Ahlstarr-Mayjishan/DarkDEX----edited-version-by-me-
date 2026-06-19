--!nocheck

local main_ref, lib_ref, apps_ref, settings_ref, env_ref, theme_ref

local plugin_data = {
	Name = "RuntimeDebugger",
	FriendlyName = "Runtime Debugger",
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

local function instrument(source)
	local lines = source:split("\n")
	local output = {}
	local in_multiline = false
	for i, line in ipairs(lines) do
		local trimmed = line:match("^%s*(.-)%s*$")
		if in_multiline then
			if line:find("]]") then
				in_multiline = false
			end
			table.insert(output, line)
		else
			if trimmed:sub(1, 2) == "--" then
				table.insert(output, line)
			elseif trimmed:find("%[%[") and not trimmed:find("]]") then
				in_multiline = true
				table.insert(output, line)
			elseif #trimmed == 0 then
				table.insert(output, line)
			else
				local indent = line:match("^(%s*)")
				table.insert(output, indent .. "_G.DEX_DEBUG_STEP(" .. tostring(i) .. "); " .. line)
			end
		end
	end
	return table.concat(output, "\n")
end

local function main()
	local debugger = {}
	debugger.PluginData = plugin_data

	local window, status_label, code_scroll, var_scroll, stack_scroll
	local start_btn, resume_btn, step_btn, stop_btn
	
	local raw_source = "local x = 1\nlocal y = 2\nfor i = 1, 5 do\n    x = x + y\n    task.wait(0.5)\nend\nprint(x)"
	local breakpoints = {} -- line_num -> true
	local line_rows = {}
	local var_rows = {}
	local stack_rows = {}
	
	local debugger_thread = nil
	local debugger_state = "stopped" -- "stopped", "paused", "running"
	local current_line = 0
	local step_mode = false
	local debug_env = {}

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

	local function clear_vars()
		for _, v in ipairs(var_rows) do v:Destroy() end
		var_rows = {}
	end

	local function clear_stack()
		for _, v in ipairs(stack_rows) do v:Destroy() end
		stack_rows = {}
	end

	local function update_ui_states()
		if debugger_state == "stopped" then
			start_btn.Text = "Start"
			start_btn.BackgroundColor3 = theme().Button
			resume_btn.Visible = false
			step_btn.Visible = false
			stop_btn.Visible = false
		elseif debugger_state == "paused" then
			start_btn.Text = "Restart"
			resume_btn.Visible = true
			step_btn.Visible = true
			stop_btn.Visible = true
		elseif debugger_state == "running" then
			start_btn.Text = "Restart"
			resume_btn.Visible = false
			step_btn.Visible = false
			stop_btn.Visible = true
		end
	end

	local function render_variables(frame_level)
		clear_vars()
		if not debugger_thread then return end
		
		local y = 4
		
		-- Display Locals
		local loc_title = label(var_scroll, "Locals & Upvalues:", UDim2.new(0, 6, 0, y), UDim2.new(1, -12, 0, 18), theme().Text, true)
		var_rows[#var_rows + 1] = loc_title
		y += 20
		
		local getlocal_fn = debug and debug.getlocal
		if getlocal_fn then
			for index = 1, 200 do
				local ok, name, val = pcall(getlocal_fn, debugger_thread, frame_level or 1, index)
				if ok and name then
					local row = Instance.new("Frame")
					row.BackgroundColor3 = theme().Main1
					row.BorderColor3 = theme().Outline1
					row.Position = UDim2.new(0, 4, 0, y)
					row.Size = UDim2.new(1, -8, 0, 24)
					row.Parent = var_scroll
					var_rows[#var_rows + 1] = row
					
					label(row, tostring(name) .. " =", UDim2.new(0, 6, 0, 3), UDim2.new(0.4, -6, 1, -6), theme().Highlight, true)
					label(row, tostring(val), UDim2.new(0.4, 6, 0, 3), UDim2.new(0.6, -12, 1, -6), theme().Text, false).TextTruncate = Enum.TextTruncate.AtEnd
					y += 28
				else
					break
				end
			end
		end
		
		-- Display Globals
		local glob_title = label(var_scroll, "Globals:", UDim2.new(0, 6, 0, y), UDim2.new(1, -12, 0, 18), theme().Text, true)
		var_rows[#var_rows + 1] = glob_title
		y += 20
		
		for k, v in pairs(debug_env) do
			if k ~= "task" and k ~= "wait" and k ~= "_G" and k ~= "shared" then
				local row = Instance.new("Frame")
				row.BackgroundColor3 = theme().Main1
				row.BorderColor3 = theme().Outline1
				row.Position = UDim2.new(0, 4, 0, y)
				row.Size = UDim2.new(1, -8, 0, 24)
				row.Parent = var_scroll
				var_rows[#var_rows + 1] = row
				
				label(row, tostring(k) .. " =", UDim2.new(0, 6, 0, 3), UDim2.new(0.4, -6, 1, -6), Color3.fromRGB(96, 165, 250), true)
				label(row, tostring(v), UDim2.new(0.4, 6, 0, 3), UDim2.new(0.6, -12, 1, -6), theme().Text, false).TextTruncate = Enum.TextTruncate.AtEnd
				y += 28
			end
		end
		
		var_scroll.CanvasSize = UDim2.new(0, 0, 0, y + 10)
	end

	local function render_call_stack()
		clear_stack()
		if not debugger_thread then return end
		
		local y = 4
		local trace_fn = debug and debug.traceback
		if trace_fn then
			local ok, stack_trace = pcall(trace_fn, debugger_thread)
			if ok and stack_trace then
				local lines = stack_trace:split("\n")
				local frame_num = 1
				for _, line in ipairs(lines) do
					if line:find(":") then
						local row = Instance.new("Frame")
						row.BackgroundColor3 = theme().Main1
						row.BorderColor3 = theme().Outline1
						row.Position = UDim2.new(0, 4, 0, y)
						row.Size = UDim2.new(1, -8, 0, 26)
						row.Parent = stack_scroll
						stack_rows[#stack_rows + 1] = row
						
						local clean_line = line:match("^%s*(.-)%s*$")
						label(row, "Frame " .. tostring(frame_num) .. ": " .. clean_line, UDim2.new(0, 6, 0, 4), UDim2.new(1, -12, 0, 18), theme().Text, false).TextTruncate = Enum.TextTruncate.AtEnd
						y += 30
						frame_num = frame_num + 1
					end
				end
			end
		end
		stack_scroll.CanvasSize = UDim2.new(0, 0, 0, y + 10)
	end

	local function render_code()
		for _, row in ipairs(line_rows) do row:Destroy() end
		line_rows = {}
		
		local lines = raw_source:split("\n")
		local y = 4
		for idx, line in ipairs(lines) do
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Position = UDim2.new(0, 4, 0, y)
			row.Size = UDim2.new(1, -8, 0, 18)
			row.Parent = code_scroll
			line_rows[#line_rows + 1] = row
			
			local bp_indicator = Instance.new("TextButton", row)
			bp_indicator.BackgroundTransparency = 1
			bp_indicator.Position = UDim2.new(0, 0, 0, 0)
			bp_indicator.Size = UDim2.new(0, 24, 1, 0)
			bp_indicator.Font = Enum.Font.SourceSansBold
			bp_indicator.Text = breakpoints[idx] and "●" or tostring(idx)
			bp_indicator.TextColor3 = breakpoints[idx] and Color3.fromRGB(239, 68, 68) or theme().PlaceholderText
			bp_indicator.TextSize = 13
			
			bp_indicator.MouseButton1Click:Connect(function()
				if breakpoints[idx] then
					breakpoints[idx] = nil
					bp_indicator.Text = tostring(idx)
					bp_indicator.TextColor3 = theme().PlaceholderText
				else
					breakpoints[idx] = true
					bp_indicator.Text = "●"
					bp_indicator.TextColor3 = Color3.fromRGB(239, 68, 68)
				end
			end)

			local is_current = (idx == current_line) and (debugger_state == "paused")
			local code_lbl = label(row, line, UDim2.new(0, 28, 0, 0), UDim2.new(1, -28, 1, 0), is_current and Color3.fromRGB(253, 224, 71) or theme().Text, is_current)
			code_lbl.Font = Enum.Font.Code
			code_lbl.TextSize = 12

			y += 20
		end
		code_scroll.CanvasSize = UDim2.new(0, 0, 0, y + 10)
	end

	local function stop_session()
		debugger_state = "stopped"
		debugger_thread = nil
		current_line = 0
		step_mode = false
		set_status("Debugging stopped.")
		update_ui_states()
		render_code()
		clear_vars()
		clear_stack()
	end

	local function step_session(action_val)
		if not debugger_thread or coroutine.status(debugger_thread) == "dead" then
			stop_session()
			return
		end

		local ok, yield_type, val = coroutine.resume(debugger_thread, action_val)
		if not ok then
			set_status("Runtime error: " .. tostring(yield_type))
			warn("Debugger execution error: " .. tostring(yield_type))
			stop_session()
			return
		end

		if coroutine.status(debugger_thread) == "dead" then
			set_status("Execution finished.")
			stop_session()
			return
		end

		if yield_type == "breakpoint" then
			debugger_state = "paused"
			current_line = val
			set_status("Paused at line " .. tostring(val))
			update_ui_states()
			render_code()
			render_variables()
			render_call_stack()
		elseif yield_type == "wait" then
			debugger_state = "running"
			update_ui_states()
			task.delay(val, function()
				if debugger_state == "running" then
					step_session()
				end
			end)
		else
			task.defer(function()
				if debugger_state == "running" then
					step_session()
				end
			end)
		end
	end

	local function start_session()
		set_status("Instrumenting and starting script...")
		stop_session()

		local explorer = apps_ref and apps_ref.Explorer
		if explorer and explorer.Selection and explorer.Selection.List and #explorer.Selection.List > 0 then
			local node = explorer.Selection.List[1]
			if typeof(node.Obj) == "Instance" and (node.Obj:IsA("LocalScript") or node.Obj:IsA("ModuleScript") or node.Obj:IsA("Script")) then
				raw_source = node.Obj.Source
			end
		end

		local inst_src = instrument(raw_source)
		local fn, err = loadstring(inst_src)
		if not fn then
			set_status("Syntax error: " .. tostring(err))
			return
		end

		-- Setup cooperative sandbox environment
		debug_env = {
			task = {
				wait = function(t)
					return coroutine.yield("wait", t or 0)
				end,
				delay = function(t, cb)
					task.delay(t, function()
						task.spawn(cb)
					end)
				end,
				spawn = function(cb)
					task.spawn(cb)
				end,
				defer = function(cb)
					task.defer(cb)
				end
			},
			wait = function(t)
				return coroutine.yield("wait", t or 0)
			end,
			print = function(...)
				print("[DEX Debugger]", ...)
			end,
			warn = function(...)
				warn("[DEX Debugger]", ...)
			end
		}
		setmetatable(debug_env, {__index = getfenv(0)})
		setfenv(fn, debug_env)

		_G.DEX_DEBUG_STEP = function(line)
			if breakpoints[line] or step_mode then
				step_mode = false
				coroutine.yield("breakpoint", line)
			end
		end

		debugger_thread = coroutine.create(fn)
		debugger_state = "running"
		update_ui_states()
		step_session()
	end

	function debugger.Init()
		window = lib_ref.Window.new()
		window:SetTitle("Runtime Debugger")
		window:Resize(650, 430)
		debugger.Window = window

		local content = window.GuiElems.Content
		local t = theme()

		-- Toolbar
		local toolbar = Instance.new("Frame")
		toolbar.BackgroundColor3 = t.Main2
		toolbar.BorderSizePixel = 0
		toolbar.Size = UDim2.new(1, 0, 0, 36)
		toolbar.Parent = content

		start_btn = button(toolbar, "Start", UDim2.new(0, 6, 0, 6), UDim2.new(0, 68, 0, 24), start_session)
		resume_btn = button(toolbar, "Resume", UDim2.new(0, 80, 0, 6), UDim2.new(0, 68, 0, 24), function()
			debugger_state = "running"
			update_ui_states()
			step_session()
		end)
		step_btn = button(toolbar, "Step Over", UDim2.new(0, 154, 0, 6), UDim2.new(0, 78, 0, 24), function()
			step_mode = true
			debugger_state = "running"
			update_ui_states()
			step_session()
		end)
		stop_btn = button(toolbar, "Stop", UDim2.new(0, 238, 0, 6), UDim2.new(0, 58, 0, 24), stop_session)

		button(toolbar, "Load Selected", UDim2.new(1, -114, 0, 6), UDim2.new(0, 108, 0, 24), function()
			stop_session()
			local explorer = apps_ref and apps_ref.Explorer
			if explorer and explorer.Selection and explorer.Selection.List and #explorer.Selection.List > 0 then
				local node = explorer.Selection.List[1]
				if typeof(node.Obj) == "Instance" and (node.Obj:IsA("LocalScript") or node.Obj:IsA("ModuleScript") or node.Obj:IsA("Script")) then
					raw_source = node.Obj.Source
					set_status("Loaded script: " .. node.Obj.Name)
				end
			end
			render_code()
		end)

		-- Code Scroll (Left Panel)
		code_scroll = Instance.new("ScrollingFrame")
		code_scroll.Active = true
		code_scroll.BackgroundColor3 = t.Main2
		code_scroll.BorderSizePixel = 0
		code_scroll.Position = UDim2.new(0, 0, 0, 36)
		code_scroll.Size = UDim2.new(0.6, 0, 1, -68)
		code_scroll.ScrollBarThickness = 6
		code_scroll.Parent = content

		-- Variables Scroll (Right Top Panel)
		var_scroll = Instance.new("ScrollingFrame")
		var_scroll.Active = true
		var_scroll.BackgroundColor3 = t.Main1
		var_scroll.BorderSizePixel = 0
		var_scroll.Position = UDim2.new(0.6, 0, 0, 36)
		var_scroll.Size = UDim2.new(0.4, 0, 0.6, -18)
		var_scroll.ScrollBarThickness = 6
		var_scroll.Parent = content

		-- Call Stack Scroll (Right Bottom Panel)
		stack_scroll = Instance.new("ScrollingFrame")
		stack_scroll.Active = true
		stack_scroll.BackgroundColor3 = t.Main1
		stack_scroll.BorderColor3 = t.Outline1
		stack_scroll.Position = UDim2.new(0.6, 0, 0.6, 18)
		stack_scroll.Size = UDim2.new(0.4, 0, 0.4, -50)
		stack_scroll.ScrollBarThickness = 6
		stack_scroll.Parent = content

		local stack_lbl = label(content, "Call Stack:", UDim2.new(0.6, 6, 0.6, 2), UDim2.new(0.4, -12, 0, 14), t.PlaceholderText, true)

		-- Footer
		local footer = Instance.new("Frame")
		footer.BackgroundColor3 = t.Menu
		footer.BorderSizePixel = 0
		footer.Position = UDim2.new(0, 0, 1, -32)
		footer.Size = UDim2.new(1, 0, 0, 32)
		footer.Parent = content

		status_label = label(footer, "Ready. Toggle breakpoints by clicking line numbers.", UDim2.new(0, 10, 0, 7), UDim2.new(1, -20, 0, 18), t.PlaceholderText, false)

		update_ui_states()
		render_code()
	end

	return debugger
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main,
	PluginData = plugin_data,
}
