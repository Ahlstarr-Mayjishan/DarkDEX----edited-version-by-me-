--!strict
--[[
	Sound Viewer App Module
	Previews sound assets from selected instances.
]]
local Main,Lib,Apps,Settings
local Explorer, SoundViewer
local API,RMD,env,service,plr,create,createSimple

local function initDeps(data)
	Main, Lib, Apps, Settings = data.Main, data.Lib, data.Apps, data.Settings
	API, RMD, env, service, plr = data.API, data.RMD, data.env, data.service, data.plr
	create, createSimple = data.create, data.createSimple
end

local function initAfterMain()
	Explorer = Apps.Explorer
	SoundViewer = Apps.SoundViewer
end

local function getPath(obj)
	if Main and Main.SafeGetInstancePath then return Main.SafeGetInstancePath(obj) end
	local ok, path = pcall(function()
		if Explorer and Explorer.GetInstancePath then return Explorer.GetInstancePath(obj) end
		return obj:GetFullName()
	end)
	return ok and tostring(path) or tostring(obj)
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
	local SoundViewer = {}
	local window, playBtn, stopBtn, loopedCb, volInput, pitchInput, timelineBar, timelineProgress, timeLabel
	local soundTitle, soundIdLabel, soundPathLabel, listFrame
	local currentItems = {}
	local selectedItem = nil
	local localSound = nil
	local isPlaying = false
	local updateConnection = nil

	local function clearRows()
		if not listFrame then return end
		for _, child in pairs(listFrame:GetChildren()) do
			if child:IsA("GuiButton") or child:IsA("TextLabel") then child:Destroy() end
		end
	end

	local function stopSound()
		if localSound then
			pcall(function()
				localSound:Stop()
			end)
		end
		isPlaying = false
		if playBtn then playBtn.Text = "Play" end
	end

	local function updatePlayback()
		if not localSound or not timelineProgress or not timeLabel then return end
		local ok, pos, duration, isL, isP = pcall(function()
			return localSound.TimePosition, localSound.TimeLength, localSound.Looped, localSound.IsPlaying
		end)
		if not ok or not pos or not duration then
			localSound = nil
			return
		end
		if duration > 0 then
			local pct = math.clamp(pos / duration, 0, 1)
			timelineProgress.Size = UDim2.new(pct, 0, 1, 0)
			timeLabel.Text = string.format("%.1f / %.1f s", pos, duration)
		else
			timelineProgress.Size = UDim2.new(0, 0, 1, 0)
			timeLabel.Text = string.format("%.1f / -- s", pos)
		end
		-- Check if naturally ended
		if not isP and isPlaying and not isL then
			stopSound()
		end
	end

	local function startSound()
		if not localSound then return end
		pcall(function()
			localSound:Play()
		end)
		isPlaying = true
		if playBtn then playBtn.Text = "Pause" end
	end

	local function togglePlay()
		if not localSound then return end
		if isPlaying then
			pcall(function()
				localSound:Pause()
			end)
			isPlaying = false
			if playBtn then playBtn.Text = "Resume" end
		else
			startSound()
		end
	end

	local function setPreview(item)
		stopSound()
		if localSound then
			pcall(function() localSound:Destroy() end)
			localSound = nil
		end
		selectedItem = item

		if not soundTitle or not soundIdLabel or not soundPathLabel then return end

		if not item then
			soundTitle.Text = "No sound selected"
			soundIdLabel.Text = "Select a Sound object to preview."
			soundPathLabel.Text = ""
			if timelineProgress then timelineProgress.Size = UDim2.new(0,0,1,0) end
			if timeLabel then timeLabel.Text = "0.0 / 0.0 s" end
			return
		end

		soundTitle.Text = item.Object.Name
		soundIdLabel.Text = item.Asset
		soundPathLabel.Text = "path: " .. item.Path

		-- Create local sound clone in SoundService
		local ok, clone = pcall(function()
			local s = Instance.new("Sound")
			s.SoundId = item.Asset
			s.Volume = tonumber(volInput and volInput.Text) or item.Object.Volume or 0.5
			s.PlaybackSpeed = tonumber(pitchInput and pitchInput.Text) or item.Object.PlaybackSpeed or 1
			s.Looped = loopedCb and loopedCb.Toggled or item.Object.Looped or false
			s.Parent = game:GetService("SoundService")
			return s
		end)

		if ok and clone then
			localSound = clone
			updatePlayback()
		else
			soundIdLabel.Text = "Failed to load sound: " .. tostring(clone)
		end
	end

	local function addRow(item)
		local row = createSimple("TextButton",{
			AutoButtonColor = false, BackgroundColor3 = Settings.Theme.Main2, BorderColor3 = Settings.Theme.Outline1,
			BorderSizePixel = 1, Font = Enum.Font.SourceSans, Size = UDim2.new(1,-8,0,42),
			Text = "", Parent = listFrame
		})
		createSimple("TextLabel",{
			BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Position = UDim2.new(0,8,0,2),
			Size = UDim2.new(1,-16,0,18), Text = item.Object.Name .. " [" .. item.Object.ClassName .. "]",
			TextColor3 = Settings.Theme.Text, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = row
		})
		createSimple("TextLabel",{
			BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Position = UDim2.new(0,8,0,21),
			Size = UDim2.new(1,-16,0,18), Text = item.Asset,
			TextColor3 = Settings.Theme.PlaceholderText, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = row
		})
		Lib.ButtonAnim(row,{Mode=2, StartColor=Settings.Theme.Main2, HoverColor=Settings.Theme.ButtonHover, PressColor=Settings.Theme.ButtonPress, OutlineColor=Settings.Theme.Outline1})
		row.MouseButton1Click:Connect(function()
			setPreview(item)
		end)
	end

	local function collectFrom(obj, results, limit)
		if obj:IsA("Sound") then
			local asset = normalizeAsset(obj.SoundId)
			if asset ~= "" then
				results[#results + 1] = {Object = obj, Asset = asset, Path = getPath(obj)}
			end
		end
	end

	local function collectSounds(root)
		local results = {}
		local limit = 160
		collectFrom(root, results, limit)
		if #results >= limit then return results end
		local descendants = nil
		local ok, list = pcall(function()
			if root == game then
				local list = {}
				for _, service in ipairs({workspace, game:GetService("ReplicatedStorage"), game:GetService("StarterPack")}) do
					local ok2, sList = pcall(service.GetDescendants, service)
					if ok2 then
						for _, d in ipairs(sList) do
							table.insert(list, d)
						end
					end
				end
				return list
			else
				return root:GetDescendants()
			end
		end)
		descendants = ok and list or {}
		local count = 0
		for _, obj in pairs(descendants) do
			count += 1
			collectFrom(obj, results, limit)
			if #results >= limit then break end
			if count % 200 == 0 then task.wait() end
		end
		return results
	end

	SoundViewer.ShowForObject = function(obj)
		if typeof(obj) ~= "Instance" then return end
		currentItems = collectSounds(obj)
		clearRows()
		window:SetTitle("Sound Viewer - " .. obj.Name)
		for _, item in ipairs(currentItems) do addRow(item) end
		if #currentItems == 0 then
			local label = createSimple("TextLabel",{
				BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Size = UDim2.new(1,-8,0,24),
				Text = "No sound assets found in selected object.", TextColor3 = Settings.Theme.PlaceholderText,
				TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = listFrame
			})
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0,6)
			pad.Parent = label
			setPreview(nil)
		else
			setPreview(currentItems[1])
		end
		window:Show()
	end

	local function makeButton(parent, text, pos, size, callback)
		local button = createSimple("TextButton",{
			AutoButtonColor = false, BackgroundColor3 = Settings.Theme.Button, BorderColor3 = Settings.Theme.Outline2,
			Font = Enum.Font.SourceSans, Position = pos, Size = size, Text = text,
			TextColor3 = Settings.Theme.Text, TextSize = 14, Parent = parent
		})
		button.MouseButton1Click:Connect(callback)
		Lib.ButtonAnim(button,{Mode=2, StartColor=Settings.Theme.Button, HoverColor=Settings.Theme.ButtonHover, PressColor=Settings.Theme.ButtonPress, OutlineColor=Settings.Theme.Outline2})
		return button
	end

	SoundViewer.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Sound Viewer")
		window:Resize(620,380)
		SoundViewer.Window = window
		local content = window.GuiElems.Content

		local previewPane = createSimple("Frame",{BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, Position=UDim2.new(0,0,0,0), Size=UDim2.new(0.48,0,1,0), Parent=content})

		soundTitle = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSansBold, Position=UDim2.new(0,8,0,8), Size=UDim2.new(1,-16,0,22), Text="No sound selected", TextColor3=Settings.Theme.Text, TextSize=15, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=previewPane})
		soundIdLabel = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,8,0,32), Size=UDim2.new(1,-16,0,20), Text="", TextColor3=Settings.Theme.PlaceholderText, TextSize=13, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=previewPane})
		soundPathLabel = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,8,0,54), Size=UDim2.new(1,-16,0,18), Text="", TextColor3=Settings.Theme.PlaceholderText, TextSize=11, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=previewPane})

		-- Playback Control UI
		-- Clickable Timeline Bar
		timelineBar = createSimple("TextButton",{
			AutoButtonColor = false, BackgroundColor3 = Settings.Theme.TextBox, BorderColor3 = Settings.Theme.Outline1,
			BorderSizePixel = 1, Position = UDim2.new(0,8,0,90), Size = UDim2.new(1,-16,0,14), Text = "", Parent = previewPane
		})
		timelineProgress = createSimple("Frame",{
			BackgroundColor3 = Settings.Theme.Highlight, BorderSizePixel = 0, Size = UDim2.new(0,0,1,0), Parent = timelineBar
		})
		timeLabel = createSimple("TextLabel",{
			BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Position = UDim2.new(0,8,0,110), Size = UDim2.new(1,-16,0,18),
			Text = "0.0 / 0.0 s", TextColor3 = Settings.Theme.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Parent = previewPane
		})

		-- Click to Seek Timeline logic
		timelineBar.MouseButton1Down:Connect(function()
			if not localSound or localSound.TimeLength == 0 then return end
			local mouse = plr:GetMouse()
			local function seek()
				local absPos = timelineBar.AbsolutePosition
				local absSize = timelineBar.AbsoluteSize
				local pct = math.clamp((mouse.X - absPos.X) / absSize.X, 0, 1)
				localSound.TimePosition = pct * localSound.TimeLength
				updatePlayback()
			end
			seek()
			-- Allow scrubbing while holding mouse
			local moveCon
			moveCon = mouse.Move:Connect(seek)
			local releaseCon
			releaseCon = game:GetService("UserInputService").InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					moveCon:Disconnect()
					releaseCon:Disconnect()
				end
			end)
		end)

		playBtn = makeButton(previewPane, "Play", UDim2.new(0,8,0,140), UDim2.new(0,70,0,24), togglePlay)
		stopBtn = makeButton(previewPane, "Stop", UDim2.new(0,84,0,140), UDim2.new(0,60,0,24), stopSound)

		-- Loop controls
		createSimple("TextLabel",{
			BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Position = UDim2.new(0,160,0,140), Size = UDim2.new(0,40,0,24),
			Text = "Loop:", TextColor3 = Settings.Theme.Text, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = previewPane
		})
		loopedCb = Lib.Checkbox.new(0)
		loopedCb.Gui.Position = UDim2.new(0,198,0,144)
		loopedCb.Gui.Parent = previewPane
		loopedCb.OnInput:Connect(function()
			if localSound then
				localSound.Looped = loopedCb.Toggled
			end
		end)

		-- Volume
		createSimple("TextLabel",{
			BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Position = UDim2.new(0,8,0,180), Size = UDim2.new(0,60,0,24),
			Text = "Volume:", TextColor3 = Settings.Theme.Text, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = previewPane
		})
		volInput = createSimple("TextBox",{
			BackgroundColor3 = Settings.Theme.TextBox, BorderColor3 = Settings.Theme.Outline3, Font = Enum.Font.SourceSans,
			Position = UDim2.new(0,70,0,180), Size = UDim2.new(0,50,0,24), Text = "0.5", TextColor3 = Settings.Theme.Text, TextSize = 14, Parent = previewPane
		})
		volInput:GetPropertyChangedSignal("Text"):Connect(function()
			local vol = tonumber(volInput.Text)
			if vol and localSound then
				localSound.Volume = math.clamp(vol, 0, 10)
			end
		end)

		-- Pitch / Speed
		createSimple("TextLabel",{
			BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Position = UDim2.new(0,135,0,180), Size = UDim2.new(0,50,0,24),
			Text = "Speed:", TextColor3 = Settings.Theme.Text, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = previewPane
		})
		pitchInput = createSimple("TextBox",{
			BackgroundColor3 = Settings.Theme.TextBox, BorderColor3 = Settings.Theme.Outline3, Font = Enum.Font.SourceSans,
			Position = UDim2.new(0,185,0,180), Size = UDim2.new(0,50,0,24), Text = "1.0", TextColor3 = Settings.Theme.Text, TextSize = 14, Parent = previewPane
		})
		pitchInput:GetPropertyChangedSignal("Text"):Connect(function()
			local spd = tonumber(pitchInput.Text)
			if spd and localSound then
				localSound.PlaybackSpeed = math.clamp(spd, 0, 20)
			end
		end)

		-- Action Buttons at bottom
		makeButton(previewPane, "Copy Sound ID", UDim2.new(0,8,1,-32), UDim2.new(0,100,0,24), function()
			if selectedItem and env.setclipboard then env.setclipboard(selectedItem.Asset) end
		end)
		makeButton(previewPane, "Copy Path", UDim2.new(0,114,1,-32), UDim2.new(0,86,0,24), function()
			if selectedItem and env.setclipboard then env.setclipboard(selectedItem.Path) end
		end)

		listFrame = createSimple("ScrollingFrame",{Active=true, AutomaticCanvasSize=Enum.AutomaticSize.Y, BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, BottomImage="", CanvasSize=UDim2.new(0,0,0,0), Position=UDim2.new(0.48,1,0,0), ScrollBarImageColor3=Color3.fromRGB(70,70,70), ScrollBarThickness=10, Size=UDim2.new(0.52,-1,1,0), TopImage="", Parent=content})
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0,4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = listFrame
		local listPad = Instance.new("UIPadding")
		listPad.PaddingBottom, listPad.PaddingLeft, listPad.PaddingRight, listPad.PaddingTop = UDim.new(0,6), UDim.new(0,4), UDim.new(0,4), UDim.new(0,4)
		listPad.Parent = listFrame

		local function connectPlaybackLoop()
			if not updateConnection then
				updateConnection = game:GetService("RunService").RenderStepped:Connect(updatePlayback)
			end
		end

		local function disconnectPlaybackLoop()
			if updateConnection then
				updateConnection:Disconnect()
				updateConnection = nil
			end
		end

		window.OnActivate:Connect(connectPlaybackLoop)
		window.OnDeactivate:Connect(function()
			stopSound()
			disconnectPlaybackLoop()
		end)
	end

	SoundViewer.CleanUp = function()
		stopSound()
		if updateConnection then
			updateConnection:Disconnect()
			updateConnection = nil
		end
		if localSound then
			pcall(function() localSound:Destroy() end)
			localSound = nil
		end
	end

	return SoundViewer
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
