--!nocheck

local main_ref, lib_ref, apps_ref, settings_ref, env_ref, theme_ref

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

local function locateInstanceByPath(path)
	local parts = {}
	for part in path:gmatch("[^%.]+") do
		table.insert(parts, part)
	end
	if parts[1] ~= "game" then return nil end

	local current = game
	for i = 2, #parts do
		local name = parts[i]
		local nextObj = current:FindFirstChild(name)
		if not nextObj then
			return nil
		end
		current = nextObj
	end
	return current
end

local function getRequestFunc()
	return env_func("request") or (syn and syn.request) or (http and http.request) or http_request or request
end

local function postToHelper(endpoint, body)
	local req = getRequestFunc()
	if not req then return false, "Request API not available" end
	local success, res = pcall(req, {
		Url = "http://localhost:8080" .. endpoint,
		Method = "POST",
		Headers = { ["Content-Type"] = "text/plain" },
		Body = body
	})
	if success and res and res.StatusCode == 200 then
		return true, res.Body
	end
	return false, res and tostring(res.StatusCode) or tostring(res)
end

local syncActive = false
local lastPollTimestamp = 0

local function startSync(status_callback)
	if syncActive then return end
	syncActive = true
	lastPollTimestamp = 0
	
	task.spawn(function()
		local service = game:GetService("HttpService")
		while syncActive do
			local success, body = postToHelper("/sync-poll", tostring(lastPollTimestamp))
			if success and body then
				local ok, data = pcall(service.JSONDecode, service, body)
				if ok and data and data.ok then
					lastPollTimestamp = data.timestamp or lastPollTimestamp
					local count = 0
					for _, file in ipairs(data.files or {}) do
						local scriptObj = locateInstanceByPath(file.path)
						if scriptObj and (scriptObj.ClassName == "LocalScript" or scriptObj.ClassName == "ModuleScript" or scriptObj.ClassName == "Script") then
							scriptObj.Source = file.source
							count = count + 1
						end
					end
					if count > 0 and status_callback then
						status_callback("Synced " .. tostring(count) .. " script(s) from IDE.")
					end
				end
			end
			task.wait(1)
		end
	end)
end

local function stopSync()
	syncActive = false
end

local function exportScript(scriptObj, status_callback)
	local path = scriptObj:GetFullName()
	local source = ""
	local decompile_fn = env_func("decompile")
	if decompile_fn then
		local ok, err = pcall(function()
			source = decompile_fn(scriptObj)
		end)
		if not ok then
			source = "-- Decompile failed: " .. tostring(err)
		end
	else
		source = scriptObj.Source or "-- Source reading failed: executor does not support decompile or script.Source read"
	end
	
	local success, err = postToHelper("/sync-to-disk", path .. "\n" .. source)
	if success then
		if status_callback then
			status_callback("Exported " .. scriptObj.Name)
		end
	else
		if status_callback then
			status_callback("Failed to export " .. scriptObj.Name .. ": " .. tostring(err))
		end
	end
end

local function exportWorkspace(targets, status_callback)
	task.spawn(function()
		local scripts = {}
		for _, target in ipairs(targets) do
			if target:IsA("LuaSourceContainer") then
				table.insert(scripts, target)
			end
			for _, desc in ipairs(target:GetDescendants()) do
				if desc:IsA("LuaSourceContainer") then
					table.insert(scripts, desc)
				end
			end
		end
		
		if #scripts == 0 then
			if status_callback then
				status_callback("No scripts found in selection.")
			end
			return
		end
		
		if status_callback then
			status_callback("Exporting " .. tostring(#scripts) .. " script(s) to workspace_sync/...")
		end
		
		for i, scr in ipairs(scripts) do
			exportScript(scr, status_callback)
			if i % 10 == 0 then
				task.wait(0.1) -- yield to avoid freezing Roblox during bulk export
			end
		end
		
		if status_callback then
			status_callback("Workspace export completed.")
		end
	end)
end

local function main()
	local IDESync = {}
	local window, statusLabel, startBtn, stopBtn, exportBtn

	local function theme()
		return settings_ref.Theme
	end

	local function setStatus(text)
		if statusLabel then
			statusLabel.Text = tostring(text)
		end
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

	local function updateButtons()
		if syncActive then
			startBtn.Visible = false
			stopBtn.Visible = true
			setStatus("Live Sync is ACTIVE (IDE -> Roblox)")
		else
			startBtn.Visible = true
			stopBtn.Visible = false
			setStatus("Ready. Live Sync is INACTIVE.")
		end
	end

	IDESync.StartSync = function()
		startSync(setStatus)
		updateButtons()
	end

	IDESync.StopSync = function()
		stopSync()
		updateButtons()
	end

	IDESync.ExportWorkspace = function()
		local explorer = apps_ref and apps_ref.Explorer
		local selection = explorer and explorer.Selection
		local targets = selection and selection:GetSelected()
		if not targets or #targets == 0 then
			setStatus("Error: Select target instances in Explorer first.")
			return
		end
		
		-- extract standard objects from Explorer nodes
		local list = {}
		for _, node in ipairs(targets) do
			if typeof(node) == "table" and node.Obj then
				table.insert(list, node.Obj)
			elseif typeof(node) == "Instance" then
				table.insert(list, node)
			end
		end

		exportWorkspace(list, setStatus)
	end

	IDESync.IsSyncActive = function()
		return syncActive
	end

	IDESync.Init = function()
		window = lib_ref.Window.new()
		window:SetTitle("IDE Sync")
		window:Resize(320, 200)
		IDESync.Window = window

		local content = window.GuiElems.Content
		local t = theme()

		local title = label(content, "IDE / Workspace Synchronizer", UDim2.new(0, 12, 0, 10), UDim2.new(1, -24, 0, 20), t.Text, true)
		local desc = label(content, "Sync Roblox scripts to/from local workspace_sync/ folder via C++ Helper on port 8080.", UDim2.new(0, 12, 0, 30), UDim2.new(1, -24, 0, 36), t.PlaceholderText, false)
		desc.TextSize = 11

		startBtn = button(content, "Start Live Sync", UDim2.new(0, 12, 0, 78), UDim2.new(1, -24, 0, 28), function()
			IDESync.StartSync()
		end)

		stopBtn = button(content, "Stop Live Sync", UDim2.new(0, 12, 0, 78), UDim2.new(1, -24, 0, 28), function()
			IDESync.StopSync()
		end)
		stopBtn.Visible = false

		exportBtn = button(content, "Export Selection to Disk", UDim2.new(0, 12, 0, 114), UDim2.new(1, -24, 0, 28), function()
			IDESync.ExportWorkspace()
		end)

		local footer = Instance.new("Frame")
		footer.BackgroundColor3 = t.Menu
		footer.BorderSizePixel = 0
		footer.Position = UDim2.new(0, 0, 1, -32)
		footer.Size = UDim2.new(1, 0, 0, 32)
		footer.Parent = content

		statusLabel = label(footer, "Ready. Select scripts in Explorer and export them.", UDim2.new(0, 10, 0, 7), UDim2.new(1, -20, 0, 18), t.PlaceholderText, false)

		updateButtons()
	end

	return IDESync
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
