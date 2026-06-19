--!nocheck
--[[
	Task Router Module
	Assigns task ownership between HelperServer/C++ and Luau-side modules.
]]

local Main, Lib, Apps, Settings
local Explorer, ScriptViewer, TaskRouter
local API, RMD, env, service, plr, create, createSimple

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
	ScriptViewer = Apps.ScriptViewer
	TaskRouter = Apps.TaskRouter
end

local function main()
	local TaskRouter = {}
	local window, inputBox, statusLabel, outputFrame

	local function setStatus(text)
		if statusLabel then statusLabel.Text = text end
	end

	local function clearRows()
		if not outputFrame then return end
		for _, child in pairs(outputFrame:GetChildren()) do
			if child:IsA("GuiButton") or child:IsA("TextLabel") or child:IsA("Frame") then
				child:Destroy()
			end
		end
	end

	local function decodeJson(body)
		local httpService = service and service.HttpService
		if not httpService then
			local ok, resolved = pcall(game.GetService, game, "HttpService")
			if ok then httpService = resolved end
		end
		if not httpService or type(body) ~= "string" then return nil end
		local ok, decoded = pcall(function()
			return httpService:JSONDecode(body)
		end)
		return ok and decoded or nil
	end

	local function countToken(text, token)
		local count, pos = 0, 1
		while true do
			local startPos, endPos = text:find(token, pos, true)
			if not startPos then break end
			count += 1
			pos = endPos + 1
		end
		return count
	end

	local roleProfiles = {
		{
			id = "cxx_helper_core",
			label = "C++ Helper Core",
			language = "C++",
			module = "HelperServer",
			summary = "Fast indexing, source analysis, cache maintenance, search, and structured export.",
			keywords = {
				index = 7, search = 7, cache = 7, analysis = 6, analyze = 6, deobfuscate = 8,
				json = 6, parse = 5, source = 4, snippet = 4, dependency = 4, graph = 4,
				report = 4, export = 4, log = 3, token = 3, score = 3, pack = 4
			}
		},
		{
			id = "luau_ui",
			label = "Luau UI / Explorer",
			language = "Luau",
			module = "Explorer",
			summary = "Immediate UI, tree rendering, selection handling, tabs, buttons, and menus.",
			keywords = {
				ui = 6, window = 6, button = 7, tab = 7, menu = 7, tree = 8, selection = 8,
				explorer = 7, panel = 5, label = 4, textbox = 6, render = 6, layout = 6,
				context = 5, click = 5, select = 6, copy = 4, view = 4
			}
		},
		{
			id = "luau_runtime",
			label = "Luau Runtime Monitor",
			language = "Luau",
			module = "RuntimeInspector",
			summary = "Live object capture, remotes, property tracking, timeline, and client state.",
			keywords = {
				runtime = 8, live = 6, remote = 8, remotes = 8, property = 7, tracker = 6,
				timeline = 8, snapshot = 6, capture = 6, monitor = 7, buffer = 5,
				record = 5, event = 5, inspector = 7, state = 4
			}
		},
		{
			id = "ai_context",
			label = "AI Context Packager",
			language = "Mixed",
			module = "CopyToAI",
			summary = "Prompt building, summary packing, context export, and beginner-friendly explanation.",
			keywords = {
				ai = 8, prompt = 8, context = 8, copy = 6, summar = 7, beginner = 5,
				explain = 5, pack = 5, export = 5, guide = 4
			}
		}
	}

	local function scoreProfile(text, profile)
		local score = 0
		local signals = {}
		for token, weight in pairs(profile.keywords) do
			local hits = countToken(text, token)
			if hits > 0 then
				score += hits * weight
				if #signals < 6 then
					signals[#signals + 1] = token
				end
			end
		end
		return {Profile = profile, Score = score, Signals = signals}
	end

	local function buildLocalDecision(taskText)
		local text = tostring(taskText or ""):lower()
		local scored = {}
		for _, profile in ipairs(roleProfiles) do
			scored[#scored + 1] = scoreProfile(text, profile)
		end
		table.sort(scored, function(a, b)
			if a.Score == b.Score then
				return a.Profile.id < b.Profile.id
			end
			return a.Score > b.Score
		end)

		local function confidence(score)
			if score <= 0 then return 35 end
			return math.min(98, 40 + score * 4)
		end

		local function pack(item)
			if not item then
				return {
					role = "unknown",
					label = "Unknown",
					language = "Unknown",
					module = "Unknown",
					confidence = 35,
					score = 0,
					summary = "No clear match",
					signals = {},
				}
			end
			return {
				role = item.Profile.id,
				label = item.Profile.label,
				language = item.Profile.language,
				module = item.Profile.module,
				confidence = confidence(item.Score),
				score = item.Score,
				summary = item.Profile.summary,
				signals = item.Signals,
			}
		end

		local primary = pack(scored[1])
		local secondary = pack(scored[2])
		local workflow = {
			"Send heavy, repeated, or cached work to " .. primary.module .. ".",
			"Keep UI, selection, and click handling in Luau.",
			"Fall back to cache-first flows if the helper is offline.",
		}
		return {
			ok = true,
			taskBytes = #taskText,
			primary = primary,
			secondary = secondary,
			workflow = workflow,
		}
	end

	local function getDecision(taskText)
		if env.HelperServer and env.HelperServer.AssignRole then
			local active = true
			if env.HelperServer.IsActive then
				active = env.HelperServer.IsActive(false)
			end
			if active then
				local body = env.HelperServer.AssignRole(taskText)
				local decoded = decodeJson(body)
				if decoded and decoded.ok == true then
					return decoded, "helper"
				end
			end
		end
		return buildLocalDecision(taskText), "local"
	end

	local function renderDecision(decision, sourceKind)
		clearRows()
		if not decision then
			setStatus("No decision produced.")
			return
		end

		local primary = decision.primary or {}
		local secondary = decision.secondary or {}
		local rows = {
			("Primary: %s [%s]"):format(tostring(primary.label or "Unknown"), tostring(primary.language or "Unknown")),
			("Module: %s | Confidence: %s%% | Source: %s"):format(tostring(primary.module or "Unknown"), tostring(primary.confidence or 0), sourceKind or "local"),
			("Why: %s"):format(tostring(primary.summary or "")),
			("Signals: %s"):format(#(primary.signals or {}) > 0 and table.concat(primary.signals, ", ") or "none"),
			("Secondary: %s [%s]"):format(tostring(secondary.label or "Unknown"), tostring(secondary.language or "Unknown")),
		}

		for _, text in ipairs(rows) do
			local label = createSimple("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSans,
				Size = UDim2.new(1, -8, 0, 22),
				Text = text,
				TextColor3 = Settings.Theme.Text,
				TextSize = 14,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = outputFrame
			})
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 6)
			pad.Parent = label
		end

		for _, step in ipairs(decision.workflow or {}) do
			local label = createSimple("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSans,
				Size = UDim2.new(1, -8, 0, 20),
				Text = "- " .. tostring(step),
				TextColor3 = Settings.Theme.PlaceholderText,
				TextSize = 13,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = outputFrame
			})
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 6)
			pad.Parent = label
		end

		setStatus(("Task routed via %s."):format(sourceKind or "local"))
	end

	TaskRouter.RouteTask = function(taskText)
		local decision, sourceKind = getDecision(taskText)
		return decision, sourceKind
	end

	TaskRouter.ShowTask = function(taskText)
		local decision, sourceKind = getDecision(taskText)
		renderDecision(decision, sourceKind)
		return decision, sourceKind
	end

	TaskRouter.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Task Router")
		window:Resize(640, 380)
		TaskRouter.Window = window

		local content = window.GuiElems.Content
		local toolbar = createSimple("Frame", {
			BackgroundColor3 = Settings.Theme.Main2,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 66),
			Parent = content
		})

		inputBox = createSimple("TextBox", {
			BackgroundColor3 = Settings.Theme.TextBox,
			BorderColor3 = Settings.Theme.Outline3,
			ClearTextOnFocus = false,
			Font = Enum.Font.SourceSans,
			PlaceholderColor3 = Settings.Theme.PlaceholderText,
			PlaceholderText = "Describe the task, module, or workflow to route...",
			Position = UDim2.new(0, 6, 0, 34),
			Size = UDim2.new(1, -12, 0, 22),
			Text = "",
			TextColor3 = Settings.Theme.Text,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = toolbar
		})

		statusLabel = createSimple("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			Position = UDim2.new(0, 140, 0, 6),
			Size = UDim2.new(1, -146, 0, 20),
			Text = "Route work to the engine that fits it best.",
			TextColor3 = Settings.Theme.PlaceholderText,
			TextSize = 14,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = toolbar
		})

		local routeButton = createSimple("TextButton", {
			BackgroundColor3 = Settings.Theme.Button,
			BorderColor3 = Settings.Theme.Outline2,
			Font = Enum.Font.SourceSans,
			Position = UDim2.new(0, 6, 0, 6),
			Size = UDim2.new(0, 72, 0, 22),
			Text = "Route",
			TextColor3 = Settings.Theme.Text,
			TextSize = 14,
			Parent = toolbar
		})
		local clearButton = createSimple("TextButton", {
			BackgroundColor3 = Settings.Theme.Button,
			BorderColor3 = Settings.Theme.Outline2,
			Font = Enum.Font.SourceSans,
			Position = UDim2.new(0, 84, 0, 6),
			Size = UDim2.new(0, 54, 0, 22),
			Text = "Clear",
			TextColor3 = Settings.Theme.Text,
			TextSize = 14,
			Parent = toolbar
		})

		outputFrame = createSimple("ScrollingFrame", {
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Settings.Theme.Main2,
			BorderSizePixel = 0,
			BottomImage = "",
			CanvasSize = UDim2.new(0, 0, 0, 0),
			Position = UDim2.new(0, 0, 0, 66),
			ScrollBarImageColor3 = Color3.fromRGB(70, 70, 70),
			ScrollBarThickness = 10,
			Size = UDim2.new(1, 0, 1, -66),
			TopImage = "",
			Parent = content
		})

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = outputFrame

		local padding = Instance.new("UIPadding")
		padding.PaddingBottom = UDim.new(0, 6)
		padding.PaddingLeft = UDim.new(0, 4)
		padding.PaddingRight = UDim.new(0, 4)
		padding.PaddingTop = UDim.new(0, 4)
		padding.Parent = outputFrame

		routeButton.MouseButton1Click:Connect(function()
			local text = tostring(inputBox.Text or "")
			if text == "" then
				setStatus("Type a task first.")
				clearRows()
				return
			end
			TaskRouter.ShowTask(text)
		end)

		clearButton.MouseButton1Click:Connect(function()
			inputBox.Text = ""
			clearRows()
			setStatus("Cleared.")
		end)

		inputBox.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				TaskRouter.ShowTask(tostring(inputBox.Text or ""))
			end
		end)
	end

	return TaskRouter
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
