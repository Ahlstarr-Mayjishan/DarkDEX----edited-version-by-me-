--[[
	Save Instance App Module
--[[
	Save Instance App Module
	
	Revival of the old dex's Save Instance
]] 

-- Common Locals
local Main,Lib,Apps,Settings -- Main Containers
local Explorer, Properties, Notepad, SettingsWindow, Notebook -- Major Apps
local API,RMD,env,service,plr,create,createSimple -- Main Locals

local function initDeps(data)
	Main = data.Main
	Lib = data.Lib
	Apps = data.Apps
	Settings = data.Settings

	API = data.API
	RMD = data.RMD
	env = data.env
	service = data.service
	plr = data.plr
	create = data.create
	createSimple = data.createSimple
end

local function initAfterMain()
	Explorer = Apps.Explorer
	Properties = Apps.Properties
	Notepad = Apps.Notepad
	SettingsWindow = Apps.SettingsWindow
	Notebook = Apps.Notebook
end

local function main()
	local SettingsWindow = {}
	local window, ListFrame
	local fileName = "Place_"..game.PlaceId.."_"..game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name.."_{TIMESTAMP}"
	local Saving = false
	
	local function AddCheckbox(title, default)
		local frame = Lib.Frame.new()
		frame.Gui.Parent = ListFrame
		frame.Gui.Transparency = 1
		frame.Gui.Size = UDim2.new(1,0,0,20)
		
		local listlayout = Instance.new("UIListLayout")
		listlayout.Parent = frame.Gui
		listlayout.FillDirection = Enum.FillDirection.Horizontal
		listlayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		listlayout.VerticalAlignment = Enum.VerticalAlignment.Center
		listlayout.Padding = UDim.new(0, 10)
		
		-- Checkbox
		local checkbox = Lib.Checkbox.new()
		
		checkbox.Gui.Parent = frame.Gui
		checkbox.Gui.Size = UDim2.new(0,15,0,15)
		
		-- Label
		local label = Lib.Label.new()
		
		label.Gui.Parent = frame.Gui
		label.Gui.Size = UDim2.new(1, 0,1, -15)
		label.Gui.Text = title
		label.TextTruncate = Enum.TextTruncate.AtEnd
		
		checkbox:SetState(default or false)
		
		return checkbox
	end
	
	local function AddTextbox(title, default, sizeX)
		default = default and tostring(default) or ""
		local frame = Lib.Frame.new()
		frame.Gui.Parent = ListFrame
		frame.Gui.Transparency = 1
		frame.Gui.Size = UDim2.new(1,0,0,20)

		local listlayout = Instance.new("UIListLayout")
		listlayout.Parent = frame.Gui
		listlayout.FillDirection = Enum.FillDirection.Horizontal
		listlayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		listlayout.VerticalAlignment = Enum.VerticalAlignment.Center
		listlayout.Padding = UDim.new(0, 10)

		-- Textbox
		local textbox = Instance.new("TextBox") -- replaced cuz why Moon make every inputs only work on mouse/pc users >:( 
		textbox.BackgroundColor3 = Settings.Theme.TextBox
		textbox.BorderColor3 = Settings.Theme.Outline3
		textbox.ClearTextOnFocus = false
		textbox.TextColor3 = Settings.Theme.Text
		textbox.Font = Enum.Font.SourceSans
		textbox.TextSize = 14
		textbox.ZIndex = 2

		textbox.Parent = frame.Gui
		if sizeX and type(sizeX) == "number" then
			textbox.Size = UDim2.new(0,sizeX,0,15)
		else
			textbox.Size = UDim2.new(0,45,0,15)
		end
		
		frame.Gui.AutomaticSize = Enum.AutomaticSize.X
		textbox.AutomaticSize = Enum.AutomaticSize.X

		-- Label
		local label = Lib.Label.new()

		label.Parent = frame.Gui
		label.Size = UDim2.new(1, 0,1, -15)
		label.Text = title
		label.TextTruncate = Enum.TextTruncate.AtEnd

		textbox.Text = default

		return textbox
	end
	
	local function AddDropdown(title, options, default, allowEmpty, sizeX)
		if allowEmpty == nil then allowEmpty = true end
		
		local frame = Lib.Frame.new()
		frame.Gui.Parent = ListFrame
		frame.Gui.Transparency = 1
		frame.Gui.Size = UDim2.new(1,0,0,20)

		local listlayout = Instance.new("UIListLayout")
		listlayout.Parent = frame.Gui
		listlayout.FillDirection = Enum.FillDirection.Horizontal
		listlayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		listlayout.VerticalAlignment = Enum.VerticalAlignment.Center
		listlayout.Padding = UDim.new(0, 10)

		-- Textbox
		local dropdown = Lib.DropDown.new()
		dropdown.CanBeEmpty = allowEmpty
		dropdown.Size = UDim2.new(0,sizeX or 75,0,15)
		dropdown:SetOptions(options)
		if default then dropdown:SetSelected(default) end
		dropdown.Gui.Parent = frame.Gui

		frame.Gui.AutomaticSize = Enum.AutomaticSize.X

		-- Label
		local label = Lib.Label.new()

		label.Parent = frame.Gui
		label.Size = UDim2.new(1, 0,1, -15)
		label.Text = title
		label.TextTruncate = Enum.TextTruncate.AtEnd
		
		return dropdown
	end
	
	local function AddSeperator(title)

		local frame = Lib.Frame.new()
		frame.Gui.Parent = ListFrame
		frame.Gui.Transparency = 1
		frame.Gui.Size = UDim2.new(1,0,0,20)
		
		-- Label
		local label = Lib.Label.new()

		label.Parent = frame.Gui
		--label.AnchorPoint = Vector2.new(0,1)
		--label.Position = UDim2.new(0,0,0,0)
		label.Size = UDim2.new(1, 0,1, 0)
		label.Text = title
		label.TextSize = 16
		label.TextTruncate = Enum.TextTruncate.AtEnd

		return label
	end
	
	local function AddText(text)
		local frame = Lib.Frame.new()
		frame.Gui.Parent = ListFrame
		frame.Gui.Transparency = 1
		frame.Gui.Size = UDim2.new(1,0,0,15)

		-- Label
		local label = Lib.Label.new()

		label.Parent = frame.Gui
		--label.AnchorPoint = Vector2.new(0,1)
		--label.Position = UDim2.new(0,0,0,0)
		label.Size = UDim2.new(1, 0,1, 0)
		label.TextColor3 = Color3.fromRGB(185,185,185)
		label.Text = text
		label.TextSize = 14
		label.TextTruncate = Enum.TextTruncate.AtEnd

		return label
	end
	
	SettingsWindow.ReloadPrompt = function()		
		local win = Notepad.ReloadPromptWindow
		if not win then
			win = Lib.Window.new()
			win.Alignable = false
			win.Resizable = false
			win:SetTitle("Apply Current Settings")
			win:SetSize(300,115)

			local reloadButton = Lib.Button.new()
			local nameLabel = Lib.Label.new()
			nameLabel.Text = "By applying current settings requires reload.\nAny unsaved progress will be lost.\nAre you sure?"
			nameLabel.Position = UDim2.new(0,30,0,20)
			nameLabel.Size = UDim2.new(0,40,0,20)
			win:Add(nameLabel)

			local cancelButton = Lib.Button.new()
			cancelButton.AnchorPoint = Vector2.new(1,1)
			cancelButton.Text = "Apply Later"
			cancelButton.Position = UDim2.new(1,-5,1,-5)
			cancelButton.Size = UDim2.new(0.5,-10,0,20)
			cancelButton.OnClick:Connect(function()
				win:Close()
			end)
			win:Add(cancelButton)

			reloadButton.Text = "Apply Now"
			reloadButton.AnchorPoint = Vector2.new(0,1)
			reloadButton.Position = UDim2.new(0,5,1,-5)
			reloadButton.Size = UDim2.new(0.5,-5,0,20)
			reloadButton.OnClick:Connect(function()
				reloadButton:SetDisabled(true)
				reloadButton.Text = "Restarting"
				cancelButton:SetDisabled(true)
				if Main.Reinit and Main.Reinit() then
					win:Close()
				else
					reloadButton.Text = "Busy"
					task.delay(1, function()
						reloadButton:SetDisabled(false)
						cancelButton:SetDisabled(false)
						reloadButton.Text = "Apply Now"
					end)
				end
			end)

			win:Add(reloadButton,"reloadButton")

			SettingsWindow.ReloadPromptWindow = win
		end
		win:Show()
	end
	
	SettingsWindow.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Settings")
		window:Resize(250,375)
		SettingsWindow.Window = window
		
		-- ListFrame
		
		ListFrame = Instance.new("ScrollingFrame")
		ListFrame.Parent = window.GuiElems.Content
		ListFrame.Size = UDim2.new(1, 0,1, -20)
		ListFrame.Position = UDim2.new(0, 0, 0, 0)
		ListFrame.Transparency = 1
		ListFrame.CanvasSize = UDim2.new(0,0,0,0)
		ListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		ListFrame.ScrollBarThickness = 16
		ListFrame.BottomImage = ""
		ListFrame.TopImage = ""
		ListFrame.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 70)
		ListFrame.ScrollBarImageTransparency = 0
		ListFrame.ZIndex = 2
		ListFrame.BorderSizePixel = 0
		
		local scrollbar = Lib.ScrollBar.new()
		scrollbar.Gui.Parent = window.GuiElems.Content
		scrollbar.Gui.Size = UDim2.new(1, 0,1, -40)
		scrollbar.Gui.Up.ZIndex = 3
		scrollbar.Gui.Down.ZIndex = 3
		
		ListFrame:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
			if ListFrame.AbsoluteCanvasSize ~= ListFrame.AbsoluteWindowSize then
				scrollbar.Gui.Visible = true
			else
				scrollbar.Gui.Visible = false
			end
		end)
		
		local ListLayout = Instance.new("UIListLayout")
		ListLayout.Parent = ListFrame
		ListLayout.Padding = UDim.new(0, 5)
		
		local Padding = Instance.new("UIPadding")
		Padding.Parent = ListFrame
		Padding.PaddingBottom = UDim.new(0, 5)
		Padding.PaddingLeft = UDim.new(0, 10)
		Padding.PaddingRight = UDim.new(0, 10)
		Padding.PaddingTop = UDim.new(0, 5)
		
		-- Options
		
		AddSeperator("UI")
		
		local titleonmiddle = AddCheckbox("Window Title On Middle", Settings.Window.TitleOnMiddle)
		titleonmiddle.OnInput:Connect(function()
			Settings.Window.TitleOnMiddle = titleonmiddle.Toggled
		end)
		
		local autocheckupdate = AddCheckbox("Auto Check Update", Settings.AutoCheckUpdate ~= false)
		autocheckupdate.OnInput:Connect(function()
			Settings.AutoCheckUpdate = autocheckupdate.Toggled
		end)

		local updateRef = AddTextbox("Update Ref (tag recommended)", Settings.AutoUpdateRef or "v3.1", 120)
		updateRef.FocusLost:Connect(function()
			local ref = tostring(updateRef.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
			if ref == "" then
				ref = "v3.1"
				updateRef.Text = ref
			end
			Settings.AutoUpdateRef = ref
		end)

		local allowBranchUpdate = AddCheckbox("Allow Main/Master Update Ref", Settings.AutoUpdateAllowBranch == true)
		allowBranchUpdate.OnInput:Connect(function()
			Settings.AutoUpdateAllowBranch = allowBranchUpdate.Toggled
		end)
		
		local bgTransparency = AddTextbox("Background Transparency", tostring(Settings.Window.Transparency), 15)
		bgTransparency.FocusLost:Connect(function()
			Settings.Window.Transparency = tonumber(bgTransparency.Text)
		end)
		
		local classIcon = AddDropdown("Class Icons", {"Old", "NewDark", "Vanilla3"}, Settings.ClassIcon, false, 100)
		classIcon.OnSelect:Connect(function()
			Settings.ClassIcon = classIcon.Selected
		end)
		
		AddSeperator("Explorer")
		
		local clickRename = AddCheckbox("Click to Rename", Settings.Explorer.ClickToRename)
		clickRename.OnInput:Connect(function()
			Settings.Explorer.ClickToRename = clickRename.Toggled
		end)
		
		local partSelectionBox = AddCheckbox("Part Selection Box", Settings.Explorer.PartSelectionBox)
		partSelectionBox.OnInput:Connect(function()
			Settings.Explorer.PartSelectionBox = partSelectionBox.Toggled
		end)
		
		local copypathUseChildren = AddCheckbox("Use GetChildren to Copy Path", Settings.Explorer.CopyPathUseGetChildren)
		copypathUseChildren.OnInput:Connect(function()
			Settings.Explorer.CopyPathUseGetChildren = copypathUseChildren.Toggled
		end)

		AddSeperator("Viewport Interaction")

		local viewportMenuEnabled = AddCheckbox("Viewport Context Menu", Settings.Explorer.ViewportContextMenuEnabled)
		viewportMenuEnabled.OnInput:Connect(function()
			Settings.Explorer.ViewportContextMenuEnabled = viewportMenuEnabled.Toggled
			if Explorer and Explorer.UpdateViewportListener then
				Explorer.UpdateViewportListener()
			end
		end)

		local viewportMenuTrigger = AddDropdown("Viewport Menu Trigger", {"Right Click", "Middle Click"}, Settings.Explorer.ViewportContextMenuTrigger, false, 100)
		viewportMenuTrigger.OnSelect:Connect(function()
			Settings.Explorer.ViewportContextMenuTrigger = viewportMenuTrigger.Selected
			if Explorer and Explorer.UpdateViewportListener then
				Explorer.UpdateViewportListener()
			end
		end)
		
		AddSeperator("Properties")

		local showDeprecated = AddCheckbox("Show Deprecated", Settings.Properties.ShowDeprecated)
		showDeprecated.OnInput:Connect(function()
			Settings.Properties.ShowDeprecated = showDeprecated.Toggled
		end)
		
		local showHidden = AddCheckbox("Show Hidden", Settings.Properties.ShowHidden)
		showHidden.OnInput:Connect(function()
			Settings.Properties.ShowHidden = showHidden.Toggled
		end)
		
		local showAttributes = AddCheckbox("Show Attributes", Settings.Properties.ShowAttributes)
		showAttributes.OnInput:Connect(function()
			Settings.Properties.ShowAttributes = showAttributes.Toggled
		end)
		local clearOnFocus = AddCheckbox("Clear On Focus", Settings.Properties.ClearOnFocus)
		clearOnFocus.OnInput:Connect(function()
			Settings.Properties.ClearOnFocus = clearOnFocus.Toggled
		end)
		
		AddSeperator("Notepad")
		
		local showMoreInfo = AddCheckbox("Show Decompiled Script Info", Settings.Notepad.ShowMoreInfo)
		showMoreInfo.OnInput:Connect(function()
			Settings.Notepad.ShowMoreInfo = showMoreInfo.Toggled
		end)
		
		AddSeperator("Decompiler")
		AddText("If executor does not support decompile, it will use the fallback option.")
		AddText("'getbytecode' is mandatory to use fallback decompilers.")
		AddText("Local C++ Helper handles /script, /normalize-source, /log and persistent source search; it does not decompile bytecode.")
		local useLocalHelper = AddCheckbox("Use Local Helper", Settings.Decompiler.UseLocalHelper == true)
		useLocalHelper.OnInput:Connect(function()
			Settings.Decompiler.UseLocalHelper = useLocalHelper.Toggled == true
		end)
		local helperLogChanges = AddCheckbox("Log Property Changes To Helper", Settings.Decompiler.HelperLogChanges == true)
		helperLogChanges.OnInput:Connect(function()
			Settings.Decompiler.HelperLogChanges = helperLogChanges.Toggled == true
		end)
		AddText("Keep property helper logging OFF during normal play. It is rate-limited, but noisy properties can still cost FPS.")
		local HelperLogLimit = AddTextbox("Helper Property Log Limit/s", tostring(Settings.Decompiler.HelperLogRateLimit or 5), 50)
		HelperLogLimit.FocusLost:Connect(function()
			local limitInput = tonumber(HelperLogLimit.Text)
			if not limitInput then
				HelperLogLimit.Text = tostring(Settings.Decompiler.HelperLogRateLimit or 5)
			else
				Settings.Decompiler.HelperLogRateLimit = math.clamp(math.floor(limitInput), 0, 100)
				HelperLogLimit.Text = tostring(Settings.Decompiler.HelperLogRateLimit)
			end
		end)
		local lowImpactIndex = AddCheckbox("Code Search Low Impact Index", Settings.Decompiler.CodeSearchLowImpact ~= false)
		lowImpactIndex.OnInput:Connect(function()
			Settings.Decompiler.CodeSearchLowImpact = lowImpactIndex.Toggled == true
		end)
		local decompilerOption = {"Executor (Native)", "Konstant", "AdvancedDecompiler", "Shiny"}
		local initialSelected = "Executor (Native)"
		if Settings.Decompiler.PreferDecompilerFallback then
			initialSelected = Settings.Decompiler.DecompilerFallback
		end

		local decompiler = AddDropdown("Active Decompiler", decompilerOption, initialSelected, false, 125)
		decompiler.OnSelect:Connect(function()
			local selected = decompiler.Selected
			if selected == "Executor (Native)" then
				Settings.Decompiler.PreferDecompilerFallback = false
			else
				Settings.Decompiler.PreferDecompilerFallback = true
				Settings.Decompiler.DecompilerFallback = selected
			end
		end)
		
		local ShinyPort = AddTextbox("Shiny Decompiler Port", tostring(Settings.Decompiler.ShinyDecompilerPort), 50)
		ShinyPort.FocusLost:Connect(function()
			local portinput = tonumber(ShinyPort.Text)
			if not portinput then
				ShinyPort.Text = Settings.Decompiler.ShinyDecompilerPort
			else
				if portinput > 0 and portinput <= 65535 then
					Settings.Decompiler.ShinyDecompilerPort = portinput
				else
					ShinyPort.Text = Settings.Decompiler.ShinyDecompilerPort
				end
			end
		end)

		local HelperPort = AddTextbox("Local Helper Port", tostring(Settings.Decompiler.HelperServerPort or 8080), 50)
		HelperPort.FocusLost:Connect(function()
			local portinput = tonumber(HelperPort.Text)
			if not portinput then
				HelperPort.Text = tostring(Settings.Decompiler.HelperServerPort or 8080)
			elseif portinput > 0 and portinput <= 65535 then
				Settings.Decompiler.HelperServerPort = portinput
			else
				HelperPort.Text = tostring(Settings.Decompiler.HelperServerPort or 8080)
			end
		end)
		
		-- Save buttons below
		local BackgroundreloadButton = Lib.Frame.new()
		BackgroundreloadButton.Gui.Parent = window.GuiElems.Content
		BackgroundreloadButton.Size = UDim2.new(1,0, 0,20)
		BackgroundreloadButton.Position = UDim2.new(0,0, 1,-20)
		
		local LabelreloadButton = Lib.Label.new()
		LabelreloadButton.Gui.Parent = window.GuiElems.Content
		LabelreloadButton.Size = UDim2.new(1,0, 0,20)
		LabelreloadButton.Position = UDim2.new(0,0, 1,-20)
		LabelreloadButton.Gui.Text = "Restart"
		LabelreloadButton.Gui.TextXAlignment = Enum.TextXAlignment.Center
		
		local reloadButton = Instance.new("TextButton")
		reloadButton.Parent = BackgroundreloadButton.Gui
		reloadButton.Size = UDim2.new(1,0, 1,0)
		reloadButton.Position = UDim2.new(0,0, 0,0)
		reloadButton.Transparency = 1
		
		local reloadClickBusy = false
		reloadButton.MouseButton1Click:Connect(function()
			if reloadClickBusy then return end
			reloadClickBusy = true
			window:SetTitle("Settings - Saving")
			
			Main.SaveCurrentSettings()
			
			window:SetTitle("Settings - Saved")
			SettingsWindow.ReloadPrompt()
			task.delay(3, function()
				reloadClickBusy = false
				if window and not window.Closed then
					window:SetTitle("Settings")
				end
			end)
		end)
	end

	return SettingsWindow
end

-- TODO: Remove when open source
if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
