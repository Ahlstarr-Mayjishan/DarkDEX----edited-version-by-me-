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
local Main, Explorer, Properties, ScriptViewer, Console, SaveInstance, ModelViewer, SettingsWindow, CodeSearch, ScriptRelations, RemoteUsageMap, ObjectLinks, ImageViewer, ClientIndex, ActivityMap, DependencyGraph, SmartSearch, RuntimeInspector, ClientIntelligence, TaskRouter, Theme, SmartDecompiler, SecurityAuditor, RemoteFuzzer, PropertyTracker, InstanceSerializer, ThreadManager--[[, SecretServicePanel]], DefaultSettings, Notebook, Serializer, Lib local ggv = getgenv or nil
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
			Main1 = rgb(25, 27, 31),
			Main2 = rgb(15, 17, 20),
			Outline1 = rgb(35, 39, 47), -- Mainly frames
			Outline2 = rgb(55, 65, 81), -- Mainly button
			Outline3 = rgb(35, 39, 47), -- Mainly textbox
			TextBox = rgb(20, 22, 26),
			Menu = rgb(18, 20, 24),
			ListSelection = rgb(99, 102, 241),
			Button = rgb(31, 41, 55),
			ButtonHover = rgb(79, 70, 229),
			ButtonPress = rgb(67, 56, 202),
			Highlight = rgb(79, 70, 229),
			Text = rgb(243, 244, 246),
			PlaceholderText = rgb(156, 163, 175),
			Important = rgb(244, 63, 94),
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
		ScriptViewer = {
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

	Main.ModuleList = {"Theme","SmartDecompiler","Explorer","Properties","ScriptViewer","Console","SaveInstance","ModelViewer","SettingsWindow","CodeSearch","ScriptRelations","RemoteUsageMap","ObjectLinks","ImageViewer","ClientIndex","ActivityMap","DependencyGraph","SmartSearch","RuntimeInspector","ClientIntelligence","TaskRouter","SecurityAuditor","RemoteFuzzer","PropertyTracker","InstanceSerializer","ThreadManager"}
	Main.Elevated = false
	Main.AllowDraggableOnMobile = true
	Main.MissingEnv = {}
	Main.Version = "3.1"
	Main.Mouse = plr:GetMouse()
	Main.AppControls = {}
	Main.Apps = Apps
	Main.MenuApps = {}
	Main.GitName = "Ahlstarr-Mayjishan"
	Main.RepoName = "DarkDEX----edited-version-by-me-"
	Main.GitRepoName = Main.GitName.."/"..Main.RepoName
	Main.UpdateScriptPath = "DEX%2B%2B_compiled.luau"
	Main.DefaultUpdateRef = "v"..Main.Version
	Main.UpdateScriptURL = nil
	Main.UpdateCheckStarted = false
	Main.LatestUpdateSource = nil

	Main.DisplayOrders = {
		SideWindow = 8,
		Window = 10,
		Menu = 100000,
		Core = 101000
	}
	
	Main.Plugins = {}
	
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

			-- Developer Mode: Load directly from local file if exists
			local localPath = 'dex/Modules/' .. name .. '.luau'
			local localPathFallback = 'dex/Modules/' .. name .. '.lua'
			if isFsSupported and (isfile(localPath) or isfile(localPathFallback)) then
				local path = isfile(localPath) and localPath or localPathFallback
				local s, err = pcall(function()
					if gethsfuncs then _G.moduleData = nil end
					control = loadstring(readfile(path))()
					if not control and gethsfuncs then
						control = _G.moduleData
					end
				end)
				if not s then
					warn('Failed to load local module ' .. name .. ': ' .. tostring(err))
				end
			end

			if not control and EmbeddedModules then -- Offline Modules
				if not EmbeddedModules[name] then Main.Error("Missing Embedded Module: "..name) end
				if gethsfuncs then _G.moduleData = nil end
				control = EmbeddedModules[name]()

				-- TODO: Remove when open source
				if gethsfuncs then
					control = _G.moduleData
				end

				if not control then Main.Error("Missing Embedded Module: "..name) end
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

			Main.AppControls[name] = control
			control.InitDeps(Main.GetInitDeps())

			local moduleData = control.Main()
			Apps[name] = moduleData
			return moduleData
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
		ScriptViewer = Apps.ScriptViewer
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
		TaskRouter = Apps.TaskRouter
		Theme = Apps.Theme
		SmartDecompiler = Apps.SmartDecompiler
		SecurityAuditor = Apps.SecurityAuditor
		RemoteFuzzer = Apps.RemoteFuzzer
		PropertyTracker = Apps.PropertyTracker
		InstanceSerializer = Apps.InstanceSerializer
		ThreadManager = Apps.ThreadManager
		
		
		--SecretServicePanel = Apps.SecretServicePanel
		local appTable = {
			Theme = Theme,
			SmartDecompiler = SmartDecompiler,
			Explorer = Explorer,
			Properties = Properties,
			ScriptViewer = ScriptViewer,
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
			TaskRouter = TaskRouter,
			SecurityAuditor = SecurityAuditor,
			RemoteFuzzer = RemoteFuzzer,
			PropertyTracker = PropertyTracker,
			InstanceSerializer = InstanceSerializer,
			ThreadManager = ThreadManager
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

		local function addDescendantMatches(list, seen, predicate)
			for _, obj in pairs(game:GetDescendants()) do
				if predicate(obj) then
					addUniqueInstance(list, seen, obj)
				end
			end
		end

		local function addNilMatches(list, seen, predicate)
			if not env.getnilinstances then return end
			local success, nilInstances = pcall(env.getnilinstances)
			if not success or type(nilInstances) ~= "table" then return end
			for _, obj in pairs(nilInstances) do
				if predicate(obj) then
					addUniqueInstance(list, seen, obj)
				end
			end
		end

		local function addLoadedModules(list, seen)
			if not env.getloadedmodules then return end
			local success, loadedModules = pcall(env.getloadedmodules)
			if not success or type(loadedModules) ~= "table" then return end
			for _, obj in pairs(loadedModules) do
				if typeof(obj) == "Instance" and obj:IsA("ModuleScript") then
					addUniqueInstance(list, seen, obj)
				end
			end
		end

		local function addGcScriptRefs(list, seen, allowNonViable)
			if not env.getgc then return end
			local success, gcObjects = pcall(env.getgc)
			if not success or type(gcObjects) ~= "table" then return end

			for _, value in pairs(gcObjects) do
				if typeof(value) == "function" then
					local envSuccess, fnEnv = pcall(getfenv, value)
					local scr = envSuccess and type(fnEnv) == "table" and rawget(fnEnv, "script")
					if typeof(scr) == "Instance" and scr:IsA("LuaSourceContainer") then
						if allowNonViable or env.isViableDecompileScript(scr) then
							addUniqueInstance(list, seen, scr)
						end
					end
				end
			end
		end

		env.GetClientScripts = function(allowNonViable)
			local scripts, seen = {}, {}
			local function isWantedScript(obj)
				if typeof(obj) ~= "Instance" or not obj:IsA("LuaSourceContainer") then return false end
				return allowNonViable or env.isViableDecompileScript(obj)
			end

			addDescendantMatches(scripts, seen, isWantedScript)
			addNilMatches(scripts, seen, isWantedScript)
			addLoadedModules(scripts, seen)
			addGcScriptRefs(scripts, seen, allowNonViable)

			return scripts
		end

		env.GetClientRemotes = function()
			local remotes, seen = {}, {}
			local function isRemote(obj)
				return typeof(obj) == "Instance" and remoteClassMap[obj.ClassName] == true
			end

			addDescendantMatches(remotes, seen, isRemote)
			addNilMatches(remotes, seen, isRemote)

			return remotes
		end

		env.GetClientSurfaceCoverage = function()
			local allScripts = env.GetClientScripts(true)
			local viableScripts = env.GetClientScripts(false)
			local remotes = env.GetClientRemotes()
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
			}

			local function getBaseUrl()
				local port = Settings.Decompiler.HelperServerPort or 8080
				return "http://localhost:" .. tostring(port)
			end

			function helper.Request(path, method, body, contentType)
				local req = env.request or (syn and syn.request) or (http and http.request) or http_request or request
				if not req then return nil, "request API unavailable" end

				local ok, result = pcall(req, {
					Url = getBaseUrl() .. path,
					Method = method or "GET",
					Headers = {
						["Content-Type"] = contentType or "text/plain"
					},
					Body = body
				})
				if not ok then return nil, tostring(result) end
				return result, nil
			end

			function helper.IsActive(force)
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

			function helper.Log(line)
				local result = helper.Request("/log", "POST", tostring(line), "text/plain")
				return result and result.StatusCode == 200
			end

			return helper
		end)()
		
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
			local hash = 2166136261
			for i = 1, #data do
				hash = (hash * 131 + data:byte(i)) % 4294967296
			end
			return ("%08x"):format(hash)
		end

		local function isCacheableSource(source)
			if type(source) ~= "string" or source == "" then return false end
			local lowered = source:lower()
			if lowered:match("failed to decompile") or lowered:match("empty bytecode") then return false end
			if lowered:match("getscriptbytecode is not supported") or lowered:match("failed to get script bytecode") then return false end
			if lowered:match("error occurred while requesting") then return false end
			return true
		end

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
			cache.Read = function(script_instance)
				loadMetadata()
				if not ensureCacheFolders() then return nil, "Filesystem APIs are unavailable." end

				local info = getInfo(script_instance)
				if not info then return nil, "Script cache info is unavailable." end

				local entry = metadata.Scripts[info.Key]
				if not entry then return nil, "No cached source." end
				if info.Hash and entry.Hash and entry.Hash ~= info.Hash then return nil, "Cached source is stale." end

				local path = placeDir .. "/" .. tostring(entry.File or info.File)
				if not env.isfile(path) then return nil, "Cached source file is missing." end

				local success, source = pcall(env.readfile, path)
				if success and type(source) == "string" then
					return source, entry
				end
				return nil, "Unable to read cached source."
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
			local tryNative = not Settings.Decompiler.PreferDecompilerFallback
			
			if nativeDecompile and tryNative then
				local success, result = pcall(nativeDecompile, script_instance, ...)
				-- Check if the native decompiler succeeded and actually returned valid code
				if success and result and tostring(result) ~= "" then
					local strResult = tostring(result)
					if not strResult:match("Failed to decompile") and not strResult:match("Empty bytecode") then
						return strResult
					end
				end
			end

			-- If native failed or was skipped, try fallbacks using bytecode
			if typeof(getscriptbytecode) == "function" then
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
						if s and res and res.StatusCode == 200 then
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
					if success and result then
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
			else
				warn("failed to decode settings json")
			end
		else
			Main.ResetSettings()
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

		Main.Uninit()
		task.wait()
		local ok, fn = pcall(loader, source, "DEX++ Latest")
		if ok and type(fn) == "function" then
			coroutine.wrap(fn)()
			return true
		end
		return false
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

		local function updateState()
			app.Main.BackgroundTransparency = data.Open and 0 or (Lib.CheckMouseInGui(app.Main) and 0 or 1)
			app.Main.Highlight.Visible = data.Open
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

		local ySize = service.TextService:GetTextSize(data.Name,13,Enum.Font.SourceSans,Vector2.new(80,999999)).Y
		app.Main.Size = UDim2.new(1,0,0,math.clamp(48+ySize,64,78))
		app.Main.AppName.Text = data.Name

		app.Main.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				app.Main.BackgroundTransparency = 0
				app.Main.BackgroundColor3 = Settings.Theme.ButtonHover
			end
		end)
		

		app.Main.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				app.Main.BackgroundTransparency = data.Open and 0 or 1
				app.Main.BackgroundColor3 = Settings.Theme.Button
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
		Main.AppsFrame.CanvasSize = UDim2.new(0,0,0,Main.AppsContainerGrid.AbsoluteCellCount.Y*86 + 12)

		control.Enable = enable
		control.Disable = disable
		Main.MenuApps[data.Name] = control
		return control
	end

	Main.SetMainGuiOpen = function(val)
		Main.MainGuiOpen = val

		Main.MainGui.OpenButton.Text = val and "Close" or "Dex++"
		if val then Main.MainGui.OpenButton.MainFrame.Visible = true end
		Main.MainGui.OpenButton.MainFrame:TweenSize(val and UDim2.new(0,292,0,258) or UDim2.new(0,0,0,0),Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.2,true)
		--Main.MainGui.OpenButton.BackgroundTransparency = val and 0 or (Lib.CheckMouseInGui(Main.MainGui.OpenButton) and 0 or 0.2)
		service.TweenService:Create(Main.MainGui.OpenButton,TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency = val and 0 or (Lib.CheckMouseInGui(Main.MainGui.OpenButton) and 0 or 0.2)}):Play()

		if Main.MainGuiMouseEvent then Main.MainGuiMouseEvent:Disconnect() end

		if not val then
			local startTime = tick()
			Main.MainGuiCloseTime = startTime
			coroutine.wrap(function()
				Lib.FastWait(0.2)
				if not Main.MainGuiOpen and startTime == Main.MainGuiCloseTime then Main.MainGui.OpenButton.MainFrame.Visible = false end
			end)()
		else
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
			{2,"TextButton",{AnchorPoint=Vector2.new(0.5,0),AutoButtonColor=false,BackgroundColor3=Settings.Theme.Main2,BorderSizePixel=0,Font=Enum.Font.Gotham,Name="OpenButton",Parent={1},Position=UDim2.new(0.5,0,0,2),Size=UDim2.new(0,68,0,34),Text="Dex++",TextColor3=Settings.Theme.Text,TextSize=16,TextTransparency=0.050000000745058,}},
			{3,"UICorner",{CornerRadius=UDim.new(0,4),Parent={2},}},
			{4,"Frame",{AnchorPoint=Vector2.new(0.5,0),BackgroundColor3=Settings.Theme.Main2,ClipsDescendants=true,Name="MainFrame",Parent={2},Position=UDim2.new(0.5,0,1,-4),Size=UDim2.new(0,292,0,258),}},
			{5,"UICorner",{CornerRadius=UDim.new(0,4),Parent={4},}},
			{6,"Frame",{BackgroundColor3=Settings.Theme.Main1,Name="BottomFrame",Parent={4},Position=UDim2.new(0,0,1,-28),Size=UDim2.new(1,0,0,28),}},
			{7,"UICorner",{CornerRadius=UDim.new(0,4),Parent={6},}},
			{8,"Frame",{BackgroundColor3=Settings.Theme.Main1,BorderSizePixel=0,Name="CoverFrame",Parent={6},Size=UDim2.new(1,0,0,4),}},
			{9,"Frame",{BackgroundColor3=Settings.Theme.Outline1,BorderSizePixel=0,Name="Line",Parent={8},Position=UDim2.new(0,0,0,-1),Size=UDim2.new(1,0,0,1),}},
			{10,"TextButton",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Settings",Parent={6},Position=UDim2.new(1,-48,0,0),Size=UDim2.new(0,24,1,0),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,}},
			{11,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://6578871732",ImageColor3=Settings.Theme.Text,ImageTransparency=0.10000000149012,Name="Icon",Parent={10},Position=UDim2.new(0,4,0,6),Size=UDim2.new(0,16,0,16),}},
			{12,"TextButton",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Information",Parent={6},Position=UDim2.new(1,-24,0,0),Size=UDim2.new(0,24,1,0),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,}},
			{13,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://6578933307",ImageColor3=Settings.Theme.Text,ImageTransparency=0.10000000149012,Name="Icon",Parent={12},Position=UDim2.new(0,4,0,6),Size=UDim2.new(0,16,0,16),}},
			{14,"ScrollingFrame",{Active=true,AnchorPoint=Vector2.new(0.5,0),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderColor3=Settings.Theme.Outline1,BorderSizePixel=0,Name="AppsFrame",Parent={4},Position=UDim2.new(0.5,0,0,0),ScrollBarImageColor3=Settings.Theme.Highlight,ScrollBarThickness=4,Size=UDim2.new(0,290,1,-29),}},
			{15,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Name="Container",Parent={14},Position=UDim2.new(0,8,0,10),Size=UDim2.new(1,-16,0,2),}},
			{16,"UIGridLayout",{CellPadding=UDim2.new(0,2,0,4),CellSize=UDim2.new(0,88,0,78),Parent={15},SortOrder=2,}},
			{17,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Name="App",Parent={1},Size=UDim2.new(0,100,0,100),Visible=false,}},
			{18,"TextButton",{AutoButtonColor=false,BackgroundColor3=Settings.Theme.Button,BorderSizePixel=0,Font=3,Name="Main",Parent={17},Size=UDim2.new(1,0,0,64),Text="",TextColor3=Color3.new(0,0,0),TextSize=14,}},
			{19,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://129589545519436",ImageColor3=Settings.Theme.Text,ImageRectSize=Vector2.new(32,32),Name="Icon",Parent={18},Position=UDim2.new(0.5,-16,0,6),ScaleType=4,Size=UDim2.new(0,32,0,32),}},
			{20,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="AppName",Parent={18},Position=UDim2.new(0,4,0,42),Size=UDim2.new(1,-8,1,-44),Text="Explorer",TextColor3=Settings.Theme.Text,TextSize=13,TextTransparency=0.050000000745058,TextTruncate=1,TextWrapped=true,TextYAlignment=0,}},
			{21,"Frame",{BackgroundColor3=Settings.Theme.ListSelection,BorderSizePixel=0,Name="Highlight",Parent={18},Position=UDim2.new(0,0,1,-2),Size=UDim2.new(1,0,0,2),}},
		})
		Main.MainGui = gui
		Main.AppsFrame = gui.OpenButton.MainFrame.AppsFrame
		Main.AppsContainer = Main.AppsFrame.Container
		Main.AppsContainerGrid = Main.AppsContainer.UIGridLayout
		Main.AppTemplate = gui.App
		Main.MainGuiOpen = false

		local openButton = gui.OpenButton
		openButton.BackgroundTransparency = 0.2
		openButton.MainFrame.Size = UDim2.new(0,0,0,0)
		openButton.MainFrame.Visible = false
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

		Main.CreateApp({Name = "Notepad", IconMap = Main.LargeIcons, Icon = "Script_Viewer", Window = ScriptViewer.Window})
		
		Main.CreateApp({Name = "Console", IconMap = Main.LargeIcons, Icon = "Executor", Window = Console.Window})
		
		Main.CreateApp({Name = "Save Instance", IconMap = Main.LargeIcons, Icon = "Book", Window = SaveInstance.Window})
		
		Main.CreateApp({Name = "3D Viewer", IconMap = Main.LargeIcons, Icon = "Object", Window = ModelViewer.Window})

		Main.CreateApp({Name = "Code Search", IconMap = Main.LargeIcons, Icon = "ScriptEdit", Window = CodeSearch.Window})

		Main.CreateApp({Name = "Script Relations", IconMap = Main.LargeIcons, Icon = "Watcher", Window = ScriptRelations.Window})

		Main.CreateApp({Name = "Remote Usage", IconMap = Main.LargeIcons, Icon = "Output", Window = RemoteUsageMap.Window})

		Main.CreateApp({Name = "Object Links", IconMap = Main.LargeIcons, Icon = "Watcher", Window = ObjectLinks.Window})

		Main.CreateApp({Name = "Image Viewer", IconMap = Main.LargeIcons, Icon = "Object", Window = ImageViewer.Window})

		Main.CreateApp({Name = "Activity Map", IconMap = Main.LargeIcons, Icon = "Watcher", Window = ActivityMap.Window})

		Main.CreateApp({Name = "Dependency Graph", IconMap = Main.LargeIcons, Icon = "ScriptEdit", Window = DependencyGraph.Window})

		Main.CreateApp({Name = "Smart Search", IconMap = Main.LargeIcons, Icon = "ScriptEdit", Window = SmartSearch.Window})

		Main.CreateApp({Name = "Runtime Inspector", IconMap = Main.LargeIcons, Icon = "Watcher", Window = RuntimeInspector.Window})

		Main.CreateApp({Name = "Client Intelligence", IconMap = Main.LargeIcons, Icon = "Output", Window = ClientIntelligence.Window})

		Main.CreateApp({Name = "Task Router", IconMap = Main.LargeIcons, Icon = "ScriptEdit", Window = TaskRouter.Window})

		Main.CreateApp({Name = "Security Auditor", IconMap = Main.LargeIcons, Icon = "Watcher", Window = SecurityAuditor.Window})
		Main.CreateApp({Name = "Property Tracker", IconMap = Main.LargeIcons, Icon = "Watcher", Window = PropertyTracker.Window})
		Main.CreateApp({Name = "Thread Manager", IconMap = Main.LargeIcons, Icon = "ScriptEdit", Window = ThreadManager.Window})
		Main.CreateApp({Name = "Serialize Inst", IconMap = Main.LargeIcons, Icon = "Object", OnClick = function(callback)
			if callback then
				if InstanceSerializer then InstanceSerializer.Init() end
				if Main.MenuApps["Serialize Inst"] then
					Main.MenuApps["Serialize Inst"].Disable(true)
				end
			end
		end})
		
		for _, loadedplugin in pairs(Main.Plugins) do
			Main.CreateApp({Name = loadedplugin.PluginData.FriendlyName, IconMap = Explorer.ClassIcons, Icon = "Attachment", Window = loadedplugin.Window})
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
		ScriptViewer.Init()
		Console.Init()
		SaveInstance.Init()
		ModelViewer.Init()
		SettingsWindow.Init()
		CodeSearch.Init()
		ScriptRelations.Init()
		RemoteUsageMap.Init()
		ObjectLinks.Init()
		ImageViewer.Init()
		ClientIndex.Init()
		ActivityMap.Init()
		DependencyGraph.Init()
		SmartSearch.Init()
		RuntimeInspector.Init()
		ClientIntelligence.Init()
		TaskRouter.Init()
		SecurityAuditor.Init()
		--SecretServicePanel.Init()
		
		
		if env.readfile and listfiles then
			if #listfiles("dex/plugins") > 0 then
				intro.SetProgress("Loading Plugin Files",0.8)
				for _, pluginDir in pairs(listfiles("dex/plugins")) do
					local moduleData = Main.LoadPluginFile(pluginDir)
					moduleData.PluginData = moduleData.PluginData or {}

					moduleData.Init()

					local pluginFriendlyName = moduleData.PluginData.FriendlyName or moduleData.Window.GuiElems.Title.Text or "Unnamed Plugin"
					local pluginName = moduleData.PluginData.Name or moduleData.Window.GuiElems.Title.Text:gsub(" ", "") or "unnamedPlugin"

					intro.SetProgress("Initializing Plugin: ".. pluginFriendlyName,0.9)

					moduleData.PluginData.Name = pluginName
					moduleData.PluginData.FriendlyName = pluginFriendlyName

					table.insert(Main.Plugins, moduleData)
					Main.CreateApp({Name = pluginFriendlyName, IconMap = Explorer.ClassIcons, Icon = "Attachment", Window = moduleData.Window})
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
		Main.MenuApps = {}
		Main.AppControls = {}
		Main.Plugins = {}
		for _, gui in pairs(Main.GetSecureContainer():GetChildren()) do
			if string.sub(gui.Name,1,5) == "_DPP_" then -- DPP stands for DexPlusPlus
				gui:Destroy()
			end
		end
	end

	Main.Reinit = function()
		Main.Uninit()
		task.wait()
		Main.Init()
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
