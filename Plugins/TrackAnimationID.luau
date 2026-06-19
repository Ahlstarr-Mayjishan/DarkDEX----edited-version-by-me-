--!nocheck

local _main_ref, lib_ref, apps_ref, settings_ref, env_ref, theme_ref

local plugin_data = {
	name         = "TrackAnimationID",
	FriendlyName = "Animation Tracker",
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

local function normalizeAsset(value)
	value = tostring(value or "")
	if value == "" then return "" end
	local id = value:match("rbxassetid://(%d+)") or value:match("[?&]id=(%d+)") or value:match("asset/%?id=(%d+)") or value:match("(%d+)")
	if id and value:find("rbxassetid://", 1, true) == nil then
		return "rbxassetid://" .. id
	end
	return value
end

local function main()
	local plugin = {}
	plugin.PluginData = plugin_data

	local animations = {}
	local animationMap = {}
	local filtered_items = {}
	local log_frames = {}
	local row_item_map = {}
	local selected_item = nil
	local filter_text = ""

	local window, list_frame, scroll_v, status_label, empty_label, list_container
	local path_box, preview_btn, copy_btn, error_label
	local rebuild_list

	local function matches(item)
		if filter_text == "" then return true end
		local low = filter_text:lower()
		return item.Name:lower():find(low, 1, true) or item.Asset:lower():find(low, 1, true) or item.Path:lower():find(low, 1, true)
	end

	local function update_scroll()
		if scroll_v then
			scroll_v.TotalSpace = #log_frames
			scroll_v.Index = math.max(0, math.min(scroll_v.Index, #log_frames - scroll_v.VisibleSpace))
			scroll_v:Update()
		end
	end

	local function rebuild_list_highlights()
		for _, row in ipairs(log_frames) do
			local item = row_item_map[row]
			if item == selected_item then
				row.BackgroundColor3 = settings_ref.Theme.ListSelection
			else
				row.BackgroundColor3 = settings_ref.Theme.Main1
			end
		end
	end

	local function ensureTool(tool)
		if not tool then return false end
		if tool.EnsureInit then
			return tool.EnsureInit()
		end
		return true
	end

	local function open_viewer(item)
		if not item then return end
		local av = apps_ref.AnimationViewer
		if av and ensureTool(av) and av.ShowForObject then
			local animInstance = item.Instance
			if not animInstance or not animInstance.Parent then
				-- Fallback: construct temporary Animation instance to view
				local newAnim = Instance.new("Animation")
				newAnim.Name = item.Name
				newAnim.AnimationId = item.Asset
				animInstance = newAnim
			end
			task.spawn(function()
				av.ShowForObject(animInstance)
			end)
		else
			error_label.Text = "Animation Viewer module not active/found."
			error_label.TextColor3 = Color3.fromRGB(239, 68, 68)
		end
	end

	local function show_details(item)
		selected_item = item
		if not item then
			path_box.Text = ""
			preview_btn.Active = false
			preview_btn.BackgroundColor3 = settings_ref.Theme.Main1
			copy_btn.Active = false
			copy_btn.BackgroundColor3 = settings_ref.Theme.Main1
			error_label.Text = ""
			return
		end
		
		path_box.Text = item.Asset .. "\nPath: " .. item.Path .. "\nLogged: " .. item.Time
		
		preview_btn.Active = true
		preview_btn.BackgroundColor3 = settings_ref.Theme.Button
		copy_btn.Active = true
		copy_btn.BackgroundColor3 = settings_ref.Theme.Button
		error_label.Text = ""
	end

	local function push_row(item)
		if not list_frame then return end
		if empty_label then empty_label.Visible = false end
		
		local row = Instance.new("Frame")
		row.BackgroundColor3 = settings_ref.Theme.Main1
		row.BorderSizePixel  = 0
		row.Size             = UDim2.new(1, 0, 0, 36)
		row.ClipsDescendants = true
		
		local badge = Instance.new("Frame", row)
		badge.BackgroundColor3 = Color3.fromRGB(59, 130, 246) -- Blue badge for tracked animation
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
		name_lbl.Text = item.Name
		
		local path_lbl = Instance.new("TextLabel", row)
		path_lbl.BackgroundTransparency = 1
		path_lbl.Position  = UDim2.new(0, 8, 0, 18)
		path_lbl.Size      = UDim2.new(1, -16, 0, 16)
		path_lbl.Font      = Enum.Font.Code
		path_lbl.TextSize  = 10
		path_lbl.TextColor3 = settings_ref.Theme.PlaceholderText
		path_lbl.TextXAlignment = Enum.TextXAlignment.Left
		path_lbl.TextTruncate = Enum.TextTruncate.AtEnd
		path_lbl.Text = item.Asset .. "  |  " .. item.Path
		
		local separator = Instance.new("Frame", row)
		separator.BackgroundColor3 = settings_ref.Theme.Outline1
		separator.BorderSizePixel = 0
		separator.Size = UDim2.new(1, 0, 0, 1)
		separator.Position = UDim2.new(0, 0, 1, -1)
		
		local lastClick = 0
		row.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement then
				row.BackgroundColor3 = selected_item == item and settings_ref.Theme.ListSelection or settings_ref.Theme.ButtonHover
			elseif i.UserInputType == Enum.UserInputType.MouseButton1 then
				selected_item = item
				show_details(item)
				rebuild_list_highlights()
				
				local now = os.clock()
				if now - lastClick < 0.35 then
					open_viewer(item)
				end
				lastClick = now
			end
		end)
		
		row.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement then
				row.BackgroundColor3 = selected_item == item and settings_ref.Theme.ListSelection or settings_ref.Theme.Main1
			end
		end)
		
		row.LayoutOrder = #log_frames + 1
		row.Parent = list_frame
		table.insert(log_frames, row)
		row_item_map[row] = item
	end

	local rebuild_pending = false
	local function queue_rebuild()
		if rebuild_pending then return end
		rebuild_pending = true
		task.defer(function()
			rebuild_pending = false
			rebuild_list()
		end)
	end

	rebuild_list = function()
		for _, f in ipairs(log_frames) do f:Destroy() end
		log_frames = {}
		table.clear(row_item_map)
		
		table.clear(filtered_items)
		for _, item in ipairs(animations) do
			if matches(item) then
				table.insert(filtered_items, item)
			end
		end
		
		local max_visible = 200
		local count = 0
		for i = #filtered_items, 1, -1 do
			local item = filtered_items[i]
			count += 1
			if count > max_visible then break end
			push_row(item)
		end
		
		if empty_label then
			empty_label.Visible = #filtered_items == 0
			empty_label.Text = #animations == 0 and "No tracked animations found" or "No animations match filter"
		end
		
		if status_label then
			local count_str = #filtered_items > max_visible and (max_visible .. "+ of " .. #filtered_items) or tostring(#filtered_items)
			status_label.Text = #animations .. " tracked (" .. count_str .. " filtered)"
		end
		
		if scroll_v then
			scroll_v.TotalSpace = #log_frames
			scroll_v.VisibleSpace = math.floor(list_container.AbsoluteSize.Y / 37)
			scroll_v:Update()
		end
		rebuild_list_highlights()
	end

	local function make_btn(parent, text, y, h, callback)
		local btn = Instance.new("TextButton")
		btn.BorderSizePixel  = 0
		btn.Font             = Enum.Font.SourceSans
		btn.TextSize         = 14
		btn.Text             = text
		btn.AutoButtonColor  = false
		btn.Size             = UDim2.new(1, -20, 0, h)
		btn.Position         = UDim2.new(0, 10, 0, y)
		btn.Parent           = parent
		btn.MouseButton1Click:Connect(callback)
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

	local function trackAnimation(anim)
		if not anim or typeof(anim) ~= "Instance" or not anim:IsA("Animation") then return end
		
		local id = normalizeAsset(anim.AnimationId)
		if id == "" then
			-- In case AnimationId is set dynamically later
			local con
			con = anim:GetPropertyChangedSignal("AnimationId"):Connect(function()
				local newId = normalizeAsset(anim.AnimationId)
				if newId ~= "" then
					con:Disconnect()
					trackAnimation(anim)
				end
			end)
			return
		end
		
		if not animationMap[id] then
			local item = {
				Asset = id,
				Name = anim.Name ~= "" and anim.Name or "Animation",
				Path = inst_path(anim),
				Instance = anim,
				Time = os.date("%H:%M:%S")
			}
			animationMap[id] = item
			table.insert(animations, item)
			
			if window and window.GuiElems.Content.Visible then
				queue_rebuild()
			elseif status_label then
				status_label.Text = #animations .. " tracked"
			end
		else
			local item = animationMap[id]
			if anim.Parent then
				item.Path = inst_path(anim)
				item.Instance = anim
				if anim.Name ~= "" then
					item.Name = anim.Name
				end
			end
		end
	end

	local function setupHooks()
		-- 1. Scan game hierarchy asynchronously (using targeted services to avoid game:GetDescendants freeze)
		task.spawn(function()
			local services = {
				workspace,
				game:GetService("ReplicatedStorage"),
				game:GetService("StarterPack"),
				game:GetService("StarterGui"),
				game:GetService("ReplicatedFirst")
			}
			for _, service in ipairs(services) do
				local ok, descs = pcall(service.GetDescendants, service)
				if ok then
					for i, obj in ipairs(descs) do
						if obj:IsA("Animation") then
							trackAnimation(obj)
						end
						if i % 100 == 0 then
							task.wait()
						end
					end
				end
			end
			
			-- Nil instances scan
			if env_ref and env_ref.getnilinstances then
				local ok2, nils = pcall(env_ref.getnilinstances)
				if ok2 and typeof(nils) == "table" then
					for _, obj in pairs(nils) do
						if typeof(obj) == "Instance" and obj:IsA("Animation") then
							trackAnimation(obj)
						end
					end
				end
			end
		end)
		
		-- 2. Hook DescendantAdded
		pcall(function()
			game.DescendantAdded:Connect(function(desc)
				if desc:IsA("Animation") then
					trackAnimation(desc)
				end
			end)
		end)
		
		-- 3. Hook Animator.LoadAnimation / Humanoid.LoadAnimation directly
		local hook = env_ref and env_ref.hookfunction or hookfunction
		if hook then
			local origHumanoidLoad
			pcall(function()
				local testHumanoid = Instance.new("Humanoid")
				origHumanoidLoad = hook(testHumanoid.LoadAnimation, function(self, animation)
					if typeof(animation) == "Instance" and animation:IsA("Animation") then
						task.spawn(trackAnimation, animation)
					end
					return origHumanoidLoad(self, animation)
				end)
			end)
			
			local origAnimatorLoad
			pcall(function()
				local testAnimator = Instance.new("Animator")
				origAnimatorLoad = hook(testAnimator.LoadAnimation, function(self, animation)
					if typeof(animation) == "Instance" and animation:IsA("Animation") then
						task.spawn(trackAnimation, animation)
					end
					return origAnimatorLoad(self, animation)
				end)
			end)
		end
	end

	plugin.Init = function()
		window = lib_ref.Window.new()
		window:SetTitle("Animation Tracker")
		window:Resize(720, 400)
		plugin.Window = window

		local toolbar = Instance.new("Frame")
		toolbar.BackgroundColor3 = settings_ref.Theme.Menu
		toolbar.BorderSizePixel  = 0
		toolbar.Size             = UDim2.new(1, 0, 0, 26)
		toolbar.Parent           = window.GuiElems.Content

		local clear_btn = Instance.new("TextButton")
		clear_btn.BorderSizePixel = 0
		clear_btn.Font = Enum.Font.SourceSans
		clear_btn.TextSize = 13
		clear_btn.Text = "Clear"
		clear_btn.AutoButtonColor = false
		clear_btn.Size = UDim2.new(0, 64, 0, 18)
		clear_btn.Position = UDim2.new(0, 4, 0, 4)
		clear_btn.Parent = toolbar
		if get_theme() then get_theme().StyleButton(clear_btn) end

		status_label = Instance.new("TextLabel")
		status_label.BackgroundTransparency = 1
		status_label.Font       = get_theme() and get_theme().MapFont(Enum.Font.SourceSans) or Enum.Font.SourceSans
		status_label.TextSize   = 12
		status_label.TextColor3 = settings_ref.Theme.PlaceholderText
		status_label.TextXAlignment = Enum.TextXAlignment.Right
		status_label.Size       = UDim2.new(1, -80, 1, 0)
		status_label.Position   = UDim2.new(0, 72, 0, 0)
		status_label.Text       = #animations .. " tracked"
		status_label.Parent     = toolbar

		local search_bar = Instance.new("Frame")
		search_bar.BackgroundColor3 = settings_ref.Theme.Main1
		search_bar.BorderSizePixel  = 0
		search_bar.Size             = UDim2.new(1, 0, 0, 26)
		search_bar.Position         = UDim2.new(0, 0, 0, 26)
		search_bar.Parent           = window.GuiElems.Content

		local search_box = Instance.new("TextBox", search_bar)
		search_box.BackgroundTransparency = 1
		search_box.PlaceholderText  = "Search animation name or ID..."
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
			queue_rebuild()
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

		list_container = Instance.new("Frame")
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
		empty_label.Text = "No tracked animations found"
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
		detail_lbl.Text = "Animation Details"

		path_box = Instance.new("TextBox", right_panel)
		path_box.BackgroundColor3 = settings_ref.Theme.Main1
		path_box.BorderSizePixel = 0
		path_box.Position = UDim2.new(0, 10, 0, 35)
		path_box.Size = UDim2.new(1, -20, 0, 80)
		path_box.Font = Enum.Font.Code
		path_box.TextSize = 11
		path_box.TextColor3 = settings_ref.Theme.Text
		path_box.TextEditable = false
		path_box.ClearTextOnFocus = false
		path_box.MultiLine = true
		path_box.TextWrapped = true
		path_box.Text = ""
		path_box.TextXAlignment = Enum.TextXAlignment.Left
		path_box.TextYAlignment = Enum.TextYAlignment.Top
		local pad = Instance.new("UIPadding", path_box)
		pad.PaddingLeft = UDim.new(0, 6)
		pad.PaddingRight = UDim.new(0, 6)
		pad.PaddingTop = UDim.new(0, 6)
		if get_theme() then get_theme().ApplyRounding(path_box, 4) end

		preview_btn = make_btn(right_panel, "Open in Animation Viewer", 125, 28, function()
			open_viewer(selected_item)
		end)
		
		copy_btn = make_btn(right_panel, "Copy Animation ID", 159, 28, function()
			if selected_item and env_ref and env_ref.setclipboard then
				env_ref.setclipboard(selected_item.Asset)
			end
		end)

		error_label = Instance.new("TextLabel", right_panel)
		error_label.BackgroundTransparency = 1
		error_label.Position = UDim2.new(0, 10, 0, 200)
		error_label.Size = UDim2.new(1, -20, 1, -210)
		error_label.Font = get_theme() and get_theme().MapFont(Enum.Font.SourceSans) or Enum.Font.SourceSans
		error_label.TextSize = 12
		error_label.TextColor3 = Color3.fromRGB(239, 68, 68)
		error_label.TextWrapped = true
		error_label.TextXAlignment = Enum.TextXAlignment.Left
		error_label.TextYAlignment = Enum.TextYAlignment.Top
		error_label.Text = ""

		clear_btn.MouseButton1Click:Connect(function()
			table.clear(animations)
			table.clear(animationMap)
			queue_rebuild()
			show_details(nil)
		end)

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

	setupHooks()

	return plugin
end

return {
	InitDeps      = initDeps,
	InitAfterMain = initAfterMain,
	Main          = main,
	PluginData    = plugin_data,
}
