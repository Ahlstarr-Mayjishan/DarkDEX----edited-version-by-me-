--!nocheck
--[[
	Smart Decompiler Module
	
	Enhances script readability by remapping obfuscated variable names,
	decoding string.char arrays, and highlighting dangerous API usage.
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
	local SmartDecompiler = {}

	-- Helper: Escapes a string to be safely represented inside Luau string literals
	local function escapeString(str)
		return str:gsub("\\", "\\\\")
		          :gsub("\"", "\\\"")
		          :gsub("\n", "\\n")
		          :gsub("\t", "\\t")
		          :gsub("\r", "\\r")
	end

	-- 1. Decode string.char(104, 101, 108, 108, 111) -> "hello"
	function SmartDecompiler.DecodeStringChar(source)
		-- Match string.char(...) with any amount of digits, spaces, and commas
		local pattern = "string%.char%s*%(([%d%s*,%s*]+)%)"
		
		local decoded = source:gsub(pattern, function(argList)
			local chars = {}
			for numStr in argList:gmatch("%d+") do
				local code = tonumber(numStr)
				if code then
					table.insert(chars, string.char(code))
				end
			end
			local combined = table.concat(chars)
			-- Check if printable, otherwise don't replace or use hex escape
			local isPrintable = true
			for i = 1, #combined do
				local b = combined:byte(i)
				if (b < 32 or b > 126) and b ~= 10 and b ~= 9 and b ~= 13 then
					isPrintable = false
					break
				end
			end
			
			if isPrintable then
				return "\"" .. escapeString(combined) .. "\""
			else
				return nil -- Keep original if contains weird binary bytes
			end
		end)
		
		return decoded
	end

	-- 2. Decode slash decimal escape sequences in strings like "\104\101\108" -> "hel"
	function SmartDecompiler.DecodeEscapeSequences(source)
		-- Decodes decimal escape sequences: \ddd
		local decoded = source:gsub("(\\[0-9][0-9][0-9])", function(esc)
			local val = tonumber(esc:sub(2))
			if val and val >= 32 and val <= 126 then
				local ch = string.char(val)
				if ch == "\"" or ch == "\\" or ch == "'" then
					return "\\" .. ch
				end
				return ch
			end
			return esc
		end)
		return decoded
	end

	-- 3. Variable Normalizer: Maps obfuscated variables to var_1, var_2, etc.
	function SmartDecompiler.NormalizeVariables(source)
		if env.HelperServer and env.HelperServer.NormalizeSource then
			local helperResult = env.HelperServer.NormalizeSource(source)
			if helperResult then
				return helperResult
			end
		end

		local req = env.request or (syn and syn.request) or (http and http.request) or http_request or request
		if req then
			local success, result = pcall(function()
				return req({
					Url = "http://localhost:8080/normalize-source",
					Method = "POST",
					Headers = {
						["Content-Type"] = "text/plain"
					},
					Body = source
				})
			end)
			if success and result and result.StatusCode == 200 then
				return result.Body
			end
		end

		local varMap = {}
		local varCounter = 0
		
		-- Match obfuscation variable formats:
		-- - l__u__123 (classic decompiler output)
		-- - _0xABC123 (hex obfuscation)
		-- - IllIIllII (bar code obfuscation)
		local patterns = {
			"([%a_][%w_]*)", -- we will filter this in the loop
		}
		
		-- Helper to identify if a word is a variable matching obfuscation criteria
		local function isObfuscatedName(name)
			-- Skip Lua/Roblox keywords and globals
			local reserved = {
				["and"]=true, ["break"]=true, ["do"]=true, ["else"]=true, ["elseif"]=true,
				["end"]=true, ["false"]=true, ["for"]=true, ["function"]=true, ["if"]=true,
				["in"]=true, ["local"]=true, ["nil"]=true, ["not"]=true, ["or"]=true,
				["repeat"]=true, ["return"]=true, ["then"]=true, ["true"]=true, ["until"]=true,
				["while"]=true, ["self"]=true, ["game"]=true, ["workspace"]=true, ["script"]=true
			}
			if reserved[name] then return false end
			
			-- 1. Match l__u__123 or v1_1 or u_2
			if name:match("^l__u__%d+") or name:match("^u_%d+") then
				return true
			end
			
			-- 2. Match hex style _0x123abc
			if name:match("^_[0xX]%x+$") or name:match("^0x%x+$") then
				return true
			end
			
			-- 3. Match bar code style IllIIlI
			if #name >= 4 and name:match("^[Il1]+$") then
				return true
			end
			
			return false
		end
		
		-- Extract all variables and map them
		for word in source:gmatch("([%a_][%w_]*)") do
			if isObfuscatedName(word) and not varMap[word] then
				varCounter = varCounter + 1
				varMap[word] = "var_" .. tostring(varCounter)
			end
		end
		
		-- Replace all occurrences cleanly using word boundaries
		-- To avoid replacing substrings, we check characters before/after each match
		local normalized = source:gsub("([%a_][%w_]*)", function(word)
			return varMap[word] or word
		end)
		
		return normalized
	end

	-- 4. Audit Heuristics: Flag dangerous APIs and generate a warning header
	function SmartDecompiler.AuditCode(source)
		local warnings = {}
		local lines = string.split(source, "\n")
		
		local dangerousAPIs = {
			{Keyword = "loadstring", Label = "Dynamic Code Execution (loadstring)"},
			{Keyword = "HttpGet", Label = "Outbound Web Request (HttpGet)"},
			{Keyword = "HttpPost", Label = "Outbound Web Request (HttpPost)"},
			{Keyword = "require", Label = "External Module Require (require)"},
			{Keyword = "getgenv", Label = "Global Environment Access (getgenv)"},
			{Keyword = "hookfunction", Label = "Function Hooking (hookfunction)"},
			{Keyword = "hookmetamethod", Label = "Metatable Hooking (hookmetamethod)"},
			{Keyword = "setclipboard", Label = "Clipboard Writing (setclipboard)"},
			{Keyword = "getgc", Label = "Garbage Collection Access (getgc)"},
			{Keyword = "getreg", Label = "Registry Access (getreg)"},
		}
		
		for lineIndex, line in ipairs(lines) do
			for _, api in ipairs(dangerousAPIs) do
				-- Match keyword as a separate token
				if line:match("[^%w_]" .. api.Keyword .. "[^%w_]") or line:match("^" .. api.Keyword .. "[^%w_]") or line:match("[^%w_]" .. api.Keyword .. "$") or line == api.Keyword then
					table.insert(warnings, {
						Line = lineIndex,
						Label = api.Label,
						Snippet = line:gsub("^%s*", "") -- Trim leading spaces
					})
				end
			end
		end
		
		if #warnings == 0 then
			return source
		end
		
		-- Generate audit header
		local header = {}
		table.insert(header, "-- [[ DARKDEX++ SMART DECOMPILER AUDIT REPORT ]]")
		table.insert(header, "-- Heuristic static analysis found the following potential security concerns:")
		for _, warnItem in ipairs(warnings) do
			table.insert(header, string.format("--  ⚠️ [Line %d]: %s", warnItem.Line, warnItem.Label))
			table.insert(header, string.format("--      Code: %s", warnItem.Snippet))
		end
		table.insert(header, "-- [[ ========================================== ]]\n")
		
		return table.concat(header, "\n") .. source
	end

	-- Main normalization pipeline
	function SmartDecompiler.Process(source)
		local processed = source
		processed = SmartDecompiler.DecodeStringChar(processed)
		processed = SmartDecompiler.DecodeEscapeSequences(processed)
		processed = SmartDecompiler.NormalizeVariables(processed)
		processed = SmartDecompiler.AuditCode(processed)
		return processed
	end

	return SmartDecompiler
end

return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
