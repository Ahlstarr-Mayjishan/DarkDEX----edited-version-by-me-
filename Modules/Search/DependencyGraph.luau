--!strict
--[[
	Script Dependency Graph App Module
	Builds a cache-backed graph of require links and remote mentions.
	Upgraded to a fully interactive visual node graph.
]]
local Main, Lib, Apps, Settings
local Explorer, ScriptViewer, DependencyGraph
local API, RMD, env, service, plr, create, createSimple

local function initDeps(data)
	Main, Lib, Apps, Settings = data.Main, data.Lib, data.Apps, data.Settings
	API, RMD, env, service, plr = data.API, data.RMD, data.env, data.service, data.plr
	create, createSimple = data.create, data.createSimple
end

local function initAfterMain()
	Explorer = Apps.Explorer
	ScriptViewer = Apps.ScriptViewer
	DependencyGraph = Apps.DependencyGraph
end

local function main()
	local DependencyGraph = {}
	local window, listFrame, statusLabel, sidePanel
	local sideTitle, sidePath, sideMeta, sideRole, sideIncoming, sideOutgoing
	local contextMenu
	local scanToken = 0
	local remoteClasses = {RemoteEvent=true, RemoteFunction=true, UnreliableRemoteEvent=true, BindableEvent=true, BindableFunction=true}

	-- Graph State
	local nodesData = {}      -- Key -> Node data
	local edgesData = {}      -- List of { fromKey, toKey }
	local edgesByNode = {}    -- Key -> incident edges
	local nodeFrames = {}     -- Key -> Frame UI
	local edgeLines = {}      -- List of Line UI Frames
	local selectedNodeKey = nil
	local hoveredNodeKey = nil

	local function getPath(obj)
		if Main and Main.SafeGetInstancePath then return Main.SafeGetInstancePath(obj) end
		local ok, path = pcall(function()
			if Explorer and Explorer.GetInstancePath then return Explorer.GetInstancePath(obj) end
			return obj:GetFullName()
		end)
		return ok and tostring(path) or tostring(obj)
	end

	local function copyText(text, okMessage)
		if not env.setclipboard then
			if statusLabel then statusLabel.Text = "Clipboard API is unavailable." end
			return false
		end
		env.setclipboard(tostring(text or ""))
		if statusLabel then statusLabel.Text = okMessage or "Copied to clipboard." end
		return true
	end

	local function scriptByKey()
		if env.ClientIndex and env.ClientIndex.GetScriptLookup then
			return env.ClientIndex.GetScriptLookup()
		end
		local map = {}
		if not env.DecompileCache or not env.DecompileCache.GetScriptKey then return map end
		local scripts = env.GetClientScripts and env.GetClientScripts(true) or game:GetDescendants()
		for _, obj in pairs(scripts) do
			if typeof(obj) == "Instance" and obj:IsA("LuaSourceContainer") then
				local ok, key = pcall(env.DecompileCache.GetScriptKey, obj)
				if ok and key then map[key] = obj end
			end
		end
		return map
	end

	local function collectRemotes()
		if env.ClientIndex and env.ClientIndex.RefreshSurface then
			return env.ClientIndex.RefreshSurface(false).Remotes
		end
		local remotes = {}
		local list = env.GetClientRemotes and env.GetClientRemotes() or game:GetDescendants()
		for _, obj in pairs(list) do
			if typeof(obj) == "Instance" and remoteClasses[obj.ClassName] then table.insert(remotes, obj) end
		end
		return remotes
	end

	local function requireBlockMentionsName(block, name)
		local loweredName = tostring(name or ""):lower()
		if #loweredName < 3 then return false end
		local loweredBlock = tostring(block or ""):lower()
		if loweredName:match("^[%w_]+$") then
			return loweredBlock:find("%f[%w_]" .. loweredName .. "%f[^%w_]") ~= nil
		end
		return loweredBlock:find(loweredName, 1, true) ~= nil
	end

	-- Simple Rotated Line Drawer for Canvas
	local function drawLine(p1, p2, outgoing)
		local dx = p2.X - p1.X
		local dy = p2.Y - p1.Y
		local length = math.sqrt(dx * dx + dy * dy)
		if length < 1 then return nil end
		local angle = math.deg(math.atan2(dy, dx))

		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.BackgroundColor3 = outgoing and Settings.Theme.Highlight or Settings.Theme.Outline2
		line.BackgroundTransparency = outgoing and 0.18 or 0.35
		line.Size = UDim2.new(0, length, 0, 2)
		line.Position = UDim2.new(0, p1.X, 0, p1.Y)
		line.Rotation = angle
		line.AnchorPoint = Vector2.new(0, 0.5)
		line.ZIndex = 2
		line.Parent = listFrame
		return line
	end

	local function updateLines()
		for _, line in ipairs(edgeLines) do
			line:Destroy()
		end
		table.clear(edgeLines)

		local focusKey = hoveredNodeKey or selectedNodeKey
		if not focusKey then return end

		for _, edge in ipairs(edgesByNode[focusKey] or {}) do
			local fFrame = nodeFrames[edge.fromKey]
			local tFrame = nodeFrames[edge.toKey]
			if fFrame and tFrame then
				local fromCenterX = fFrame.Position.X.Offset + fFrame.Size.X.Offset / 2
				local toCenterX = tFrame.Position.X.Offset + tFrame.Size.X.Offset / 2
				local direction = toCenterX >= fromCenterX and 1 or -1
				local p1 = Vector2.new(
					fromCenterX + direction * fFrame.Size.X.Offset / 2,
					fFrame.Position.Y.Offset + fFrame.Size.Y.Offset / 2
				)
				local p2 = Vector2.new(
					toCenterX - direction * tFrame.Size.X.Offset / 2,
					tFrame.Position.Y.Offset + tFrame.Size.Y.Offset / 2
				)
				local line = drawLine(p1, p2, edge.fromKey == focusKey)
				if line then
					table.insert(edgeLines, line)
				end
			end
		end
	end

	-- Context Menu Helper
	local function showContextMenu(pos, node)
		if contextMenu then contextMenu:Destroy() end
		
		contextMenu = Instance.new("Frame")
		contextMenu.BackgroundColor3 = Settings.Theme.Main1
		contextMenu.BorderColor3 = Settings.Theme.Outline2
		contextMenu.BorderSizePixel = 1
		contextMenu.Size = UDim2.new(0, 150, 0, 0)
		contextMenu.Position = UDim2.new(0, pos.X, 0, pos.Y)
		contextMenu.ZIndex = 100
		contextMenu.Parent = listFrame

		local menuLayout = Instance.new("UIListLayout", contextMenu)
		menuLayout.SortOrder = Enum.SortOrder.LayoutOrder

		local function addOption(text, cb)
			local btn = Instance.new("TextButton", contextMenu)
			btn.Size = UDim2.new(1, 0, 0, 24)
			btn.BorderSizePixel = 0
			btn.BackgroundColor3 = Settings.Theme.Main1
			btn.TextColor3 = Settings.Theme.Text
			btn.Font = Enum.Font.SourceSans
			btn.TextSize = 13
			btn.Text = text
			btn.ZIndex = 100

			btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Settings.Theme.ButtonHover end)
			btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Settings.Theme.Main1 end)
			btn.MouseButton1Click:Connect(function()
				contextMenu:Destroy()
				cb()
			end)
		end

		addOption("Decompile Source", function()
			if node.InstanceObj and ScriptViewer then
				ScriptViewer.ViewScript(node.InstanceObj)
			end
		end)

		addOption("Focus in Explorer", function()
			if node.InstanceObj and Explorer then
				if Explorer.SelectObject then
					Explorer.SelectObject(node.InstanceObj)
				elseif Explorer.ViewObj then
					Explorer.ViewObj(node.InstanceObj)
				end
			end
		end)

		addOption("Copy Path", function()
			if node.InstanceObj then
				copyText(getPath(node.InstanceObj), "Copied script path.")
			end
		end)

		addOption("Copy Source Code", function()
			if node.InstanceObj and env.readfile and node.FilePath then
				local ok, source = pcall(env.readfile, node.FilePath)
				if ok then copyText(source, "Copied code.") end
			end
		end)

		local itemsCount = #menuLayout:GetChildren() - 1
		contextMenu.Size = UDim2.new(0, 150, 0, itemsCount * 24)

		-- Close context menu on clicking elsewhere
		local con
		con = service.UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
				contextMenu:Destroy()
				con:Disconnect()
			end
		end)
	end

	-- Details Sidebar Inspector
	local function showNodeDetails(node)
		if not sidePanel then return end
		sidePanel.Visible = true

		sideTitle.Text = node.Name
		sidePath.Text = node.InstanceObj and getPath(node.InstanceObj) or "Path unavailable"
		sideMeta.Text = tostring(node.Class) .. " | key " .. tostring(node.Key:sub(1,8))
		sideRole.Text = "Role: " .. node.Role:upper()
		
		if node.Role == "Core Logic" then
			sideRole.TextColor3 = Color3.fromRGB(239, 68, 68)
		elseif node.Role == "Remote Gateway" then
			sideRole.TextColor3 = Color3.fromRGB(59, 130, 246)
		else
			sideRole.TextColor3 = Settings.Theme.Text
		end

		-- Build relations text
		local incoming = {}
		for _, edge in ipairs(edgesData) do
			if edge.toKey == node.Key then
				local fNode = nodesData[edge.fromKey]
				if fNode then table.insert(incoming, fNode.Name) end
			end
		end
		sideIncoming.Text = #incoming > 0 and table.concat(incoming, ", ") or "None"

		local outgoing = {}
		for _, edge in ipairs(edgesData) do
			if edge.fromKey == node.Key then
				local tNode = nodesData[edge.toKey]
				if tNode then table.insert(outgoing, tNode.Name) end
			end
		end
		sideOutgoing.Text = #outgoing > 0 and table.concat(outgoing, ", ") or "None"
	end

	local function clearCanvas()
		for _, frame in pairs(nodeFrames) do
			frame:Destroy()
		end
		table.clear(nodeFrames)
		for _, line in ipairs(edgeLines) do
			line:Destroy()
		end
		table.clear(edgeLines)
		if contextMenu then contextMenu:Destroy() end
		if sidePanel then sidePanel.Visible = false end
		selectedNodeKey = nil
		hoveredNodeKey = nil
	end

	local function scan()
		scanToken += 1
		local token = scanToken
		clearCanvas()
		table.clear(nodesData)
		table.clear(edgesData)
		table.clear(edgesByNode)

		window:SetTitle("Script Dependency Graph")
		if not env.DecompileCache or not env.DecompileCache.GetEntries or not env.isfile then
			statusLabel.Text = "Cache unavailable. Run Code Search > Index Scripts first."
			return
		end

		statusLabel.Text = "Scanning cached scripts..."
		task.spawn(function()
			local entries, cacheDir = env.DecompileCache.GetEntries()
			local byKey, remotes = scriptByKey(), collectRemotes()
			
			local scanned = 0
			local remoteHits = 0

			-- Pass 1: Parse all scripts and build nodes & adjacency lists
			local inDegree = {} -- Key -> Count
			local tempRelations = {} -- Key -> list of required keys

			for key, entry in pairs(entries) do
				if token ~= scanToken then return end
				if entry.File then
					local filePath = cacheDir .. "/" .. tostring(entry.File)
					if env.isfile(filePath) then
						local ok, source = pcall(env.readfile, filePath)
						if ok and type(source) == "string" then
							scanned += 1
							tempRelations[key] = {}
							inDegree[key] = inDegree[key] or 0

							-- Find requires
							local relationSeen = {}
							for block in source:gmatch("require%s*%b()") do
								-- Match other script names in require
								for otherKey, otherEntry in pairs(entries) do
									if otherKey ~= key and otherEntry.Name then
										if not relationSeen[otherKey] and requireBlockMentionsName(block, otherEntry.Name) then
											relationSeen[otherKey] = true
											table.insert(tempRelations[key], otherKey)
											inDegree[otherKey] = (inDegree[otherKey] or 0) + 1
										end
									end
								end
							end

							-- Find remotes
							local lower = source:lower()
							local hasRemote = false
							for _, remote in ipairs(remotes) do
								if #remote.Name >= 3 and lower:find(remote.Name:lower(), 1, true) then
									hasRemote = true
									remoteHits += 1
								end
							end

							nodesData[key] = {
								Key = key,
								Name = tostring(entry.Name or "Script"),
								Class = tostring(entry.ClassName or "Script"),
								FilePath = filePath,
								InstanceObj = byKey[key],
								HasRemote = hasRemote,
								InDegree = 0,
								Role = "Client Controller"
							}
						end
					end
				end
				if scanned % 30 == 0 then
					statusLabel.Text = ("Reading %d cached scripts..."):format(scanned)
					task.wait()
				end
			end

			-- Pass 2: Apply classification & save edges
			local edgeSet = {}
			for key, node in pairs(nodesData) do
				node.InDegree = inDegree[key] or 0
				
				-- Classify roles
				if node.InDegree >= 3 then
					node.Role = "Core Logic"
				elseif node.HasRemote then
					node.Role = "Remote Gateway"
				elseif node.Class == "ModuleScript" then
					node.Role = "Utility Library"
				end

				-- Register Edges
				local deps = tempRelations[key]
				if deps then
					for _, depKey in ipairs(deps) do
						if nodesData[depKey] then
							local edgeId = tostring(key) .. ">" .. tostring(depKey)
							if not edgeSet[edgeId] then
								edgeSet[edgeId] = true
								local edge = { fromKey = key, toKey = depKey }
								table.insert(edgesData, edge)
								edgesByNode[key] = edgesByNode[key] or {}
								edgesByNode[depKey] = edgesByNode[depKey] or {}
								table.insert(edgesByNode[key], edge)
								table.insert(edgesByNode[depKey], edge)
							end
						end
					end
				end
			end

			-- Pass 3: Lay out nodes dynamically and render
			local index = 0
			local columns = {
				["Client Controller"] = 1,
				["Remote Gateway"] = 2,
				["Core Logic"] = 3,
				["Utility Library"] = 4
			}
			local colY = {100, 100, 100, 100}

			for key, node in pairs(nodesData) do
				local col = columns[node.Role] or 1
				local x = col * 260 - 150
				local y = colY[col]
				colY[col] = colY[col] + 80

				local nodeFrame = Instance.new("Frame")
				nodeFrame.BackgroundColor3 = Settings.Theme.Main1
				nodeFrame.BorderColor3 = Settings.Theme.Outline2
				nodeFrame.BorderSizePixel = 1
				nodeFrame.Size = UDim2.new(0, 180, 0, 48)
				nodeFrame.Position = UDim2.new(0, x, 0, y)
				nodeFrame.ZIndex = 10
				nodeFrame.Parent = listFrame

				local c = Instance.new("UICorner", nodeFrame)
				c.CornerRadius = UDim.new(0, 4)

				-- Node Header Name
				local nameLbl = Instance.new("TextLabel", nodeFrame)
				nameLbl.BackgroundTransparency = 1
				nameLbl.ZIndex = 11
				nameLbl.Position = UDim2.new(0, 8, 0, 4)
				nameLbl.Size = UDim2.new(1, -16, 0, 18)
				nameLbl.Font = Enum.Font.SourceSansBold
				nameLbl.TextSize = 13
				nameLbl.TextColor3 = Settings.Theme.Text
				nameLbl.TextXAlignment = Enum.TextXAlignment.Left
				nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
				nameLbl.Text = node.Name

				-- Role Badge
				local badgeLbl = Instance.new("TextLabel", nodeFrame)
				badgeLbl.BackgroundTransparency = 1
				badgeLbl.ZIndex = 11
				badgeLbl.Position = UDim2.new(0, 8, 0, 22)
				badgeLbl.Size = UDim2.new(1, -16, 0, 16)
				badgeLbl.Font = Enum.Font.SourceSans
				badgeLbl.TextSize = 11
				badgeLbl.TextXAlignment = Enum.TextXAlignment.Left
				badgeLbl.Text = "[" .. node.Role .. "]"

				if node.Role == "Core Logic" then
					badgeLbl.TextColor3 = Color3.fromRGB(239, 68, 68)
				elseif node.Role == "Remote Gateway" then
					badgeLbl.TextColor3 = Color3.fromRGB(59, 130, 246)
				else
					badgeLbl.TextColor3 = Settings.Theme.PlaceholderText
				end

				nodeFrames[key] = nodeFrame

				nodeFrame.MouseEnter:Connect(function()
					hoveredNodeKey = key
					updateLines()
				end)
				nodeFrame.MouseLeave:Connect(function()
					if hoveredNodeKey == key then
						hoveredNodeKey = nil
						updateLines()
					end
				end)

				-- Interactivity: Drag & Drop
				local dragging = false
				local dragStart, startPos, dragInput

				nodeFrame.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						selectedNodeKey = key
						updateLines()
						dragging = true
						dragStart = input.Position
						startPos = nodeFrame.Position

						local con
						con = input.Changed:Connect(function()
							if input.UserInputState == Enum.UserInputState.End then
								dragging = false
								con:Disconnect()
							end
						end)
					elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
						selectedNodeKey = key
						updateLines()
						showContextMenu(Vector2.new(nodeFrame.Position.X.Offset + 10, nodeFrame.Position.Y.Offset + 10), node)
					end
				end)

				nodeFrame.InputChanged:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseMovement then
						dragInput = input
					end
				end)

				service.UserInputService.InputChanged:Connect(function(input)
					if input == dragInput and dragging then
						local delta = input.Position - dragStart
						nodeFrame.Position = UDim2.new(0, startPos.X.Offset + delta.X, 0, startPos.Y.Offset + delta.Y)
						updateLines()
					end
				end)

				-- Double click to inspect
				nodeFrame.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						local now = tick()
						if nodeFrame:GetAttribute("LastClick") and now - nodeFrame:GetAttribute("LastClick") < 0.35 then
							showNodeDetails(node)
						end
						nodeFrame:SetAttribute("LastClick", now)
					end
				end)
			end

			-- Auto size scrolling canvas
			local maxX, maxY = 800, 600
			for _, frame in pairs(nodeFrames) do
				maxX = math.max(maxX, frame.Position.X.Offset + 300)
				maxY = math.max(maxY, frame.Position.Y.Offset + 200)
			end
			listFrame.CanvasSize = UDim2.new(0, maxX, 0, maxY)

			updateLines()
			statusLabel.Text = ("Graph built: %d nodes, %d unique links, %d remotes. Select or hover a node to show links."):format(scanned, #edgesData, remoteHits)
		end)
	end

	local function button(parent, text, x, w, cb)
		local b = createSimple("TextButton",{AutoButtonColor=false, BackgroundColor3=Settings.Theme.Button, BorderColor3=Settings.Theme.Outline2, Font=Enum.Font.SourceSans, Position=UDim2.new(0,x,0,4), Size=UDim2.new(0,w,0,22), Text=text, TextColor3=Settings.Theme.Text, TextSize=14, Parent=parent})
		b.MouseButton1Click:Connect(cb)
		Lib.ButtonAnim(b,{Mode=2, StartColor=Settings.Theme.Button, HoverColor=Settings.Theme.ButtonHover, PressColor=Settings.Theme.ButtonPress, OutlineColor=Settings.Theme.Outline2})
	end

	DependencyGraph.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Script Dependency Graph")
		window:Resize(780, 480)
		DependencyGraph.Window = window

		local content = window.GuiElems.Content

		local toolbar = createSimple("Frame",{BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, Size=UDim2.new(1,0,0,32), Parent=content})
		button(toolbar,"Scan Graph",6,86,scan)

		statusLabel = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Position=UDim2.new(0,100,0,4), Size=UDim2.new(1,-106,0,22), Text="Run Code Search index first, then click Scan Graph.", TextColor3=Settings.Theme.PlaceholderText, TextSize=13, TextTruncate=Enum.TextTruncate.AtEnd, TextXAlignment=Enum.TextXAlignment.Left, Parent=toolbar})

		local mainArea = createSimple("Frame",{BackgroundTransparency=1, Position=UDim2.new(0,0,0,32), Size=UDim2.new(1,0,1,-32), Parent=content})

		-- Collapsible Side Panel (Initially Collapsed/Hidden)
		sidePanel = createSimple("Frame",{BackgroundColor3=Settings.Theme.Main1, BorderColor3=Settings.Theme.Outline2, BorderSizePixel=1, Position=UDim2.new(1,-220,0,0), Size=UDim2.new(0,220,1,0), Visible=false, ZIndex=50, Parent=mainArea})
		
		local sidePad = Instance.new("UIPadding", sidePanel)
		sidePad.PaddingLeft, sidePad.PaddingRight, sidePad.PaddingTop, sidePad.PaddingBottom = UDim.new(0,8), UDim.new(0,8), UDim.new(0,8), UDim.new(0,8)

		local sideLayout = Instance.new("UIListLayout", sidePanel)
		sideLayout.Padding = UDim.new(0,6)

		sideTitle = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSansBold, Size=UDim2.new(1,0,0,20), Text="Script Name", TextColor3=Settings.Theme.Text, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left, Parent=sidePanel})
		sideRole = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSansBold, Size=UDim2.new(1,0,0,16), Text="Role: Core Logic", TextColor3=Settings.Theme.Important, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left, Parent=sidePanel})
		sideMeta = createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSans, Size=UDim2.new(1,0,0,16), Text="Class & ID", TextColor3=Settings.Theme.PlaceholderText, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left, Parent=sidePanel})
		
		createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSansBold, Size=UDim2.new(1,0,0,16), Text="Path:", TextColor3=Settings.Theme.PlaceholderText, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left, Parent=sidePanel})
		sidePath = createSimple("TextBox",{BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, Font=Enum.Font.Code, Size=UDim2.new(1,0,0,40), TextEditable=false, ClearTextOnFocus=false, TextWrapped=true, TextSize=10, TextColor3=Settings.Theme.Text, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, Parent=sidePanel})
		Instance.new("UIPadding", sidePath).PaddingLeft = UDim.new(0,4)

		createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSansBold, Size=UDim2.new(1,0,0,16), Text="Required By (Incoming):", TextColor3=Settings.Theme.PlaceholderText, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left, Parent=sidePanel})
		sideIncoming = createSimple("TextBox",{BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, Font=Enum.Font.SourceSans, Size=UDim2.new(1,0,0,50), TextEditable=false, ClearTextOnFocus=false, TextWrapped=true, TextSize=11, TextColor3=Settings.Theme.Text, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, Parent=sidePanel})
		Instance.new("UIPadding", sideIncoming).PaddingLeft = UDim.new(0,4)

		createSimple("TextLabel",{BackgroundTransparency=1, Font=Enum.Font.SourceSansBold, Size=UDim2.new(1,0,0,16), Text="Requires (Outgoing):", TextColor3=Settings.Theme.PlaceholderText, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left, Parent=sidePanel})
		sideOutgoing = createSimple("TextBox",{BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, Font=Enum.Font.SourceSans, Size=UDim2.new(1,0,0,50), TextEditable=false, ClearTextOnFocus=false, TextWrapped=true, TextSize=11, TextColor3=Settings.Theme.Text, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, Parent=sidePanel})
		Instance.new("UIPadding", sideOutgoing).PaddingLeft = UDim.new(0,4)

		local closeSideBtn = createSimple("TextButton",{AutoButtonColor=false, BackgroundColor3=Settings.Theme.Button, BorderSizePixel=0, Font=Enum.Font.SourceSans, Size=UDim2.new(1,0,0,24), Text="Close Inspector", TextColor3=Settings.Theme.Text, TextSize=13, Parent=sidePanel})
		closeSideBtn.MouseButton1Click:Connect(function() sidePanel.Visible = false end)
		Lib.ButtonAnim(closeSideBtn,{Mode=2, StartColor=Settings.Theme.Button, HoverColor=Settings.Theme.ButtonHover, PressColor=Settings.Theme.ButtonPress})

		-- Node Canvas area
		listFrame = createSimple("ScrollingFrame",{Active=true, AutomaticCanvasSize=Enum.AutomaticSize.None, BackgroundColor3=Settings.Theme.Main2, BorderSizePixel=0, BottomImage="", CanvasSize=UDim2.new(0,2000,0,2000), Position=UDim2.new(0,0,0,0), ScrollBarImageColor3=Color3.fromRGB(70,70,70), ScrollBarThickness=10, Size=UDim2.new(1,0,1,0), TopImage="", Parent=mainArea})
	end

	DependencyGraph.ShowForScript = function(scr)
		if not window then
			DependencyGraph.Init()
		end
		if window then
			window:Show()
		end
		scan()

		task.spawn(function()
			-- Wait for scan and node frame creation to complete
			task.wait(0.25)
			if not env.DecompileCache or not env.DecompileCache.GetScriptKey then return end
			local ok, key = pcall(env.DecompileCache.GetScriptKey, scr)
			if ok and key then
				local frame = nodeFrames[key]
				if frame then
					selectedNodeKey = key
					updateLines()
					-- Highlight node border
					frame.BorderColor3 = Color3.fromRGB(255, 170, 0)
					frame.BorderSizePixel = 2
					-- Scroll listFrame to center on this node
					local canvasX = math.clamp(frame.Position.X.Offset - 250, 0, math.max(0, listFrame.CanvasSize.X.Offset - listFrame.AbsoluteSize.X))
					local canvasY = math.clamp(frame.Position.Y.Offset - 180, 0, math.max(0, listFrame.CanvasSize.Y.Offset - listFrame.AbsoluteSize.Y))
					listFrame.CanvasPosition = Vector2.new(canvasX, canvasY)
					-- Slide open sidebar inspector
					local nodeData = nodesData[key]
					if nodeData then
						showNodeDetails(nodeData)
					end
				end
			end
		end)
	end

	DependencyGraph.Scan = scan
	return DependencyGraph
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
