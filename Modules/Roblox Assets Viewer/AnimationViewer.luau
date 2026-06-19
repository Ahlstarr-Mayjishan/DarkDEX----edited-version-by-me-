--!strict
--[[
	Animation Viewer App Module
	Previews animation assets inside a ViewportFrame using a WorldModel and Dummy rig.
]]
local Main,Lib,Apps,Settings
local Explorer, AnimationViewer
local API,RMD,env,service,plr,create,createSimple

local function initDeps(data)
	Main, Lib, Apps, Settings = data.Main, data.Lib, data.Apps, data.Settings
	API, RMD, env, service, plr = data.API, data.RMD, data.env, data.service, data.plr
	create, createSimple = data.create, data.createSimple
end

local function initAfterMain()
	Explorer = Apps.Explorer
	AnimationViewer = Apps.AnimationViewer
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
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")

	local AnimationViewer = {
		EnableInputCamera = true,
		IsViewing = false,
		ZoomMultiplier = 2,
		AutoRotate = false,
		RotationSpeed = 0.01,
	}

	local window, viewportFrame, worldModel, playBtn, loopedCb, speedInput, timelineBar, timelineProgress, timeLabel, charModeBtn
	local animTitle, animIdLabel, animPathLabel, listFrame
	local currentItems = {}
	local selectedItem = nil
	local dummyModel = nil
	local activeTrack = nil
	local animatorInstance = nil
	local activeAnimMode = "Grey" -- "Grey" or "Player"
	local camera = nil
	local isPlaying = false
	local updateConnection = nil
	local cameraConnection = nil

	-- Camera variables
	local rotationX, rotationY = -10, 0
	local distance = 9
	local dragging = false
	local hovering = false
	local lastpos = Vector2.zero

	local function clearRows()
		if not listFrame then return end
		for _, child in pairs(listFrame:GetChildren()) do
			if child:IsA("GuiButton") or child:IsA("TextLabel") then child:Destroy() end
		end
	end

	local function createGreyDummy()
		if not plr.Character then return nil end
		plr.Character.Archivable = true
		local charClone = plr.Character:Clone()
		if not charClone then return nil end

		-- Remove accessories, clothes, face, packages styling and make it plain grey
		for _, child in ipairs(charClone:GetDescendants()) do
			if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") or child:IsA("BodyColors") or child:IsA("CharacterMesh") or child:IsA("Decal") then
				child:Destroy()
			elseif child:IsA("BasePart") then
				child.Color = Color3.fromRGB(160, 160, 160)
				child.Material = Enum.Material.SmoothPlastic
				child.Transparency = 0
			end
		end

		local humanoid = charClone:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end

		return charClone
	end

	local function createPlayerDummy()
		if not plr.Character then return nil end
		plr.Character.Archivable = true
		local charClone = plr.Character:Clone()
		local humanoid = charClone and charClone:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		return charClone
	end

	local function stopAnimation()
		if activeTrack then
			pcall(function()
				activeTrack:Stop()
			end)
		end
		isPlaying = false
		if playBtn then playBtn.Text = "Play" end
	end

	local function updatePlayback()
		if not activeTrack or not timelineProgress or not timeLabel then return end
		local ok, pos, duration = pcall(function()
			return activeTrack.TimePosition, activeTrack.Length
		end)
		if not ok or not pos or not duration then
			activeTrack = nil
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
	end

	local function startAnimation()
		if not activeTrack then return end
		pcall(function()
			activeTrack:Play()
		end)
		isPlaying = true
		if playBtn then playBtn.Text = "Pause" end
	end

	local function togglePlay()
		if not activeTrack then return end
		if isPlaying then
			pcall(function()
				activeTrack:AdjustSpeed(0)
			end)
			isPlaying = false
			if playBtn then playBtn.Text = "Resume" end
		else
			pcall(function()
				activeTrack:AdjustSpeed(tonumber(speedInput.Text) or 1)
			end)
			startAnimation()
		end
	end

	local function loadRigAndTrack()
		stopAnimation()
		if dummyModel then
			dummyModel:Destroy()
			dummyModel = nil
		end
		activeTrack = nil
		animatorInstance = nil

		if not selectedItem or not worldModel then return end

		-- Build character dummy based on mode
		if activeAnimMode == "Grey" then
			dummyModel = createGreyDummy()
		else
			dummyModel = createPlayerDummy()
		end

		if not dummyModel then
			animIdLabel.Text = "Failed to load character preview rig"
			return
		end

		dummyModel.Parent = worldModel
		
		-- Position Dummy at center
		local primary = dummyModel.PrimaryPart or dummyModel:FindFirstChild("HumanoidRootPart") or dummyModel:FindFirstChild("Torso")
		if primary then
			dummyModel:SetPrimaryPartCFrame(CFrame.new(0, 0, 0))
		end

		-- Setup Animation
		local humanoid = dummyModel:FindFirstChildOfClass("Humanoid")
		if humanoid then
			animatorInstance = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
		end

		if animatorInstance then
			local ok, track = pcall(function()
				local anim = Instance.new("Animation")
				anim.AnimationId = selectedItem.Asset
				local tr = animatorInstance:LoadAnimation(anim)
				tr.Looped = loopedCb and loopedCb.Toggled or false
				return tr
			end)
			if ok and track then
				activeTrack = track
				startAnimation()
			else
				animIdLabel.Text = "Failed to load animation track: " .. tostring(track)
			end
		end
	end

	local function toggleCharMode()
		if activeAnimMode == "Grey" then
			activeAnimMode = "Player"
			if charModeBtn then charModeBtn.Text = "Mode: Player avatar" end
		else
			activeAnimMode = "Grey"
			if charModeBtn then charModeBtn.Text = "Mode: Grey dummy" end
		end
		loadRigAndTrack()
	end

	local function setPreview(item)
		selectedItem = item
		if not animTitle or not animIdLabel or not animPathLabel then return end

		if not item then
			animTitle.Text = "No animation selected"
			animIdLabel.Text = "Select an Animation object to preview."
			animPathLabel.Text = ""
			if timelineProgress then timelineProgress.Size = UDim2.new(0,0,1,0) end
			if timeLabel then timeLabel.Text = "0.0 / 0.0 s" end
			stopAnimation()
			if dummyModel then dummyModel:Destroy() dummyModel = nil end
			return
		end

		animTitle.Text = item.Object.Name
		animIdLabel.Text = item.Asset
		animPathLabel.Text = "path: " .. item.Path

		loadRigAndTrack()
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
		if obj:IsA("Animation") then
			local asset = normalizeAsset(obj.AnimationId)
			if asset ~= "" then
				results[#results + 1] = {Object = obj, Asset = asset, Path = getPath(obj)}
			end
		end
	end

	local function collectAnimations(root)
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

	AnimationViewer.ShowForObject = function(obj)
		if typeof(obj) ~= "Instance" then return end
		currentItems = collectAnimations(obj)
		clearRows()
		window:SetTitle("Animation Viewer - " .. obj.Name)
		for _, item in ipairs(currentItems) do addRow(item) end
		if #currentItems == 0 then
			local label = createSimple("TextLabel",{
				BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Size = UDim2.new(1,-8,0,24),
				Text = "No animation assets found in selected object.", TextColor3 = Settings.Theme.PlaceholderText,
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

	AnimationViewer.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Animation Viewer")
		window:Resize(650,430)
		AnimationViewer.Window = window
		local content = window.GuiElems.Content

		-- Viewport Container Left
		local viewportPane = createSimple("Frame",{BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, Position=UDim2.new(0,0,0,0), Size=UDim2.new(0.48,0,1,0), Parent=content})

		viewportFrame = Instance.new("ViewportFrame")
		viewportFrame.BackgroundTransparency = 1
		viewportFrame.Position = UDim2.new(0,8,0,8)
		viewportFrame.Size = UDim2.new(1,-16,0,220)
		viewportFrame.Parent = viewportPane

		worldModel = Instance.new("WorldModel")
		worldModel.Parent = viewportFrame

		camera = Instance.new("Camera")
		camera.FieldOfView = 50
		camera.Parent = viewportFrame
		viewportFrame.CurrentCamera = camera

		-- Drag Camera logic
		viewportFrame.InputBegan:Connect(function(input)
			if not AnimationViewer.EnableInputCamera then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				lastpos = input.Position
			elseif input.KeyCode == Enum.KeyCode.LeftShift then
				AnimationViewer.ZoomMultiplier = 10
			end
		end)
		viewportFrame.MouseEnter:Connect(function() hovering = true end)
		viewportFrame.MouseLeave:Connect(function() hovering = false end)
		viewportFrame.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			elseif input.KeyCode == Enum.KeyCode.LeftShift then
				AnimationViewer.ZoomMultiplier = 2
			end
		end)
		viewportFrame.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				local delta = input.Position - lastpos
				lastpos = input.Position
				rotationY -= delta.X * 0.01
				rotationX -= delta.Y * 0.01
				rotationX = math.clamp(rotationX, -math.pi/2 + 0.1, math.pi/2 - 0.1)
			end
			if input.UserInputType == Enum.UserInputType.MouseWheel and hovering then
				distance = math.clamp(distance - (input.Position.Z * AnimationViewer.ZoomMultiplier), 2, 40)
			end
		end)

		-- (Camera RenderStepped connection managed dynamically below via window focus)

		-- Controls
		animTitle = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSansBold, Position=UDim2.new(0,8,0,234), Size=UDim2.new(1,-16,0,20), Text="No animation selected", TextColor3=Settings.Theme.Text, TextSize=14, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=viewportPane})
		animIdLabel = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,8,0,252), Size=UDim2.new(1,-16,0,18), Text="", TextColor3=Settings.Theme.PlaceholderText, TextSize=12, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=viewportPane})
		animPathLabel = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,8,0,268), Size=UDim2.new(1,-16,0,16), Text="", TextColor3=Settings.Theme.PlaceholderText, TextSize=11, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=viewportPane})

		-- Playback Timeline
		timelineBar = createSimple("TextButton",{
			AutoButtonColor = false, BackgroundColor3 = Settings.Theme.TextBox, BorderColor3 = Settings.Theme.Outline1,
			BorderSizePixel = 1, Position = UDim2.new(0,8,0,290), Size = UDim2.new(1,-16,0,12), Text = "", Parent = viewportPane
		})
		timelineProgress = createSimple("Frame",{
			BackgroundColor3 = Settings.Theme.Highlight, BorderSizePixel = 0, Size = UDim2.new(0,0,1,0), Parent = timelineBar
		})
		timeLabel = createSimple("TextLabel",{
			BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Position = UDim2.new(0,8,0,305), Size = UDim2.new(1,-16,0,16),
			Text = "0.0 / 0.0 s", TextColor3 = Settings.Theme.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Parent = viewportPane
		})

		-- Click/Seek Timeline logic
		timelineBar.MouseButton1Down:Connect(function()
			if not activeTrack or activeTrack.Length == 0 then return end
			local mouse = plr:GetMouse()
			local function seek()
				local absPos = timelineBar.AbsolutePosition
				local absSize = timelineBar.AbsoluteSize
				local pct = math.clamp((mouse.X - absPos.X) / absSize.X, 0, 1)
				activeTrack.TimePosition = pct * activeTrack.Length
				updatePlayback()
			end
			seek()
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

		playBtn = makeButton(viewportPane, "Play", UDim2.new(0,8,0,330), UDim2.new(0,70,0,24), togglePlay)
		charModeBtn = makeButton(viewportPane, "Mode: Grey dummy", UDim2.new(0,84,0,330), UDim2.new(0,120,0,24), toggleCharMode)

		-- Loop controls
		createSimple("TextLabel",{
			BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Position = UDim2.new(0,212,0,330), Size = UDim2.new(0,40,0,24),
			Text = "Loop:", TextColor3 = Settings.Theme.Text, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = viewportPane
		})
		loopedCb = Lib.Checkbox.new(0)
		loopedCb.Gui.Position = UDim2.new(0,246,0,334)
		loopedCb.Gui.Parent = viewportPane
		loopedCb.OnInput:Connect(function()
			if activeTrack then
				activeTrack.Looped = loopedCb.Toggled
			end
		end)

		-- Speed
		createSimple("TextLabel",{
			BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Position = UDim2.new(0,8,0,364), Size = UDim2.new(0,60,0,24),
			Text = "Speed:", TextColor3 = Settings.Theme.Text, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = viewportPane
		})
		speedInput = createSimple("TextBox",{
			BackgroundColor3 = Settings.Theme.TextBox, BorderColor3 = Settings.Theme.Outline3, Font = Enum.Font.SourceSans,
			Position = UDim2.new(0,60,0,364), Size = UDim2.new(0,40,0,24), Text = "1.0", TextColor3 = Settings.Theme.Text, TextSize = 14, Parent = viewportPane
		})
		speedInput:GetPropertyChangedSignal("Text"):Connect(function()
			local spd = tonumber(speedInput.Text)
			if spd and activeTrack then
				activeTrack:AdjustSpeed(math.clamp(spd, 0, 20))
			end
		end)

		makeButton(viewportPane, "Copy Animation ID", UDim2.new(0,110,0,364), UDim2.new(0,110,0,24), function()
			if selectedItem and env.setclipboard then env.setclipboard(selectedItem.Asset) end
		end)
		makeButton(viewportPane, "Copy Path", UDim2.new(0,226,0,364), UDim2.new(0,68,0,24), function()
			if selectedItem and env.setclipboard then env.setclipboard(selectedItem.Path) end
		end)

		-- Right side list
		listFrame = createSimple("ScrollingFrame",{Active=true, AutomaticCanvasSize=Enum.AutomaticSize.Y, BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, BottomImage="", CanvasSize=UDim2.new(0,0,0,0), Position=UDim2.new(0.48,1,0,0), ScrollBarImageColor3=Color3.fromRGB(70,70,70), ScrollBarThickness=10, Size=UDim2.new(0.52,-1,1,0), TopImage="", Parent=content})
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0,4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = listFrame
		local listPad = Instance.new("UIPadding")
		listPad.PaddingBottom, listPad.PaddingLeft, listPad.PaddingRight, listPad.PaddingTop = UDim.new(0,6), UDim.new(0,4), UDim.new(0,4), UDim.new(0,4)
		listPad.Parent = listFrame

		local function connectRenderLoops()
			if not updateConnection then
				updateConnection = RunService.RenderStepped:Connect(updatePlayback)
			end
			if not cameraConnection then
				cameraConnection = RunService.RenderStepped:Connect(function(dt)
					if camera and dummyModel and dummyModel.Parent then
						local ok, primary = pcall(function()
							return dummyModel.PrimaryPart or dummyModel:FindFirstChild("HumanoidRootPart") or dummyModel:FindFirstChild("Torso")
						end)
						if ok and primary then
							local center = primary.Position
							local offset = CFrame.new(0, 1.5, distance) -- offset camera height slightly
							local rotation = CFrame.Angles(0, rotationY, 0) * CFrame.Angles(rotationX, 0, 0)
							local camCF = CFrame.new(center) * rotation * offset
							camera.CFrame = CFrame.lookAt(camCF.Position, center + Vector3.new(0, 0.5, 0))
						end
					end
				end)
			end
		end

		local function disconnectRenderLoops()
			if updateConnection then
				updateConnection:Disconnect()
				updateConnection = nil
			end
			if cameraConnection then
				cameraConnection:Disconnect()
				cameraConnection = nil
			end
		end

		window.OnActivate:Connect(connectRenderLoops)
		window.OnDeactivate:Connect(function()
			stopAnimation()
			disconnectRenderLoops()
		end)

	end

	AnimationViewer.CleanUp = function()
		stopAnimation()
		if updateConnection then
			updateConnection:Disconnect()
			updateConnection = nil
		end
		if dummyModel then
			pcall(function() dummyModel:Destroy() end)
			dummyModel = nil
		end
	end

	return AnimationViewer
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
