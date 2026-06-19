--[[
	Theme Module
	
	Centralizes UI aesthetics, fonts, custom colors, and transition helpers.
]]

-- Common Locals
local Main, Lib, Apps, Settings -- Main Containers
local Explorer, Properties, ScriptViewer, Notebook -- Major Apps
local API, RMD, env, service, plr, create, createSimple -- Main Locals

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

local function initAfterMain(t)
	Explorer = t.Explorer
	Properties = t.Properties
	ScriptViewer = t.ScriptViewer
	Notebook = t.Notebook
end

local function main()
	local Theme = {}

	-- Font Mapping: Upgrades basic SourceSans font to modern Gotham family
	function Theme.MapFont(font)
		if font == Enum.Font.SourceSans then
			return Enum.Font.Gotham
		elseif font == Enum.Font.SourceSansBold then
			return Enum.Font.GothamBold
		end
		return font
	end

	-- Rounded Corners Helper
	function Theme.ApplyRounding(guiInstance, radius)
		local corner = guiInstance:FindFirstChildOfClass("UICorner")
		if not corner then
			corner = Instance.new("UICorner")
			corner.Parent = guiInstance
		end
		corner.CornerRadius = UDim.new(0, radius or 4)
		return corner
	end

	-- Outline Stroke Helper (Replaces ugly BordersizePixel)
	function Theme.ApplyStroke(guiInstance, color, thickness, transparency)
		guiInstance.BorderSizePixel = 0
		local stroke = guiInstance:FindFirstChildOfClass("UIStroke")
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Parent = guiInstance
		end
		stroke.Color = color or Settings.Theme.Outline1
		stroke.Thickness = thickness or 1
		stroke.Transparency = transparency or 0
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		return stroke
	end

	-- Standardized Button Styling with Smooth Tweens
	function Theme.StyleButton(button, isAccent)
		Theme.ApplyRounding(button, 4)
		button.Font = Theme.MapFont(button.Font)
		button.BorderSizePixel = 0

		local theme = Settings.Theme
		local startCol = isAccent and theme.ListSelection or theme.Button
		local hoverCol = theme.ButtonHover
		local pressCol = theme.ButtonPress

		button.BackgroundColor3 = startCol
		button.TextColor3 = theme.Text

		button.MouseEnter:Connect(function()
			service.TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = hoverCol
			}):Play()
		end)
		button.MouseLeave:Connect(function()
			service.TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = startCol
			}):Play()
		end)
		button.MouseButton1Down:Connect(function()
			service.TweenService:Create(button, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = pressCol
			}):Play()
		end)
		button.MouseButton1Up:Connect(function()
			service.TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = hoverCol
			}):Play()
		end)
	end

	-- Standardized TextBox Styling
	function Theme.StyleTextBox(textBox)
		Theme.ApplyRounding(textBox, 4)
		Theme.ApplyStroke(textBox, Settings.Theme.Outline3, 1, 0.3)
		textBox.Font = Theme.MapFont(textBox.Font)
		textBox.BackgroundColor3 = Settings.Theme.TextBox
		textBox.TextColor3 = Settings.Theme.Text
		textBox.PlaceholderColor3 = Settings.Theme.PlaceholderText
		textBox.BorderSizePixel = 0
	end

	-- Standardized Frame Styling
	function Theme.StyleFrame(frame, mainType)
		Theme.ApplyRounding(frame, 4)
		local theme = Settings.Theme
		local bgCol = (mainType == 1) and theme.Main1 or ((mainType == 2) and theme.Main2 or theme.Menu)
		frame.BackgroundColor3 = bgCol
		frame.BorderSizePixel = 0
		Theme.ApplyStroke(frame, theme.Outline1, 1, 0.4)
	end

	return Theme
end

return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
