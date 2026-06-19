--!strict
--[[
	Client Index Module
	Shared cached index for developer/debug tools. Keeps expensive scans and cache reads off hot UI paths.
]]
local Main,Lib,Apps,Settings
local Explorer, ClientIndex
local API,RMD,env,service,plr,create,createSimple

local function initDeps(data)
	Main, Lib, Apps, Settings = data.Main, data.Lib, data.Apps, data.Settings
	API, RMD, env, service, plr = data.API, data.RMD, data.env, data.service, data.plr
	create, createSimple = data.create, data.createSimple
end

local function initAfterMain()
	Explorer = Apps.Explorer
	ClientIndex = Apps.ClientIndex
	env.ClientIndex = ClientIndex
end

local function main()
	local ClientIndex = {}
	local remoteClasses = {RemoteEvent=true, RemoteFunction=true, UnreliableRemoteEvent=true, BindableEvent=true, BindableFunction=true}
	local surfaceTtl = 4
	local surfaceStamp = 0
	local surface = {AllInstances={}, AllScripts={}, ViableScripts={}, Remotes={}}
	local scriptByKey = {}

	local function getPath(obj)
        if Main and Main.SafeGetInstancePath then return Main.SafeGetInstancePath(obj) end
		local ok, path = pcall(function()
			if Explorer and Explorer.GetInstancePath then return Explorer.GetInstancePath(obj) end
			return obj:GetFullName()
		end)
		return ok and tostring(path) or tostring(obj)
	end
	local function addUnique(list, seen, obj)
		if typeof(obj) == "Instance" and not seen[obj] then
			seen[obj] = true
			list[#list + 1] = obj
		end
	end
	local function collectAllInstances()
		if env.RefreshClientSurface then
			return env.RefreshClientSurface(false, false).AllInstances
		end
		local list, seen = {}, {}
		for _, obj in ipairs(game:GetDescendants()) do addUnique(list, seen, obj) end
		if env.getnilinstances then
			local ok, nils = pcall(env.getnilinstances)
			if ok and type(nils) == "table" then
				for _, obj in pairs(nils) do addUnique(list, seen, obj) end
			end
		end
		return list
	end
	local function rebuildScriptLookup()
		table.clear(scriptByKey)
		if not env.DecompileCache or not env.DecompileCache.GetScriptKey then return scriptByKey end
		for _, obj in ipairs(surface.AllScripts) do
			local ok, key = pcall(env.DecompileCache.GetScriptKey, obj)
			if ok and key then scriptByKey[key] = obj end
		end
		return scriptByKey
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
	function ClientIndex.RefreshSurface(force)
		local now = os.clock()
		if not force and now - surfaceStamp < surfaceTtl then return surface end
		surfaceStamp = now
		if env.RefreshClientSurface then
			local sharedSurface = env.RefreshClientSurface(force == true, false)
			surface = {
				AllInstances = sharedSurface.AllInstances or {},
				AllScripts = sharedSurface.AllScripts or {},
				ViableScripts = sharedSurface.ViableScripts or {},
				Remotes = sharedSurface.Remotes or {},
			}
			rebuildScriptLookup()
			return surface
		end
		local all = collectAllInstances()
		local allScripts, viableScripts, remotes = {}, {}, {}
		for _, obj in ipairs(all) do
			if obj:IsA("LuaSourceContainer") then
				allScripts[#allScripts + 1] = obj
				if not env.isViableDecompileScript or env.isViableDecompileScript(obj) then viableScripts[#viableScripts + 1] = obj end
			elseif remoteClasses[obj.ClassName] then
				remotes[#remotes + 1] = obj
			end
		end
		if env.getloadedmodules then
			local ok, loaded = pcall(env.getloadedmodules)
			if ok and type(loaded) == "table" then
				local seen = {}
				for _, obj in ipairs(allScripts) do seen[obj] = true end
				for _, obj in pairs(loaded) do
					if typeof(obj) == "Instance" and obj:IsA("ModuleScript") and not seen[obj] then
						allScripts[#allScripts + 1] = obj
						viableScripts[#viableScripts + 1] = obj
					end
				end
			end
		end
		surface = {AllInstances=all, AllScripts=allScripts, ViableScripts=viableScripts, Remotes=remotes}
		rebuildScriptLookup()
		return surface
	end
	function ClientIndex.GetScriptLookup()
		ClientIndex.RefreshSurface(false)
		return scriptByKey
	end
	function ClientIndex.GetCacheEntries()
		if not env.DecompileCache or not env.DecompileCache.GetEntries or not env.isfile then return {}, nil end
		local entries, cacheDir = env.DecompileCache.GetEntries()
		return entries or {}, cacheDir
	end
	function ClientIndex.SearchCached(query, keepGoing, limit)
		local rows, lowerQuery = {}, tostring(query or ""):lower()
		if lowerQuery == "" then return rows end
		if env.HelperServer and env.HelperServer.SearchSource then
			local active = true
			if env.HelperServer.IsActive then active = env.HelperServer.IsActive(false) end
			if active then
				local decoded = decodeJson(env.HelperServer.SearchSource(query, limit or 80))
				if decoded and decoded.ok == true and tonumber(decoded.indexed or 0) > 0 and type(decoded.results) == "table" then
					for _, item in ipairs(decoded.results) do
						if keepGoing and not keepGoing() then return rows end
						rows[#rows + 1] = {
							Key = tostring(item.key or ""),
							Entry = {
								Path = item.path,
								Name = item.name,
								ClassName = item.className,
							},
							Snippet = tostring(item.snippet or "helper source hit"),
							Score = tonumber(item.score or 0),
							MatchType = tostring(item.matchType or "helper"),
							MatchedToken = tostring(item.matchedToken or ""),
							Confidence = tonumber(item.confidence or 0),
							UpdatedAt = tonumber(item.updatedAt or 0),
							Analysis = item.analysis,
							Source = "helper-index",
						}
						if limit and #rows >= limit then return rows end
					end
					return rows
				end
			end
		end
		local entries, cacheDir = ClientIndex.GetCacheEntries()
		local count = 0
		for key, entry in pairs(entries) do
			if keepGoing and not keepGoing() then return rows end
			if entry.File then
				local path = cacheDir .. "/" .. tostring(entry.File)
				if env.isfile(path) then
					local ok, source = pcall(env.readfile, path)
					if ok and type(source) == "string" then
						local lowerPath, lowerSource = tostring(entry.Path or ""):lower(), source:lower()
						local hitAt = lowerSource:find(lowerQuery, 1, true)
						if hitAt or lowerPath:find(lowerQuery, 1, true) then
							rows[#rows + 1] = {Key=key, Entry=entry, Snippet=source:sub(math.max(1, (hitAt or 1) - 45), math.min(#source, (hitAt or 1) + 120)):gsub("\r"," "):gsub("\n"," ")}
							if limit and #rows >= limit then return rows end
						end
					end
				end
			end
			count += 1
			if count % 20 == 0 then task.wait() end
		end
		return rows
	end
	function ClientIndex.FindCachedReferences(tokens, keepGoing, limit)
		local rows, entries, cacheDir = {}, ClientIndex.GetCacheEntries()
		local count = 0
		for key, entry in pairs(entries) do
			if keepGoing and not keepGoing() then return rows end
			if entry.File then
				local path = cacheDir .. "/" .. tostring(entry.File)
				if env.isfile(path) then
					local ok, source = pcall(env.readfile, path)
					if ok and type(source) == "string" then
						local lower = source:lower()
						for _, token in ipairs(tokens) do
							local needle = tostring(token):lower()
							local pos = #needle >= 2 and lower:find(needle, 1, true)
							if pos then
								rows[#rows + 1] = {Key=key, Entry=entry, Token=token, Snippet=source:sub(math.max(1,pos-50), math.min(#source,pos+120)):gsub("\r"," "):gsub("\n"," ")}
								break
							end
						end
						if limit and #rows >= limit then return rows end
					end
				end
			end
			count += 1
			if count % 20 == 0 then task.wait() end
		end
		return rows
	end
	function ClientIndex.GetIndexStatus()
		if not env.HelperServer or not env.HelperServer.IndexStatus then return nil end
		local active = true
		if env.HelperServer.IsActive then active = env.HelperServer.IsActive(false) end
		if not active then return nil end
		local decoded = decodeJson(env.HelperServer.IndexStatus())
		if decoded and decoded.ok == true then
			return decoded
		end
		return nil
	end
	function ClientIndex.Path(obj) return getPath(obj) end
	function ClientIndex.Init()
		task.spawn(function()
			task.wait(0.2)
			ClientIndex.RefreshSurface(false)
		end)
	end
	return ClientIndex
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
