--!nocheck
--[[
	Auto Security Auditor Module

	Scans the game structure and script contents for security vulnerabilities,
	exposed RemoteEvents, suspicious require loaders, and obfuscated code.
]]

-- Common Locals
local Main, Lib, Apps, Settings -- Main Containers
local Explorer, Notepad, SecurityAuditor, Theme -- Major Apps
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
	Notepad = t.Notepad
	SecurityAuditor = t.SecurityAuditor
	Theme = t.Theme
end

local function main()
	local SecurityAuditor = {}
	local window, statusLabel, listFrame
	local scanToken = 0
	local isScanning = false
	local deepScanEnabled = false

	local function setStatus(text)
		if statusLabel then
			statusLabel.Text = text
		end
	end

	local function clearRows()
		if not listFrame then return end
		for _, child in pairs(listFrame:GetChildren()) do
			if child:IsA("GuiButton") or child:IsA("TextLabel") or child:IsA("Frame") then
				child:Destroy()
			end
		end
	end

	local function getPath(obj)
        if Main and Main.SafeGetInstancePath then return Main.SafeGetInstancePath(obj) end
		local ok, path = pcall(function()
			if Explorer and Explorer.GetInstancePath then
				return Explorer.GetInstancePath(obj)
			end
			return obj:GetFullName()
		end)
		return ok and tostring(path) or tostring(obj)
	end

	local function pad(gui, left)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, left or 8)
		padding.PaddingRight = UDim.new(0, 8)
		padding.Parent = gui
	end

	-- Custom color palette for severities
	local colors = {
		High = Color3.fromRGB(244, 63, 94),   -- Red
		Medium = Color3.fromRGB(251, 146, 60), -- Orange
		Low = Color3.fromRGB(250, 204, 21),   -- Yellow
	}

	-- Renders a finding row
	local function addFindingRow(finding)
		local row = createSimple("Frame", {
			BackgroundColor3 = Settings.Theme.Main2,
			BorderColor3 = Settings.Theme.Outline1,
			BorderSizePixel = 1,
			Size = UDim2.new(1, -8, 0, 48),
			Parent = listFrame
		})
		Theme.ApplyRounding(row, 4)

		-- Severity Tag
		local sevTag = createSimple("TextLabel", {
			BackgroundColor3 = colors[finding.Severity] or Settings.Theme.Button,
			BorderSizePixel = 0,
			Font = Enum.Font.SourceSansBold,
			Position = UDim2.new(0, 8, 0, 8),
			Size = UDim2.new(0, 52, 0, 16),
			Text = string.upper(finding.Severity),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 12,
			Parent = row
		})
		Theme.ApplyRounding(sevTag, 3)

		-- Finding Title
		local _title = createSimple("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			Position = UDim2.new(0, 68, 0, 6),
			Size = UDim2.new(1, -210, 0, 20),
			Text = finding.Title,
			TextColor3 = Settings.Theme.Text,
			TextSize = 14,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row
		})

		-- Description / Path
		local _desc = createSimple("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			Position = UDim2.new(0, 8, 0, 26),
			Size = UDim2.new(1, -150, 0, 18),
			Text = finding.Description,
			TextColor3 = Settings.Theme.PlaceholderText,
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row
		})

		-- Select button (focus in Explorer)
		local selectBtn = createSimple("TextButton", {
			BackgroundColor3 = Settings.Theme.Button,
			BorderSizePixel = 0,
			Font = Enum.Font.SourceSansBold,
			Position = UDim2.new(1, -132, 0, 12),
			Size = UDim2.new(0, 58, 0, 24),
			Text = "Select",
			TextColor3 = Settings.Theme.Text,
			TextSize = 13,
			Parent = row
		})
		Theme.StyleButton(selectBtn, false)

		selectBtn.MouseButton1Click:Connect(function()
			if Explorer and Explorer.Selection and Explorer.ClassIcons then
				local node = Explorer.Selection.Map and Explorer.Selection.Map[finding.Object]
				if not node then
					-- Search for the node in Explorer list
					for _, n in pairs(Explorer.Selection) do
						if n.Obj == finding.Object then
							node = n
							break
						end
					end
				end
				-- If node not cached directly, set Selection using Explorer logic
				pcall(function()
					Explorer.Selection:Set(finding.Object)
					Explorer.Refresh()
					setStatus("Focused " .. finding.Object.Name .. " in Explorer.")
				end)
			end
		end)

		-- View Script button (if script)
		if finding.Object:IsA("LuaSourceContainer") then
			local viewBtn = createSimple("TextButton", {
				BackgroundColor3 = Settings.Theme.ListSelection,
				BorderSizePixel = 0,
				Font = Enum.Font.SourceSansBold,
				Position = UDim2.new(1, -66, 0, 12),
				Size = UDim2.new(0, 58, 0, 24),
				Text = "View",
				TextColor3 = Settings.Theme.Text,
				TextSize = 13,
				Parent = row
			})
			Theme.StyleButton(viewBtn, true)

			viewBtn.MouseButton1Click:Connect(function()
				if Notepad then
					Notepad.ViewScript(finding.Object)
				end
			end)
		end
	end

	-- Core scanning logic
	local function runScan(token)
		isScanning = true
		setStatus("Scanning services...")
		clearRows()

		local targetServices = {
			workspace,
			service.ReplicatedStorage,
			service.ReplicatedFirst,
			service.Lighting,
			service.StarterPack,
			service.StarterGui,
			service.StarterPlayer,
			service.SoundService,
			service.Teams
		}

		local findings = {}
		local totalScanned = 0
		local targetMap = {}
		for _, srv in ipairs(targetServices) do
			if srv then targetMap[srv] = true end
		end
		local function isInTarget(obj)
			local cur = obj
			while cur and cur ~= game do
				if targetMap[cur] then return true end
				cur = cur.Parent
			end
			return false
		end
		local function collectCandidates()
			if env.RefreshClientSurface then
				local surface = env.RefreshClientSurface(false, false)
				local filtered = {}
				for _, obj in ipairs(surface.AllInstances or {}) do
					if isInTarget(obj) then filtered[#filtered + 1] = obj end
				end
				return filtered
			end
			local filtered = {}
			for _, srv in ipairs(targetServices) do
				if srv then
					local ok, descendants = pcall(srv.GetDescendants, srv)
					if ok then
						for _, obj in ipairs(descendants) do filtered[#filtered + 1] = obj end
					end
				end
			end
			return filtered
		end

		-- Insecure remote keywords
		local insecureKeywords = {
			"admin", "give", "buy", "cash", "money", "ban", "kick", "kill", "points", "rank", "gold", "purchase", "set", "save", "load", "fire"
		}

		-- Suspicious script keywords
		local suspiciousScriptKeywords = {
			"backdoor", "vaccine", "lag", "anti", "loader", "virus", "weld", "fix", "free", "admin"
		}

		for _, obj in ipairs(collectCandidates()) do
				if token ~= scanToken then return end
				totalScanned = totalScanned + 1

				if totalScanned % 100 == 0 then
					setStatus(string.format("Scanning: %d instances, found %d issues...", totalScanned, #findings))
					task.wait()
				end

				-- 1. Exposed Remotes Auditing
				if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
					local lowerName = obj.Name:lower()
					local isGeneric = false
					for _, keyword in ipairs(insecureKeywords) do
						if lowerName:find(keyword, 1, true) then
							isGeneric = true
							break
						end
					end

					if isGeneric then
						local severity = "Low"
						if lowerName:find("ban", 1, true) or lowerName:find("kick", 1, true) or lowerName:find("give", 1, true) or lowerName:find("kill", 1, true) or lowerName:find("admin", 1, true) then
							severity = "High"
						elseif obj:IsA("RemoteFunction") then
							severity = "Medium"
						end

						table.insert(findings, {
							Severity = severity,
							Title = string.format("Exposed Remote: '%s' (%s)", obj.Name, obj.ClassName),
							Description = "Path: " .. getPath(obj),
							Object = obj
						})
					end
				end

				-- 2. Heuristic Script Auditing (Static properties)
				if obj:IsA("LuaSourceContainer") then
					local lowerName = obj.Name:lower()
					local isSuspiciousName = false
					for _, keyword in ipairs(suspiciousScriptKeywords) do
						if lowerName:find(keyword, 1, true) then
							isSuspiciousName = true
							break
						end
					end

					if isSuspiciousName then
						table.insert(findings, {
							Severity = "Medium",
							Title = string.format("Suspicious Script Name: '%s'", obj.Name),
							Description = "Static script name suggests backdoor loader. Path: " .. getPath(obj),
							Object = obj
						})
					end
				end
		end

		-- 3. Deep script content audit (requires decompile)
		if deepScanEnabled and env.decompile then
			local scripts = {}
			for _, obj in ipairs(collectCandidates()) do
				if obj:IsA("LuaSourceContainer") then
					table.insert(scripts, obj)
				end
			end

			setStatus(string.format("Deep Scan: Auditing contents of %d scripts...", #scripts))
			task.wait()

			for scriptIndex, scr in ipairs(scripts) do
				if token ~= scanToken then return end
				setStatus(string.format("Deep Scan: %d/%d scripts analyzed (%d issues)...", scriptIndex, #scripts, #findings))

				-- Run decompile safely
				local success, source = pcall(env.decompile, scr)
				if success and type(source) == "string" and #source > 0 then
					local analyzedViaHelper = false

					-- Try helper AST deep analysis
					local req = env.request or (syn and syn.request) or (http and http.request) or http_request or request
					if req then
						local okReq, result = pcall(function()
							return req({
								Url = "http://localhost:8080/analyze-source-deep",
								Method = "POST",
								Headers = {
									["Content-Type"] = "text/plain"
								},
								Body = source
							})
						end)

						if okReq and result and result.StatusCode == 200 then
							local okDecode, data = pcall(function()
								return service.HttpService:JSONDecode(result.Body)
							end)

							if okDecode and data and data.findings then
								analyzedViaHelper = true
								for _, finding in ipairs(data.findings) do
									table.insert(findings, {
										Severity = finding.severity or "Medium",
										Title = string.format("%s in '%s'", finding.title or "Security finding", scr.Name),
										Description = string.format("[Line %d] %s. Path: %s", finding.line or 0, finding.description or "", getPath(scr)),
										Object = scr
									})
								end
							end
						end
					end

					-- Fallback to regex checks if helper analysis was unavailable
					if not analyzedViaHelper then
						-- Check require(number) backdoors
						local backdoorRequire = source:match("require%s*%(%s*%d+%s*%)")
						if backdoorRequire then
							table.insert(findings, {
								Severity = "High",
								Title = string.format("Backdoor Loader in '%s'", scr.Name),
								Description = string.format("Flags require(AssetId): '%s'. Path: %s", backdoorRequire, getPath(scr)),
								Object = scr
							})
						end

						-- Check loadstring
						if source:match("[^%w_]loadstring%s*%(") then
							table.insert(findings, {
								Severity = "Medium",
								Title = string.format("Dynamic Code (loadstring) in '%s'", scr.Name),
								Description = "Script uses loadstring which executes dynamic unverified code. Path: " .. getPath(scr),
								Object = scr
							})
						end

						-- Check obfuscation (high density of decimal escapes)
						local _, escapeCount = source:gsub("\\[0-9][0-9][0-9]", "")
						if escapeCount > 15 then
							table.insert(findings, {
								Severity = "Medium",
								Title = string.format("Obfuscated Code in '%s'", scr.Name),
								Description = string.format("High count of decimal escape sequences (%d found). Path: %s", escapeCount, getPath(scr)),
								Object = scr
							})
						end

						-- Check suspicious webhook urls
						if source:find("discord.com/api/webhooks", 1, true) or source:find("discordapp.com/api/webhooks", 1, true) then
							table.insert(findings, {
								Severity = "Medium",
								Title = string.format("Discord Webhook in '%s'", scr.Name),
								Description = "Script leaks communications or sends data to Discord. Path: " .. getPath(scr),
								Object = scr
							})
						end
					end
				end

				-- Yield every decompile run to avoid client lag
				task.wait()
			end
		end

		-- Render findings
		if token ~= scanToken then return end

		-- Sort findings: High, Medium, Low
		table.sort(findings, function(a, b)
			local severityWeight = { High = 3, Medium = 2, Low = 1 }
			return (severityWeight[a.Severity] or 0) > (severityWeight[b.Severity] or 0)
		end)

		for _, finding in ipairs(findings) do
			addFindingRow(finding)
		end

		local highCount = 0
		local medCount = 0
		local lowCount = 0
		for _, f in ipairs(findings) do
			if f.Severity == "High" then highCount = highCount + 1
			elseif f.Severity == "Medium" then medCount = medCount + 1
			elseif f.Severity == "Low" then lowCount = lowCount + 1 end
		end

		setStatus(string.format("Scan complete: %d High, %d Med, %d Low issues found.", highCount, medCount, lowCount))
		isScanning = false
	end

	SecurityAuditor.Show = function()
		scanToken = scanToken + 1
		clearRows()
		setStatus("Ready to scan.")
		window:Show()
	end

	SecurityAuditor.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Security Auditor")
		window:Resize(520, 420)
		SecurityAuditor.Window = window

		-- Controls Toolbar
		local toolbar = createSimple("Frame", {
			BackgroundColor3 = Settings.Theme.Main1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 0, 32),
			Parent = window.GuiElems.Content
		})

		-- Scan Button
		local scanBtn = createSimple("TextButton", {
			BackgroundColor3 = Settings.Theme.ListSelection,
			BorderSizePixel = 0,
			Font = Enum.Font.SourceSansBold,
			Position = UDim2.new(0, 6, 0, 4),
			Size = UDim2.new(0, 84, 0, 24),
			Text = "Scan Game",
			TextColor3 = Settings.Theme.Text,
			TextSize = 13,
			Parent = toolbar
		})
		Theme.StyleButton(scanBtn, true)

		-- Deep Scan Checkbox Label
		local _deepLabel = createSimple("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			Position = UDim2.new(0, 98, 0, 6),
			Size = UDim2.new(0, 80, 0, 20),
			Text = "Deep Scan (Decompile)",
			TextColor3 = Settings.Theme.Text,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = toolbar
		})

		-- Deep Scan Checkbox Button
		local deepCheck = createSimple("TextButton", {
			BackgroundColor3 = Settings.Theme.Button,
			BorderSizePixel = 1,
			BorderColor3 = Settings.Theme.Outline2,
			Font = Enum.Font.SourceSansBold,
			Position = UDim2.new(0, 230, 0, 8),
			Size = UDim2.new(0, 16, 0, 16),
			Text = "",
			TextColor3 = Settings.Theme.Highlight,
			TextSize = 14,
			Parent = toolbar
		})
		Theme.ApplyRounding(deepCheck, 2)

		deepCheck.MouseButton1Click:Connect(function()
			deepScanEnabled = not deepScanEnabled
			deepCheck.Text = deepScanEnabled and "✓" or ""
		end)

		-- Status Text
		statusLabel = createSimple("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			Position = UDim2.new(0, 256, 0, 6),
			Size = UDim2.new(1, -262, 0, 20),
			Text = "Ready to scan.",
			TextColor3 = Settings.Theme.PlaceholderText,
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = toolbar
		})

		-- Results Scroll Frame
		listFrame = createSimple("ScrollingFrame", {
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Settings.Theme.Main2,
			BorderSizePixel = 0,
			BottomImage = "",
			CanvasSize = UDim2.new(0, 0, 0, 0),
			Position = UDim2.new(0, 0, 0, 32),
			ScrollBarImageColor3 = Color3.fromRGB(70, 70, 70),
			ScrollBarThickness = 10,
			Size = UDim2.new(1, 0, 1, -32),
			TopImage = "",
			Parent = window.GuiElems.Content
		})

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = listFrame

		local padding = Instance.new("UIPadding")
		padding.PaddingBottom = UDim.new(0, 6)
		padding.PaddingLeft = UDim.new(0, 4)
		padding.PaddingRight = UDim.new(0, 4)
		padding.PaddingTop = UDim.new(0, 4)
		padding.Parent = listFrame

		scanBtn.MouseButton1Click:Connect(function()
			if isScanning then return end
			scanToken = scanToken + 1
			local token = scanToken
			task.spawn(function()
				runScan(token)
			end)
		end)
	end

	return SecurityAuditor
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
