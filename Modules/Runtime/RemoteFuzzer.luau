--!nocheck
--[[
	Remote Fuzzer Generator Module
	Generates custom payload/fuzz testing scripts for RemoteEvents and RemoteFunctions.
]]
local Main, Lib, Apps, Settings
local ScriptViewer

local function initDeps(data)
	Main = data.Main
	Lib = data.Lib
	Apps = data.Apps
	Settings = data.Settings
end

local function initAfterMain(apps)
	ScriptViewer = apps.ScriptViewer
end

local function main()
	local RemoteFuzzer = {}

	local function getPath(obj)
        if Main and Main.SafeGetInstancePath then return Main.SafeGetInstancePath(obj) end
		local ok, path = pcall(function()
			if Apps.Explorer and Apps.Explorer.GetInstancePath then
				return Apps.Explorer.GetInstancePath(obj)
			end
			return obj:GetFullName()
		end)
		return ok and tostring(path) or tostring(obj)
	end

	RemoteFuzzer.Generate = function(remote: Instance)
		if not remote then return end
		local path = getPath(remote)
		local isFunction = remote:IsA("RemoteFunction") or remote:IsA("BindableFunction")
		local isBindable = remote:IsA("BindableEvent") or remote:IsA("BindableFunction")

		local fireMethod = "FireServer"
		if isBindable then
			fireMethod = isFunction and "Invoke" or "Fire"
		else
			fireMethod = isFunction and "InvokeServer" or "FireServer"
		end

		local code = {}
		table.insert(code, "-- Auto-generated Remote Fuzzer Payload")
		table.insert(code, "-- Target: " .. path)
		table.insert(code, "-- Class: " .. remote.ClassName .. "\n")
		
		table.insert(code, "local target = " .. path)
		table.insert(code, "if not target then")
		table.insert(code, "    warn(\"Fuzzer target not found!\")")
		table.insert(code, "    return")
		table.insert(code, "end\n")

		table.insert(code, "-- Define a diverse list of fuzz payloads (boundary values, incorrect types, etc.)")
		table.insert(code, "local payloads = {")
		table.insert(code, "    {name = \"Zero\", val = 0},")
		table.insert(code, "    {name = \"Positive Int\", val = 1},")
		table.insert(code, "    {name = \"Negative Int\", val = -1},")
		table.insert(code, "    {name = \"Large Int\", val = 999999},")
		table.insert(code, "    {name = \"Float\", val = 1.00001},")
		table.insert(code, "    {name = \"NaN\", val = 0/0},")
		table.insert(code, "    {name = \"Infinity\", val = math.huge},")
		table.insert(code, "    {name = \"Negative Infinity\", val = -math.huge},")
		table.insert(code, "    {name = \"Empty String\", val = \"\"},")
		table.insert(code, "    {name = \"Long String (10k)\", val = string.rep(\"A\", 10000)},")
		table.insert(code, "    {name = \"Format Injection\", val = \"%s%s%s%s%d%x\"},")
		table.insert(code, "    {name = \"Special Chars\", val = \"\\\\0\\\\n\\\\r\\\\t!@#$%^&*()\"},")
		table.insert(code, "    {name = \"Empty Table\", val = {}},")
		table.insert(code, "    {name = \"Simple Array\", val = {1, 2, 3}},")
		table.insert(code, "    {name = \"Simple Dict\", val = {key = \"value\"}},")
		table.insert(code, "    {name = \"Nested Table\", val = {a = {b = {c = 1}}}},")
		table.insert(code, "    {name = \"Nil\", val = nil},")
		table.insert(code, "    {name = \"True\", val = true},")
		table.insert(code, "    {name = \"False\", val = false},")
		table.insert(code, "    {name = \"Vector3\", val = Vector3.new(100, 200, 300)},")
		table.insert(code, "    {name = \"CFrame\", val = CFrame.new(0, 50, 0)},")
		table.insert(code, "    {name = \"Color3\", val = Color3.fromRGB(255, 0, 0)},")
		table.insert(code, "}")

		table.insert(code, "\nprint(\"=== Starting Remote Fuzzer on: \" .. target:GetFullName() .. \" ===\")\n")
		table.insert(code, "for _, payload in ipairs(payloads) do")
		table.insert(code, "    print(\"Testing: \" .. payload.name .. \" (\" .. typeof(payload.val) .. \")\")")
		table.insert(code, "    task.spawn(function()")
		table.insert(code, "        local ok, result = pcall(function()")
		if isFunction then
			table.insert(code, "            return target:" .. fireMethod .. "(payload.val)")
		else
			table.insert(code, "            target:" .. fireMethod .. "(payload.val)")
		end
		table.insert(code, "        end)")
		table.insert(code, "        if not ok then")
		table.insert(code, "            warn(\"  Error: \" .. tostring(result))")
		if isFunction then
			table.insert(code, "        else")
			table.insert(code, "            print(\"  Success. Return value: \" .. tostring(result))")
		end
		table.insert(code, "        end")
		table.insert(code, "    end)")
		table.insert(code, "    task.wait(0.1) -- yield to prevent client rate limit kick")
		table.insert(code, "end")
		table.insert(code, "\nprint(\"=== Remote Fuzzing Finished ===\")")

		local finalCode = table.concat(code, "\n")
		if ScriptViewer and ScriptViewer.ViewRawCode then
			ScriptViewer.ViewRawCode(finalCode, remote.Name .. " Fuzzer")
		else
			warn("ScriptViewer not available or missing ViewRawCode!")
		end
	end

	return RemoteFuzzer
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
