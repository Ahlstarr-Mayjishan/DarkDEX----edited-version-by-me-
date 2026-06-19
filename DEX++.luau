--[[
	Dex++
	Version 3.1

	Developed by Chillz
	Decompiler fixed + rspy plugin + adonis bypass by mcdaggitt,
	Dex++ is a revival of Moon's Dex, made to fulfill Moon's Dex prophecy.
]]

local selection
local nodes = {}

local oldgame = game
local game = workspace.Parent

cloneref = cloneref or function(ref)
	if not getreg then return ref end

	local InstanceList

	local a = Instance.new("Part")
	for _, c in pairs(getreg()) do
		if type(c) == "table" and #c then
			if rawget(c, "__mode") == "kvs" then
				for d, e in pairs(c) do
					if e == a then
						InstanceList = c
						break
					end
				end
			end
		end
	end
	local f = {}
	function f.invalidate(g)
		if not InstanceList then
			return
		end
		for b, c in pairs(InstanceList) do
			if c == g then
				InstanceList[b] = nil
				return g
			end
		end
	end
	return f.invalidate
end

local EmbeddedModules = {
    -- [[EMBEDDED_MODULES_PLACEHOLDER]]
}

local isFsSupported = readfile and writefile and isfile and isfolder and listfiles and delfile and delfolder

-- Main vars
local Main, Explorer, Properties, Notepad, Console, SaveInstance, ModelViewer, SettingsWindow, CodeSearch, ScriptRelations, RemoteUsageMap, ObjectLinks, ImageViewer, ClientIndex, ActivityMap, DependencyGraph, SmartSearch, RuntimeInspector, ClientIntelligence, InspectorHub, TaskRouter, ControlCenter, Theme, SmartDecompiler, SecurityAuditor, RemoteFuzzer, PropertyTracker, InstanceSerializer, ThreadManager, IDESync--[[, SecretServicePanel]], DefaultSettings, Notebook, Serializer, Lib local ggv = getgenv or nil
local API, RMD

-- Default Settings
DefaultSettings = (function()
	local rgb = Color3.fromRGB

	return {
		Explorer = {
			_Recurse = true,
			Sorting = true,
			TeleportToOffset = Vector3.new(0,0,0),
			ClickToRename = true,
			AutoUpdateSearch = true,
			AutoUpdateMode = 0, -- 0 Default, 1 no tree update, 2 no descendant events, 3 frozen
			PartSelectionBox = true,
			GuiSelectionBox = true,
			CopyPathUseGetChildren = true
		},
		Properties = {
			_Recurse = true,
			MaxConflictCheck = 50,
			ShowDeprecated = true,
			ShowHidden = false,
			ClearOnFocus = false,
			LoadstringInput = true,
			NumberRounding = 3,
			ShowAttributes = true,
			MaxAttributes = 50,
			ScaleType = 0 -- 0 Full Name Shown, 1 Equal Halves
		},
		Theme = {
			_Recurse = true,
			UIRevision = 2,
			Main1 = rgb(24, 27, 32),
			Main2 = rgb(11, 13, 17),
			Outline1 = rgb(42, 48, 58), -- Mainly frames
			Outline2 = rgb(62, 72, 86), -- Mainly button
			Outline3 = rgb(33, 39, 49), -- Mainly textbox
			TextBox = rgb(16, 19, 25),
			Menu = rgb(14, 16, 21),
			ListSelection = rgb(55, 139, 121),
			Button = rgb(29, 34, 42),
			ButtonHover = rgb(43, 91, 83),
			ButtonPress = rgb(35, 74, 69),
			Highlight = rgb(65, 168, 144),
			Text = rgb(237, 241, 245),
			PlaceholderText = rgb(141, 153, 166),
			Important = rgb(232, 89, 102),
			Success = rgb(70, 180, 126),
			Warning = rgb(220, 170, 74),
			AccentSoft = rgb(20, 48, 45),
			ExplorerIconMap = "",
			MiscIconMap = "",
			Syntax = {
				Text = rgb(171, 178, 191),
				Background = rgb(20, 22, 26),
				Selection = rgb(243, 244, 246),
				SelectionBack = rgb(67, 56, 202),
				Operator = rgb(86, 182, 224),
				Number = rgb(209, 154, 102),
				String = rgb(152, 195, 121),
				Comment = rgb(92, 99, 112),
				Keyword = rgb(198, 120, 221),
				Error = rgb(244, 63, 94),
				FindBackground = rgb(234, 179, 8),
				MatchingWord = rgb(75, 85, 99),
				BuiltIn = rgb(229, 192, 123),
				CurrentLine = rgb(31, 41, 55),
				LocalMethod = rgb(97, 175, 239),
				LocalProperty = rgb(224, 108, 117),
				Nil = rgb(209, 154, 102),
				Bool = rgb(209, 154, 102),
				Function = rgb(198, 120, 221),
				Local = rgb(198, 120, 221),
				Self = rgb(224, 108, 117),
				FunctionName = rgb(97, 175, 239),
				Bracket = rgb(171, 178, 191)
			},
		},
		Notepad = {
			ShowMoreInfo = true;
		},
		Window = {
			TitleOnMiddle = false,
			Transparency = .12
		},
		Decompiler = {
			DecompilerFallback = "Konstant", --Konstant, Shiny, AdvancedDecompiler
			PreferDecompilerFallback = false,
			ShinyDecompilerPort = 3000,
			HelperServerPort = 8080,
			UseLocalHelper = false,
			PreferLocalHelperDecompiler = true,
			FastCacheRead = true,
			HelperLogChanges = false,
			HelperLogRateLimit = 5,
			HelperRequestTimeout = 2,
			HelperDecompileTimeout = 15,
			CodeSearchLowImpact = true,
		},
		AutoCheckUpdate = true,
		AutoUpdateRef = "v3.1",
		AutoUpdateAllowBranch = false,

		RemoteBlockWriteAttribute = false, -- writes attribute to remote instance if remote is blocked/unblocked
		ClassIcon = "NewDark",

		-- What available icons:
		-- > Vanilla3
		-- > Old
		-- > NewDark
	}
end)()

-- Vars
local Settings = DefaultSettings or {}
local Apps = {}
local env = {}

local service = setmetatable({},{__index = function(self,name)
	local serv = cloneref(game:GetService(name))
	self[name] = serv
	return serv
end})
local plr = service.Players.LocalPlayer or service.Players.PlayerAdded:wait()

local mapFont = function(font)
	if font == Enum.Font.SourceSans then
		return Enum.Font.Gotham
	elseif font == Enum.Font.SourceSansBold then
		return Enum.Font.GothamBold
	end
	return font
end

local create = function(data)
	local insts = {}
	for i,v in pairs(data) do insts[v[1]] = Instance.new(v[2]) end

	for _,v in pairs(data) do
		for prop,val in pairs(v[3]) do
			if type(val) == "table" then
				insts[v[1]][prop] = insts[val[1]]
			else
				local actualVal = val
				if prop == "Font" then
					actualVal = mapFont(val)
				end
				insts[v[1]][prop] = actualVal
			end
		end
	end

	return insts[1]
end

local createSimple = function(class,props)
	local inst = Instance.new(class)
	for i,v in next,props do
		local actualVal = v
		if i == "Font" then
			actualVal = mapFont(v)
		end
		inst[i] = actualVal
	end
	return inst
end

