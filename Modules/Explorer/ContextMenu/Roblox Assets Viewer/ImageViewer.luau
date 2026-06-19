--!strict
--[[
	Image Viewer App Module
	Previews image-like asset properties from selected instances.
]]
local Main,Lib,Apps,Settings
local Explorer, ImageViewer, Notebook
local API,RMD,env,service,plr,create,createSimple

local function initDeps(data)
	Main, Lib, Apps, Settings = data.Main, data.Lib, data.Apps, data.Settings
	API, RMD, env, service, plr = data.API, data.RMD, data.env, data.service, data.plr
	create, createSimple = data.create, data.createSimple
end

local function initAfterMain()
	Explorer = Apps.Explorer
	ImageViewer = Apps.ImageViewer
	Notebook = Apps.Notebook
end

local function main()
	local ImageViewer = {}
	local window, preview, titleLabel, detailLabel, listFrame
	local currentItems = {}
	local selectedItem = nil

	local imagePropsByClass = {
		Decal = {"Texture"},
		Texture = {"Texture"},
		ImageLabel = {"Image"},
		ImageButton = {"Image", "HoverImage", "PressedImage"},
		ImageHandleAdornment = {"Image"},
		ParticleEmitter = {"Texture"},
		Trail = {"Texture"},
		Beam = {"Texture"},
		MeshPart = {"TextureID"},
		SpecialMesh = {"TextureId"},
		SurfaceAppearance = {"ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap"},
		Sky = {"SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp"},
		Shirt = {"ShirtTemplate"},
		Pants = {"PantsTemplate"},
		ShirtGraphic = {"Graphic"},
	}

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

	local function clearRows()
		if not listFrame then return end
		for _, child in pairs(listFrame:GetChildren()) do
			if child:IsA("GuiButton") or child:IsA("TextLabel") then child:Destroy() end
		end
	end

	local function setPreview(item)
		selectedItem = item
		if not preview or not titleLabel or not detailLabel then return end
		if not item then
			preview.Image = ""
			titleLabel.Text = "No image selected"
			detailLabel.Text = "Right click an image object or a folder/model containing image assets."
			return
		end
		preview.Image = item.Asset
		titleLabel.Text = item.Object.Name .. "." .. item.Property
		detailLabel.Text = item.Asset .. " | " .. item.Path
	end

	local function addRow(item)
		local row = createSimple("TextButton",{
			AutoButtonColor = false, BackgroundColor3 = Settings.Theme.Main2, BorderColor3 = Settings.Theme.Outline1,
			BorderSizePixel = 1, Font = Enum.Font.SourceSans, Size = UDim2.new(1,-8,0,42),
			Text = "", Parent = listFrame
		})
		createSimple("TextLabel",{
			BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Position = UDim2.new(0,8,0,2),
			Size = UDim2.new(1,-16,0,18), Text = item.Object.Name .. " [" .. item.Object.ClassName .. "] ." .. item.Property,
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
		local props = imagePropsByClass[obj.ClassName]
		if props then
			for _, prop in ipairs(props) do
				local ok, value = pcall(function() return obj[prop] end)
				local asset = ok and normalizeAsset(value) or ""
				if asset ~= "" then
					results[#results + 1] = {Object = obj, Property = prop, Asset = asset, Path = getPath(obj)}
					if #results >= limit then return end
				end
			end
		end
	end

	local function collectImages(root)
		local results = {}
		local limit = 160
		collectFrom(root, results, limit)
		if #results >= limit then return results end
		local descendants = nil
		if root == game and env.RefreshClientSurface then
			descendants = env.RefreshClientSurface(false, false).AllInstances
		else
			local ok, list = pcall(root.GetDescendants, root)
			descendants = ok and list or {}
		end
		local count = 0
		for _, obj in pairs(descendants) do
			count += 1
			collectFrom(obj, results, limit)
			if #results >= limit then break end
			if count % 200 == 0 then task.wait() end
		end
		return results
	end

	ImageViewer.ShowForObject = function(obj)
		if typeof(obj) ~= "Instance" then return end
		currentItems = collectImages(obj)
		clearRows()
		window:SetTitle("Image Viewer - " .. obj.Name)
		for _, item in ipairs(currentItems) do addRow(item) end
		if #currentItems == 0 then
			local label = createSimple("TextLabel",{
				BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Size = UDim2.new(1,-8,0,24),
				Text = "No image assets found in selected object.", TextColor3 = Settings.Theme.PlaceholderText,
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
	end

	ImageViewer.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Image Viewer")
		window:Resize(620,430)
		ImageViewer.Window = window
		local content = window.GuiElems.Content
		local previewPane = createSimple("Frame",{BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, Position=UDim2.new(0,0,0,0), Size=UDim2.new(0.48,0,1,0), Parent=content})
		preview = createSimple("ImageLabel",{BackgroundColor3=Settings.Theme.TextBox, BorderColor3=Settings.Theme.Outline1, Position=UDim2.new(0,8,0,8), Size=UDim2.new(1,-16,1,-88), ScaleType=Enum.ScaleType.Fit, Image="", Parent=previewPane})
		titleLabel = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSansBold, Position=UDim2.new(0,8,1,-76), Size=UDim2.new(1,-16,0,22), Text="No image selected", TextColor3=Settings.Theme.Text, TextSize=14, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=previewPane})
		detailLabel = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,8,1,-54), Size=UDim2.new(1,-16,0,22), Text="", TextColor3=Settings.Theme.PlaceholderText, TextSize=13, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=previewPane})
		makeButton(previewPane, "Copy Asset", UDim2.new(0,8,1,-28), UDim2.new(0,96,0,22), function()
			if selectedItem and env.setclipboard then env.setclipboard(selectedItem.Asset) end
		end)
		makeButton(previewPane, "Copy Path", UDim2.new(0,110,1,-28), UDim2.new(0,86,0,22), function()
			if selectedItem and env.setclipboard then env.setclipboard(selectedItem.Path) end
		end)
		listFrame = createSimple("ScrollingFrame",{Active=true, AutomaticCanvasSize=Enum.AutomaticSize.Y, BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, BottomImage="", CanvasSize=UDim2.new(0,0,0,0), Position=UDim2.new(0.48,1,0,0), ScrollBarImageColor3=Color3.fromRGB(70,70,70), ScrollBarThickness=10, Size=UDim2.new(0.52,-1,1,0), TopImage="", Parent=content})
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0,4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = listFrame
		local pad = Instance.new("UIPadding")
		pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop = UDim.new(0,6), UDim.new(0,4), UDim.new(0,4), UDim.new(0,4)
		pad.Parent = listFrame
	end
	return ImageViewer
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
