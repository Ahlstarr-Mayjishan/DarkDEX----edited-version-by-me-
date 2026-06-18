local main_ref, lib_ref, apps_ref, settings_ref

local plugin_data = {
	Name = "TaskRouterLab",
	FriendlyName = "Task Router Lab",
}

local function initDeps(data)
	main_ref = data.Main
	lib_ref = data.Lib
	apps_ref = data.Apps
	settings_ref = data.Settings
end

local function initAfterMain(_) end

local function main()
	local plugin = {}
	plugin.PluginData = plugin_data

	local window
	local input_box
	local output_label
	local status_label

	local function setText(label, text)
		if label then
			label.Text = text
		end
	end

	local function routeTask()
		local task_text = tostring(input_box and input_box.Text or "")
		if task_text == "" then
			setText(status_label, "Type a task first.")
			setText(output_label, "")
			return
		end

		local router = apps_ref and apps_ref.TaskRouter
		if not router or not router.RouteTask then
			setText(status_label, "Core Task Router is unavailable.")
			setText(output_label, "Load the core Task Router module first.")
			return
		end

		local ok, decision, source_kind = pcall(router.RouteTask, task_text)
		if not ok or not decision or not decision.primary then
			setText(status_label, "Routing failed.")
			setText(output_label, tostring(decision))
			return
		end

		local primary = decision.primary
		local secondary = decision.secondary or {}
		setText(status_label, "Routed via " .. tostring(source_kind or "local") .. ".")
		setText(output_label, table.concat({
			"Primary: " .. tostring(primary.label or "Unknown") .. " [" .. tostring(primary.language or "Unknown") .. "]",
			"Module: " .. tostring(primary.module or "Unknown"),
			"Confidence: " .. tostring(primary.confidence or 0) .. "%",
			"Why: " .. tostring(primary.summary or ""),
			"Fallback: " .. tostring(secondary.label or "Unknown") .. " [" .. tostring(secondary.language or "Unknown") .. "]",
		}, "\n"))
	end

	function plugin.Init()
		window = lib_ref.Window.new()
		window:SetTitle("Task Router Lab")
		window:Resize(480, 230)
		plugin.Window = window

		local content = window.GuiElems.Content
		local theme = settings_ref.Theme

		input_box = Instance.new("TextBox")
		input_box.BackgroundColor3 = theme.TextBox
		input_box.BorderColor3 = theme.Outline3
		input_box.ClearTextOnFocus = false
		input_box.Font = Enum.Font.SourceSans
		input_box.PlaceholderColor3 = theme.PlaceholderText
		input_box.PlaceholderText = "Describe a task to route..."
		input_box.Position = UDim2.new(0, 8, 0, 8)
		input_box.Size = UDim2.new(1, -94, 0, 24)
		input_box.Text = ""
		input_box.TextColor3 = theme.Text
		input_box.TextSize = 14
		input_box.TextXAlignment = Enum.TextXAlignment.Left
		input_box.Parent = content

		local route_button = Instance.new("TextButton")
		route_button.BackgroundColor3 = theme.Button
		route_button.BorderColor3 = theme.Outline2
		route_button.Font = Enum.Font.SourceSans
		route_button.Position = UDim2.new(1, -78, 0, 8)
		route_button.Size = UDim2.new(0, 70, 0, 24)
		route_button.Text = "Route"
		route_button.TextColor3 = theme.Text
		route_button.TextSize = 14
		route_button.Parent = content

		status_label = Instance.new("TextLabel")
		status_label.BackgroundTransparency = 1
		status_label.Font = Enum.Font.SourceSans
		status_label.Position = UDim2.new(0, 8, 0, 38)
		status_label.Size = UDim2.new(1, -16, 0, 20)
		status_label.Text = "Plugin sandbox for routing experiments."
		status_label.TextColor3 = theme.PlaceholderText
		status_label.TextSize = 14
		status_label.TextXAlignment = Enum.TextXAlignment.Left
		status_label.Parent = content

		output_label = Instance.new("TextLabel")
		output_label.BackgroundColor3 = theme.Main2
		output_label.BorderColor3 = theme.Outline1
		output_label.Font = Enum.Font.SourceSans
		output_label.Position = UDim2.new(0, 8, 0, 66)
		output_label.Size = UDim2.new(1, -16, 1, -74)
		output_label.Text = ""
		output_label.TextColor3 = theme.Text
		output_label.TextSize = 14
		output_label.TextWrapped = true
		output_label.TextXAlignment = Enum.TextXAlignment.Left
		output_label.TextYAlignment = Enum.TextYAlignment.Top
		output_label.Parent = content

		route_button.MouseButton1Click:Connect(routeTask)
		input_box.FocusLost:Connect(function(enter_pressed)
			if enter_pressed then
				routeTask()
			end
		end)
	end

	return plugin
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main,
	PluginData = plugin_data,
}