Main = (function()
	local Main = {}

	-- Hook & Connection Registry for clean script restarts
	Main.HookRegistry = {
		Metatable = {},
		Functions = {},
		Connections = {}
	}

	local raw_hookmetamethod = getgenv().hookmetamethod
	local raw_hookfunction = getgenv().hookfunction

	local appCategories = {
		["Explorer"] = "Core",
		["Properties"] = "Core",
		["Click part to select"] = "Core",
		["Notepad"] = "Core",
		["Console"] = "Core",
		["Save Instance"] = "Core",
		["Settings"] = "Core",

		["Runtime Monitor"] = "Spy & Hook",
		["Remote Usage"] = "Spy & Hook",
		["Runtime Inspector"] = "Spy & Hook",
		["Activity Map"] = "Spy & Hook",

		["Search Center"] = "Search & Info",
		["Code Search"] = "Search & Info",
		["Script Relations"] = "Search & Info",
		["Object Links"] = "Search & Info",
		["Dependency Graph"] = "Search & Info",
		["Smart Search"] = "Search & Info",
		["Client Intelligence"] = "Search & Info",
		["Inspector Hub"] = "Search & Info",

		["3D Viewer"] = "Advanced",
		["Image Viewer"] = "Advanced",
		["Task Router"] = "Advanced",
		["Control Center"] = "Advanced",
		["Security Auditor"] = "Advanced",
		["Property Tracker"] = "Advanced",
		["Thread Manager"] = "Advanced",
		["Serialize Inst"] = "Advanced",
		["Memory Forensics"] = "Advanced",
		["Runtime Debugger"] = "Advanced",
		["IDE Sync"] = "Advanced",
	}

	local currentCategory = "All"

	local table_clear = table.clear or function(t)
		for k in pairs(t) do
			t[k] = nil
		end
	end

	local function rebuildMetatableChain(metamethod)
		local reg = Main.HookRegistry.Metatable[metamethod]
		if not reg then return end

		if #reg.hooks > 0 then
			reg.active_hook = reg.hooks[#reg.hooks].hook_fn
		else
			reg.active_hook = reg.original
		end
	end

	Main.HookMetamethod = function(target, metamethod, key, hook_fn)
		local reg = Main.HookRegistry.Metatable[metamethod]
		if not reg then
			local original
			local master_hook = function(...)
				local r = Main.HookRegistry.Metatable[metamethod]
				if r and r.active_hook then
					return r.active_hook(...)
				end
				return original(...)
			end

			if not raw_hookmetamethod then
				warn("Failed to hook metamethod: hookmetamethod is nil")
				return nil
			end

			local ok, result = pcall(raw_hookmetamethod, target, metamethod, master_hook)
			if ok and result then
				original = result
				reg = {
					original = original,
					hooks = {},
					active_hook = original
				}
				Main.HookRegistry.Metatable[metamethod] = reg
			else
				warn("Failed to hook metamethod " .. tostring(metamethod) .. ": " .. tostring(result))
				return nil
			end
		end

		local found = false
		for _, hookData in ipairs(reg.hooks) do
			if hookData.key == key then
				hookData.hook_fn = hook_fn
				found = true
				break
			end
		end
		if not found then
			table.insert(reg.hooks, { key = key, hook_fn = hook_fn })
		end

		rebuildMetatableChain(metamethod)

		-- Create a proxy that executes the next hook down the chain (or original)
		local proxy = function(...)
			local r = Main.HookRegistry.Metatable[metamethod]
			if not r then return reg.original(...) end
			local idx
			for i, h in ipairs(r.hooks) do
				if h.key == key then
					idx = i
					break
				end
			end
			if idx and idx > 1 then
				return r.hooks[idx - 1].hook_fn(...)
			else
				return r.original(...)
			end
		end

		return proxy
	end

	Main.UnhookMetamethod = function(metamethod, key)
		local reg = Main.HookRegistry.Metatable[metamethod]
		if not reg then return end

		for i = #reg.hooks, 1, -1 do
			if reg.hooks[i].key == key then
				table.remove(reg.hooks, i)
			end
		end

		rebuildMetatableChain(metamethod)
	end

	local function rebuildFunctionChain(target)
		local reg = Main.HookRegistry.Functions[target]
		if not reg then return end

		if #reg.hooks > 0 then
			reg.active_hook = reg.hooks[#reg.hooks].hook_fn
		else
			reg.active_hook = reg.original
		end
	end

	Main.HookFunction = function(target, key, hook_fn)
		if not target then return nil end
		local reg = Main.HookRegistry.Functions[target]
		if not reg then
			local original
			local master_hook = function(...)
				local r = Main.HookRegistry.Functions[target]
				if r and r.active_hook then
					return r.active_hook(...)
				end
				return original(...)
			end

			if not raw_hookfunction then
				warn("Failed to hook function: hookfunction is nil")
				return nil
			end

			local ok, result = pcall(raw_hookfunction, target, master_hook)
			if ok and result then
				original = result
				reg = {
					original = original,
					hooks = {},
					active_hook = original
				}
				Main.HookRegistry.Functions[target] = reg
			else
				warn("Failed to hook function: " .. tostring(result))
				return nil
			end
		end

		local found = false
		for _, hookData in ipairs(reg.hooks) do
			if hookData.key == key then
				hookData.hook_fn = hook_fn
				found = true
				break
			end
		end
		if not found then
			table.insert(reg.hooks, { key = key, hook_fn = hook_fn })
		end

		rebuildFunctionChain(target)

		-- Create a proxy that executes the next hook down the chain (or original)
		local proxy = function(...)
			local r = Main.HookRegistry.Functions[target]
			if not r then return reg.original(...) end
			local idx
			for i, h in ipairs(r.hooks) do
				if h.key == key then
					idx = i
					break
				end
			end
			if idx and idx > 1 then
				return r.hooks[idx - 1].hook_fn(...)
			else
				return r.original(...)
			end
		end

		return proxy
	end

	Main.UnhookFunction = function(target, key)
		local reg = Main.HookRegistry.Functions[target]
		if not reg then return end

		for i = #reg.hooks, 1, -1 do
			if reg.hooks[i].key == key then
				table.remove(reg.hooks, i)
			end
		end

		rebuildFunctionChain(target)
	end

	Main.RegisterConnection = function(conn)
		if conn then
			table.insert(Main.HookRegistry.Connections, conn)
		end
		return conn
	end

	Main.CleanHooksAndConnections = function()
		for _, conn in ipairs(Main.HookRegistry.Connections) do
			pcall(function() conn:Disconnect() end)
		end
		table_clear(Main.HookRegistry.Connections)

		for metamethod, reg in pairs(Main.HookRegistry.Metatable) do
			table_clear(reg.hooks)
			rebuildMetatableChain(metamethod)
		end

		for target, reg in pairs(Main.HookRegistry.Functions) do
			table_clear(reg.hooks)
			rebuildFunctionChain(target)
			if raw_hookfunction then
				pcall(raw_hookfunction, target, reg.original)
			end
		end
	end

	-- Overwrite globals in getgenv() so loaded modules and plugins route through registry
	if raw_hookmetamethod then
		getgenv().hookmetamethod = function(target, metamethod, hook_fn)
			return Main.HookMetamethod(target, metamethod, tostring(hook_fn), hook_fn)
		end
	end

	if raw_hookfunction then
		getgenv().hookfunction = function(target, hook_fn)
			return Main.HookFunction(target, tostring(hook_fn), hook_fn)
		end
	end

	Main.RestoreGlobals = function()
		if raw_hookmetamethod then
			getgenv().hookmetamethod = raw_hookmetamethod
		end
		if raw_hookfunction then
			getgenv().hookfunction = raw_hookfunction
		end
	end

	Main.ModuleList = {"Theme","Lib","Console","SettingsWindow","ControlCenter","TaskRouter","ThreadManager","Explorer","Properties","SaveInstance","ModelViewer","ImageViewer","ObjectLinks","InstanceSerializer","SmartDecompiler","Notepad","ClientIndex","CodeSearch","SmartSearch","DependencyGraph","ScriptRelations","SecurityAuditor","RuntimeInspector","RemoteUsageMap","ActivityMap","PropertyTracker","RemoteFuzzer","ClientIntelligence","InspectorHub","IDESync"}
	Main.ModulePathMap = {
		Theme = "Core/Theme",
		Lib = "Core/Lib",
		Console = "Core/Console",
		SettingsWindow = "Core/SettingsWindow",
		ControlCenter = "Core/ControlCenter",
		TaskRouter = "Core/TaskRouter",
		ThreadManager = "Core/ThreadManager",
		Explorer = "Explorer/Explorer",
		Properties = "Explorer/Properties",
		SaveInstance = "Explorer/SaveInstance",
		ModelViewer = "Explorer/ModelViewer",
		ImageViewer = "Explorer/ImageViewer",
		ObjectLinks = "Explorer/ObjectLinks",
		InstanceSerializer = "Explorer/InstanceSerializer",
		SmartDecompiler = "Search/SmartDecompiler",
		Notepad = "Search/Notepad",
		ClientIndex = "Search/ClientIndex",
		CodeSearch = "Search/CodeSearch",
		SmartSearch = "Search/SmartSearch",
		DependencyGraph = "Search/DependencyGraph",
		ScriptRelations = "Search/ScriptRelations",
		SecurityAuditor = "Search/SecurityAuditor",
		RuntimeInspector = "Runtime/RuntimeInspector",
		RemoteUsageMap = "Runtime/RemoteUsageMap",
		ActivityMap = "Runtime/ActivityMap",
		PropertyTracker = "Runtime/PropertyTracker",
		RemoteFuzzer = "Runtime/RemoteFuzzer",
		ClientIntelligence = "Runtime/ClientIntelligence",
		InspectorHub = "Runtime/InspectorHub",
		IDESync = "Tools/IDESync",
	}
	Main.Elevated = false
	Main.AllowDraggableOnMobile = true
	Main.MissingEnv = {}
	Main.Version = "3.1"
	Main.Mouse = plr:GetMouse()
	Main.AppControls = {}
	Main.Apps = Apps
	Main.MenuApps = {}
	Main.AppCards = {}
	Main.MenuSearchText = ""
	Main.GitName = "Ahlstarr-Mayjishan"
	Main.RepoName = "DarkDEX----edited-version-by-me-"
	Main.GitRepoName = Main.GitName.."/"..Main.RepoName
	Main.UpdateScriptPath = "DEX%2B%2B_compiled.luau"
	Main.DefaultUpdateRef = "v"..Main.Version
	Main.UpdateScriptURL = nil
	Main.UpdateCheckStarted = false
	Main.LatestUpdateSource = nil
	Main.StartedAt = os.time()
	Main.ToolState = {}
	Main.ToolStatePostQueued = false
	Main.ToolStateLastPost = 0
	Main.GameContext = {
		PlaceId = tostring(game.PlaceId or ""),
		GameId = tostring(game.GameId or ""),
		JobId = tostring(game.JobId or ""),
		Name = tostring(game.Name or "Roblox session"),
	}

	Main.DisplayOrders = {
		SideWindow = 8,
		Window = 10,
		Menu = 100000,
		Core = 101000
	}

	Main.Plugins = {}

	Main.ReportToolState = function(name, state)
		if type(name) ~= "string" or type(state) ~= "table" then return end
		local old = Main.ToolState[name] or {}
		for k, v in pairs(state) do
			old[k] = v
		end
		old.UpdatedAt = os.clock()
		old.UpdatedWallAt = os.time()
		Main.ToolState[name] = old
		if Main.ScheduleToolStatePost then
			Main.ScheduleToolStatePost()
		end
	end

	Main.GetToolStates = function()
		return Main.ToolState
	end

	--[[Main.LoadAdonisBypass = function()
		-- skidded off reddit :pensive:
		local getinfo = getinfo or debug.getinfo
		local DEBUG = false
		local Hooked = {}

		local Detected, Kill

		setthreadidentity(2)

		for i, v in getgc(true) do
			if typeof(v) == "table" then
				local DetectFunc = rawget(v, "Detected")
				local KillFunc = rawget(v, "Kill")

				if typeof(DetectFunc) == "function" and not Detected then
					Detected = DetectFunc

					local Old; Old = hookfunction(Detected, function(Action, Info, NoCrash)
						if Action ~= "_" then
							if DEBUG then
								warn(`Adonis AntiCheat flagged\nMethod: {Action}\nInfo: {Info}`)
							end
						end

						return true
					end)

					table.insert(Hooked, Detected)
				end

				if rawget(v, "Variables") and rawget(v, "Process") and typeof(KillFunc) == "function" and not Kill then
					Kill = KillFunc
					local Old; Old = hookfunction(Kill, function(Info)
						if DEBUG then
							warn(`Adonis AntiCheat tried to kill (fallback): {Info}`)
						end
					end)

					table.insert(Hooked, Kill)
				end
			end
		end

		local Old; Old = hookfunction(getrenv().debug.info, newcclosure(function(...)
			local LevelOrFunc, Info = ...

			if Detected and LevelOrFunc == Detected then
				if DEBUG then
					warn(`Adonis AntiCheat sanity check detected and broken`)
				end

				return coroutine.yield(coroutine.running())
			end

			return Old(...)
		end))
		-- setthreadidentity(9)
		setthreadidentity(7)
	end

	Main.LoadGCBypass = function()
		loadstring(game:HttpGet("https://raw.githubusercontent.com/secretisadev/Babyhamsta_Backup/refs/heads/main/Universal/Bypasses.lua", true))()
	end]]

	Main.GetRandomString = function()
		local output = ""
		for i = 2, 25 do
			output = output .. string.char(math.random(1,250))
		end

		return output
	end

	Main.GetSecureContainer = function()
		return
			syn and syn.protect_gui or
			gethui and gethui() or
			service.CoreGui or
			service.Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	Main.SecureGui = function(gui)
		--warn("Secured: "..gui.Name)
		gui.Name = "_DPP_".. Main.GetRandomString()
		-- service already using cloneref
		if gethui then
			gui.Parent = gethui()
		elseif syn and syn.protect_gui then
			syn.protect_gui(gui)
			gui.Parent = service.CoreGui
		elseif protect_gui then
			protect_gui(gui)
			gui.Parent = service.CoreGui
		elseif protectgui then
			protectgui(gui)
			gui.Parent = service.CoreGui
		else
			if Main.Elevated then
				gui.Parent = service.CoreGui
			else
				gui.Parent = service.Players.LocalPlayer:WaitForChild("PlayerGui")
			end
		end
	end

	Main.GetInitDeps = function()
		return {
			Main = Main,
			Lib = Lib,
			Apps = Apps,
			Settings = Settings,

			API = API,
			RMD = RMD,
			env = env,
			service = service,
			plr = plr,
			create = create,
			createSimple = createSimple
		}
	end

	Main.SafeGetInstancePath = function(obj)
		if not obj then
			return "?"
		end

		local explorerApp = Apps and Apps.Explorer
		if explorerApp and explorerApp.GetInstancePath then
			local ok, path = pcall(explorerApp.GetInstancePath, obj)
			if ok and path ~= nil then
				return tostring(path)
			end
		end

		local okFullName, fullName = pcall(function()
			return obj:GetFullName()
		end)
		if okFullName and fullName and fullName ~= "" then
			return tostring(fullName)
		end

		local okManual, manualPath = pcall(function()
			if typeof(obj) ~= "Instance" then
				return tostring(obj)
			end

			local parts = {}
			local cur = obj
			while cur and cur ~= game do
				table.insert(parts, 1, tostring(cur.Name))
				cur = cur.Parent
			end
			if cur == game then
				table.insert(parts, 1, "game")
			end
			return #parts > 0 and table.concat(parts, ".") or tostring(obj)
		end)
		if okManual and manualPath and manualPath ~= "" then
			return tostring(manualPath)
		end

		return tostring(obj)
	end

	Main.Error = function(str)
		if rconsoleprint then
			rconsoleprint("DEX ERROR: "..tostring(str).."\n")
			wait(9e9)
		else
			error(str)
		end
	end

	Main.LoadModule = function(name)
		if Main.Elevated then -- If you don't have filesystem api then ur outta luck tbh
			local control
			local usedLocalOverride = false

			local function loadEmbeddedControl()
				if not EmbeddedModules then return nil end
				if not EmbeddedModules[name] then Main.Error("Missing Embedded Module: "..name) end
				if gethsfuncs then _G.moduleData = nil end
				local embeddedControl = EmbeddedModules[name]()

				-- TODO: Remove when open source
				if gethsfuncs then
					embeddedControl = _G.moduleData
				end

				if not embeddedControl then Main.Error("Missing Embedded Module: "..name) end
				return embeddedControl
			end

			local function activateControl(selectedControl)
				Main.AppControls[name] = selectedControl
				selectedControl.InitDeps(Main.GetInitDeps())

				local moduleData = selectedControl.Main()
				Apps[name] = moduleData
				return moduleData
			end

			-- Developer Mode: Load directly from local file if exists
			local modulePath = Main.ModulePathMap and Main.ModulePathMap[name] or name
			local localPath = 'dex/Modules/' .. modulePath .. '.luau'
			local localPathFallback = 'dex/Modules/' .. modulePath .. '.lua'
			local flatLocalPath = 'dex/Modules/' .. name .. '.luau'
			local flatLocalPathFallback = 'dex/Modules/' .. name .. '.lua'
			if isFsSupported and (isfile(localPath) or isfile(localPathFallback)) then
				local path = isfile(localPath) and localPath or localPathFallback
				local s, err = pcall(function()
					if gethsfuncs then _G.moduleData = nil end
					control = loadstring(readfile(path))()
					if not control and gethsfuncs then
						control = _G.moduleData
					end
				end)
				if s and control then
					usedLocalOverride = true
				end
				if not s then
					warn('Failed to load local module ' .. name .. ': ' .. tostring(err))
				end
			elseif isFsSupported and (isfile(flatLocalPath) or isfile(flatLocalPathFallback)) then
				local path = isfile(flatLocalPath) and flatLocalPath or flatLocalPathFallback
				local s, err = pcall(function()
					if gethsfuncs then _G.moduleData = nil end
					control = loadstring(readfile(path))()
					if not control and gethsfuncs then
						control = _G.moduleData
					end
				end)
				if s and control then
					usedLocalOverride = true
				end
				if not s then
					warn('Failed to load local flat module ' .. name .. ': ' .. tostring(err))
				end
			end

			if not control then
				if EmbeddedModules and EmbeddedModules[name] then -- Offline Modules
					control = loadEmbeddedControl()
				else
					-- Get hash data
					local hashs = Main.ModuleHashData
					if not hashs then
						local s,hashDataStr = pcall(oldgame.HttpGet, game, "https://api.github.com/repos/"..Main.GitRepoName.."/ModuleHashs.dat")
						if not s then Main.Error("Failed to get module hashs") end

						local s,hashData = pcall(service.HttpService.JSONDecode,service.HttpService,hashDataStr)
						if not s then Main.Error("Failed to decode module hash JSON") end

						hashs = hashData
						Main.ModuleHashData = hashs
					end

					-- Check if local copy exists with matching hashs
					local hashfunc = (syn and syn.crypt.hash) or function() return "" end
					local filePath = "dex/ModuleCache/"..name..".lua"
					local s,moduleStr = pcall(env.readfile,filePath)

					if s and hashfunc(moduleStr) == hashs[name] then
						control = loadstring(moduleStr)()
					else
						-- Download and cache
						local s,moduleStr = pcall(oldgame.HttpGet, game, "https://api.github.com/repos/"..Main.GitRepoName.."/Modules/"..name..".lua")
						if not s then Main.Error("Failed to get external module data of "..name) end

						env.writefile(filePath,moduleStr)
						control = loadstring(moduleStr)()
					end
				end
			end

			if usedLocalOverride then
				local ok, moduleData = pcall(activateControl, control)
				if ok then
					return moduleData
				end
				warn("Local module " .. name .. " failed during init; falling back to embedded: " .. tostring(moduleData))
				Main.AppControls[name] = nil
				Apps[name] = nil
				control = loadEmbeddedControl()
			end

			return activateControl(control)
		else
			local module = script:WaitForChild("Modules"):WaitForChild(name,2)
			if not module then Main.Error("CANNOT FIND MODULE "..name) end

			local control = require(module)
			Main.AppControls[name] = control
			control.InitDeps(Main.GetInitDeps())

			local moduleData = control.Main()
			Apps[name] = moduleData
			return moduleData
		end
	end

	Main.LoadPluginFile = function(pluginDir)
		if env.readfile then
			if isfile(pluginDir) then
				local preloadedPlugin = loadfile and loadfile(pluginDir) or loadstring(env.readfile(pluginDir))
				local loadedPlugin = preloadedPlugin()

				local control = loadedPlugin
				control.InitDeps(Main.GetInitDeps())

				local moduleData = control.Main()
				Apps[pluginDir] = moduleData
				Main.AppControls[pluginDir] = control

				moduleData.PluginData = control.PluginData

				return moduleData
			else
				Main.Error("CANNOT FIND FILE MODULE "..pluginDir)
			end
		end
	end

	Main.LoadModules = function()
		for i,v in pairs(Main.ModuleList) do
			local s,e = pcall(Main.LoadModule,v)
			if not s then
				Main.Error("FAILED LOADING " .. v .. " CAUSE " .. e)
			end
		end

		-- Init Major Apps and define them in modules
		Explorer = Apps.Explorer
		Properties = Apps.Properties
		Notepad = Apps.Notepad
		Console = Apps.Console
		SaveInstance = Apps.SaveInstance
		ModelViewer = Apps.ModelViewer
		Notebook = Apps.Notebook
		SettingsWindow = Apps.SettingsWindow
		CodeSearch = Apps.CodeSearch
		ScriptRelations = Apps.ScriptRelations
		RemoteUsageMap = Apps.RemoteUsageMap
		ObjectLinks = Apps.ObjectLinks
		ImageViewer = Apps.ImageViewer
		ClientIndex = Apps.ClientIndex
		ActivityMap = Apps.ActivityMap
		DependencyGraph = Apps.DependencyGraph
		SmartSearch = Apps.SmartSearch
		RuntimeInspector = Apps.RuntimeInspector
		ClientIntelligence = Apps.ClientIntelligence
		InspectorHub = Apps.InspectorHub
		TaskRouter = Apps.TaskRouter
		ControlCenter = Apps.ControlCenter
		Theme = Apps.Theme
		SmartDecompiler = Apps.SmartDecompiler
		SecurityAuditor = Apps.SecurityAuditor
		RemoteFuzzer = Apps.RemoteFuzzer
		PropertyTracker = Apps.PropertyTracker
		InstanceSerializer = Apps.InstanceSerializer
		ThreadManager = Apps.ThreadManager
		IDESync = Apps.IDESync


		--SecretServicePanel = Apps.SecretServicePanel
		local appTable = {
			Theme = Theme,
			SmartDecompiler = SmartDecompiler,
			Explorer = Explorer,
			Properties = Properties,
			Notepad = Notepad,
			Console = Console,
			SaveInstance = SaveInstance,
			ModelViewer = ModelViewer,
			Notebook = Notebook,
			SettingsWindow = SettingsWindow,
			CodeSearch = CodeSearch,
			ScriptRelations = ScriptRelations,
			RemoteUsageMap = RemoteUsageMap,
			ObjectLinks = ObjectLinks,
			ImageViewer = ImageViewer,
			ClientIndex = ClientIndex,
			ActivityMap = ActivityMap,
			DependencyGraph = DependencyGraph,
			SmartSearch = SmartSearch,
			RuntimeInspector = RuntimeInspector,
			ClientIntelligence = ClientIntelligence,
			InspectorHub = InspectorHub,
			TaskRouter = TaskRouter,
			ControlCenter = ControlCenter,
			SecurityAuditor = SecurityAuditor,
			RemoteFuzzer = RemoteFuzzer,
			PropertyTracker = PropertyTracker,
			InstanceSerializer = InstanceSerializer,
			ThreadManager = ThreadManager,
			IDESync = IDESync
		}

		Main.AppControls.Lib.InitAfterMain(appTable)
		for i,v in pairs(Main.ModuleList) do
			local control = Main.AppControls[v]
			if control then
				control.InitAfterMain(appTable)
			end
		end
	end

	Main.InitEnv = function()
		setmetatable(env,{__newindex = function(self,name,func)
			if not func then Main.MissingEnv[#Main.MissingEnv+1] = name return end
			rawset(self,name,func)
		end})

		env.isonmobile = game:GetService("UserInputService").TouchEnabled

		env.loadstring = (pcall(loadstring,"local a = 1") and loadstring) or (game:GetService("RunService"):IsStudio() and script.Modules:FindFirstChild("Loadstring") and require(script.Modules:FindFirstChild("Loadstring")))

		-- file
		env.isfile = isfile
		env.isfolder = isfolder
		env.readfile = readfile
		env.writefile = writefile
		env.appendfile = appendfile
		env.makefolder = makefolder
		env.listfiles = listfiles
		env.loadfile = loadfile
		env.saveinstance = (function()
	if game:GetService("RunService"):IsStudio() then
		return function() error("Cannot run in Roblox Studio!") end
	end

	local Params = {
		RepoURL = "https://raw.githubusercontent.com/luau/SynSaveInstance/main/",
		SSI = "saveinstance",
	}
	local synsaveinstance = loadstring(oldgame:HttpGet(Params.RepoURL .. Params.SSI .. ".luau", true), Params.SSI)()

	    local function wrappedsaveinstance(obj, filepath, options)
		            options["FilePath"] = filepath
		            options["Object"] = obj
		            return synsaveinstance(options)
	            end
	        getgenv().saveinstance = wrappedsaveinstance
	        return wrappedsaveinstance
        end)()

		env.parsefile = function(name)
			return tostring(name):gsub("[*\\?:<>|]+", ""):sub(1, 175)
		end

		-- debug
		env.getupvalues = debug.getupvalues or getupvalues or getupvals
		env.getconstants = debug.getconstants or getconstants or getconsts
		env.islclosure = islclosure or is_l_closure
		env.checkcaller = checkcaller
		env.getreg = getreg
		env.getgc = getgc

		-- hooks
		env.hookfunction = hookfunction
		env.hookmetamethod = hookmetamethod

		-- other
		env.getscriptbytecode = getscriptbytecode
		env.setfflag = setfflag
		env.protectgui = protect_gui or (syn and syn.protect_gui)
		env.gethui = gethui
		env.setclipboard = setclipboard
		env.getnilinstances = getnilinstances or get_nil_instances
		env.getloadedmodules = getloadedmodules
		env.getconnections = getconnections

		env.isViableDecompileScript = function(obj)
			if obj:IsA("ModuleScript") then
				return true
			elseif obj:IsA("LocalScript") and (obj.RunContext == Enum.RunContext.Client or obj.RunContext == Enum.RunContext.Legacy) then
				return true
			elseif obj:IsA("Script") and obj.RunContext == Enum.RunContext.Client then
				return true
			end
			return false
		end

		local remoteClassMap = {
			RemoteEvent = true,
			RemoteFunction = true,
			UnreliableRemoteEvent = true,
			BindableEvent = true,
			BindableFunction = true,
		}

		local function addUniqueInstance(list, seen, obj)
			if typeof(obj) == "Instance" and not seen[obj] then
				seen[obj] = true
				list[#list+1] = obj
				return true
			end
			return false
		end

		local clientSurfaceTtl = 4
		local clientSurfaceStamp = 0
		local clientSurface = {
			AllInstances = {},
			AllScripts = {},
			ViableScripts = {},
			Remotes = {},
		}

		local function addGcScriptRefs(list, seen, allowNonViable)
			if not env.getgc then return end
			local success, gcObjects = pcall(env.getgc)
			if not success or type(gcObjects) ~= "table" then return end

			local count = 0
			for _, value in pairs(gcObjects) do
				if typeof(value) == "function" then
					local envSuccess, fnEnv = pcall(getfenv, value)
					local scr = envSuccess and type(fnEnv) == "table" and rawget(fnEnv, "script")
					if typeof(scr) == "Instance" and scr:IsA("LuaSourceContainer") then
						if allowNonViable or env.isViableDecompileScript(scr) then
							if typeof(scr) == "Instance" and not seen[scr] then
								seen[scr] = true
								table.insert(list, scr)
							end
						end
					end
				end
				count = count + 1
				if count % 350 == 0 then task.wait() end
			end
		end

		env.RefreshClientSurface = function(force, includeGcScripts)
			local now = os.clock()
			if not force and now - clientSurfaceStamp < clientSurfaceTtl then
				return clientSurface
			end

			clientSurfaceStamp = now
			local allInstances, seen = {}, {}
			local allScripts, viableScripts, remotes = {}, {}, {}
			local scriptSeen, viableSeen, remoteSeen = {}, {}, {}

			local count = 0
			local function processInstance(obj)
				if typeof(obj) ~= "Instance" then return end
				if not seen[obj] then
					seen[obj] = true
					table.insert(allInstances, obj)
					if obj:IsA("LuaSourceContainer") then
						if not scriptSeen[obj] then
							scriptSeen[obj] = true
							table.insert(allScripts, obj)
							if env.isViableDecompileScript(obj) then
								viableSeen[obj] = true
								table.insert(viableScripts, obj)
							end
						end
					elseif remoteClassMap[obj.ClassName] then
						if not remoteSeen[obj] then
							remoteSeen[obj] = true
							table.insert(remotes, obj)
						end
					end
				end
				count = count + 1
				if count % 400 == 0 then
					task.wait()
				end
			end

			-- 1. Descendants
			local ok, descendants = pcall(game.GetDescendants, game)
			if ok and type(descendants) == "table" then
				for _, obj in ipairs(descendants) do
					processInstance(obj)
				end
			end

			-- 2. Nil Instances
			if env.getnilinstances then
				local success, nilInstances = pcall(env.getnilinstances)
				if success and type(nilInstances) == "table" then
					for _, obj in pairs(nilInstances) do
						processInstance(obj)
					end
				end
			end

			-- 3. Loaded Modules
			if env.getloadedmodules then
				local success, loadedModules = pcall(env.getloadedmodules)
				if success and type(loadedModules) == "table" then
					for _, obj in pairs(loadedModules) do
						processInstance(obj)
					end
				end
			end

			-- 4. GC scripts (optional)
			if includeGcScripts == true then
				addGcScriptRefs(allScripts, scriptSeen, true)
				-- Also update viableScripts from the newly added ones
				for _, scr in ipairs(allScripts) do
					if env.isViableDecompileScript(scr) and not viableSeen[scr] then
						viableSeen[scr] = true
						table.insert(viableScripts, scr)
					end
				end
			end

			clientSurface = {
				AllInstances = allInstances,
				AllScripts = allScripts,
				ViableScripts = viableScripts,
				Remotes = remotes,
				UpdatedAt = now,
			}
			return clientSurface
		end

		env.GetClientScripts = function(allowNonViable, forceDeep)
			local surface = env.RefreshClientSurface(forceDeep == true, forceDeep == true)
			return allowNonViable and surface.AllScripts or surface.ViableScripts
		end

		env.GetClientRemotes = function(force)
			return env.RefreshClientSurface(force == true, false).Remotes
		end

		env.GetClientSurfaceCoverage = function()
			local surface = env.RefreshClientSurface(false, false)
			local allScripts = surface.AllScripts
			local viableScripts = surface.ViableScripts
			local remotes = surface.Remotes
			local cached = 0

			if env.DecompileCache and env.DecompileCache.GetEntries then
				local entries = env.DecompileCache.GetEntries()
				for _ in pairs(entries) do
					cached += 1
				end
			end

			return {
				AllScripts = #allScripts,
				ViableScripts = #viableScripts,
				Remotes = #remotes,
				CachedScripts = cached,
				HasNilInstances = env.getnilinstances ~= nil,
				HasLoadedModules = env.getloadedmodules ~= nil,
				HasGc = env.getgc ~= nil,
				HasConnections = env.getconnections ~= nil,
			}
		end

		env.GetScriptConstants = function(scriptInstance)
			local constants, seen = {}, {}
			if not env.getgc or not env.getconstants then return constants end

			local success, gcObjects = pcall(env.getgc)
			if not success or type(gcObjects) ~= "table" then return constants end

			for _, value in pairs(gcObjects) do
				if typeof(value) == "function" then
					local envSuccess, fnEnv = pcall(getfenv, value)
					if envSuccess and type(fnEnv) == "table" and rawget(fnEnv, "script") == scriptInstance then
						local constSuccess, constList = pcall(env.getconstants, value)
						if constSuccess and type(constList) == "table" then
							for _, constant in pairs(constList) do
								local key = tostring(constant)
								if not seen[key] then
									seen[key] = true
									constants[#constants+1] = constant
								end
							end
						end
					end
				end
			end

			return constants
		end
		env.request = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

		env.HelperServer = (function()
			local helper = {
				LastStatus = "unknown",
				LastChecked = 0,
				FailCount = 0,
				DisabledUntil = 0,
			}

			local function getBaseUrl()
				local port = Settings.Decompiler.HelperServerPort or 8080
				return "http://localhost:" .. tostring(port)
			end

			local function helperEnabled()
				return Settings
					and Settings.Decompiler
					and Settings.Decompiler.UseLocalHelper == true
			end

			function helper.Request(path, method, body, contentType, timeoutSeconds, allowWhenDisabled)
				if not helperEnabled() and not allowWhenDisabled then return nil, "local helper disabled" end
				local now = os.clock()
				if helper.DisabledUntil > now then
					return nil, "local helper temporarily disabled"
				end
				local req = env.request or (syn and syn.request) or (http and http.request) or http_request or request
				if not req then return nil, "request API unavailable" end

				local ok, result = pcall(req, {
					Url = getBaseUrl() .. path,
					Method = method or "GET",
					Headers = {
						["Content-Type"] = contentType or "text/plain"
					},
					Body = body,
					Timeout = timeoutSeconds or Settings.Decompiler.HelperRequestTimeout or 2,
				})
				if not ok or not result then
					helper.FailCount += 1
					if helper.FailCount >= 3 then
						helper.DisabledUntil = os.clock() + 10
						helper.LastStatus = "offline"
					end
					return nil, tostring(result)
				end
				helper.FailCount = 0
				return result, nil
			end

			function helper.IsActive(force)
				if not helperEnabled() then
					helper.LastStatus = "disabled"
					return false
				end
				if not force and os.clock() - helper.LastChecked < 5 then
					return helper.LastStatus == "active"
				end
				helper.LastChecked = os.clock()
				local result = helper.Request("/status", "GET")
				helper.LastStatus = (result and result.StatusCode == 200) and "active" or "offline"
				return helper.LastStatus == "active"
			end

			function helper.NormalizeSource(source)
				local result = helper.Request("/normalize-source", "POST", source, "text/plain")
				if result and result.StatusCode == 200 and type(result.Body) == "string" then
					return result.Body
				end
				return nil
			end

			function helper.Deobfuscate(source)
				return helper.NormalizeSource(source)
			end

			function helper.AnalyzeSource(source)
				local result = helper.Request("/analyze-source", "POST", source, "text/plain")
				if result and result.StatusCode == 200 and type(result.Body) == "string" then
					return result.Body
				end
				return nil
			end

			function helper.IndexSource(key, path, name, className, source)
				local body = table.concat({
					tostring(key or ""),
					tostring(path or ""),
					tostring(name or ""),
					tostring(className or ""),
					tostring(source or "")
				}, "\n")
				local result = helper.Request("/index-source", "POST", body, "text/plain")
				if result and result.StatusCode == 200 and type(result.Body) == "string" then
					return result.Body
				end
				return nil
			end

			function helper.SearchSource(query, limit)
				local body = tostring(limit or 80) .. "\n" .. tostring(query or "")
				local result = helper.Request("/search-source", "POST", body, "text/plain")
				if result and result.StatusCode == 200 and type(result.Body) == "string" then
					return result.Body
				end
				return nil
			end

			function helper.IndexStatus()
				local result = helper.Request("/index-status", "GET")
				if result and result.StatusCode == 200 and type(result.Body) == "string" then
					return result.Body
				end
				return nil
			end

			function helper.ClearSourceIndex()
				local result = helper.Request("/index-clear", "POST", "", "text/plain")
				return result and result.StatusCode == 200
			end

			function helper.SaveSourceIndex()
				local result = helper.Request("/index-save", "POST", "", "text/plain")
				if result and result.StatusCode == 200 and type(result.Body) == "string" then
					return result.Body
				end
				return nil
			end

			function helper.LoadSourceIndex()
				local result = helper.Request("/index-load", "POST", "", "text/plain")
				if result and result.StatusCode == 200 and type(result.Body) == "string" then
					return result.Body
				end
				return nil
			end

			function helper.AssignRole(task)
				local result = helper.Request("/assign-role", "POST", tostring(task or ""), "text/plain")
				if result and result.StatusCode == 200 and type(result.Body) == "string" then
					return result.Body
				end
				return nil
			end

			function helper.Decompile(bytecode)
				local timeout = Settings.Decompiler.HelperDecompileTimeout or 15
				local result = helper.Request("/decompile", "POST", bytecode, "application/octet-stream", timeout)
				if result and result.StatusCode == 200 and type(result.Body) == "string" then
					return result.Body
				end
				return nil
			end

			function helper.PostToolState(json)
				local result = helper.Request("/tool-state", "POST", tostring(json or "{}"), "application/json", 1, true)
				return result and result.StatusCode == 200
			end

			function helper.Log(line)
				local result = helper.Request("/log", "POST", tostring(line), "text/plain")
				return result and result.StatusCode == 200
			end

			return helper
		end)()

		task.spawn(function()
			local ok, info = pcall(function()
				local marketplace = service.MarketplaceService or game:GetService("MarketplaceService")
				return marketplace:GetProductInfo(game.PlaceId)
			end)
			if ok and type(info) == "table" then
				local resolvedName = info.Name or info.AssetName
				if type(resolvedName) == "string" and resolvedName ~= "" then
					Main.GameContext.Name = resolvedName
				end
				Main.GameContext.Creator = info.Creator and info.Creator.Name or nil
			end
			if Main.ScheduleToolStatePost then
				Main.ScheduleToolStatePost()
			end
		end)

		Main.BuildHelperToolState = function()
			local payload = {
				ok = true,
				updatedAt = os.time(),
				version = Main.Version,
				session = {
					state = "connected",
					startedAt = Main.StartedAt or os.time(),
					executor = Main.Executor or "unknown",
				},
				game = Main.GameContext,
				settings = {
					useLocalHelper = Settings.Decompiler and Settings.Decompiler.UseLocalHelper == true,
					lowImpact = Settings.Decompiler and Settings.Decompiler.CodeSearchLowImpact ~= false,
					fastCacheRead = Settings.Decompiler and Settings.Decompiler.FastCacheRead == true,
				},
				tools = Main.ToolState or {},
			}
			local ok, encoded = pcall(service.HttpService.JSONEncode, service.HttpService, payload)
			return ok and encoded or nil
		end

		Main.PushToolStateToHelper = function()
			if not env.HelperServer or not env.HelperServer.PostToolState then return false end
			local encoded = Main.BuildHelperToolState and Main.BuildHelperToolState()
			if not encoded then return false end
			return env.HelperServer.PostToolState(encoded)
		end

		Main.ScheduleToolStatePost = function()
			if Main.ToolStatePostQueued then return end
			Main.ToolStatePostQueued = true
			local delayTime = math.max(0, 0.5 - (os.clock() - (Main.ToolStateLastPost or 0)))
			task.delay(delayTime, function()
				Main.ToolStatePostQueued = false
				Main.ToolStateLastPost = os.clock()
				pcall(Main.PushToolStateToHelper)
			end)
		end

		Main.ReportToolState("DEX Session", {
			State = "connected",
			Load = "low",
			Version = Main.Version,
			PlaceId = tostring(game.PlaceId or ""),
			GameId = tostring(game.GameId or ""),
			JobId = tostring(game.JobId or ""),
		})

		env.isdecompile = function()
			return typeof(decompile) == "function" or typeof(getscriptbytecode) == "function" or false
		end

		env.isdecompilefallback = function()
			return typeof(decompile) ~= "function" or typeof(getscriptbytecode) == "function" or false
		end


        -- DECOMPILERS

		local luaexpert_last_call = 0

		local function LuaExpertDec(script_instance)
			local success, bytecode = pcall(env.getscriptbytecode, script_instance)

			if (not success) then
				return "-- Failed to get script bytecode, error:\n\n--[[\n" .. tostring(bytecode) .. "\n--]]"
			end

			local time_elapsed = os.clock() - luaexpert_last_call
			if time_elapsed <= 0.6 then
				task.wait(0.6 - time_elapsed)
			end

			local encoder = base64_encode or (crypt and crypt.base64encode) or (crypt and crypt.base64 and crypt.base64.encode)
			if not encoder then
				encoder = function(data)
					local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
					return ((data:gsub('.', function(x)
						local r,byte = '',x:byte()
						for i=8,1,-1 do r = r .. (byte % 2^i - byte % 2^(i-1) > 0 and '1' or '0') end
						return r
					end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
						if #x < 6 then return '' end
						local c = 0
						for i=1,6 do c = c + (x:sub(i,i) == '1' and 2^(6-i) or 0) end
						return b:sub(c+1,c+1)
					end)..({ '', '==', '=' })[#data % 3 + 1])
				end
			end

			local HttpService = game:GetService("HttpService")
			local req = env.request or (syn and syn.request) or (http and http.request) or http_request or request

			local httpResult = req({
				Url = "https://api.lua.expert/decompile",
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json"
				},
				Body = HttpService:JSONEncode({
					script = encoder(bytecode)
				})
			})

			luaexpert_last_call = os.clock()

			if (not httpResult or httpResult.StatusCode ~= 200) then
				return "-- Error occurred while requesting lua.expert API, error:\n\n--[[\n" .. tostring(httpResult and httpResult.Body or "No response") .. "\n--]]"
			else
				return httpResult.Body
			end
		end

		local nativeDecompile = decompile or (getgenv and getgenv().decompile)

		local function hashString(data)
			if type(data) ~= "string" then return "" end
			
			-- Try to use native crypt library if available
			local crypt = getgenv().crypt or (getgenv().syn and getgenv().syn.crypt)
			if crypt and type(crypt.hash) == "function" then
				local success, result = pcall(crypt.hash, data, "sha1")
				if success and result then
					return result
				end
			end

			-- Fast sample-based hashing in Luau to prevent lag/freezes on large strings
			local hash = 2166136261
			local len = #data
			if len > 2000 then
				for i = 1, 500 do
					hash = (hash * 131 + data:byte(i)) % 4294967296
				end
				local mid = math.floor(len / 2)
				for i = mid - 250, mid + 250 do
					hash = (hash * 131 + data:byte(i)) % 4294967296
				end
				for i = len - 500, len do
					hash = (hash * 131 + data:byte(i)) % 4294967296
				end
				hash = (hash * 131 + len) % 4294967296
			else
				for i = 1, len do
					hash = (hash * 131 + data:byte(i)) % 4294967296
				end
			end
			return ("%08x"):format(hash)
		end

		local decompileFailures = {
			{Code = "empty_source", Text = "empty source", Patterns = {"empty bytecode", "empty bytecode payload", "empty response"}},
			{Code = "deserialization", Text = "bytecode deserialization or parsing failed", Patterns = {"deserialization failed", "parsing error", "code: eof", "unexpected end of file"}},
			{Code = "unsupported_version", Text = "unsupported Luau bytecode version", Patterns = {"unsupported bytecode version"}},
			{Code = "bytecode_unavailable", Text = "executor could not extract script bytecode", Patterns = {"getscriptbytecode is not supported", "failed to get script bytecode"}},
			{Code = "transport", Text = "decompiler connection or HTTP request failed", Patterns = {"error occurred while requesting", "could not connect to potassium decompiler", "failed to send request", "incomplete request send", "invalid http response", "non-200 status"}},
			{Code = "decompiler_error", Text = "decompiler rejected the bytecode", Patterns = {"failed to decompile", "decompile failed:", "-- error:"}},
		}

		local function getDecompileFailure(source)
			if type(source) ~= "string" or source:match("%S") == nil then
				return {Code = "empty_source", Text = "decompiler returned no source"}
			end
			local lowered = source:lower()
			for _, failure in ipairs(decompileFailures) do
				for _, pattern in ipairs(failure.Patterns) do
					if lowered:find(pattern, 1, true) then
						return {Code = failure.Code, Text = failure.Text, Raw = source}
					end
				end
			end
			return nil
		end

		local function isCacheableSource(source)
			return getDecompileFailure(source) == nil
		end
		env.GetDecompileFailure = getDecompileFailure
		env.IsValidDecompileSource = isCacheableSource

		local function createDecompileCache()
			local cache = {}
			local HttpService = service.HttpService
			local rootDir = "dex/DecompileCache"
			local placeDir = rootDir .. "/" .. tostring(game.PlaceId)
			local metadataPath = placeDir .. "/metadata.json"
			local metadataLoaded = false
			local metadata = {PlaceId = tostring(game.PlaceId), Scripts = {}}

			local function isReady()
				return env.readfile and env.writefile and env.isfile and env.isfolder and env.makefolder
			end

			local function ensureFolder(path)
				if env.isfolder and not env.isfolder(path) then
					pcall(env.makefolder, path)
				end
			end

			local function ensureCacheFolders()
				if not isReady() then return false end
				ensureFolder("dex")
				ensureFolder(rootDir)
				ensureFolder(placeDir)
				return true
			end

			local function loadMetadata()
				if metadataLoaded then return end
				metadataLoaded = true
				metadata = {PlaceId = tostring(game.PlaceId), Scripts = {}}
				if not ensureCacheFolders() or not env.isfile(metadataPath) then return end

				local success, raw = pcall(env.readfile, metadataPath)
				if not success or type(raw) ~= "string" or raw == "" then return end

				local decodedSuccess, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
				if decodedSuccess and type(decoded) == "table" then
					metadata = decoded
					metadata.PlaceId = metadata.PlaceId or tostring(game.PlaceId)
					metadata.Scripts = metadata.Scripts or {}
				end
			end

			local function saveMetadata()
				loadMetadata()
				if not ensureCacheFolders() then return false end
				metadata.UpdatedAt = os.time()

				local encodedSuccess, encoded = pcall(HttpService.JSONEncode, HttpService, metadata)
				if not encodedSuccess then return false end

				local writeSuccess = pcall(env.writefile, metadataPath, encoded)
				return writeSuccess
			end

			local function getScriptPath(script_instance)
				local success, path = pcall(function()
					return script_instance:GetFullName()
				end)
				return success and path or tostring(script_instance)
			end

			local function getScriptKey(script_instance)
				local path = getScriptPath(script_instance)
				return hashString(tostring(script_instance.ClassName) .. "|" .. path)
			end

			local function getBytecodeHash(script_instance)
				if typeof(env.getscriptbytecode) ~= "function" then return nil end
				local success, bytecode = pcall(env.getscriptbytecode, script_instance)
				if not success or type(bytecode) ~= "string" or bytecode == "" then return nil end
				return hashString(bytecode)
			end

			local function getInfo(script_instance, skipHash)
				if typeof(script_instance) ~= "Instance" then return nil end
				local key = getScriptKey(script_instance)
				return {
					Key = key,
					Hash = skipHash and nil or getBytecodeHash(script_instance),
					File = key .. ".lua",
					Path = getScriptPath(script_instance),
					Name = script_instance.Name,
					ClassName = script_instance.ClassName
				}
			end

			cache.IsReady = isReady
			cache.GetDirectory = function()
				ensureCacheFolders()
				return placeDir
			end
			cache.GetMetadataPath = function()
				ensureCacheFolders()
				return metadataPath
			end
			cache.GetScriptKey = getScriptKey
			cache.GetInfo = getInfo
			cache.GetEntries = function()
				loadMetadata()
				return metadata.Scripts, placeDir
			end
			cache.HasCachedFile = function(script_instance)
				loadMetadata()
				if not ensureCacheFolders() then return false end
				local info = getInfo(script_instance, true)
				if not info then return false end
				local entry = metadata.Scripts[info.Key]
				if not entry then return false end
				local path = placeDir .. "/" .. tostring(entry.File or info.File)
				return env.isfile(path)
			end
			cache.HasFresh = function(script_instance)
				loadMetadata()
				if not ensureCacheFolders() then return false end

				local info = getInfo(script_instance)
				if not info then return false end

				local entry = metadata.Scripts[info.Key]
				if not entry then return false end
				if info.Hash and entry.Hash and entry.Hash ~= info.Hash then return false end

				local path = placeDir .. "/" .. tostring(entry.File or info.File)
				return env.isfile(path)
			end
			cache.HasFreshFast = function(script_instance)
				loadMetadata()
				if not ensureCacheFolders() then return false end

				local info = getInfo(script_instance, true)
				if not info then return false end

				local entry = metadata.Scripts[info.Key]
				if not entry then return false end

				local path = placeDir .. "/" .. tostring(entry.File or info.File)
				return env.isfile(path)
			end
			cache.Read = function(script_instance)
				loadMetadata()
				if not ensureCacheFolders() then return nil, "Filesystem APIs are unavailable." end

				local info = getInfo(script_instance, Settings.Decompiler and Settings.Decompiler.FastCacheRead == true)
				if not info then return nil, "Script cache info is unavailable." end

				local entry = metadata.Scripts[info.Key]
				if not entry then return nil, "No cached source." end
				if info.Hash and entry.Hash and entry.Hash ~= info.Hash then return nil, "Cached source is stale." end

				local path = placeDir .. "/" .. tostring(entry.File or info.File)
				if not env.isfile(path) then return nil, "Cached source file is missing." end

				local success, source = pcall(env.readfile, path)
				if success and isCacheableSource(source) then
					return source, entry
				end
				return nil, "Cached source is empty or contains a decompiler failure."
			end
			cache.Write = function(script_instance, source)
				if not isCacheableSource(source) then return false end
				if not ensureCacheFolders() then return false end

				local info = getInfo(script_instance)
				if not info then return false end

				local path = placeDir .. "/" .. info.File
				local writeSuccess = pcall(env.writefile, path, source)
				if not writeSuccess then return false end

				loadMetadata()
				metadata.Scripts[info.Key] = {
					Hash = info.Hash,
					File = info.File,
					Path = info.Path,
					Name = info.Name,
					ClassName = info.ClassName,
					UpdatedAt = os.time()
				}
				return saveMetadata()
			end

			return cache
		end

		env.DecompileCache = createDecompileCache()

		local function decompileUncached(script_instance, ...)
			local helperPreferred = Settings.Decompiler.UseLocalHelper == true
				and Settings.Decompiler.PreferLocalHelperDecompiler ~= false
				and env.HelperServer
				and env.HelperServer.Decompile
				and typeof(getscriptbytecode) == "function"

			if helperPreferred then
				local success, bytecode = pcall(env.getscriptbytecode, script_instance)
				if success and type(bytecode) == "string" and bytecode ~= "" then
					local decompiled = env.HelperServer.Decompile(bytecode)
					if isCacheableSource(decompiled) then
						return decompiled
					end
				end
			end

			local tryNative = not Settings.Decompiler.PreferDecompilerFallback

			if nativeDecompile and tryNative then
				local success, result = pcall(nativeDecompile, script_instance, ...)
				if success and isCacheableSource(result) then
					return tostring(result)
				end
			end

			-- If native failed or was skipped, try fallbacks using bytecode
			if typeof(getscriptbytecode) == "function" then
				-- Helper Fallback (offload to external decompiler backend)
				if not helperPreferred and Settings.Decompiler.UseLocalHelper == true and env.HelperServer and env.HelperServer.Decompile then
					local success, bytecode = pcall(env.getscriptbytecode, script_instance)
					if success and bytecode then
						local decompiled = env.HelperServer.Decompile(bytecode)
						if isCacheableSource(decompiled) then
							return decompiled
						end
					end
				end
				-- Fallback 1: Shiny Local Decompiler
				if Settings.Decompiler.DecompilerFallback == "Shiny" then
					local success, bytecode = pcall(env.getscriptbytecode, script_instance)
					if success and bytecode then
						local encoder = base64_encode or (crypt and crypt.base64encode) or (crypt and crypt.base64 and crypt.base64.encode)
						local encodedBytecode = encoder and encoder(bytecode) or bytecode

						local req = env.request or request
						local s, res = pcall(req, {
							Url = "http://localhost:" .. tostring(Settings.Decompiler.ShinyDecompilerPort) .. "/decompile",
							Method = "POST",
							Headers = {
								["Content-Type"] = "application/json"
							},
							Body = game:GetService("HttpService"):JSONEncode({
								script = encodedBytecode
							})
						})
						if s and res and res.StatusCode == 200 and isCacheableSource(res.Body) then
							return res.Body
						end
					end
				end

				-- Fallback 2: Default to lua.expert API
				return LuaExpertDec(script_instance)
			else
				-- If bytecode isn't supported but we had native decompiler, try it as absolute last resort
				if nativeDecompile then
					local success, result = pcall(nativeDecompile, script_instance, ...)
					if success and isCacheableSource(result) then
						return tostring(result)
					end
				end
			    return "-- getscriptbytecode is not supported by your executor and native decompiler failed."
			end
		end

		local function decompileWithCache(script_instance, ...)
			local cache = env.DecompileCache
			if cache then
				local cachedSource = cache.Read(script_instance)
				if cachedSource then
					return cachedSource
				end
			end

			local source = decompileUncached(script_instance, ...)
			if cache then
				pcall(cache.Write, script_instance, source)
			end
			return source
		end

		local function createDecompileQueue()
			local queue = {
				Jobs = {},
				Running = false,
				Paused = false,
				ActiveJob = nil,
				LastRun = 0,
				Completed = 0,
				Failed = 0,
			}

			local function getMinDelay()
				local tryNative = not Settings.Decompiler.PreferDecompilerFallback
				if nativeDecompile and tryNative then
					return 0.002 -- Instant native decompiler (2ms delay)
				elseif Settings.Decompiler.DecompilerFallback == "Shiny" then
					return 0.02 -- Localhost Shiny (20ms)
				else
					return 0.15 -- Remote API like lua.expert (150ms delay to prevent rate limits)
				end
			end

			local function sortJobs()
				table.sort(queue.Jobs, function(a, b)
					if a.Priority == b.Priority then
						return a.CreatedAt < b.CreatedAt
					end
					return a.Priority > b.Priority
				end)
			end

			local function startWorker()
				if queue.Running then return end
				queue.Running = true
				task.spawn(function()
					while #queue.Jobs > 0 do
						if queue.Paused then
							task.wait(0.2)
							continue
						end

						sortJobs()
						local job = table.remove(queue.Jobs, 1)
						queue.ActiveJob = job

						local waitTime = getMinDelay() - (os.clock() - queue.LastRun)
						if waitTime > 0 then task.wait(waitTime) end

						local success, result = pcall(decompileWithCache, job.Script, table.unpack(job.Args))
						job.Success = success
						job.Result = result
						job.Done = true
						queue.LastRun = os.clock()
						queue.ActiveJob = nil

						if success then
							queue.Completed += 1
						else
							queue.Failed += 1
						end

						if job.Callback then
							pcall(job.Callback, success, result, job.Script)
						end

						task.wait()
					end
					queue.Running = false
				end)
			end

			queue.Submit = function(script_instance, options, ...)
				options = options or {}
				local job = {
					Script = script_instance,
					Args = {...},
					Priority = options.Priority or 50,
					CreatedAt = os.clock(),
					Callback = options.Callback,
					Done = false,
					Success = false,
					Result = nil,
				}

				table.insert(queue.Jobs, job)
				startWorker()

				if options.Async then
					return job
				end

				while not job.Done do
					task.wait()
				end

				if not job.Success then
					error(job.Result)
				end
				return job.Result
			end

			queue.GetStatus = function()
				return {
					Queued = #queue.Jobs,
					Running = queue.Running,
					Paused = queue.Paused,
					Active = queue.ActiveJob and queue.ActiveJob.Script or nil,
					Completed = queue.Completed,
					Failed = queue.Failed,
				}
			end

			queue.SetPaused = function(paused)
				queue.Paused = paused and true or false
				if not queue.Paused then startWorker() end
			end

			queue.CancelQueued = function()
				for _, job in pairs(queue.Jobs) do
					job.Done = true
					job.Success = false
					job.Result = "Cancelled"
				end
				table.clear(queue.Jobs)
			end

			return queue
		end

		env.DecompileQueue = createDecompileQueue()

		-- Hook it directly into Dex with smart fallback chain and cache reuse.
		env.decompile = function(script_instance, ...)
			return env.DecompileQueue.Submit(script_instance, {Priority = 50}, ...)
		end

		env.decompilebackground = function(script_instance, callback, priority, ...)
			return env.DecompileQueue.Submit(script_instance, {Priority = priority or 10, Callback = callback, Async = true}, ...)
		end

		if Main.Elevated then
			getgenv().decompile = env.decompile
		end


		if identifyexecutor then
			Main.Executor = identifyexecutor()
		end

		Main.GuiHolder = Main.Elevated and service.CoreGui or plr:FindFirstChildOfClass("PlayerGui")

		setmetatable(env,nil)
	end

	Main.IncompatibleTest = function()
		--[[local function incompatibleMessage(reason, tolerated)
			local msg = Instance.new("ScreenGui")
			msg.IgnoreGuiInset = true
			local t = Instance.new("TextLabel",msg)
			t.BackgroundColor3 = Color3.fromRGB(50,50,50)
			t.Position = UDim2.new(0,0,0,0)
			t.Size = UDim2.new(1,0,1,0)
			t.TextColor3 = Color3.new(1,1,1)
			t.TextWrapped = true
			t.TextScaled = true
			t.Text = "\n\n\n\n\n\n\n\nHello Skidsploit user,\nZinnia, Chillz and the Secret Service does not approve of Dex being used on your skidsploit.\nPlease consider getting something better.\n\nIncompatible Reason: "..reason.."\n\n\n\n\n\n\n\n"

			-- This sound wont work!!!
			local sound = Instance.new("Sound",msg)
			sound.SoundId = "rbxassetid://175964948"
			sound.Volume = 1
			sound.Looped = true
			sound.Playing = true

			if not tolerated then
				Lib.ShowGui(msg)

				if os and os.execute then pcall(os.execute,'explorer "https://weao.xyz"') end
				if pcall(game.GetService, game,"MessageBusService") and game:GetService("MessageBusService").Publish then pcall(game:GetService("MessageBusService").Publish, game:GetService("MessageBusService"), game:GetService("MessageBusService"):GetMessageId("Linking", "openURLRequest"), {url = 'explorer "https://weao.xyz"'}) end
			else
				warn(msg)
			end
		end

																																													local yummy, evilList = "\105\100\101\110\116\105\102\121\101\120\101\99\117\116\111\114", { "\120\101\110\111", "\115\111\108\97\114\97", "\119\97\118\101" }
																																													if ggv and ggv()[yummy] then local wow = ggv()[yummy] if table.find(evilList, string.lower(wow)) then incompatibleMessage("\83\72\73\84\84\89\32\69\88\69\67\85\84\79\82") end end

		local t = {}
		t[1] = t
		local x = unpack(t) or incompatibleMessage("WRAPPER FAILED TO CYCLIC #1")
		if x[1] ~= t then incompatibleMessage("WRAPPER FAILED TO CYCLIC #2") end

		if game ~= workspace.Parent then
			incompatibleMessage("WRAPPER NO CACHE (game â‰  workspace.Parent)", true)
			game = workspace.Parent
		end

		if Main.Elevated and not loadstring("for i = 1,1 do continue end") then incompatibleMessage("CAN'T CONTINUE OR NO LOADSTRING")end

		local obj = newproxy(true)
		local mt = getmetatable(obj)
		mt.__index = function() incompatibleMessage("CAN'T NAMECALL (__index triggered instead of __namecall)") end
		mt.__namecall = function() end
		obj:No()

		local fEnv = setmetatable({zin = 5},{__index = getfenv()})
		local caller = function(f) f() end
		setfenv(caller,fEnv)
		caller(function() if not getfenv(2).zin then incompatibleMessage("RERU WILL BE FILING A LAWSUIT AGAINST YOU SOON") end end)

		local second = false
		coroutine.wrap(function() local start = tick() wait(5) if tick() - start < 0.1 or not second then incompatibleMessage("SKIDDED YIELDING") end end)()
		second = true]]
	end

	local function serialize(val)
		if typeof(val) == "Color3" then
			local serializedColor = {}
			serializedColor.R = val.R
			serializedColor.G = val.G
			serializedColor.B = val.B
			return serializedColor
		else
			return val
		end
	end

	local function deserialize(val)
		if typeof(val) == "table" then
			if val.R and val.G and val.B then
				return Color3.new(val.R, val.G, val.B)
			else
				return val
			end
		else
			return val
		end
	end

	Main.ExportSettings = function()
		local rawData = Settings or DefaultSettings

		local function recur(tbl)
			local newTbl = {}
			for i, v in pairs(tbl) do
				if typeof(v) == "table" then
					newTbl[i] = recur(v)
				else
					newTbl[i] = serialize(v)
				end
			end
			return newTbl
		end

		-- serialize color3 sebelum encode
		local serializedData = recur(rawData)

		local s, json = pcall(service.HttpService.JSONEncode, service.HttpService, serializedData)
		if s and json then
			return json
		end
	end


	--warn(Main.ExportSettings())

	Main.LoadSettings = function()
		local function applyModernThemeDefaults()
			if type(Settings.Theme) ~= "table" then
				Settings.Theme = {}
			end

			local defaults = DefaultSettings.Theme
			if Settings.Theme.UIRevision ~= defaults.UIRevision then
				local paletteKeys = {
					"Main1", "Main2", "Outline1", "Outline2", "Outline3", "TextBox", "Menu",
					"ListSelection", "Button", "ButtonHover", "ButtonPress", "Highlight", "Text",
					"PlaceholderText", "Important", "Success", "Warning", "AccentSoft"
				}
				for _, key in ipairs(paletteKeys) do
					Settings.Theme[key] = defaults[key]
				end
				Settings.Theme.UIRevision = defaults.UIRevision
			end

			for key, value in pairs(defaults) do
				if Settings.Theme[key] == nil then
					Settings.Theme[key] = value
				end
			end
		end

		local s, data = pcall(env.readfile or error, "DexPlusPlusSettings.json")
		if s and data and data ~= "" then

			local s, decoded = pcall(service.HttpService.JSONDecode, service.HttpService, data)
			if s and decoded then

				local function recur(tbl)
					local newTbl = {}
					for i, v in pairs(tbl) do
						if typeof(v) == "table" then
							newTbl[i] = deserialize(recur(v))
						else
							newTbl[i] = deserialize(v)
						end
					end
					return newTbl
				end

				local deserializedData = recur(decoded)
				for k, v in pairs(deserializedData) do
					Settings[k] = v
				end
				applyModernThemeDefaults()
			else
				warn("failed to decode settings json")
			end
		else
			Main.ResetSettings()
			applyModernThemeDefaults()
		end
	end




	Main.ResetSettings = function()
		local function recur(t,res)
			for set,val in pairs(t) do
				if type(val) == "table" and val._Recurse then
					if type(res[set]) ~= "table" then
						res[set] = {}
					end
					recur(val,res[set])
				else
					res[set] = val
				end
			end
			return res
		end
		recur(DefaultSettings,Settings)
	end

	Main.FetchAPI = function(callbackiflong, callbackiftoolong, XD)
		local downloaded = false
		local api,rawAPI
		if Main.Elevated then
			if Main.LocalDepsUpToDate() then
				local localAPI = Lib.ReadFile("dex/rbx_api.dat")
				if localAPI then
					rawAPI = localAPI
				else
					Main.DepsVersionData[1] = ""
				end
			end
			task.spawn(function()
				task.wait(10)
				if not downloaded and callbackiflong then callbackiflong() end

				task.wait(20) -- 30
				if not downloaded and callbackiftoolong then callbackiftoolong() end

				task.wait(30) -- 60
				if not downloaded and XD then XD() end
			end)
			-- lmfao async makes it work to load big file
			rawAPI = rawAPI or game:HttpGet("http://setup.roblox.com/"..Main.RobloxVersion.."-API-Dump.json")
		else
			if script:FindFirstChild("API") then
				rawAPI = require(script.API)
			else
				error("NO API EXISTS")
			end
		end
		downloaded = true

		Main.RawAPI = rawAPI
		api = service.HttpService:JSONDecode(rawAPI)

		local classes,enums = {},{}
		local categoryOrder,seenCategories = {},{}

		local function insertAbove(t,item,aboveItem)
			local findPos = table.find(t,item)
			if not findPos then return end
			table.remove(t,findPos)

			local pos = table.find(t,aboveItem)
			if not pos then return end
			table.insert(t,pos,item)
		end

		for _,class in pairs(api.Classes) do
			local newClass = {}
			newClass.Name = class.Name
			newClass.Superclass = class.Superclass
			newClass.Properties = {}
			newClass.Functions = {}
			newClass.Events = {}
			newClass.Callbacks = {}
			newClass.Tags = {}

			if class.Tags then for c,tag in pairs(class.Tags) do newClass.Tags[tag] = true end end
			for __,member in pairs(class.Members) do
				local newMember = {}
				newMember.Name = member.Name
				newMember.Class = class.Name
				newMember.Security = member.Security
				newMember.Tags ={}
				if member.Tags then for c,tag in pairs(member.Tags) do newMember.Tags[tag] = true end end

				local mType = member.MemberType
				if mType == "Property" then
					local propCategory = member.Category or "Other"
					propCategory = propCategory:match("^%s*(.-)%s*$")
					if not seenCategories[propCategory] then
						categoryOrder[#categoryOrder+1] = propCategory
						seenCategories[propCategory] = true
					end
					newMember.ValueType = member.ValueType
					newMember.Category = propCategory
					newMember.Serialization = member.Serialization
					table.insert(newClass.Properties,newMember)
				elseif mType == "Function" then
					newMember.Parameters = {}
					newMember.ReturnType = member.ReturnType.Name
					for c,param in pairs(member.Parameters) do
						table.insert(newMember.Parameters,{Name = param.Name, Type = param.Type.Name})
					end
					table.insert(newClass.Functions,newMember)
				elseif mType == "Event" then
					newMember.Parameters = {}
					for c,param in pairs(member.Parameters) do
						table.insert(newMember.Parameters,{Name = param.Name, Type = param.Type.Name})
					end
					table.insert(newClass.Events,newMember)
				end
			end

			classes[class.Name] = newClass
		end

		for _,class in pairs(classes) do
			class.Superclass = classes[class.Superclass]
		end

		for _,enum in pairs(api.Enums) do
			local newEnum = {}
			newEnum.Name = enum.Name
			newEnum.Items = {}
			newEnum.Tags = {}

			if enum.Tags then for c,tag in pairs(enum.Tags) do newEnum.Tags[tag] = true end end
			for __,item in pairs(enum.Items) do
				local newItem = {}
				newItem.Name = item.Name
				newItem.Value = item.Value
				table.insert(newEnum.Items,newItem)
			end

			enums[enum.Name] = newEnum
		end

		local function getMember(class,member)
			if not classes[class] or not classes[class][member] then return end
			local result = {}

			local currentClass = classes[class]
			while currentClass do
				for _,entry in pairs(currentClass[member]) do
					result[#result+1] = entry
				end
				currentClass = currentClass.Superclass
			end

			table.sort(result,function(a,b) return a.Name < b.Name end)
			return result
		end

		insertAbove(categoryOrder,"Behavior","Tuning")
		insertAbove(categoryOrder,"Appearance","Data")
		insertAbove(categoryOrder,"Attachments","Axes")
		insertAbove(categoryOrder,"Cylinder","Slider")
		insertAbove(categoryOrder,"Localization","Jump Settings")
		insertAbove(categoryOrder,"Surface","Motion")
		insertAbove(categoryOrder,"Surface Inputs","Surface")
		insertAbove(categoryOrder,"Part","Surface Inputs")
		insertAbove(categoryOrder,"Assembly","Surface Inputs")
		insertAbove(categoryOrder,"Character","Controls")
		categoryOrder[#categoryOrder+1] = "Unscriptable"
		categoryOrder[#categoryOrder+1] = "Attributes"

		local categoryOrderMap = {}
		for i = 1,#categoryOrder do
			categoryOrderMap[categoryOrder[i]] = i
		end

		return {
			Classes = classes,
			Enums = enums,
			CategoryOrder = categoryOrderMap,
			GetMember = getMember
		}
	end

	Main.FetchRMD = function()
		local rawXML
		if Main.Elevated then
			if Main.LocalDepsUpToDate() then
				local localRMD = Lib.ReadFile("dex/rbx_rmd.dat")
				if localRMD then
					rawXML = localRMD
				else
					Main.DepsVersionData[1] = ""
				end
			end
			rawXML = rawXML or game:HttpGet("https://raw.githubusercontent.com/CloneTrooper1019/Roblox-Client-Tracker/roblox/ReflectionMetadata.xml")
		else
			if script:FindFirstChild("RMD") then
				rawXML = require(script.RMD)
			else
				error("NO RMD EXISTS")
			end
		end
		Main.RawRMD = rawXML
		local parsed = Lib.ParseXML(rawXML)
		local classList = parsed.children[1].children[1].children
		local enumList = parsed.children[1].children[2].children
		local propertyOrders = {}

		local classes,enums = {},{}
		for _,class in pairs(classList) do
			local className = ""
			for _,child in pairs(class.children) do
				if child.tag == "Properties" then
					local data = {Properties = {}, Functions = {}}
					local props = child.children
					for _,prop in pairs(props) do
						local name = prop.attrs.name
						name = name:sub(1,1):upper()..name:sub(2)
						data[name] = prop.children[1].text
					end
					className = data.Name
					classes[className] = data
				elseif child.attrs.class == "ReflectionMetadataProperties" then
					local members = child.children
					for _,member in pairs(members) do
						if member.attrs.class == "ReflectionMetadataMember" then
							local data = {}
							if member.children[1].tag == "Properties" then
								local props = member.children[1].children
								for _,prop in pairs(props) do
									if prop.attrs then
										local name = prop.attrs.name
										name = name:sub(1,1):upper()..name:sub(2)
										data[name] = prop.children[1].text
									end
								end
								if data.PropertyOrder then
									local orders = propertyOrders[className]
									if not orders then orders = {} propertyOrders[className] = orders end
									orders[data.Name] = tonumber(data.PropertyOrder)
								end
								classes[className].Properties[data.Name] = data
							end
						end
					end
				elseif child.attrs.class == "ReflectionMetadataFunctions" then
					local members = child.children
					for _,member in pairs(members) do
						if member.attrs.class == "ReflectionMetadataMember" then
							local data = {}
							if member.children[1].tag == "Properties" then
								local props = member.children[1].children
								for _,prop in pairs(props) do
									if prop.attrs then
										local name = prop.attrs.name
										name = name:sub(1,1):upper()..name:sub(2)
										data[name] = prop.children[1].text
									end
								end
								classes[className].Functions[data.Name] = data
							end
						end
					end
				end
			end
		end

		for _,enum in pairs(enumList) do
			local enumName = ""
			for _,child in pairs(enum.children) do
				if child.tag == "Properties" then
					local data = {Items = {}}
					local props = child.children
					for _,prop in pairs(props) do
						local name = prop.attrs.name
						name = name:sub(1,1):upper()..name:sub(2)
						data[name] = prop.children[1].text
					end
					enumName = data.Name
					enums[enumName] = data
				elseif child.attrs.class == "ReflectionMetadataEnumItem" then
					local data = {}
					if child.children[1].tag == "Properties" then
						local props = child.children[1].children
						for _,prop in pairs(props) do
							local name = prop.attrs.name
							name = name:sub(1,1):upper()..name:sub(2)
							data[name] = prop.children[1].text
						end
						enums[enumName].Items[data.Name] = data
					end
				end
			end
		end

		return {Classes = classes, Enums = enums, PropertyOrders = propertyOrders}
	end

	Main.ShowGui = Main.SecureGui

	Main.CreateIntro = function(initStatus) -- TODO: Must theme and show errors
		local gui = create({
			{1,"ScreenGui",{Name="Intro",}},
			{2,"Frame",{Active=true,BackgroundColor3=Color3.new(0.20392157137394,0.20392157137394,0.20392157137394),BorderSizePixel=0,Name="Main",Parent={1},Position=UDim2.new(0.5,-175,0.5,-100),Size=UDim2.new(0,350,0,200),}},
			{3,"Frame",{BackgroundColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),BorderSizePixel=0,ClipsDescendants=true,Name="Holder",Parent={2},Size=UDim2.new(1,0,1,0),}},
			{4,"UIGradient",{Parent={3},Rotation=30,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(1,1,0),}),}},
			{5,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=4,Name="Title",Parent={3},Position=UDim2.new(0,-190,0,15),Size=UDim2.new(0,100,0,50),Text="Dex++",TextColor3=Color3.new(1,1,1),TextSize=50,TextTransparency=1,}},
			{6,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Desc",Parent={3},Position=UDim2.new(0,-230,0,60),Size=UDim2.new(0,180,0,25),Text="Ultimate Debugging Suite",TextColor3=Color3.new(1,1,1),TextSize=18,TextTransparency=1,}},
			{7,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="StatusText",Parent={3},Position=UDim2.new(0,20,0,110),Size=UDim2.new(0,180,0,25),Text="Fetching API",TextColor3=Color3.new(1,1,1),TextSize=14,TextTransparency=1,}},
			{8,"Frame",{BackgroundColor3=Color3.new(0.20392157137394,0.20392157137394,0.20392157137394),BorderSizePixel=0,Name="ProgressBar",Parent={3},Position=UDim2.new(0,110,0,145),Size=UDim2.new(0,0,0,4),}},
			{9,"Frame",{BackgroundColor3=Color3.new(0.2392156869173,0.56078433990479,0.86274510622025),BorderSizePixel=0,Name="Bar",Parent={8},Size=UDim2.new(0,0,1,0),}},
			{10,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://2764171053",ImageColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),Parent={8},ScaleType=1,Size=UDim2.new(1,0,1,0),SliceCenter=Rect.new(2,2,254,254),}},
			{11,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Creator",Parent={2},Position=UDim2.new(1,-110,1,-20),Size=UDim2.new(0,105,0,20),Text="Developed by Chillz.",TextColor3=Color3.new(1,1,1),TextSize=14,TextXAlignment=1,}},
			{12,"UIGradient",{Parent={11},Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(1,1,0),}),}},
			{13,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Version",Parent={2},Position=UDim2.new(1,-110,1,-35),Size=UDim2.new(0,105,0,20),Text=Main.Version,TextColor3=Color3.new(1,1,1),TextSize=14,TextXAlignment=1,}},
			{14,"UIGradient",{Parent={13},Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(1,1,0),}),}},
			{15,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Image="rbxassetid://1427967925",Name="Outlines",Parent={2},Position=UDim2.new(0,-5,0,-5),ScaleType=1,Size=UDim2.new(1,10,1,10),SliceCenter=Rect.new(6,6,25,25),TileSize=UDim2.new(0,20,0,20),}},
			{16,"UIGradient",{Parent={15},Rotation=-30,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(1,1,0),}),}},
			{17,"UIGradient",{Parent={2},Rotation=-30,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(1,1,0),}),}},
			{18,"UIDragDetector", {Parent={2}}}
		})
		Main.ShowGui(gui)
		local backGradient = gui.Main.UIGradient
		local outlinesGradient = gui.Main.Outlines.UIGradient
		local holderGradient = gui.Main.Holder.UIGradient
		local titleText = gui.Main.Holder.Title
		local descText = gui.Main.Holder.Desc
		local versionText = gui.Main.Version
		local versionGradient = versionText.UIGradient
		local creatorText = gui.Main.Creator
		local creatorGradient = creatorText.UIGradient
		local statusText = gui.Main.Holder.StatusText
		local progressBar = gui.Main.Holder.ProgressBar
		local tweenS = service.TweenService

		local renderStepped = service.RunService.RenderStepped
		local signalWait = renderStepped.wait
		local fastwait = function(s)
			if not s then return signalWait(renderStepped) end
			local start = tick()
			while tick() - start < s do signalWait(renderStepped) end
		end

		statusText.Text = initStatus

		local function tweenNumber(n,ti,func)
			local tweenVal = Instance.new("IntValue")
			tweenVal.Value = 0
			tweenVal.Changed:Connect(func)
			local tween = tweenS:Create(tweenVal,ti,{Value = n})
			tween:Play()
			tween.Completed:Connect(function()
				tweenVal:Destroy()
			end)
		end

		local ti = TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
		tweenNumber(100,ti,function(val)
			val = val/200
			local start = NumberSequenceKeypoint.new(0,0)
			local a1 = NumberSequenceKeypoint.new(val,0)
			local a2 = NumberSequenceKeypoint.new(math.min(0.5,val+math.min(0.05,val)),1)
			if a1.Time == a2.Time then a2 = a1 end
			local b1 = NumberSequenceKeypoint.new(1-val,0)
			local b2 = NumberSequenceKeypoint.new(math.max(0.5,1-val-math.min(0.05,val)),1)
			if b1.Time == b2.Time then b2 = b1 end
			local goal = NumberSequenceKeypoint.new(1,0)
			backGradient.Transparency = NumberSequence.new({start,a1,a2,b2,b1,goal})
			outlinesGradient.Transparency = NumberSequence.new({start,a1,a2,b2,b1,goal})
		end)

		fastwait(0.4)

		tweenNumber(100,ti,function(val)
			val = val/166.66
			local start = NumberSequenceKeypoint.new(0,0)
			local a1 = NumberSequenceKeypoint.new(val,0)
			local a2 = NumberSequenceKeypoint.new(val+0.01,1)
			local goal = NumberSequenceKeypoint.new(1,1)
			holderGradient.Transparency = NumberSequence.new({start,a1,a2,goal})
		end)

		tweenS:Create(titleText,ti,{Position = UDim2.new(0,60,0,15), TextTransparency = 0}):Play()
		tweenS:Create(descText,ti,{Position = UDim2.new(0,20,0,60), TextTransparency = 0}):Play()

		local function rightTextTransparency(obj)
			tweenNumber(100,ti,function(val)
				val = val/100
				local a1 = NumberSequenceKeypoint.new(1-val,0)
				local a2 = NumberSequenceKeypoint.new(math.max(0,1-val-0.01),1)
				if a1.Time == a2.Time then a2 = a1 end
				local start = NumberSequenceKeypoint.new(0,a1 == a2 and 0 or 1)
				local goal = NumberSequenceKeypoint.new(1,0)
				obj.Transparency = NumberSequence.new({start,a2,a1,goal})
			end)
		end
		rightTextTransparency(versionGradient)
		rightTextTransparency(creatorGradient)

		fastwait(0.9)

		local progressTI = TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)

		tweenS:Create(statusText,progressTI,{Position = UDim2.new(0,20,0,120), TextTransparency = 0}):Play()
		tweenS:Create(progressBar,progressTI,{Position = UDim2.new(0,60,0,145), Size = UDim2.new(0,100,0,4)}):Play()

		fastwait(0.25)

		local function setProgress(text,n)
			statusText.Text = text
			tweenS:Create(progressBar.Bar,progressTI,{Size = UDim2.new(n,0,1,0)}):Play()
		end

		local function close()
			tweenS:Create(titleText,progressTI,{TextTransparency = 1}):Play()
			tweenS:Create(descText,progressTI,{TextTransparency = 1}):Play()
			tweenS:Create(versionText,progressTI,{TextTransparency = 1}):Play()
			tweenS:Create(creatorText,progressTI,{TextTransparency = 1}):Play()
			tweenS:Create(statusText,progressTI,{TextTransparency = 1}):Play()
			tweenS:Create(progressBar,progressTI,{BackgroundTransparency = 1}):Play()
			tweenS:Create(progressBar.Bar,progressTI,{BackgroundTransparency = 1}):Play()
			tweenS:Create(progressBar.ImageLabel,progressTI,{ImageTransparency = 1}):Play()

			tweenNumber(100,TweenInfo.new(0.4,Enum.EasingStyle.Back,Enum.EasingDirection.In),function(val)
				val = val/250
				local start = NumberSequenceKeypoint.new(0,0)
				local a1 = NumberSequenceKeypoint.new(0.6+val,0)
				local a2 = NumberSequenceKeypoint.new(math.min(1,0.601+val),1)
				if a1.Time == a2.Time then a2 = a1 end
				local goal = NumberSequenceKeypoint.new(1,a1 == a2 and 0 or 1)
				holderGradient.Transparency = NumberSequence.new({start,a1,a2,goal})
			end)

			fastwait(0.5)
			gui.Main.BackgroundTransparency = 1
			outlinesGradient.Rotation = 30

			tweenNumber(100,ti,function(val)
				val = val/100
				local start = NumberSequenceKeypoint.new(0,1)
				local a1 = NumberSequenceKeypoint.new(val,1)
				local a2 = NumberSequenceKeypoint.new(math.min(1,val+math.min(0.05,val)),0)
				if a1.Time == a2.Time then a2 = a1 end
				local goal = NumberSequenceKeypoint.new(1,a1 == a2 and 1 or 0)
				outlinesGradient.Transparency = NumberSequence.new({start,a1,a2,goal})
				holderGradient.Transparency = NumberSequence.new({start,a1,a2,goal})
			end)

			fastwait(0.45)
			gui:Destroy()
		end

		return {SetProgress = setProgress, Close = close, Object = gui}
	end

	Main.CompareVersions = function(current, latest)
		local function nums(version)
			local out = {}
			for n in tostring(version or ""):gmatch("%d+") do
				out[#out + 1] = tonumber(n) or 0
			end
			return out
		end

		local a, b = nums(current), nums(latest)
		for i = 1, math.max(#a, #b) do
			local av, bv = a[i] or 0, b[i] or 0
			if bv > av then return 1 end
			if bv < av then return -1 end
		end
		return 0
	end

	Main.GetRemoteScriptVersion = function(source)
		if type(source) ~= "string" then return nil end
		return source:match('Main%.Version%s*=%s*"([^"]+)"')
			or source:match("Main%.Version%s*=%s*'([^']+)'")
			or source:match("Version%s+([%d%.]+)")
	end

	Main.GetUpdateRef = function()
		local settings = Settings or DefaultSettings or {}
		local ref = tostring(settings.AutoUpdateRef or Main.DefaultUpdateRef or "")
		ref = ref:gsub("^%s+", ""):gsub("%s+$", "")
		if ref == "" then return nil end

		local lowerRef = ref:lower()
		local isBranchRef = lowerRef == "main" or lowerRef == "master" or lowerRef:match("^refs/heads/")
		if isBranchRef and settings.AutoUpdateAllowBranch ~= true then
			return nil
		end
		return ref
	end

	Main.GetUpdateScriptURL = function()
		local ref = Main.GetUpdateRef()
		if not ref then return nil end
		return "https://raw.githubusercontent.com/"..Main.GitRepoName.."/"..ref.."/"..Main.UpdateScriptPath
	end

	Main.RestartFromLatest = function()
		if Main.Restarting then return true end
		local source = Main.LatestUpdateSource
		if not source or source == "" then
			local updateUrl = Main.GetUpdateScriptURL()
			if not updateUrl then return false end
			local ok, result = pcall(oldgame.HttpGet, game, updateUrl, true)
			if ok then source = result end
		end
		if type(source) ~= "string" or source == "" then return false end

		local loader = env and env.loadstring or loadstring
		if not loader then return false end

		Main.Restarting = true
		task.spawn(function()
			local restarted = false
			local okRestart, restartErr = pcall(function()
				Main.Uninit()
				task.wait(0.2)
				local ok, fn = pcall(loader, source, "DEX++ Latest")
				if ok and type(fn) == "function" then
					restarted = true
					task.spawn(fn)
				elseif not ok then
					warn("DEX++ latest restart load failed: " .. tostring(fn))
				end
			end)
			if not okRestart then
				warn("DEX++ latest restart failed: " .. tostring(restartErr))
			end
			if not restarted then
				Main.Restarting = false
			end
		end)
		return true
	end

	Main.ShowUpdatePrompt = function(latestVersion)
		local gui = create({
			{1,"ScreenGui",{IgnoreGuiInset=true,Name="UpdatePrompt",ResetOnSpawn=false,}},
			{2,"Frame",{BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=0.35,BorderSizePixel=0,Name="Dim",Parent={1},Size=UDim2.new(1,0,1,0),}},
			{3,"Frame",{AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=Settings.Theme.Main2,BorderSizePixel=0,Name="Card",Parent={2},Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(0,360,0,156),}},
			{4,"UICorner",{CornerRadius=UDim.new(0,6),Parent={3},}},
			{5,"Frame",{BackgroundColor3=Settings.Theme.ListSelection,BorderSizePixel=0,Name="Accent",Parent={3},Size=UDim2.new(1,0,0,3),}},
			{6,"TextLabel",{BackgroundTransparency=1,Font=4,Name="Title",Parent={3},Position=UDim2.new(0,18,0,16),Size=UDim2.new(1,-36,0,24),Text="New DEX++ version detected",TextColor3=Settings.Theme.Text,TextSize=18,TextXAlignment=0,}},
			{7,"TextLabel",{BackgroundTransparency=1,Font=3,Name="Body",Parent={3},Position=UDim2.new(0,18,0,46),Size=UDim2.new(1,-36,0,44),Text="Current: "..tostring(Main.Version).."  |  Latest: "..tostring(latestVersion).."\nRestart now to load the latest script?",TextColor3=Settings.Theme.PlaceholderText,TextSize=14,TextWrapped=true,TextXAlignment=0,TextYAlignment=0,}},
			{8,"TextButton",{AutoButtonColor=false,BackgroundColor3=Settings.Theme.ListSelection,BorderSizePixel=0,Font=4,Name="Restart",Parent={3},Position=UDim2.new(1,-174,1,-46),Size=UDim2.new(0,78,0,28),Text="Restart",TextColor3=Settings.Theme.Text,TextSize=14,}},
			{9,"UICorner",{CornerRadius=UDim.new(0,4),Parent={8},}},
			{10,"TextButton",{AutoButtonColor=false,BackgroundColor3=Settings.Theme.Button,BorderSizePixel=0,Font=4,Name="Later",Parent={3},Position=UDim2.new(1,-88,1,-46),Size=UDim2.new(0,70,0,28),Text="Later",TextColor3=Settings.Theme.Text,TextSize=14,}},
			{11,"UICorner",{CornerRadius=UDim.new(0,4),Parent={10},}},
		})

		Main.SecureGui(gui)

		local card = gui.Dim.Card
		card.Restart.MouseEnter:Connect(function() card.Restart.BackgroundColor3 = Settings.Theme.ButtonHover end)
		card.Restart.MouseLeave:Connect(function() card.Restart.BackgroundColor3 = Settings.Theme.ListSelection end)
		card.Later.MouseEnter:Connect(function() card.Later.BackgroundColor3 = Settings.Theme.ButtonHover end)
		card.Later.MouseLeave:Connect(function() card.Later.BackgroundColor3 = Settings.Theme.Button end)
		card.Later.MouseButton1Click:Connect(function()
			gui:Destroy()
		end)
		card.Restart.MouseButton1Click:Connect(function()
			card.Restart.Text = "Loading"
			card.Restart.Active = false
			card.Later.Active = false
			if not Main.RestartFromLatest() then
				card.Restart.Text = "Failed"
				task.wait(1.5)
				if gui.Parent then gui:Destroy() end
			end
		end)
	end

	Main.CheckForUpdatesAsync = function()
		if Settings.AutoCheckUpdate == false then return end
		if Main.UpdateCheckStarted then return end
		Main.UpdateCheckStarted = true
		coroutine.wrap(function()
			task.wait(1)
			local updateUrl = Main.GetUpdateScriptURL()
			if not updateUrl then return end
			Main.UpdateScriptURL = updateUrl
			local ok, source = pcall(function() return game:HttpGet(updateUrl, true) end)
			if not ok or type(source) ~= "string" or source == "" then return end
			local latestVersion = Main.GetRemoteScriptVersion(source)
			if not latestVersion then return end
			if Main.CompareVersions(Main.Version, latestVersion) <= 0 then return end
			Main.LatestUpdateSource = source
			Main.ShowUpdatePrompt(latestVersion)
		end)()
	end

	Main.UpdateMenuCanvas = function()
		if not Main.AppsFrame or not Main.AppsContainerGrid then return end
		task.defer(function()
			if not Main.AppsFrame or not Main.AppsContainerGrid then return end
			local height = math.max(Main.AppsContainerGrid.AbsoluteContentSize.Y + 20, Main.AppsFrame.AbsoluteSize.Y)
			Main.AppsFrame.CanvasSize = UDim2.new(0,0,0,height)
		end)
	end

	Main.ApplyMenuFilter = function()
		local query = string.lower(Main.MenuSearchText or "")
		local visible = 0
		local total = 0
		for _, card in ipairs(Main.AppCards) do
			total = total + 1
			local category = appCategories[card.Name] or "Advanced"
			local categoryMatch = (currentCategory == "All") or 
								  (currentCategory == "Core" and category == "Core") or
								  (currentCategory == "Spy" and category == "Spy & Hook") or
								  (currentCategory == "Search" and category == "Search & Info") or
								  (currentCategory == "Advanced" and category == "Advanced")

			local isVisible = categoryMatch and (query == "" or string.find(card.SearchText, query, 1, true) ~= nil)
			if Main.HiddenAppsContainer and Main.AppsContainer then
				card.Gui.Parent = isVisible and Main.AppsContainer or Main.HiddenAppsContainer
				card.Gui.Visible = true
			else
				card.Gui.Visible = isVisible
			end
			if isVisible then visible = visible + 1 end
		end
		if Main.MenuCountLabel then
			Main.MenuCountLabel.Text = query == "" and (visible .. " tools") or (visible .. " / " .. total .. " tools")
		end
		Main.UpdateMenuCanvas()
	end

	Main.SmoothScrollingFrame = function(frame, step)
		local targetY = 0
		local tween
		local suppressCanvasSync = false
		local disabledNativeScroll = pcall(function()
			frame.ScrollingEnabled = false
		end)
		if not disabledNativeScroll then
			return
		end

		local function clampTarget()
			local maxY = math.max(0, frame.AbsoluteCanvasSize.Y - frame.AbsoluteWindowSize.Y)
			targetY = math.clamp(targetY, 0, maxY)
			return maxY
		end

		frame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			if suppressCanvasSync then return end
			local currentY = frame.CanvasPosition.Y
			if math.abs(currentY - targetY) > 2 and (not tween or tween.PlaybackState ~= Enum.PlaybackState.Playing) then
				targetY = currentY
				clampTarget()
			end
		end)

		local function scrollByInput(input)
			if not tween or tween.PlaybackState ~= Enum.PlaybackState.Playing then
				targetY = frame.CanvasPosition.Y
			end
			local direction = input.Position.Z > 0 and -1 or 1
			targetY = targetY + direction * (step or 96)
			clampTarget()
			suppressCanvasSync = true
			if tween then tween:Cancel() end
			tween = service.TweenService:Create(frame, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CanvasPosition = Vector2.new(frame.CanvasPosition.X, targetY)
			})
			suppressCanvasSync = false
			tween:Play()
		end

		return scrollByInput
	end

	Main.CreateApp = function(data)
		if Main.MenuApps[data.Name] then return end -- TODO: Handle conflict
		local control = {}

		local app = Main.AppTemplate:Clone()

		local iconIndex = data.Icon
		if data.IconMap and iconIndex then
			if type(iconIndex) == "number" then
				data.IconMap:Display(app.Main.Icon,iconIndex)
			elseif type(iconIndex) == "string" then
				data.IconMap:DisplayByKey(app.Main.Icon,iconIndex)
			end
		elseif type(iconIndex) == "string" then
			app.Main.Icon.Image = iconIndex
		else
			app.Main.Icon.Image = ""
		end

		local stroke = app.Main:FindFirstChildOfClass("UIStroke")
		local function updateState()
			local hovering = Lib.CheckMouseInGui(app.Main)
			app.Main.BackgroundTransparency = 0
			app.Main.BackgroundColor3 = data.Open and (Settings.Theme.AccentSoft or Settings.Theme.Main1) or (hovering and Settings.Theme.Main1 or Settings.Theme.Button)
			app.Main.Highlight.Visible = data.Open
			if app.Main:FindFirstChild("ActiveMarker") then
				app.Main.ActiveMarker.Visible = data.Open
			end
			if stroke then
				stroke.Color = data.Open and Settings.Theme.Highlight or Settings.Theme.Outline1
				stroke.Transparency = data.Open and 0.05 or (hovering and 0.18 or 0.48)
			end
		end

		local function enable(silent)
			if data.Open then return end
			data.Open = true
			updateState()
			if not silent then
				if data.Window then data.Window:Show() end
				if data.OnClick then data.OnClick(data.Open) end
			end
		end

		local function disable(silent)
			if not data.Open then return end
			data.Open = false
			updateState()
			if not silent then
				if data.Window then data.Window:Hide() end
				if data.OnClick then data.OnClick(data.Open) end
			end
		end

		updateState()

		app.Main.Size = UDim2.new(1,0,0,68)
		app.Main.AppName.Text = data.Name
		app.Main.AppName.Font = Enum.Font.GothamBold
		app.Main.AppName.TextXAlignment = Enum.TextXAlignment.Left

		local categoryLabel = app.Main:FindFirstChild("CategoryLabel")
		if not categoryLabel then
			categoryLabel = Instance.new("TextLabel")
			categoryLabel.Name = "CategoryLabel"
			categoryLabel.BackgroundTransparency = 1
			categoryLabel.Font = Enum.Font.Gotham
			categoryLabel.Position = UDim2.new(0,58,0,34)
			categoryLabel.Size = UDim2.new(1,-72,0,18)
			categoryLabel.TextColor3 = Settings.Theme.PlaceholderText
			categoryLabel.TextSize = 11
			categoryLabel.TextTruncate = Enum.TextTruncate.AtEnd
			categoryLabel.TextXAlignment = Enum.TextXAlignment.Left
			categoryLabel.Parent = app.Main
		end
		categoryLabel.Text = appCategories[data.Name] or "Advanced"
		categoryLabel.Visible = true

		if app.Main.Icon then
			app.Main.Icon.BackgroundTransparency = 1
			app.Main.Icon.ImageColor3 = Settings.Theme.Text
			app.Main.Icon.ImageTransparency = 0
		end

		app.Main.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				app.Main.BackgroundColor3 = data.Open and (Settings.Theme.AccentSoft or Settings.Theme.Main1) or Settings.Theme.Main1
				if stroke then stroke.Transparency = data.Open and 0.05 or 0.18 end
			end
		end)


		app.Main.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				updateState()
			end
		end)

		app.Main.MouseButton1Click:Connect(function()
			if data.Open then disable() else enable() end
		end)

		local window = data.Window
		if window then
			window.OnActivate:Connect(function() enable(true) end)
			window.OnDeactivate:Connect(function() disable(true) end)
		end

		app.Visible = true
		app.Parent = Main.AppsContainer
		table.insert(Main.AppCards, {
			Gui = app,
			Name = data.Name,
			SearchText = string.lower(data.Name .. " " .. tostring(data.Icon or "") .. " " .. tostring(appCategories[data.Name] or "Advanced"))
		})
		Main.ApplyMenuFilter()

		control.Enable = enable
		control.Disable = disable
		Main.MenuApps[data.Name] = control
		return control
	end

	Main.CreateLazyWindowApp = function(data)
		local initialized = false
		local control
		local moduleData = data.Module
		local ensureInit

		ensureInit = function()
			if not moduleData then
				if data.GetModule then
					moduleData = data.GetModule()
				end
				if not moduleData then
					warn("Lazy app module unavailable: " .. tostring(data.Name))
					if control then control.Disable(true) end
					return false
				end
				moduleData.EnsureInit = ensureInit
			end

			if initialized then return true end
			if moduleData.Init then
				local ok, err = pcall(moduleData.Init)
				if not ok then
					warn("Failed to lazy init " .. tostring(data.Name) .. ": " .. tostring(err))
					if control then control.Disable(true) end
					return false
				end
			end
			initialized = true
			if moduleData.Window then
				moduleData.Window.OnActivate:Connect(function()
					if control then control.Enable(true) end
				end)
				moduleData.Window.OnDeactivate:Connect(function()
					if control then control.Disable(true) end
				end)
			end
			return true
		end

		if moduleData then
			moduleData.EnsureInit = ensureInit
		end

		if data.Hidden then
			control = {
				Enable = function(silent)
					if not ensureInit() then return end
					if not silent and moduleData and moduleData.Window then
						moduleData.Window:Show()
					end
				end,
				Disable = function(silent)
					if not silent and initialized and moduleData and moduleData.Window then
						moduleData.Window:Hide()
					end
				end,
			}
			Main.MenuApps[data.Name] = control
			return control
		end

		control = Main.CreateApp({
			Name = data.Name,
			IconMap = data.IconMap,
			Icon = data.Icon,
			OnClick = function(open)
				if open then
					if not ensureInit() then return end
					if moduleData.Window then
						moduleData.Window:Show()
					else
						warn("Lazy app has no window: " .. tostring(data.Name))
						if control then control.Disable(true) end
					end
				elseif initialized and moduleData and moduleData.Window then
					moduleData.Window:Hide()
				end
			end
		})

		return control
	end

	Main.SetMainGuiOpen = function(val)
		Main.MainGuiOpen = val

		Main.MainGui.OpenButton.Text = "DEX++"
		if val then Main.MainGui.OpenButton.MainFrame.Visible = true end
		Main.MainGui.OpenButton.MainFrame:TweenSize(val and UDim2.new(0,500,0,560) or UDim2.new(0,0,0,0),Enum.EasingDirection.Out,Enum.EasingStyle.Quart,0.22,true)
		--Main.MainGui.OpenButton.BackgroundTransparency = val and 0 or (Lib.CheckMouseInGui(Main.MainGui.OpenButton) and 0 or 0.2)
		service.TweenService:Create(Main.MainGui.OpenButton,TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency = val and 0 or (Lib.CheckMouseInGui(Main.MainGui.OpenButton) and 0 or 0.2)}):Play()

		if Main.MainGuiMouseEvent then Main.MainGuiMouseEvent:Disconnect() end
		service.ContextActionService:UnbindAction("DEXPP_MenuWheel")

		if not val then
			local startTime = tick()
			Main.MainGuiCloseTime = startTime
			coroutine.wrap(function()
				Lib.FastWait(0.2)
				if not Main.MainGuiOpen and startTime == Main.MainGuiCloseTime then Main.MainGui.OpenButton.MainFrame.Visible = false end
			end)()
		else
			service.ContextActionService:BindActionAtPriority("DEXPP_MenuWheel", function(_, inputState, input)
				if inputState ~= Enum.UserInputState.Change then
					return Enum.ContextActionResult.Pass
				end
				if input.UserInputType == Enum.UserInputType.MouseWheel
					and Main.ScrollMenuBy
					and Lib.CheckMouseInGui(Main.MainGui.OpenButton.MainFrame)
				then
					Main.ScrollMenuBy(input)
					return Enum.ContextActionResult.Sink
				end
				return Enum.ContextActionResult.Pass
			end, false, Enum.ContextActionPriority.High.Value + 100, Enum.UserInputType.MouseWheel)

			Main.MainGuiMouseEvent = service.UserInputService.InputBegan:Connect(function(input)
				if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not Lib.CheckMouseInGui(Main.MainGui.OpenButton) and not Lib.CheckMouseInGui(Main.MainGui.OpenButton.MainFrame) then

					Main.SetMainGuiOpen(false)
				end
			end)
		end
	end

	Main.CreateMainGui = function()
		local gui = create({
			{1,"ScreenGui",{IgnoreGuiInset=true,Name="MainMenu",}},
			{2,"TextButton",{AnchorPoint=Vector2.new(0.5,0),AutoButtonColor=false,BackgroundColor3=Settings.Theme.Menu,BorderSizePixel=0,Font=Enum.Font.GothamBold,Name="OpenButton",Parent={1},Position=UDim2.new(0.5,0,0,6),Size=UDim2.new(0,96,0,34),Text="DEX++",TextColor3=Settings.Theme.Text,TextSize=14,TextTransparency=0.02,}},
			{3,"UICorner",{CornerRadius=UDim.new(0,10),Parent={2},}},
			{4,"Frame",{AnchorPoint=Vector2.new(0.5,0),BackgroundColor3=Settings.Theme.Main2,ClipsDescendants=true,Name="MainFrame",Parent={2},Position=UDim2.new(0.5,0,1,8),Size=UDim2.new(0,500,0,560),}},
			{5,"UICorner",{CornerRadius=UDim.new(0,8),Parent={4},}},
			{6,"Frame",{BackgroundColor3=Settings.Theme.Menu,Name="BottomFrame",Parent={4},Position=UDim2.new(0,0,1,-46),Size=UDim2.new(1,0,0,46),}},
			{7,"UICorner",{CornerRadius=UDim.new(0,8),Parent={6},}},
			{8,"Frame",{BackgroundColor3=Settings.Theme.Main1,BorderSizePixel=0,Name="CoverFrame",Parent={6},Size=UDim2.new(1,0,0,6),}},
			{9,"Frame",{BackgroundColor3=Settings.Theme.Outline1,BorderSizePixel=0,Name="Line",Parent={8},Position=UDim2.new(0,0,0,-1),Size=UDim2.new(1,0,0,1),}},
			{10,"TextButton",{BackgroundColor3=Settings.Theme.Button,BackgroundTransparency=0,BorderSizePixel=0,Font=3,Name="Settings",Parent={6},Position=UDim2.new(1,-86,0,8),Size=UDim2.new(0,32,0,28),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,}},
			{11,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://6578871732",ImageColor3=Settings.Theme.Text,ImageTransparency=0.05,Name="Icon",Parent={10},Position=UDim2.new(0.5,-8,0.5,-8),Size=UDim2.new(0,16,0,16),}},
			{12,"TextButton",{BackgroundColor3=Settings.Theme.Button,BackgroundTransparency=0,BorderSizePixel=0,Font=3,Name="Information",Parent={6},Position=UDim2.new(1,-46,0,8),Size=UDim2.new(0,32,0,28),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,}},
			{13,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://6578933307",ImageColor3=Settings.Theme.Text,ImageTransparency=0.05,Name="Icon",Parent={12},Position=UDim2.new(0.5,-8,0.5,-8),Size=UDim2.new(0,16,0,16),}},
			{14,"ScrollingFrame",{Active=true,AnchorPoint=Vector2.new(0.5,0),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderColor3=Settings.Theme.Outline1,BorderSizePixel=0,Name="AppsFrame",Parent={4},Position=UDim2.new(0.5,0,0,120),ScrollBarImageColor3=Settings.Theme.Highlight,ScrollBarImageTransparency=0.15,ScrollBarThickness=4,Size=UDim2.new(1,-20,1,-174),}},
			{15,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Name="Container",Parent={14},Position=UDim2.new(0,8,0,8),Size=UDim2.new(1,-24,0,2),}},
			{16,"UIGridLayout",{CellPadding=UDim2.new(0,8,0,8),CellSize=UDim2.new(0,224,0,68),Parent={15},SortOrder=2,}},
			{17,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Name="App",Parent={1},Size=UDim2.new(0,100,0,100),Visible=false,}},
			{18,"TextButton",{AutoButtonColor=false,BackgroundColor3=Settings.Theme.Button,BorderSizePixel=0,Font=Enum.Font.GothamBold,Name="Main",Parent={17},Size=UDim2.new(1,0,0,68),Text="",TextColor3=Color3.new(0,0,0),TextSize=14,}},
			{19,"ImageLabel",{BackgroundTransparency=1,Image="rbxassetid://129589545519436",ImageColor3=Settings.Theme.Text,ImageTransparency=0,ImageRectSize=Vector2.new(32,32),Name="Icon",Parent={18},Position=UDim2.new(0,14,0.5,-16),ScaleType=4,Size=UDim2.new(0,32,0,32),}},
			{20,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=Enum.Font.GothamBold,Name="AppName",Parent={18},Position=UDim2.new(0,58,0,10),Size=UDim2.new(1,-72,0,20),Text="Explorer",TextColor3=Settings.Theme.Text,TextSize=13,TextTransparency=0,TextTruncate=1,TextWrapped=false,TextXAlignment=0,}},
			{21,"Frame",{BackgroundColor3=Settings.Theme.ListSelection,BorderSizePixel=0,Name="Highlight",Parent={18},Position=UDim2.new(0,0,0,0),Size=UDim2.new(0,3,1,0),}},
			{22,"UIStroke",{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Color=Settings.Theme.Outline1,Thickness=1,Transparency=0.2,Parent={2},}},
			{23,"UIStroke",{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Color=Settings.Theme.Outline1,Thickness=1,Transparency=0.25,Parent={4},}},
			{24,"Frame",{BackgroundColor3=Settings.Theme.Main1,BorderSizePixel=0,Name="Header",Parent={4},Position=UDim2.new(0,0,0,0),Size=UDim2.new(1,0,0,116),}},
			{25,"TextLabel",{BackgroundTransparency=1,Font=Enum.Font.GothamBold,Name="Title",Parent={24},Position=UDim2.new(0,18,0,12),Size=UDim2.new(1,-36,0,22),Text="DEX++ Tools",TextColor3=Settings.Theme.Text,TextSize=17,TextXAlignment=0,}},
			{26,"TextLabel",{BackgroundTransparency=1,Font=Enum.Font.Gotham,Name="Subtitle",Parent={24},Position=UDim2.new(0,18,0,35),Size=UDim2.new(1,-36,0,18),Text="Open, search, and manage client tools",TextColor3=Settings.Theme.PlaceholderText,TextSize=12,TextXAlignment=0,}},
			{27,"TextBox",{BackgroundColor3=Settings.Theme.TextBox,BorderSizePixel=0,ClearTextOnFocus=false,Font=Enum.Font.RobotoMono,Name="SearchBox",Parent={24},PlaceholderColor3=Settings.Theme.PlaceholderText,PlaceholderText="Search tools by name or category",Position=UDim2.new(0,16,0,64),Size=UDim2.new(1,-32,0,30),Text="",TextColor3=Settings.Theme.Text,TextSize=12,TextXAlignment=0,}},
			{28,"UICorner",{CornerRadius=UDim.new(0,6),Parent={27},}},
			{29,"UIStroke",{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Color=Settings.Theme.Outline1,Thickness=1,Transparency=0.35,Parent={27},}},
			{30,"TextLabel",{BackgroundTransparency=1,Font=Enum.Font.Gotham,Name="AppCount",Parent={6},Position=UDim2.new(0,12,0,0),Size=UDim2.new(1,-98,1,0),Text="0 tools",TextColor3=Settings.Theme.PlaceholderText,TextSize=12,TextXAlignment=0,}},
			{31,"UICorner",{CornerRadius=UDim.new(0,6),Parent={10},}},
			{32,"UICorner",{CornerRadius=UDim.new(0,6),Parent={12},}},
			{33,"UICorner",{CornerRadius=UDim.new(0,6),Parent={18},}},
			{34,"UIStroke",{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Color=Settings.Theme.Outline1,Thickness=1,Transparency=0.55,Parent={18},}},
			{35,"Frame",{BackgroundColor3=Settings.Theme.Highlight,BorderSizePixel=0,Name="ActiveMarker",Parent={18},Position=UDim2.new(0,0,0,0),Size=UDim2.new(0,3,1,0),Visible=false,}},
		})
		Main.MainGui = gui
		Main.AppsFrame = gui.OpenButton.MainFrame.AppsFrame
		Main.AppsContainer = Main.AppsFrame.Container
		Main.AppsContainerGrid = Main.AppsContainer.UIGridLayout
		Main.AppTemplate = gui.App
		Main.HiddenAppsContainer = Instance.new("Frame")
		Main.HiddenAppsContainer.Name = "HiddenApps"
		Main.HiddenAppsContainer.Visible = false
		Main.HiddenAppsContainer.Parent = gui
		Main.MenuSearchBox = gui.OpenButton.MainFrame.Header.SearchBox
		Main.MenuCountLabel = gui.OpenButton.MainFrame.BottomFrame.AppCount
		Main.MainGuiOpen = false

		-- Dynamically modify dimensions to make space for category tabs
		local mainFrame = gui.OpenButton.MainFrame
		local header = mainFrame.Header
		header.Size = UDim2.new(1, 0, 0, 142)
		mainFrame.AppsFrame.Position = UDim2.new(0.5, 0, 0, 148)
		mainFrame.AppsFrame.Size = UDim2.new(1, -16, 1, -196)

		-- Create tabs container
		local tabContainer = Instance.new("Frame")
		tabContainer.Name = "CategoryTabs"
		tabContainer.BackgroundTransparency = 1
		tabContainer.Position = UDim2.new(0, 14, 0, 104)
		tabContainer.Size = UDim2.new(1, -28, 0, 28)
		tabContainer.Parent = header

		local tabLayout = Instance.new("UIListLayout")
		tabLayout.FillDirection = Enum.FillDirection.Horizontal
		tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		tabLayout.Padding = UDim.new(0, 6)
		tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
		tabLayout.Parent = tabContainer

		local categories = {"All", "Core", "Spy", "Search", "Advanced"}
		local tabButtons = {}

		local function updateTabVisuals()
			for cat, btn in pairs(tabButtons) do
				local active = (cat == currentCategory)
				btn.BackgroundColor3 = active and (Settings.Theme.AccentSoft or Settings.Theme.Main1) or Settings.Theme.Button
				btn.TextColor3 = active and Settings.Theme.Text or Settings.Theme.PlaceholderText
				local stroke = btn:FindFirstChild("UIStroke")
				if stroke then
					stroke.Color = active and Settings.Theme.Highlight or Settings.Theme.Outline1
					stroke.Transparency = active and 0.08 or 0.42
				end
			end
		end

		for i, cat in ipairs(categories) do
			local btn = Instance.new("TextButton")
			btn.Name = cat .. "Tab"
			btn.AutoButtonColor = false
			btn.BackgroundColor3 = Settings.Theme.Button
			btn.BorderSizePixel = 0
			btn.Font = Enum.Font.GothamBold
			btn.Size = UDim2.new(0, cat == "Advanced" and 78 or (cat == "Search" and 68 or (cat == "Spy" and 84 or 58)), 1, 0)
			btn.Text = cat == "Spy" and "Spy & Hook" or (cat == "Search" and "Search" or cat)
			btn.TextColor3 = Settings.Theme.PlaceholderText
			btn.TextSize = 11
			btn.LayoutOrder = i
			btn.Parent = tabContainer

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = btn

			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = Settings.Theme.Outline1
			stroke.Thickness = 1
			stroke.Transparency = 0.35
			stroke.Parent = btn

			tabButtons[cat] = btn

			btn.MouseButton1Click:Connect(function()
				currentCategory = cat
				updateTabVisuals()
				Main.ApplyMenuFilter()
			end)

			btn.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
					if cat ~= currentCategory then
						btn.BackgroundColor3 = Settings.Theme.Main1
					end
				end
			end)

			btn.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
					updateTabVisuals()
				end
			end)
		end

		updateTabVisuals()

		local openButton = gui.OpenButton
		openButton.BackgroundTransparency = 0.2
		openButton.MainFrame.Size = UDim2.new(0,0,0,0)
		openButton.MainFrame.Visible = false
		Main.MenuSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
			Main.MenuSearchText = Main.MenuSearchBox.Text
			Main.ApplyMenuFilter()
		end)
		Main.AppsContainerGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(Main.UpdateMenuCanvas)
		Main.ScrollMenuBy = Main.SmoothScrollingFrame(Main.AppsFrame, 76)
		openButton.MouseButton1Click:Connect(function()
			Main.SetMainGuiOpen(not Main.MainGuiOpen)
		end)

		openButton.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				service.TweenService:Create(Main.MainGui.OpenButton,TweenInfo.new(0,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency = 0}):Play()
			end
		end)

		openButton.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				service.TweenService:Create(Main.MainGui.OpenButton,TweenInfo.new(0,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency = Main.MainGuiOpen and 0 or 0.2}):Play()
			end
		end)

		local infoDexIntro, isInfoCD

		--openButton.MainFrame.BottomFrame.Settings.Visible = false

		openButton.MainFrame.BottomFrame.Settings.MouseButton1Click:Connect(function()
			if not SettingsWindow.Window.Closed then
				SettingsWindow.Window:Hide()
			else
				SettingsWindow.Window:Show()
			end
		end)

		openButton.MainFrame.BottomFrame.Information.MouseButton1Click:Connect(function()
			local duration = 1
			local Infos = {
				"Contributors >>",
				"Toon (IY Dex and PRs)",
				"Moon (Dex)",
				"Cazan (3D Preview)",
			}

			if isInfoCD then return end
			isInfoCD = true
			if not infoDexIntro then
				infoDexIntro = Main.CreateIntro("Running")
				--Main.AppControls ~= {}
				coroutine.wrap(function()
					while infoDexIntro and openButton.Parent ~= nil do
						for i,text in Infos do
							if not infoDexIntro or openButton.Parent == nil then break end
							infoDexIntro.SetProgress(text,(1 / #Infos) * i)
							task.wait(duration)
						end
					end
				end)()

				Lib.FastWait(1.5)
				isInfoCD = false
			else
				coroutine.wrap(function()
					infoDexIntro.Close()
					infoDexIntro = nil

					Lib.FastWait(1.5)
					isInfoCD = false
				end)()
			end
		end)

		-- Create Main Apps
		Main.CreateApp({Name = "Explorer", IconMap = Main.LargeIcons, Icon = "Explorer", Open = true, Window = Explorer.Window})

		Main.CreateApp({Name = "Properties", IconMap = Main.LargeIcons, Icon = "Properties", Open = true, Window = Properties.Window})

		local cptsOnMouseClick = nil
		Main.CreateApp({Name = "Click part to select", IconMap = Main.LargeIcons, Icon = "Object", OnClick = function(callback)
			if callback then
				local mouse = Main.Mouse
				cptsOnMouseClick = mouse.Button1Down:Connect(function()
					pcall(function()
						local object = mouse.Target
						if nodes[object] then
							selection:Set(nodes[object])
							Explorer.ViewNode(nodes[object])
						end
					end)
				end)
			else if cptsOnMouseClick ~= nil then cptsOnMouseClick:Disconnect() cptsOnMouseClick = nil end end
		end})

		Main.CreateApp({Name = "Notepad", IconMap = Main.LargeIcons, Icon = "Script_Viewer", Window = Notepad.Window})

		Main.CreateApp({Name = "Console", IconMap = Main.LargeIcons, Icon = "Executor", Window = Console.Window})

		Main.CreateLazyWindowApp({Name = "Save Instance", IconMap = Main.LargeIcons, Icon = "Book", Module = SaveInstance})

		Main.CreateLazyWindowApp({Name = "3D Viewer", IconMap = Main.LargeIcons, Icon = "Object", Module = ModelViewer, Hidden = true})

		Main.CreateLazyWindowApp({Name = "Search Center", IconMap = Main.LargeIcons, Icon = "ScriptEdit", Module = CodeSearch})
		Main.CreateLazyWindowApp({Name = "Script Relations", IconMap = Main.LargeIcons, Icon = "Watcher", Module = ScriptRelations, Hidden = true})
		Main.CreateLazyWindowApp({Name = "Dependency Graph", IconMap = Main.LargeIcons, Icon = "ScriptEdit", Module = DependencyGraph, Hidden = true})
		Main.CreateLazyWindowApp({Name = "Smart Search", IconMap = Main.LargeIcons, Icon = "ScriptEdit", Module = SmartSearch, Hidden = true})

		Main.CreateLazyWindowApp({Name = "Image Viewer", IconMap = Main.LargeIcons, Icon = "Object", Module = ImageViewer, Hidden = true})

		Main.CreateLazyWindowApp({Name = "Runtime Monitor", IconMap = Main.LargeIcons, Icon = "Watcher", Module = RuntimeInspector})
		Main.CreateLazyWindowApp({Name = "Remote Usage", IconMap = Main.LargeIcons, Icon = "Output", Module = RemoteUsageMap, Hidden = true})
		Main.CreateLazyWindowApp({Name = "Object Links", IconMap = Main.LargeIcons, Icon = "Watcher", Module = ObjectLinks, Hidden = true})
		Main.CreateLazyWindowApp({Name = "Activity Map", IconMap = Main.LargeIcons, Icon = "Watcher", Module = ActivityMap, Hidden = true})
		Main.CreateLazyWindowApp({Name = "Client Intelligence", IconMap = Main.LargeIcons, Icon = "Output", Module = ClientIntelligence, Hidden = true})

		Main.CreateLazyWindowApp({Name = "Inspector Hub", IconMap = Main.LargeIcons, Icon = "Watcher", Module = InspectorHub})

		Main.CreateLazyWindowApp({Name = "Task Router", IconMap = Main.LargeIcons, Icon = "ScriptEdit", Module = TaskRouter, Hidden = true})
		Main.CreateLazyWindowApp({Name = "Control Center", IconMap = Main.LargeIcons, Icon = "Watcher", Module = ControlCenter})

		Main.CreateLazyWindowApp({Name = "Security Auditor", IconMap = Main.LargeIcons, Icon = "Watcher", Module = SecurityAuditor, Hidden = true})
		Main.CreateLazyWindowApp({Name = "Property Tracker", IconMap = Main.LargeIcons, Icon = "Watcher", Module = PropertyTracker, Hidden = true})
		Main.CreateLazyWindowApp({Name = "Thread Manager", IconMap = Main.LargeIcons, Icon = "ScriptEdit", Module = ThreadManager, Hidden = true})
		Main.CreateLazyWindowApp({Name = "IDE Sync", IconMap = Main.LargeIcons, Icon = "ScriptEdit", Module = IDESync})
		Main.CreateApp({Name = "Serialize Inst", IconMap = Main.LargeIcons, Icon = "Object", OnClick = function(callback)
			if callback then
				if InstanceSerializer then InstanceSerializer.Init() end
				if Main.MenuApps["Serialize Inst"] then
					Main.MenuApps["Serialize Inst"].Disable(true)
				end
			end
		end})

		for _, loadedplugin in pairs(Main.Plugins) do
			Main.CreateLazyWindowApp({Name = loadedplugin.PluginData.FriendlyName, IconMap = Explorer.ClassIcons, Icon = "Attachment", Module = loadedplugin})
		end

		Lib.ShowGui(gui)
	end

	Main.SetupFilesystem = function()
		if not env.writefile or not env.makefolder then return end

		local writefile,makefolder = env.writefile,env.makefolder
		local function safeMakeFolder(path)
			if not env.isfolder or not env.isfolder(path) then
				makefolder(path)
			end
		end

		safeMakeFolder("dex")
		safeMakeFolder("dex/assets")
		safeMakeFolder("dex/saved")
		safeMakeFolder("dex/plugins")
		safeMakeFolder("dex/ModuleCache")
		safeMakeFolder("dex/DecompileCache")
		safeMakeFolder("dex/DecompileCache/" .. tostring(game.PlaceId))
	end

	Main.SaveCurrentSettings = function()
		if writefile then
			writefile("DexPlusPlusSettings.json", Main.ExportSettings())
		end
	end

	Main.LocalDepsUpToDate = function()
		return Main.DepsVersionData and Main.ClientVersion == Main.DepsVersionData[1]
	end

	Main.Init = function()
		Main.Elevated = pcall(function() local a = game:GetService("CoreGui"):GetFullName() end)

		-- saves new settings if does not exist
		if isfile and not isfile("DexPlusPlusSettings.json") then
			Main.SaveCurrentSettings()
		end

		Main.InitEnv()
		Main.LoadSettings() -- loads the settings before init

		Main.SetupFilesystem()

		-- Load Lib
		local intro = Main.CreateIntro("Initializing Library")
		Lib = Main.LoadModule("Lib")
		Lib.FastWait()

		-- Init other stuff
		Main.IncompatibleTest()

		-- Init icons
		Main.MiscIcons = Lib.IconMap.new("rbxassetid://6511490623",256,256,16,16)
		Main.MiscIcons:SetDict({
			Reference = 0,             Cut = 1,                         Cut_Disabled = 2,      Copy = 3,               Copy_Disabled = 4,    Paste = 5,                Paste_Disabled = 6,
			Delete = 7,                Delete_Disabled = 8,             Group = 9,             Group_Disabled = 10,    Ungroup = 11,         Ungroup_Disabled = 12,    TeleportTo = 13,
			Rename = 14,               JumpToParent = 15,               ExploreData = 16,      Save = 17,              CallFunction = 18,    CallRemote = 19,          Undo = 20,
			Undo_Disabled = 21,        Redo = 22,                       Redo_Disabled = 23,    Expand_Over = 24,       Expand = 25,          Collapse_Over = 26,       Collapse = 27,
			SelectChildren = 28,       SelectChildren_Disabled = 29,    InsertObject = 30,     ViewScript = 31,        AddStar = 32,         RemoveStar = 33,          Script_Disabled = 34,
			LocalScript_Disabled = 35, Play = 36,                       Pause = 37,            Rename_Disabled = 38,   Empty = 1000
		})
		Main.LargeIcons = Lib.IconMap.new("rbxassetid://129589545519436",256,256,32,32)
		Main.LargeIcons:SetDict({
			Explorer = 0, Properties = 1, Script_Viewer = 2, Watcher = 3, Output = 4, ScriptEdit = 5, Book = 6, Executor = 7, Object = 8, Honey = 9
		})

		--[[ Loading bypasses
		intro.SetProgress("Loading Adonis Bypass",0.1)
		pcall(Main.LoadAdonisBypass)

		intro.SetProgress("Loading GC Bypass",0.2)
		pcall(Main.LoadGCBypass)]]

		-- Fetch version if needed
		intro.SetProgress("Fetching Roblox Version",0.3)
		if Main.Elevated then
			local fileVer = Lib.ReadFile("dex/deps_version.dat")
			Main.ClientVersion = Version()
			if fileVer then
				Main.DepsVersionData = string.split(fileVer,"\n")
				if Main.LocalDepsUpToDate() then
					Main.RobloxVersion = Main.DepsVersionData[2]
				end
			end

			Main.RobloxVersion = Main.RobloxVersion or oldgame:HttpGet("https://clientsettings.roblox.com/v2/client-version/WindowsStudio64/channel/LIVE"):match("(version%-[%w]+)")
		end

		-- Fetch external deps
		intro.SetProgress("Fetching API",0.35)
		API = Main.FetchAPI(
			function()
				intro.SetProgress("Fetching API, Please Wait.",0.4)
			end,
			function()
				intro.SetProgress("Fetching API, Please Wait Due To Huge API File To Download.",0.45)
			end,
			function()
				intro.SetProgress("Fetching API, LOL STILL DOWNlOADING? bad wifi xD",0.475)
			end
		)
		Lib.FastWait()
		intro.SetProgress("Fetching RMD",0.5)
		RMD = Main.FetchRMD()
		Lib.FastWait()

		-- Save external deps locally if needed
		if Main.Elevated and env.writefile and not Main.LocalDepsUpToDate() then
			env.writefile("dex/deps_version.dat",Main.ClientVersion.."\n"..Main.RobloxVersion)
			env.writefile("dex/rbx_api.dat",Main.RawAPI)
			env.writefile("dex/rbx_rmd.dat",Main.RawRMD)
		end

		-- Load other modules
		intro.SetProgress("Loading Modules",0.75)
		Main.AppControls.Lib.InitDeps(Main.GetInitDeps()) -- Missing deps now available
		Main.LoadModules()
		Lib.FastWait()

		-- Init other modules
		intro.SetProgress("Initializing Modules",0.8)
		Explorer.Init()
		Properties.Init()
		Notepad.Init()
		Console.Init()
		SettingsWindow.Init()
		--SecretServicePanel.Init()


		if env.readfile and listfiles then
			if #listfiles("dex/plugins") > 0 then
				intro.SetProgress("Loading Plugin Files",0.8)
				for _, pluginDir in pairs(listfiles("dex/plugins")) do
					local moduleData = Main.LoadPluginFile(pluginDir)
					moduleData.PluginData = moduleData.PluginData or {}

					local pluginFriendlyName = moduleData.PluginData.FriendlyName or moduleData.PluginData.Name or tostring(pluginDir):match("[^/\\]+$") or "Unnamed Plugin"
					local pluginName = moduleData.PluginData.Name or tostring(pluginFriendlyName):gsub(" ", "") or "unnamedPlugin"

					intro.SetProgress("Initializing Plugin: ".. pluginFriendlyName,0.9)

					moduleData.PluginData.Name = pluginName
					moduleData.PluginData.FriendlyName = pluginFriendlyName

					table.insert(Main.Plugins, moduleData)
				end
			end
		end


		Lib.FastWait()

		-- Done
		intro.SetProgress("Complete",1)
		coroutine.wrap(function()
			Lib.FastWait(1.25)
			intro.Close()
		end)()

		-- Init window system, create main menu, show explorer and properties
		Lib.Window.Init()
		Main.CreateMainGui()
		Explorer.Window:Show({Align = "right", Pos = 1, Size = 0.5, Silent = true})
		Properties.Window:Show({Align = "right", Pos = 2, Size = 0.5, Silent = true})
		Main.CheckForUpdatesAsync()

		Lib.DeferFunc(function() Lib.Window.ToggleSide("right") end)
	end

	Main.Uninit = function()
		-- Call Uninit/CleanUp on all active module and plugin instances
		if Apps then
			for name, app in pairs(Apps) do
				if type(app) == "table" then
					if type(app.Uninit) == "function" then
						pcall(app.Uninit)
					elseif type(app.CleanUp) == "function" then
						pcall(app.CleanUp)
					end
				end
			end
		end

		-- Disconnect connections and clear hook chains
		if Main.CleanHooksAndConnections then
			pcall(Main.CleanHooksAndConnections)
		end

		-- Restore getgenv globals to original functions
		if Main.RestoreGlobals then
			pcall(Main.RestoreGlobals)
		end

		if Main.MainGuiMouseEvent then
			pcall(function() Main.MainGuiMouseEvent:Disconnect() end)
			Main.MainGuiMouseEvent = nil
		end
		Main.MenuApps = {}
		Main.AppCards = {}
		Main.MenuSearchText = ""
		Main.MenuSearchBox = nil
		Main.MenuCountLabel = nil
		Main.HiddenAppsContainer = nil
		Main.AppControls = {}
		Main.Plugins = {}
		for _, gui in pairs(Main.GetSecureContainer():GetChildren()) do
			if string.sub(gui.Name,1,5) == "_DPP_" then -- DPP stands for DexPlusPlus
				gui:Destroy()
			end
		end
	end

	Main.Reinit = function()
		if Main.Restarting then return false end
		Main.Restarting = true
		task.spawn(function()
			local ok, err = pcall(function()
				Main.Uninit()
				task.wait(0.2)
				Main.Init()
			end)
			Main.Restarting = false
			if not ok then
				warn("DEX++ restart failed: " .. tostring(err))
			end
		end)
		return true
	end

	return Main
end)()

-- Bundled Plugins
local bundled_plugins = {
	-- [[PLUGIN_SOURCES_PLACEHOLDER]]
}

if writefile and isfolder and makefolder then
	if not isfolder("dex") then makefolder("dex") end
	if not isfolder("dex/plugins") then makefolder("dex/plugins") end
	for pluginName, pluginSource in pairs(bundled_plugins) do
		writefile("dex/plugins/" .. pluginName, pluginSource)
	end
end

-- Start
Main.Init()

--for i,v in pairs(Main.MissingEnv) do print(i,v) end

-- Adonis related
local function InitAdonisBypass()
	local Adonis = { Name = "Adonis", Game = "*" }
	local AdonisAnticheatThreads = {}

	if not getreg or not getgc or not isfunctionhooked then
		warn("Executor does not support Adonis bypass functions.")
		return false
	end

	for _, thread in getreg() do
		if typeof(thread) ~= "thread" then continue end
		local Source = debug.info(thread, 1, "s")
		if Source and (Source:match(".Core.Anti") or Source:match(".Plugins.Anti_Cheat")) then
			table.insert(AdonisAnticheatThreads, thread)
		end
	end

	for _, thread in AdonisAnticheatThreads do
		pcall(coroutine.close, thread)
	end

	local AdonisTables = {}
	if filtergc then
		local ContendorAdonisTables = filtergc("table", { Keys = { "Detected", "RLocked" } }, false)
		for _, AdonisTable in ContendorAdonisTables do
			if typeof(rawget(AdonisTable, "Detected")) == "function" then
				table.insert(AdonisTables, AdonisTable)
			end
		end
	else
		for _, Table in getgc(true) do
			if typeof(Table) == "table" and typeof(rawget(Table, "Detected")) == "function" and rawget(Table, "RLocked") then
				table.insert(AdonisTables, Table)
			end
		end
	end

	for _, AdonisTable in AdonisTables do
		for _, DetectionFunc in AdonisTable do
			if typeof(DetectionFunc) == "function" and not isfunctionhooked(DetectionFunc) then
				hookfunction(DetectionFunc, function()
					coroutine.yield()
					return task.wait(9e9)
				end)
			end
		end
	end
	return true
end

InitAdonisBypass()
