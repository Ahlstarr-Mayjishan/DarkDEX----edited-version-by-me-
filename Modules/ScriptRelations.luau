--!strict
--[[
	Script Relations App Module
	Shows hierarchy and source-inferred relationships for scripts.
]]
-- Common Locals
local Main,Lib,Apps,Settings -- Main Containers
local Explorer, Properties, ScriptViewer, ScriptRelations, Notebook -- Major Apps
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
	ScriptViewer = Apps.ScriptViewer
	ScriptRelations = Apps.ScriptRelations
	Notebook = Apps.Notebook
end
local function main()
	local ScriptRelations = {}
	local window, statusLabel, listFrame
	local currentScript = nil
	local analysisToken = 0
	local function setStatus(text)
		if statusLabel then statusLabel.Text = text end
	end
	local function isScript(obj)
		return typeof(obj) == "Instance" and obj:IsA("LuaSourceContainer")
	end
	local function isViableScript(obj)
		return isScript(obj) and env.isViableDecompileScript and env.isViableDecompileScript(obj)
	end
	local function getPath(obj)
		local success, path = pcall(function()
			if Explorer and Explorer.GetInstancePath then
				return Explorer.GetInstancePath(obj)
			end
			return obj:GetFullName()
		end)
		return success and tostring(path) or tostring(obj)
	end
	local function collectScripts()
		local scripts = {}
		for _, obj in pairs(game:GetDescendants()) do
			if isScript(obj) then table.insert(scripts, obj) end
		end
		if env.getnilinstances then
			local success, nilInstances = pcall(env.getnilinstances)
			if success and type(nilInstances) == "table" then
				for _, obj in pairs(nilInstances) do
					if isScript(obj) then table.insert(scripts, obj) end
				end
			end
		end
		return scripts
	end
	local function clearRows()
		if not listFrame then return end
		for _, child in pairs(listFrame:GetChildren()) do
			if child:IsA("GuiButton") or child:IsA("TextLabel") then
				child:Destroy()
			end
		end
	end
	local function addDivider(text)
		local label = createSimple("TextLabel",{
			BackgroundColor3 = Settings.Theme.Main1, BorderSizePixel = 0, Font = Enum.Font.SourceSansBold,
			Size = UDim2.new(1,-8,0,22), Text = text, TextColor3 = Settings.Theme.Text,
			TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = listFrame
		})
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0,6)
		padding.Parent = label
	end
	local function addRow(indent, text, obj, muted)
		local row = createSimple("TextButton",{
			AutoButtonColor = false, BackgroundColor3 = Settings.Theme.Main2, BackgroundTransparency = obj and 0 or 1,
			BorderColor3 = Settings.Theme.Outline1, BorderSizePixel = obj and 1 or 0, Font = Enum.Font.SourceSans,
			Size = UDim2.new(1,-8,0,22), Text = string.rep("  ", indent) .. text,
			TextColor3 = muted and Settings.Theme.PlaceholderText or Settings.Theme.Text, TextSize = 14,
			TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, Parent = listFrame
		})
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0,6)
		padding.Parent = row
		if obj then
			Lib.ButtonAnim(row,{Mode = 2, StartColor = Settings.Theme.Main2, HoverColor = Settings.Theme.ButtonHover, PressColor = Settings.Theme.ButtonPress, OutlineColor = Settings.Theme.Outline1})
			row.MouseButton1Click:Connect(function()
				if ScriptViewer and ScriptViewer.ViewScript then
					ScriptViewer.ViewScript(obj)
				end
			end)
		end
		return row
	end
	local function addScriptRow(indent, prefix, scriptObj)
		addRow(indent, prefix .. scriptObj.Name .. " [" .. scriptObj.ClassName .. "]", scriptObj, not isViableScript(scriptObj))
	end
	local function addHierarchy(scr)
		addDivider("Hierarchy")
		local lineage = {}
		local cur = scr.Parent
		while cur do
			table.insert(lineage, 1, cur)
			cur = cur.Parent
		end
		for i, obj in ipairs(lineage) do
			addRow(i - 1, obj.Name .. " [" .. obj.ClassName .. "]", nil, true)
		end
		addScriptRow(#lineage, "> ", scr)
		local childCount = 0
		for _, child in pairs(scr:GetChildren()) do
			if isScript(child) then
				childCount += 1
				addScriptRow(#lineage + 1, "- child: ", child)
			end
		end
		if childCount == 0 then addRow(#lineage + 1, "no script children", nil, true) end
		addDivider("Sibling Scripts")
		local siblingCount = 0
		if scr.Parent then
			for _, sibling in pairs(scr.Parent:GetChildren()) do
				if sibling ~= scr and isScript(sibling) then
					siblingCount += 1
					addScriptRow(1, "- ", sibling)
				end
			end
		end
		if siblingCount == 0 then addRow(1, "no sibling scripts", nil, true) end
	end
	local function buildScriptLookup()
		local byKey = {}
		if not env.DecompileCache or not env.DecompileCache.GetScriptKey then return byKey end
		for _, scr in pairs(collectScripts()) do
			local success, key = pcall(env.DecompileCache.GetScriptKey, scr)
			if success and key then byKey[key] = scr end
		end
		return byKey
	end
	local function addUnique(list, seen, obj)
		if obj and not seen[obj] then
			seen[obj] = true
			table.insert(list, obj)
		end
	end
	local function findOutgoingRelations(source, selected)
		local lowerSource = source:lower()
		local requires = {}
		local references = {}
		local seenRequires = {}
		local seenReferences = {}
		for _, other in pairs(collectScripts()) do
			if other ~= selected then
				local name = other.Name:lower()
				if #name >= 3 then
					for block in lowerSource:gmatch("require%s*%b()") do
						if block:find(name, 1, true) then
							addUnique(requires, seenRequires, other)
						end
					end
					if lowerSource:find(name, 1, true) then
						addUnique(references, seenReferences, other)
					end
				end
			end
		end
		return requires, references
	end
	local function findIncomingRelations(selected, selectedPath)
		local incoming = {}
		local seen = {}
		if not env.DecompileCache or not env.DecompileCache.GetEntries or not env.isfile then
			return incoming
		end
		local entries, cacheDir = env.DecompileCache.GetEntries()
		local byKey = buildScriptLookup()
		local nameToken = selected.Name:lower()
		local pathToken = selectedPath:lower()
		for key, entry in pairs(entries) do
			if entry.File then
				local obj = byKey[key]
				if obj and obj ~= selected then
					local filePath = cacheDir .. "/" .. tostring(entry.File)
					if env.isfile(filePath) then
						local success, source = pcall(env.readfile, filePath)
						if success and type(source) == "string" then
							local lowerSource = source:lower()
							local nameHit = #nameToken >= 3 and lowerSource:find(nameToken, 1, true)
							local pathHit = #pathToken >= 6 and lowerSource:find(pathToken, 1, true)
							if nameHit or pathHit then addUnique(incoming, seen, obj) end
						end
					end
				end
			end
			task.wait()
		end
		return incoming
	end
	local function addRelationSection(title, rows)
		addDivider(title)
		if #rows == 0 then
			addRow(1, "none found", nil, true)
			return
		end
		for i, obj in ipairs(rows) do
			if i > 50 then
				addRow(1, "more results omitted", nil, true)
				break
			end
			addScriptRow(1, "- ", obj)
		end
	end
	local function analyzeSource(scr, token)
		local sourceSuccess, source = pcall(env.decompile, scr)
		if token ~= analysisToken then return end
		if not sourceSuccess or type(source) ~= "string" then
			setStatus("Could not decompile selected script for source relations.")
			return
		end
		local requires, references = findOutgoingRelations(source, scr)
		local incoming = findIncomingRelations(scr, getPath(scr))
		if token ~= analysisToken then return end
		addRelationSection("Requires / Module Links", requires)
		addRelationSection("Mentions Other Scripts", references)
		addRelationSection("Mentioned By Cached Scripts", incoming)
		setStatus("Relations ready. Click a script row to open it.")
	end
	ScriptRelations.ShowForScript = function(scr)
		if not isScript(scr) then
			setStatus("Select a script first.")
			return
		end
		currentScript = scr
		analysisToken += 1
		clearRows()
		window:SetTitle("Script Relations - " .. scr.Name)
		addHierarchy(scr)
		setStatus("Building source relations...")
		window:Show()
		local token = analysisToken
		task.spawn(function()
			analyzeSource(scr, token)
		end)
	end
	ScriptRelations.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Script Relations")
		window:Resize(560,420)
		ScriptRelations.Window = window
		statusLabel = createSimple("TextLabel",{
			BackgroundColor3 = Settings.Theme.Main2, BorderSizePixel = 0, Font = Enum.Font.SourceSans,
			Position = UDim2.new(0,0,0,0), Size = UDim2.new(1,0,0,24),
			Text = "Right click a script in Explorer, then choose Script Relations.",
			TextColor3 = Settings.Theme.PlaceholderText, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = window.GuiElems.Content
		})
		local statusPadding = Instance.new("UIPadding")
		statusPadding.PaddingLeft = UDim.new(0,6)
		statusPadding.Parent = statusLabel
		listFrame = createSimple("ScrollingFrame",{
			Active = true, AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundColor3 = Settings.Theme.Main2,
			BorderSizePixel = 0, BottomImage = "", CanvasSize = UDim2.new(0,0,0,0), Position = UDim2.new(0,0,0,24),
			ScrollBarImageColor3 = Color3.fromRGB(70,70,70), ScrollBarThickness = 10, Size = UDim2.new(1,0,1,-24),
			TopImage = "", Parent = window.GuiElems.Content
		})
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0,4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = listFrame
		local padding = Instance.new("UIPadding")
		padding.PaddingBottom = UDim.new(0,6)
		padding.PaddingLeft = UDim.new(0,4)
		padding.PaddingRight = UDim.new(0,4)
		padding.PaddingTop = UDim.new(0,4)
		padding.Parent = listFrame
	end
	return ScriptRelations
end
-- TODO: Remove when open source
if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
