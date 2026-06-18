--!nocheck

local main_ref, lib_ref, apps_ref, settings_ref, env_ref, theme_ref

local plugin_data = {
	Name = "MetatableHookManager",
	FriendlyName = "Hook Safety Center",
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

local function main()
	local center = {}
	center.PluginData = plugin_data

	local window
	local status_label

	local function theme()
		return settings_ref.Theme
	end

	local function set_status(text)
		if status_label then
			status_label.Text = tostring(text)
		end
	end

	local function open_tool(name)
		local control = main_ref and main_ref.MenuApps and main_ref.MenuApps[name]
		if control and control.Enable then
			control.Enable(true)
			set_status("Opened " .. name .. ".")
			return true
		end
		set_status(name .. " is not loaded yet.")
		return false
	end

	local function label(parent, text, pos, size, color, bold)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = bold and Enum.Font.SourceSansBold or Enum.Font.SourceSans
		l.Position = pos
		l.Size = size
		l.Text = text
		l.TextColor3 = color or theme().Text
		l.TextSize = bold and 16 or 13
		l.TextWrapped = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextYAlignment = Enum.TextYAlignment.Top
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

	local function card(parent, y, title, body, accent, actions)
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = theme().Main1
		frame.BorderColor3 = theme().Outline1
		frame.Position = UDim2.new(0, 10, 0, y)
		frame.Size = UDim2.new(1, -20, 0, 82)
		frame.Parent = parent
		if theme_ref and theme_ref.ApplyRounding then
			theme_ref.ApplyRounding(frame, 5)
		end

		local mark = Instance.new("Frame")
		mark.BackgroundColor3 = accent or theme().Highlight
		mark.BorderSizePixel = 0
		mark.Size = UDim2.new(0, 4, 1, 0)
		mark.Parent = frame

		label(frame, title, UDim2.new(0, 12, 0, 8), UDim2.new(1, -24, 0, 20), theme().Text, true)
		label(frame, body, UDim2.new(0, 12, 0, 32), UDim2.new(1, actions and -160 or -24, 0, 42), theme().PlaceholderText, false)

		if actions then
			local totalWidth = -6
			for _, action in ipairs(actions) do
				totalWidth += (action.Width or 68) + 6
			end
			local x = -totalWidth - 12
			for _, action in ipairs(actions) do
				local w = action.Width or 68
				button(frame, action.Text, UDim2.new(1, x, 0, 26), UDim2.new(0, w, 0, 24), action.OnClick)
				x += w + 6
			end
		end

		return frame
	end

	function center.Init()
		window = lib_ref.Window.new()
		window:SetTitle("Hook Safety Center")
		window:Resize(620, 430)
		center.Window = window

		local content = window.GuiElems.Content

		local header = Instance.new("Frame")
		header.BackgroundColor3 = theme().Main2
		header.BorderSizePixel = 0
		header.Size = UDim2.new(1, 0, 0, 76)
		header.Parent = content

		label(header, "Global hooks disabled", UDim2.new(0, 12, 0, 8), UDim2.new(1, -24, 0, 24), theme().Important, true).TextSize = 18
		label(header, "__namecall, __index, and __newindex are blocked on this client because global metamethod hooks can freeze or crash Roblox.", UDim2.new(0, 12, 0, 36), UDim2.new(1, -24, 0, 34), theme().PlaceholderText, false)

		local body = Instance.new("Frame")
		body.BackgroundColor3 = theme().Main2
		body.BorderSizePixel = 0
		body.Position = UDim2.new(0, 0, 0, 76)
		body.Size = UDim2.new(1, 0, 1, -108)
		body.Parent = content

		card(body, 10, "Use targeted property probing",
			"Select object(s) in Explorer, choose property keys, and capture reads/writes for a short bounded window.",
			Color3.fromRGB(34, 197, 94),
			{{Text = "Open", Width = 62, OnClick = function() open_tool("Targeted Property Probe") end}}
		)

		card(body, 102, "Use remote-focused capture",
			"For RemoteEvent/RemoteFunction traffic, prefer Remote Spy with pause/filters/rate limits instead of raw global hook logging.",
			Color3.fromRGB(96, 165, 250),
			{{Text = "Open", Width = 62, OnClick = function() open_tool("Remote Spy") end}}
		)

		card(body, 194, "Use runtime snapshots",
			"For broad client behavior, use snapshot/ranking tools. They avoid installing hot-path metamethod wrappers.",
			Color3.fromRGB(168, 85, 247),
			{
				{Text = "Runtime", Width = 68, OnClick = function() open_tool("Runtime Inspector") end},
				{Text = "Control", Width = 64, OnClick = function() open_tool("Control Center") end},
			}
		)

		card(body, 286, "Current capability check",
			("hookmetamethod: %s | getnamecallmethod: %s | checkcaller: %s. Capability exists, but this client is unstable with global hooks."):format(
				env_func("hookmetamethod") and "present" or "missing",
				env_func("getnamecallmethod") and "present" or "missing",
				env_func("checkcaller") and "present" or "missing"
			),
			Color3.fromRGB(249, 115, 22),
			{{Text = "Copy", Width = 62, OnClick = function()
				if setclipboard then
					setclipboard(table.concat({
						"DEX++ Hook Safety Center",
						"Global metamethod hooks are disabled for this client.",
						"Reason: __namecall/__index/__newindex caused freezes or Roblox client crashes.",
						"Replacement: Targeted Property Probe, Remote Spy with limits, Runtime Inspector snapshots.",
						"Restart Roblox after any old unsafe hook session because hookmetamethod chains may persist.",
					}, "\n"))
					set_status("Copied safety brief.")
				else
					set_status("Clipboard API unavailable.")
				end
			end}}
		)

		local footer = Instance.new("Frame")
		footer.BackgroundColor3 = theme().Menu
		footer.BorderSizePixel = 0
		footer.Position = UDim2.new(0, 0, 1, -32)
		footer.Size = UDim2.new(1, 0, 0, 32)
		footer.Parent = content

		status_label = label(footer, "Ready. Restart Roblox after old unsafe hook sessions.", UDim2.new(0, 10, 0, 7), UDim2.new(1, -20, 0, 18), theme().PlaceholderText, false)
	end

	return center
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main,
	PluginData = plugin_data,
}
