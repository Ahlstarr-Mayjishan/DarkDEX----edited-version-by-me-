local main_ref, lib_ref, apps_ref, settings_ref, env_ref, theme_ref

local plugin_data = {
	Name = "MetatableHookManager",
	FriendlyName = "Metatable Hook Manager",
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

local function get_theme()
	return theme_ref or (apps_ref and apps_ref.Theme)
end

local table_clear = table.clear or function(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

local table_pack = table.pack or function(...)
	return { n = select("#", ...), ... }
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

local function protect_closure(fn)
	local newcclosure_fn = env_func("newcclosure")
	if newcclosure_fn then
		local ok, wrapped = pcall(newcclosure_fn, fn)
		if ok and wrapped then
			return wrapped
		end
	end
	return fn
end

local function main()
	local manager = {}
	manager.PluginData = plugin_data

	local hooks = {
		__namecall = {
			name = "__namecall",
			enabled = true,
			installed = false,
			count = 0,
			last = "never",
			color = Color3.fromRGB(96, 165, 250),
			error = "",
		},
		__index = {
			name = "__index",
			enabled = false,
			installed = false,
			count = 0,
			last = "never",
			color = Color3.fromRGB(34, 197, 94),
			error = "",
		},
		__newindex = {
			name = "__newindex",
			enabled = false,
			installed = false,
			count = 0,
			last = "never",
			color = Color3.fromRGB(249, 115, 22),
			error = "",
		},
	}
	local hook_order = { "__namecall", "__index", "__newindex" }

	local logs = {}
	local log_frames = {}
	local row_entry_map = {}
	local selected_entry = nil
	local running_hooks = {}
	local filter_text = ""
	local active = false
	local paused = false
	local refresh_scheduled = false
	local dropped_logs = 0
	local rate_window_start = 0
	local rate_window_count = 0
	local max_logs_per_second = 140
	local log_limit = 320
	local visible_log_limit = 90
	local high_volume_hook_active = false

	local window, list_frame, scroll_v, status_label, empty_label, inspector_scroll, hook_panel, capability_label
	local rebuild_list, render_hooks, show_details

	local function checkcaller_safe()
		local checkcaller_fn = env_func("checkcaller")
		if not checkcaller_fn then
			return false
		end
		local ok, result = pcall(checkcaller_fn)
		return ok and result == true
	end

	local function getnamecallmethod_safe()
		local getnamecallmethod_fn = env_func("getnamecallmethod")
		if not getnamecallmethod_fn then
			return "unknown"
		end
		local ok, result = pcall(getnamecallmethod_fn)
		return ok and tostring(result) or "unknown"
	end

	local function get_caller()
		local getcallingscript_fn = env_func("getcallingscript")
		if not getcallingscript_fn then
			return nil
		end
		local ok, caller = pcall(getcallingscript_fn)
		if ok and typeof(caller) == "Instance" then
			return caller
		end
		return nil
	end

	local function inst_path(obj)
		if typeof(obj) ~= "Instance" then
			return tostring(obj)
		end
		if main_ref and main_ref.SafeGetInstancePath then
			local ok, path = pcall(main_ref.SafeGetInstancePath, obj)
			if ok and path then
				return tostring(path)
			end
		end
		local ok, full = pcall(function()
			return obj:GetFullName()
		end)
		if ok and full then
			return "game." .. tostring(full)
		end
		local parts, cur = {}, obj
		while cur and cur ~= game do
			local ok_name, name = pcall(function()
				return cur.Name
			end)
			table.insert(parts, 1, ok_name and name or "?")
			local ok_parent, parent = pcall(function()
				return cur.Parent
			end)
			cur = ok_parent and parent or nil
		end
		table.insert(parts, 1, "game")
		return table.concat(parts, ".")
	end

	local function summarize_value(value, depth)
		depth = depth or 0
		local kind = typeof(value)
		if kind == "Instance" then
			local class_name = "Instance"
			local ok_class, class = pcall(function()
				return value.ClassName
			end)
			if ok_class then
				class_name = class
			end
			return class_name .. ":" .. inst_path(value)
		elseif kind == "string" then
			local s = #value > 120 and value:sub(1, 120) .. "...(" .. #value .. ")" or value
			return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
		elseif kind == "table" then
			if depth >= 2 then
				return "{...}"
			end
			local out, n = {}, 0
			for k, v in pairs(value) do
				n += 1
				if n > 6 then
					out[#out + 1] = "..."
					break
				end
				out[#out + 1] = tostring(k) .. "=" .. summarize_value(v, depth + 1)
			end
			return "{" .. table.concat(out, ", ") .. "}"
		elseif kind == "function" then
			return "function"
		elseif kind == "nil" then
			return "nil"
		end
		return tostring(value)
	end

	local function summarize_args(args)
		local n = args.n or #args
		if n == 0 then
			return "()"
		end
		local out = {}
		for i = 1, math.min(n, 6) do
			out[#out + 1] = summarize_value(args[i])
		end
		if n > 6 then
			out[#out + 1] = "..."
		end
		return table.concat(out, ", ")
	end

	local function class_name_of(obj)
		if typeof(obj) ~= "Instance" then
			return typeof(obj)
		end
		local ok, class = pcall(function()
			return obj.ClassName
		end)
		return ok and class or "Instance"
	end

	local function can_capture_log()
		local now = os.clock()
		if now - rate_window_start >= 1 then
			rate_window_start = now
			rate_window_count = 0
		end
		rate_window_count += 1
		if rate_window_count > max_logs_per_second then
			dropped_logs += 1
			return false
		end
		return true
	end

	local function matches(entry)
		if filter_text == "" then
			return true
		end
		local low = filter_text:lower()
		return entry.hook:lower():find(low, 1, true)
			or entry.path:lower():find(low, 1, true)
			or entry.action:lower():find(low, 1, true)
			or entry.summary:lower():find(low, 1, true)
			or entry.caller:lower():find(low, 1, true)
	end

	local function update_scroll()
		if not scroll_v then
			return
		end
		scroll_v.TotalSpace = #log_frames
		scroll_v.Index = math.max(0, #log_frames - scroll_v.VisibleSpace)
		scroll_v:Update()
	end

	local function update_status()
		if not status_label then
			return
		end
		local installed_count = 0
		for _, name in ipairs(hook_order) do
			if hooks[name].installed then
				installed_count += 1
			end
		end
		status_label.Text = string.format(
			"%s | %d hooks installed | %d events%s%s",
			active and (paused and "Paused" or "Capturing") or "Idle",
			installed_count,
			#logs,
			dropped_logs > 0 and (" | dropped " .. dropped_logs) or "",
			high_volume_hook_active and " | __index safe solo" or ""
		)
	end

	local function enforce_safe_hook_set(changed_hook)
		if changed_hook == "__index" and hooks.__index.enabled then
			hooks.__namecall.enabled = false
			hooks.__newindex.enabled = false
			max_logs_per_second = 40
			high_volume_hook_active = true
			return
		end
		if changed_hook ~= "__index" and hooks[changed_hook] and hooks[changed_hook].enabled then
			hooks.__index.enabled = false
		end
		high_volume_hook_active = hooks.__index.enabled == true
		max_logs_per_second = high_volume_hook_active and 40 or 140
	end

	local function schedule_refresh()
		if refresh_scheduled then
			return
		end
		refresh_scheduled = true
		task.delay(0.12, function()
			refresh_scheduled = false
			if render_hooks then
				render_hooks()
			end
			if rebuild_list then
				rebuild_list()
			end
			update_status()
		end)
	end

	local function add_event(hook_name, target, action, summary, arg_count, extra)
		if not active or paused then
			return
		end
		if not hooks[hook_name] or not hooks[hook_name].enabled then
			return
		end
		if checkcaller_safe() then
			return
		end
		if not can_capture_log() then
			return
		end

		local caller = get_caller()
		local hook = hooks[hook_name]
		hook.count += 1
		hook.last = os.date("%H:%M:%S")

		local entry = {
			time = hook.last,
			hook = hook_name,
			path = inst_path(target),
			class = class_name_of(target),
			action = tostring(action or ""),
			summary = tostring(summary or ""),
			arg_count = arg_count or 0,
			caller = caller and inst_path(caller) or "unknown",
			extra = extra or "",
		}

		logs[#logs + 1] = entry
		if #logs > log_limit then
			table.remove(logs, 1)
		end
		schedule_refresh()
	end

	local function install_namecall_hook()
		local hook = hooks.__namecall
		if hook.installed then
			return
		end
		local hookmetamethod_fn = env_func("hookmetamethod")
		if not hookmetamethod_fn then
			hook.error = "hookmetamethod unavailable"
			return
		end

		local original
		local ok, result = pcall(hookmetamethod_fn, game, "__namecall", protect_closure(function(self, ...)
			local packed_args = table_pack(...)
			if active and hook.enabled and typeof(self) == "Instance" then
				local thread = coroutine.running()
				if not running_hooks[thread] then
					running_hooks[thread] = true
					local ok_log = pcall(function()
						local method = getnamecallmethod_safe()
						add_event("__namecall", self, method .. "()", summarize_args(packed_args), packed_args.n)
					end)
					running_hooks[thread] = nil
					if not ok_log then
						dropped_logs += 1
					end
				end
			end
			return original(self, ...)
		end))

		if ok and result then
			original = result
			hook.installed = true
			hook.error = ""
		else
			hook.error = tostring(result or "install failed")
		end
	end

	local function install_index_hook()
		local hook = hooks.__index
		if hook.installed then
			return
		end
		local hookmetamethod_fn = env_func("hookmetamethod")
		if not hookmetamethod_fn then
			hook.error = "hookmetamethod unavailable"
			return
		end

		local original
		local ok, result = pcall(hookmetamethod_fn, game, "__index", protect_closure(function(self, key)
			if active and hook.enabled and typeof(self) == "Instance" then
				local thread = coroutine.running()
				if running_hooks[thread] then
					return original(self, key)
				end
				running_hooks[thread] = true
				local ok_log = pcall(function()
					add_event("__index", self, tostring(key), "read", 1)
				end)
				running_hooks[thread] = nil
				if not ok_log then
					dropped_logs += 1
				end
			end
			return original(self, key)
		end))

		if ok and result then
			original = result
			hook.installed = true
			hook.error = ""
		else
			hook.error = tostring(result or "install failed")
		end
	end

	local function install_newindex_hook()
		local hook = hooks.__newindex
		if hook.installed then
			return
		end
		local hookmetamethod_fn = env_func("hookmetamethod")
		if not hookmetamethod_fn then
			hook.error = "hookmetamethod unavailable"
			return
		end

		local original
		local ok, result = pcall(hookmetamethod_fn, game, "__newindex", protect_closure(function(self, key, value)
			if active and hook.enabled and typeof(self) == "Instance" then
				local thread = coroutine.running()
				if running_hooks[thread] then
					return original(self, key, value)
				end
				running_hooks[thread] = true
				local ok_log = pcall(function()
					add_event("__newindex", self, tostring(key), summarize_value(value), 1)
				end)
				running_hooks[thread] = nil
				if not ok_log then
					dropped_logs += 1
				end
			end
			return original(self, key, value)
		end))

		if ok and result then
			original = result
			hook.installed = true
			hook.error = ""
		else
			hook.error = tostring(result or "install failed")
		end
	end

	local function install_hooks()
		if hooks.__index.enabled then
			enforce_safe_hook_set("__index")
		end
		if hooks.__namecall.enabled then
			install_namecall_hook()
		end
		if hooks.__index.enabled then
			install_index_hook()
		end
		if hooks.__newindex.enabled then
			install_newindex_hook()
		end
	end

	local function clear_log_rows()
		for _, row in ipairs(log_frames) do
			row_entry_map[row] = nil
			row:Destroy()
		end
		log_frames = {}
	end

	local function rebuild_list_highlights()
		for _, row in ipairs(log_frames) do
			local entry = row_entry_map[row]
			row.BackgroundColor3 = entry == selected_entry and settings_ref.Theme.ListSelection or settings_ref.Theme.Main1
		end
	end

	local function push_row(entry)
		if not list_frame then
			return
		end
		if empty_label then
			empty_label.Visible = false
		end

		local hook = hooks[entry.hook]
		local col = hook and hook.color or settings_ref.Theme.Highlight

		local row = Instance.new("TextButton")
		row.AutoButtonColor = false
		row.BackgroundColor3 = entry == selected_entry and settings_ref.Theme.ListSelection or settings_ref.Theme.Main1
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, 42)
		row.Text = ""
		row.ClipsDescendants = true

		local badge = Instance.new("Frame", row)
		badge.BackgroundColor3 = col
		badge.BorderSizePixel = 0
		badge.Size = UDim2.new(0, 3, 1, 0)

		local time_lbl = Instance.new("TextLabel", row)
		time_lbl.BackgroundTransparency = 1
		time_lbl.Position = UDim2.new(0, 8, 0, 0)
		time_lbl.Size = UDim2.new(0, 58, 0, 18)
		time_lbl.Font = Enum.Font.Code
		time_lbl.TextSize = 11
		time_lbl.TextColor3 = settings_ref.Theme.PlaceholderText
		time_lbl.TextXAlignment = Enum.TextXAlignment.Left
		time_lbl.Text = entry.time

		local hook_lbl = Instance.new("TextLabel", row)
		hook_lbl.BackgroundTransparency = 1
		hook_lbl.Position = UDim2.new(0, 68, 0, 0)
		hook_lbl.Size = UDim2.new(0, 92, 0, 18)
		hook_lbl.Font = get_theme() and get_theme().MapFont(Enum.Font.SourceSansBold) or Enum.Font.SourceSansBold
		hook_lbl.TextSize = 13
		hook_lbl.TextColor3 = col
		hook_lbl.TextXAlignment = Enum.TextXAlignment.Left
		hook_lbl.Text = entry.hook

		local action_lbl = Instance.new("TextLabel", row)
		action_lbl.BackgroundTransparency = 1
		action_lbl.Position = UDim2.new(0, 162, 0, 0)
		action_lbl.Size = UDim2.new(1, -168, 0, 18)
		action_lbl.Font = Enum.Font.Code
		action_lbl.TextSize = 12
		action_lbl.TextColor3 = settings_ref.Theme.Text
		action_lbl.TextXAlignment = Enum.TextXAlignment.Left
		action_lbl.TextTruncate = Enum.TextTruncate.AtEnd
		action_lbl.Text = entry.action

		local path_lbl = Instance.new("TextLabel", row)
		path_lbl.BackgroundTransparency = 1
		path_lbl.Position = UDim2.new(0, 8, 0, 20)
		path_lbl.Size = UDim2.new(0.55, -8, 0, 18)
		path_lbl.Font = Enum.Font.Code
		path_lbl.TextSize = 11
		path_lbl.TextColor3 = settings_ref.Theme.PlaceholderText
		path_lbl.TextXAlignment = Enum.TextXAlignment.Left
		path_lbl.TextTruncate = Enum.TextTruncate.AtEnd
		path_lbl.Text = entry.path

		local summary_lbl = Instance.new("TextLabel", row)
		summary_lbl.BackgroundTransparency = 1
		summary_lbl.Position = UDim2.new(0.55, 0, 0, 20)
		summary_lbl.Size = UDim2.new(0.45, -8, 0, 18)
		summary_lbl.Font = Enum.Font.Code
		summary_lbl.TextSize = 11
		summary_lbl.TextColor3 = settings_ref.Theme.Syntax.Number or Color3.fromRGB(210, 210, 140)
		summary_lbl.TextXAlignment = Enum.TextXAlignment.Right
		summary_lbl.TextTruncate = Enum.TextTruncate.AtEnd
		summary_lbl.Text = entry.summary

		local separator = Instance.new("Frame", row)
		separator.BackgroundColor3 = settings_ref.Theme.Outline1
		separator.BorderSizePixel = 0
		separator.Size = UDim2.new(1, 0, 0, 1)
		separator.Position = UDim2.new(0, 0, 1, -1)

		row.MouseEnter:Connect(function()
			if selected_entry ~= entry then
				row.BackgroundColor3 = settings_ref.Theme.ButtonHover
			end
		end)
		row.MouseLeave:Connect(function()
			if selected_entry ~= entry then
				row.BackgroundColor3 = settings_ref.Theme.Main1
			end
		end)
		row.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				selected_entry = entry
				if show_details then
					show_details(entry)
				end
				rebuild_list_highlights()
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 and setclipboard then
				setclipboard(entry.path)
			end
		end)

		row.LayoutOrder = #log_frames + 1
		row.Parent = list_frame
		log_frames[#log_frames + 1] = row
		row_entry_map[row] = entry
	end

	rebuild_list = function()
		if not list_frame then
			return
		end
		clear_log_rows()

		local matched = {}
		for i = #logs, 1, -1 do
			local entry = logs[i]
			if matches(entry) then
				table.insert(matched, 1, entry)
				if #matched >= visible_log_limit then
					break
				end
			end
		end

		for _, entry in ipairs(matched) do
			push_row(entry)
		end

		if empty_label then
			empty_label.Visible = #matched == 0
			empty_label.Text = filter_text ~= "" and "No hook events match filter" or "Start capture to visualize metatable activity"
		end

		update_scroll()
		rebuild_list_highlights()
	end

	local function create_detail_block(title, text, order)
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, 0, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.LayoutOrder = order
		frame.Parent = inspector_scroll

		local title_lbl = Instance.new("TextLabel", frame)
		title_lbl.BackgroundTransparency = 1
		title_lbl.Size = UDim2.new(1, -54, 0, 19)
		title_lbl.Font = get_theme() and get_theme().MapFont(Enum.Font.SourceSansBold) or Enum.Font.SourceSansBold
		title_lbl.TextSize = 12
		title_lbl.TextColor3 = settings_ref.Theme.PlaceholderText
		title_lbl.TextXAlignment = Enum.TextXAlignment.Left
		title_lbl.Text = title

		local copy_btn = Instance.new("TextButton", frame)
		copy_btn.AutoButtonColor = false
		copy_btn.Position = UDim2.new(1, -50, 0, 0)
		copy_btn.Size = UDim2.new(0, 48, 0, 18)
		copy_btn.Font = Enum.Font.SourceSans
		copy_btn.TextSize = 12
		copy_btn.Text = "Copy"
		if get_theme() then
			get_theme().StyleButton(copy_btn)
		else
			copy_btn.BackgroundColor3 = settings_ref.Theme.Button
			copy_btn.TextColor3 = settings_ref.Theme.Text
		end

		local box = Instance.new("TextBox", frame)
		box.BackgroundColor3 = settings_ref.Theme.Main1
		box.BorderSizePixel = 0
		box.ClearTextOnFocus = false
		box.MultiLine = true
		box.TextEditable = false
		box.TextWrapped = true
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.TextYAlignment = Enum.TextYAlignment.Top
		box.Position = UDim2.new(0, 0, 0, 21)
		box.Size = UDim2.new(1, 0, 0, math.max(44, math.min(130, 26 + math.ceil(#text / 58) * 14)))
		box.Font = Enum.Font.Code
		box.TextSize = 11
		box.TextColor3 = settings_ref.Theme.Text
		box.Text = text

		local pad = Instance.new("UIPadding", box)
		pad.PaddingLeft = UDim.new(0, 6)
		pad.PaddingRight = UDim.new(0, 6)
		pad.PaddingTop = UDim.new(0, 5)
		pad.PaddingBottom = UDim.new(0, 5)

		if get_theme() then
			get_theme().ApplyRounding(box, 4)
		end

		copy_btn.MouseButton1Click:Connect(function()
			if setclipboard then
				setclipboard(text)
				copy_btn.Text = "Copied"
				task.delay(0.8, function()
					if copy_btn then
						copy_btn.Text = "Copy"
					end
				end)
			end
		end)
	end

	show_details = function(entry)
		if not inspector_scroll then
			return
		end
		for _, child in ipairs(inspector_scroll:GetChildren()) do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end

		if not entry then
			local placeholder = Instance.new("TextLabel", inspector_scroll)
			placeholder.BackgroundTransparency = 1
			placeholder.Size = UDim2.new(1, 0, 0, 50)
			placeholder.Font = get_theme() and get_theme().MapFont(Enum.Font.SourceSans) or Enum.Font.SourceSans
			placeholder.TextSize = 14
			placeholder.TextColor3 = settings_ref.Theme.PlaceholderText
			placeholder.Text = "Select a hook event to inspect"
			return
		end

		local meta = table.concat({
			"Time: " .. entry.time,
			"Hook: " .. entry.hook,
			"Action: " .. entry.action,
			"Class: " .. entry.class,
			"Arg count: " .. tostring(entry.arg_count),
			"Caller: " .. entry.caller,
		}, "\n")

		create_detail_block("Event", meta, 1)
		create_detail_block("Target", entry.path, 2)
		create_detail_block("Value / Args", entry.summary, 3)
	end

	render_hooks = function()
		if not hook_panel then
			return
		end
		for _, child in ipairs(hook_panel:GetChildren()) do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end

		for i, name in ipairs(hook_order) do
			local hook = hooks[name]
			local row = Instance.new("TextButton")
			row.AutoButtonColor = false
			row.BackgroundColor3 = hook.enabled and settings_ref.Theme.Main2 or settings_ref.Theme.Main1
			row.BorderSizePixel = 0
			row.Size = UDim2.new(1, -8, 0, 56)
			row.Text = ""
			row.LayoutOrder = i
			row.Parent = hook_panel
			if get_theme() then
				get_theme().ApplyRounding(row, 4)
			end

			local badge = Instance.new("Frame", row)
			badge.BackgroundColor3 = hook.enabled and hook.color or settings_ref.Theme.Outline2
			badge.BorderSizePixel = 0
			badge.Size = UDim2.new(0, 4, 1, 0)

			local name_lbl = Instance.new("TextLabel", row)
			name_lbl.BackgroundTransparency = 1
			name_lbl.Position = UDim2.new(0, 10, 0, 3)
			name_lbl.Size = UDim2.new(1, -20, 0, 18)
			name_lbl.Font = get_theme() and get_theme().MapFont(Enum.Font.SourceSansBold) or Enum.Font.SourceSansBold
			name_lbl.TextSize = 14
			name_lbl.TextColor3 = hook.enabled and settings_ref.Theme.Text or settings_ref.Theme.PlaceholderText
			name_lbl.TextXAlignment = Enum.TextXAlignment.Left
			name_lbl.Text = hook.name

			local state_lbl = Instance.new("TextLabel", row)
			state_lbl.BackgroundTransparency = 1
			state_lbl.Position = UDim2.new(0, 10, 0, 22)
			state_lbl.Size = UDim2.new(1, -20, 0, 15)
			state_lbl.Font = Enum.Font.Code
			state_lbl.TextSize = 11
			state_lbl.TextColor3 = hook.installed and hook.color or settings_ref.Theme.PlaceholderText
			state_lbl.TextXAlignment = Enum.TextXAlignment.Left
			local state_text = hook.installed and "installed" or "not installed"
			if hook.error ~= "" then
				state_text = hook.error
			end
			state_lbl.Text = (hook.enabled and "capture on | " or "capture off | ") .. state_text

			local count_lbl = Instance.new("TextLabel", row)
			count_lbl.BackgroundTransparency = 1
			count_lbl.Position = UDim2.new(0, 10, 0, 38)
			count_lbl.Size = UDim2.new(1, -20, 0, 15)
			count_lbl.Font = Enum.Font.Code
			count_lbl.TextSize = 11
			count_lbl.TextColor3 = settings_ref.Theme.PlaceholderText
			count_lbl.TextXAlignment = Enum.TextXAlignment.Left
			count_lbl.Text = tostring(hook.count) .. " events | last " .. hook.last

			row.MouseButton1Click:Connect(function()
				hook.enabled = not hook.enabled
				enforce_safe_hook_set(hook.name)
				if active and hook.enabled then
					install_hooks()
				end
				render_hooks()
				update_status()
			end)
		end

		if capability_label then
			local caps = {
				(env_func("hookmetamethod") and "hookmetamethod OK" or "hookmetamethod missing"),
				(env_func("getnamecallmethod") and "getnamecallmethod OK" or "getnamecallmethod missing"),
				(env_func("checkcaller") and "checkcaller OK" or "checkcaller missing"),
				(env_func("getcallingscript") and "getcallingscript OK" or "getcallingscript missing"),
			}
			capability_label.Text = table.concat(caps, "\n")
		end
	end

	local function make_btn(parent, text, x, w)
		local btn = Instance.new("TextButton")
		btn.BorderSizePixel = 0
		btn.Font = Enum.Font.SourceSans
		btn.TextSize = 13
		btn.Text = text
		btn.AutoButtonColor = false
		btn.Size = UDim2.new(0, w, 0, 18)
		btn.Position = UDim2.new(0, x, 0, 4)
		btn.Parent = parent
		if get_theme() then
			get_theme().StyleButton(btn)
		else
			btn.BackgroundColor3 = settings_ref.Theme.Button
			btn.TextColor3 = settings_ref.Theme.Text
		end
		return btn
	end

	local function update_button_states(start_btn, stop_btn, pause_btn)
		local theme = settings_ref.Theme
		if active then
			start_btn.Text = paused and "Paused" or "Active"
			start_btn.BackgroundColor3 = paused and Color3.fromRGB(234, 179, 8) or theme.ListSelection
			stop_btn.Text = "Stop"
			stop_btn.BackgroundColor3 = theme.Button
		else
			start_btn.Text = "Start"
			start_btn.BackgroundColor3 = theme.Button
			stop_btn.Text = "Stopped"
			stop_btn.BackgroundColor3 = Color3.fromRGB(244, 63, 94)
		end
		pause_btn.Text = paused and "Resume" or "Pause"
		pause_btn.BackgroundColor3 = paused and Color3.fromRGB(234, 179, 8) or theme.Button
		update_status()
	end

	manager.Init = function()
		window = lib_ref.Window.new()
		window:SetTitle("Metatable Hook Manager")
		window:Resize(860, 500)
		manager.Window = window

		local content = window.GuiElems.Content

		local toolbar = Instance.new("Frame")
		toolbar.BackgroundColor3 = settings_ref.Theme.Menu
		toolbar.BorderSizePixel = 0
		toolbar.Size = UDim2.new(1, 0, 0, 26)
		toolbar.Parent = content

		local start_btn = make_btn(toolbar, "Start", 4, 58)
		local stop_btn = make_btn(toolbar, "Stop", 66, 58)
		local pause_btn = make_btn(toolbar, "Pause", 128, 58)
		local clear_btn = make_btn(toolbar, "Clear", 190, 54)
		local copy_btn = make_btn(toolbar, "Copy", 248, 54)

		status_label = Instance.new("TextLabel")
		status_label.BackgroundTransparency = 1
		status_label.Position = UDim2.new(0, 310, 0, 0)
		status_label.Size = UDim2.new(1, -318, 1, 0)
		status_label.Font = get_theme() and get_theme().MapFont(Enum.Font.SourceSans) or Enum.Font.SourceSans
		status_label.TextSize = 12
		status_label.TextColor3 = settings_ref.Theme.PlaceholderText
		status_label.TextXAlignment = Enum.TextXAlignment.Right
		status_label.Text = "Idle"
		status_label.Parent = toolbar

		local search_bar = Instance.new("Frame")
		search_bar.BackgroundColor3 = settings_ref.Theme.Main1
		search_bar.BorderSizePixel = 0
		search_bar.Position = UDim2.new(0, 0, 0, 26)
		search_bar.Size = UDim2.new(1, 0, 0, 26)
		search_bar.Parent = content

		local search_box = Instance.new("TextBox", search_bar)
		search_box.BackgroundTransparency = 1
		search_box.ClearTextOnFocus = false
		search_box.Font = Enum.Font.Code
		search_box.PlaceholderColor3 = settings_ref.Theme.PlaceholderText
		search_box.PlaceholderText = "filter hook, target, action, value, or caller"
		search_box.Position = UDim2.new(0, 8, 0, 0)
		search_box.Size = UDim2.new(1, -16, 1, 0)
		search_box.Text = ""
		search_box.TextColor3 = settings_ref.Theme.Text
		search_box.TextSize = 13
		search_box.TextXAlignment = Enum.TextXAlignment.Left
		search_box.Parent = search_bar
		search_box:GetPropertyChangedSignal("Text"):Connect(function()
			filter_text = search_box.Text
			rebuild_list()
		end)

		local body = Instance.new("Frame")
		body.BackgroundColor3 = settings_ref.Theme.Main2
		body.BorderSizePixel = 0
		body.Position = UDim2.new(0, 0, 0, 52)
		body.Size = UDim2.new(1, 0, 1, -52)
		body.Parent = content

		local left_panel = Instance.new("Frame")
		left_panel.BackgroundColor3 = settings_ref.Theme.Main1
		left_panel.BorderSizePixel = 0
		left_panel.Size = UDim2.new(0, 226, 1, 0)
		left_panel.Parent = body

		local left_title = Instance.new("TextLabel", left_panel)
		left_title.BackgroundTransparency = 1
		left_title.Position = UDim2.new(0, 8, 0, 0)
		left_title.Size = UDim2.new(1, -16, 0, 26)
		left_title.Font = get_theme() and get_theme().MapFont(Enum.Font.SourceSansBold) or Enum.Font.SourceSansBold
		left_title.TextSize = 14
		left_title.TextColor3 = settings_ref.Theme.Text
		left_title.TextXAlignment = Enum.TextXAlignment.Left
		left_title.Text = "Hook controls"

		hook_panel = Instance.new("Frame")
		hook_panel.BackgroundTransparency = 1
		hook_panel.Position = UDim2.new(0, 4, 0, 30)
		hook_panel.Size = UDim2.new(1, -4, 0, 176)
		hook_panel.Parent = left_panel

		local hook_layout = Instance.new("UIListLayout", hook_panel)
		hook_layout.SortOrder = Enum.SortOrder.LayoutOrder
		hook_layout.Padding = UDim.new(0, 6)

		capability_label = Instance.new("TextLabel", left_panel)
		capability_label.BackgroundColor3 = settings_ref.Theme.Main2
		capability_label.BorderSizePixel = 0
		capability_label.Position = UDim2.new(0, 8, 0, 218)
		capability_label.Size = UDim2.new(1, -16, 0, 88)
		capability_label.Font = Enum.Font.Code
		capability_label.TextSize = 11
		capability_label.TextColor3 = settings_ref.Theme.PlaceholderText
		capability_label.TextXAlignment = Enum.TextXAlignment.Left
		capability_label.TextYAlignment = Enum.TextYAlignment.Top
		capability_label.TextWrapped = true
		if get_theme() then
			get_theme().ApplyRounding(capability_label, 4)
		end

		local left_note = Instance.new("TextLabel", left_panel)
		left_note.BackgroundTransparency = 1
		left_note.Position = UDim2.new(0, 8, 0, 316)
		left_note.Size = UDim2.new(1, -16, 0, 78)
		left_note.Font = get_theme() and get_theme().MapFont(Enum.Font.SourceSans) or Enum.Font.SourceSans
		left_note.TextSize = 12
		left_note.TextColor3 = settings_ref.Theme.PlaceholderText
		left_note.TextWrapped = true
		left_note.TextXAlignment = Enum.TextXAlignment.Left
		left_note.TextYAlignment = Enum.TextYAlignment.Top
		left_note.Text = "__index is high-volume and runs in solo safe mode. Enabling it disables __namecall and __newindex to avoid client crashes. Stop disables capture, but installed metamethod chains stay passive."

		local split_left = Instance.new("Frame", body)
		split_left.BackgroundColor3 = settings_ref.Theme.Outline1
		split_left.BorderSizePixel = 0
		split_left.Position = UDim2.new(0, 226, 0, 0)
		split_left.Size = UDim2.new(0, 1, 1, 0)

		local list_panel = Instance.new("Frame")
		list_panel.BackgroundColor3 = settings_ref.Theme.Main2
		list_panel.BorderSizePixel = 0
		list_panel.Position = UDim2.new(0, 227, 0, 0)
		list_panel.Size = UDim2.new(0, 384, 1, 0)
		list_panel.Parent = body

		local list_container = Instance.new("Frame")
		list_container.BackgroundColor3 = settings_ref.Theme.Main2
		list_container.BorderSizePixel = 0
		list_container.ClipsDescendants = true
		list_container.Size = UDim2.new(1, -16, 1, 0)
		list_container.Parent = list_panel

		list_frame = Instance.new("Frame")
		list_frame.BackgroundTransparency = 1
		list_frame.Size = UDim2.new(1, 0, 0, 0)
		list_frame.AutomaticSize = Enum.AutomaticSize.Y
		list_frame.Parent = list_container

		local list_layout = Instance.new("UIListLayout", list_frame)
		list_layout.SortOrder = Enum.SortOrder.LayoutOrder
		list_layout.Padding = UDim.new(0, 1)

		empty_label = Instance.new("TextLabel", list_container)
		empty_label.BackgroundTransparency = 1
		empty_label.Position = UDim2.new(0, 0, 0.5, -24)
		empty_label.Size = UDim2.new(1, 0, 0, 48)
		empty_label.Font = get_theme() and get_theme().MapFont(Enum.Font.SourceSans) or Enum.Font.SourceSans
		empty_label.TextSize = 14
		empty_label.TextColor3 = settings_ref.Theme.PlaceholderText
		empty_label.Text = "Start capture to visualize metatable activity"
		empty_label.Visible = true
		empty_label.Parent = list_container

		scroll_v = lib_ref.ScrollBar.new()
		scroll_v.WheelIncrement = 3
		scroll_v.Gui.Position = UDim2.new(1, -16, 0, 0)
		scroll_v.Gui.Size = UDim2.new(0, 16, 1, 0)
		scroll_v.Gui.Parent = list_panel
		scroll_v:SetScrollFrame(list_container)
		scroll_v.Scrolled:Connect(function()
			list_frame.Position = UDim2.new(0, 0, 0, -scroll_v.Index * 43)
		end)

		local split_right = Instance.new("Frame", body)
		split_right.BackgroundColor3 = settings_ref.Theme.Outline1
		split_right.BorderSizePixel = 0
		split_right.Position = UDim2.new(0, 611, 0, 0)
		split_right.Size = UDim2.new(0, 1, 1, 0)

		local right_panel = Instance.new("Frame")
		right_panel.BackgroundColor3 = settings_ref.Theme.Main2
		right_panel.BorderSizePixel = 0
		right_panel.Position = UDim2.new(0, 612, 0, 0)
		right_panel.Size = UDim2.new(1, -612, 1, 0)
		right_panel.Parent = body

		inspector_scroll = Instance.new("ScrollingFrame")
		inspector_scroll.Active = true
		inspector_scroll.BackgroundTransparency = 1
		inspector_scroll.BorderSizePixel = 0
		inspector_scroll.Position = UDim2.new(0, 6, 0, 6)
		inspector_scroll.Size = UDim2.new(1, -12, 1, -12)
		inspector_scroll.ScrollBarImageColor3 = settings_ref.Theme.Highlight
		inspector_scroll.ScrollBarThickness = 4
		inspector_scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		inspector_scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		inspector_scroll.Parent = right_panel

		local inspector_layout = Instance.new("UIListLayout", inspector_scroll)
		inspector_layout.SortOrder = Enum.SortOrder.LayoutOrder
		inspector_layout.Padding = UDim.new(0, 10)

		start_btn.MouseButton1Click:Connect(function()
			if not active then
				active = true
				paused = false
				rate_window_start = os.clock()
				rate_window_count = 0
				install_hooks()
				update_button_states(start_btn, stop_btn, pause_btn)
				render_hooks()
			end
		end)

		stop_btn.MouseButton1Click:Connect(function()
			if active then
				active = false
				paused = false
				update_button_states(start_btn, stop_btn, pause_btn)
				render_hooks()
			end
		end)

		pause_btn.MouseButton1Click:Connect(function()
			if active then
				paused = not paused
				update_button_states(start_btn, stop_btn, pause_btn)
			end
		end)

		clear_btn.MouseButton1Click:Connect(function()
			logs = {}
			clear_log_rows()
			table_clear(row_entry_map)
			selected_entry = nil
			dropped_logs = 0
			for _, name in ipairs(hook_order) do
				hooks[name].count = 0
				hooks[name].last = "never"
			end
			rebuild_list()
			render_hooks()
			show_details(nil)
			update_status()
		end)

		copy_btn.MouseButton1Click:Connect(function()
			if not setclipboard then
				return
			end
			local lines = {}
			for _, entry in ipairs(logs) do
				lines[#lines + 1] = string.format("[%s] %s %s %s | %s | caller %s",
					entry.time, entry.hook, entry.path, entry.action, entry.summary, entry.caller)
			end
			setclipboard(table.concat(lines, "\n"))
		end)

		render_hooks()
		rebuild_list()
		show_details(nil)
		update_button_states(start_btn, stop_btn, pause_btn)

		window.OnActivate:Connect(function()
			if scroll_v then
				scroll_v.TotalSpace = #log_frames
				scroll_v.VisibleSpace = math.floor(list_container.AbsoluteSize.Y / 43)
				scroll_v:Update()
			end
		end)
	end

	manager.Uninit = function()
		active = false
		paused = false
	end
	return manager
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main,
	CleanUp = function() active = false paused = false end,
	PluginData = plugin_data,
}
