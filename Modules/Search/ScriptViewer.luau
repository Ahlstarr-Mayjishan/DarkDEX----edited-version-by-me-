--[[
	Script Viewer App Module
	
	A script viewer that is basically a notepad
]]
-- Common Locals
local Main,Lib,Apps,Settings -- Main Containers
local Explorer, Properties, ScriptViewer, Notebook, SmartDecompiler -- Major Apps
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

local function initAfterMain(t)
	Explorer = t.Explorer
	Properties = t.Properties
	ScriptViewer = t.ScriptViewer
	Notebook = t.Notebook
	SmartDecompiler = t.SmartDecompiler
end

local executorName = "Unknown"
local executorVersion = "???"
if identifyexecutor then
	local name,ver = identifyexecutor()
	executorName = name
	executorVersion = ver
elseif game:GetService("RunService"):IsStudio() then
	executorName = "Studio"
	executorVersion = version()
end

local function getPath(obj)
    if Main and Main.SafeGetInstancePath then
        return Main.SafeGetInstancePath(obj)
    end
    if not obj then return "?" end
    if obj.Parent == nil then return "Nil parented" end
    local ok, fullName = pcall(function()
        return obj:GetFullName()
    end)
    return ok and fullName or tostring(obj)
end

local function main()
	local ScriptViewer = {}
	local window, codeFrame
	local searchBox, searchStatus
	local selectionMenu
	local searchMatches = {}
	local searchIndex = 0
	
	local execute, clear, dumpbtn, smartViewBtn
	
	local PreviousScr = nil
	local rawSourceCache = ""
	local smartViewActive = false
	local lastSelectionText = ""
	
	ScriptViewer.DumpFunctions = function(scr)
		-- thanks King.Kevin#6025 you'll obviously be credited (no discord tag since that can easily be impersonated)
		local getgc = getgc or get_gc_objects
		local getupvalues = (debug and debug.getupvalues) or getupvalues or getupvals
		local getconstants = (debug and debug.getconstants) or getconstants or getconsts
		local getinfo = (debug and (debug.getinfo or debug.info)) or getinfo
		local original = ("\n-- // Function Dumper made by King.Kevin\n-- // Script Path: %s\n\n--[["):format(getPath(scr))
		local dump = original
		local functions, function_count, data_base = {}, 0, {}
		function functions:add_to_dump(str, indentation, new_line)
			local new_line = new_line or true
			dump = dump .. ("%s%s%s"):format(string.rep("		", indentation), tostring(str), new_line and "\n" or "")
		end
		function functions:get_function_name(func)
			local n = getinfo(func).name
			return n ~= "" and n or "Unknown Name"
		end
		function functions:dump_table(input, indent, index)
			local indent = indent < 0 and 0 or indent
			functions:add_to_dump(("%s [%s] %s"):format(tostring(index), tostring(typeof(input)), tostring(input)), indent - 1)
			local count = 0
			for index, value in pairs(input) do
				count = count + 1
				if type(value) == "function" then
					functions:add_to_dump(("%d [function] = %s"):format(count, functions:get_function_name(value)), indent)
				elseif type(value) == "table" then
					if not data_base[value] then
						data_base[value] = true
						functions:add_to_dump(("%d [table]:"):format(count), indent)
						functions:dump_table(value, indent + 1, index)
					else
						functions:add_to_dump(("%d [table] (Recursive table detected)"):format(count), indent)
					end
				else
					functions:add_to_dump(("%d [%s] = %s"):format(count, tostring(typeof(value)), tostring(value)), indent)
				end
			end
		end
		function functions:dump_function(input, indent)
			functions:add_to_dump(("\nFunction Dump: %s"):format(functions:get_function_name(input)), indent)
			functions:add_to_dump(("\nFunction Upvalues: %s"):format(functions:get_function_name(input)), indent)
			for index, upvalue in pairs(getupvalues(input)) do
				if type(upvalue) == "function" then
					functions:add_to_dump(("%d [function] = %s"):format(index, functions:get_function_name(upvalue)), indent + 1)
				elseif type(upvalue) == "table" then
					if not data_base[upvalue] then
						data_base[upvalue] = true
						functions:add_to_dump(("%d [table]:"):format(index), indent + 1)
						functions:dump_table(upvalue, indent + 2, index)
					else
						functions:add_to_dump(("%d [table] (Recursive table detected)"):format(index), indent + 1)
					end
				else
					functions:add_to_dump(("%d [%s] = %s"):format(index, tostring(typeof(upvalue)), tostring(upvalue)), indent + 1)
				end
			end
			functions:add_to_dump(("\nFunction Constants: %s"):format(functions:get_function_name(input)), indent)
			for index, constant in pairs(getconstants(input)) do
				if type(constant) == "function" then
					functions:add_to_dump(("%d [function] = %s"):format(index, functions:get_function_name(constant)), indent + 1)
				elseif type(constant) == "table" then
					if not data_base[constant] then
						data_base[constant] = true
						functions:add_to_dump(("%d [table]:"):format(index), indent + 1)
						functions:dump_table(constant, indent + 2, index)
					else
						functions:add_to_dump(("%d [table] (Recursive table detected)"):format(index), indent + 1)
					end
				else
					functions:add_to_dump(("%d [%s] = %s"):format(index, tostring(typeof(constant)), tostring(constant)), indent + 1)
				end
			end
		end
		for _, _function in pairs(env.getgc()) do
			if typeof(_function) == "function" and getfenv(_function).script and getfenv(_function).script == scr then
				functions:dump_function(_function, 0)
				functions:add_to_dump("\n" .. ("="):rep(100), 0, false)
			end
		end
		local source = codeFrame:GetText()

		if dump ~= original then source = source .. dump .. "]]" end
		codeFrame:SetText(source)
		
		window:Show()
	end

	local function setSearchStatus(text, color)
		if not searchStatus then return end
		searchStatus.Text = text
		searchStatus.TextColor3 = color or Settings.Theme.PlaceholderText
	end

	local function rebuildSearch()
		searchMatches = {}
		searchIndex = 0

		if not searchBox or not codeFrame then return end
		local keyword = searchBox.Text
		if keyword == "" then
			codeFrame:ResetSelection()
			setSearchStatus("0")
			return
		end

		local loweredKeyword = keyword:lower()
		for lineIndex, line in ipairs(codeFrame.Lines) do
			local loweredLine = line:lower()
			local startAt = 1
			while true do
				local first, last = loweredLine:find(loweredKeyword, startAt, true)
				if not first then break end
				searchMatches[#searchMatches + 1] = {
					line = lineIndex - 1,
					first = first - 1,
					last = last,
				}
				startAt = math.max(last + 1, first + 1)
			end
		end

		if #searchMatches == 0 then
			codeFrame:ResetSelection()
			setSearchStatus("0", Settings.Theme.Important)
		else
			searchIndex = 1
			setSearchStatus("1/" .. #searchMatches)
		end
	end

	local function jumpSearch(delta)
		if not codeFrame then return end
		if #searchMatches == 0 then
			rebuildSearch()
		end
		if #searchMatches == 0 then return end

		searchIndex = ((searchIndex - 1 + delta) % #searchMatches) + 1
		local match = searchMatches[searchIndex]
		codeFrame.SelectionRange = {{match.first, match.line}, {match.last, match.line}}
		codeFrame:MoveCursor(match.first, match.line)
		codeFrame:SetCopyableSelection()
		codeFrame:Refresh()
		setSearchStatus(searchIndex .. "/" .. #searchMatches)
	end

	local function getSelectionText()
		if not codeFrame or not codeFrame.GetSelectionText then return "" end
		local ok, text = pcall(function()
			return codeFrame:GetSelectionText()
		end)
		return ok and tostring(text or "") or ""
	end

	local function copySelected()
		local text = getSelectionText()
		if text == "" then return end
		if env.setclipboard then
			env.setclipboard(text)
		end
	end

	local function searchSelected()
		local text = getSelectionText()
		if text == "" or not searchBox then return end
		local oneLine = text:gsub("[\r\n]+", " ")
		if #oneLine > 120 then oneLine = oneLine:sub(1, 120) end
		searchBox.Text = oneLine
		rebuildSearch()
		jumpSearch(0)
	end

	local function copySelectedAI()
		local text = getSelectionText()
		if text == "" or not env.setclipboard then return end
		local lines = {
			"DEX++ selected code context",
			"Script: " .. (PreviousScr and getPath(PreviousScr) or "Generated/Notepad source"),
			"",
			"Selected code:",
			text,
			"",
			"Task for AI:",
			"Explain this selected block, identify important calls/remotes/services, and suggest what I should inspect next.",
		}
		env.setclipboard(table.concat(lines, "\n"))
	end

	local function saveSelected()
		local text = getSelectionText()
		if text == "" then return end
		Lib.SaveAsPrompt("Selected_Code_" .. os.time() .. ".luau", text)
	end

	local function copyScriptPath()
		if not env.setclipboard then return end
		env.setclipboard(PreviousScr and getPath(PreviousScr) or "Generated/Notepad source")
	end

	local function selectAllCode()
		if not codeFrame or not codeFrame.Lines or #codeFrame.Lines == 0 then return end
		codeFrame.SelectionRange = {{0, 0}, {#codeFrame.Lines[#codeFrame.Lines], #codeFrame.Lines - 1}}
		codeFrame:SetCopyableSelection()
		codeFrame:Refresh()
	end

	local function clearSelection()
		if selectionMenu then selectionMenu:Hide() end
		if codeFrame and codeFrame.ResetSelection then
			codeFrame:ResetSelection()
		end
	end

	local function buildSelectionMenu()
		if not selectionMenu then
			selectionMenu = Lib.ContextMenu.new()
			selectionMenu.Width = 210
			selectionMenu.MaxHeight = 260
			selectionMenu.Iconless = true
			selectionMenu.SearchEnabled = false
			selectionMenu.ReverseYOffset = 4
			selectionMenu:ApplyTheme({
				ContentColor = Settings.Theme.Main1,
				OutlineColor = Settings.Theme.Outline1,
				DividerColor = Settings.Theme.Outline2,
				TextColor = Settings.Theme.Text,
				HighlightColor = Settings.Theme.ButtonHover,
			})
		end

		local hasClipboard = env.setclipboard ~= nil
		local hasSelection = getSelectionText() ~= ""

		selectionMenu:Clear()
		selectionMenu:Add({
			Name = "Copy",
			Shortcut = "Ctrl+C",
			Disabled = not hasClipboard or not hasSelection,
			OnClick = copySelected,
		})
		selectionMenu:Add({
			Name = "Search Selection",
			Shortcut = "Ctrl+F",
			Disabled = not hasSelection,
			OnClick = searchSelected,
		})
		selectionMenu:Add({
			Name = "Copy AI Context",
			Disabled = not hasClipboard or not hasSelection,
			OnClick = copySelectedAI,
		})
		selectionMenu:Add({
			Name = "Save Selection",
			Disabled = not hasSelection,
			OnClick = saveSelected,
		})
		selectionMenu:AddDivider()
		selectionMenu:Add({
			Name = "Copy Script Path",
			Disabled = not hasClipboard,
			OnClick = copyScriptPath,
		})
		selectionMenu:Add({
			Name = "Select All",
			Shortcut = "Ctrl+A",
			OnClick = selectAllCode,
		})
		selectionMenu:Add({
			Name = "Clear Selection",
			Disabled = not hasSelection,
			OnClick = clearSelection,
		})
	end

	local function showSelectionMenu(x, y)
		if not codeFrame then return end
		local text = getSelectionText()
		if text == "" then return end
		buildSelectionMenu()
		selectionMenu:Show(x, y)
	end

	local function updateSelectionMenu(text)
		text = tostring(text or "")
		lastSelectionText = text
		if text == "" and selectionMenu then
			selectionMenu:Hide()
		end
	end

	ScriptViewer.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Notepad")
		window:Resize(500,400)
		ScriptViewer.Window = window

		codeFrame = Lib.CodeFrame.new()
		codeFrame.Frame.Position = UDim2.new(0,0,0,44)
		codeFrame.Frame.Size = UDim2.new(1,0,1,-64)
		codeFrame.Frame.Parent = window.GuiElems.Content

		if codeFrame.OnSelectionChanged then
			codeFrame.OnSelectionChanged:Connect(updateSelectionMenu)
		end
		if codeFrame.OnSelectionFinished then
			codeFrame.OnSelectionFinished:Connect(function(text, x, y)
				if tostring(text or "") ~= "" then
					showSelectionMenu(x, y)
				end
			end)
		end
		if codeFrame.OnRightClick then
			codeFrame.OnRightClick:Connect(function(x, y)
				if lastSelectionText == "" then
					local ok, current = pcall(function()
						return codeFrame:GetSelectionText()
					end)
					lastSelectionText = ok and tostring(current or "") or ""
				end
				if lastSelectionText ~= "" then
					showSelectionMenu(x, y)
				end
			end)
		end
		
		local copy = Instance.new("TextButton",window.GuiElems.Content)
		copy.BackgroundTransparency = 1
		copy.Size = UDim2.new(0.25,0,0,20)
		copy.Position = UDim2.new(0,0,0,0)
		copy.Text = "Copy to Clipboard"
		
		if env.setclipboard then
			copy.TextColor3 = Color3.new(1,1,1)
			copy.Interactable = true
		else
			copy.TextColor3 = Color3.new(0.5,0.5,0.5)
			copy.Interactable = false
		end

		copy.MouseButton1Click:Connect(function()
			local source = codeFrame:GetText()
			env.setclipboard(source)
		end)

		local save = Instance.new("TextButton",window.GuiElems.Content)
		save.BackgroundTransparency = 1
		save.Size = UDim2.new(0.25,0,0,20)
		save.Position = UDim2.new(0.25,0,0,0)
		save.Text = "Save to File"
		save.TextColor3 = Color3.new(1,1,1)
		
		if env.writefile then
			save.TextColor3 = Color3.new(1,1,1)
			save.Interactable = true
		else
			save.TextColor3 = Color3.new(0.5,0.5,0.5)
			--save.Interactable = false
		end

		save.MouseButton1Click:Connect(function()
			local source = codeFrame:GetText()
			local filename = "Place_"..game.PlaceId.."_Script_"..os.time()..".txt"

			Lib.SaveAsPrompt(filename,source)
			--env.writefile(filename,source)
		end)
		
		dumpbtn = Instance.new("TextButton",window.GuiElems.Content)
		dumpbtn.BackgroundTransparency = 1
		dumpbtn.Position = UDim2.new(0.5,0,0,0)
		dumpbtn.Size = UDim2.new(0.25,0,0,20)
		dumpbtn.Text = "Dump Functions"
		
		if env.getgc then
			dumpbtn.TextColor3 = Color3.new(1,1,1)
			dumpbtn.Interactable = true
		else
			dumpbtn.TextColor3 = Color3.new(0.5,0.5,0.5)
			dumpbtn.Interactable = false
		end

		dumpbtn.MouseButton1Click:Connect(function()
			if PreviousScr ~= nil then
				pcall(ScriptViewer.DumpFunctions, PreviousScr)
			end
		end)

		smartViewBtn = Instance.new("TextButton",window.GuiElems.Content)
		smartViewBtn.BackgroundTransparency = 1
		smartViewBtn.Position = UDim2.new(0.75,0,0,0)
		smartViewBtn.Size = UDim2.new(0.25,0,0,20)
		smartViewBtn.Text = "Smart View: OFF"
		smartViewBtn.TextColor3 = Color3.new(0.5,0.5,0.5)
		
		smartViewBtn.MouseButton1Click:Connect(function()
			smartViewActive = not smartViewActive
			if smartViewActive then
				smartViewBtn.Text = "Smart View: ON"
				smartViewBtn.TextColor3 = Settings.Theme.ListSelection
			else
				smartViewBtn.Text = "Smart View: OFF"
				smartViewBtn.TextColor3 = Color3.new(0.5,0.5,0.5)
			end
			if PreviousScr ~= nil then
				ScriptViewer.ViewScript(PreviousScr)
			end
		end)

		local searchBar = Instance.new("Frame", window.GuiElems.Content)
		searchBar.BackgroundColor3 = Settings.Theme.TextBox
		searchBar.BorderSizePixel = 0
		searchBar.Position = UDim2.new(0, 0, 0, 21)
		searchBar.Size = UDim2.new(1, 0, 0, 22)

		searchBox = Instance.new("TextBox", searchBar)
		searchBox.BackgroundTransparency = 1
		searchBox.ClearTextOnFocus = false
		searchBox.Font = Enum.Font.Code
		searchBox.PlaceholderColor3 = Settings.Theme.PlaceholderText
		searchBox.PlaceholderText = "Search keywords..."
		searchBox.Position = UDim2.new(0, 8, 0, 0)
		searchBox.Size = UDim2.new(1, -138, 1, 0)
		searchBox.Text = ""
		searchBox.TextColor3 = Settings.Theme.Text
		searchBox.TextSize = 13
		searchBox.TextXAlignment = Enum.TextXAlignment.Left

		local prevBtn = Instance.new("TextButton", searchBar)
		prevBtn.AutoButtonColor = false
		prevBtn.BackgroundColor3 = Settings.Theme.Button
		prevBtn.BorderSizePixel = 0
		prevBtn.Font = Enum.Font.SourceSansBold
		prevBtn.Position = UDim2.new(1, -128, 0, 2)
		prevBtn.Size = UDim2.new(0, 28, 0, 18)
		prevBtn.Text = "<"
		prevBtn.TextColor3 = Settings.Theme.Text
		prevBtn.TextSize = 14

		local nextBtn = Instance.new("TextButton", searchBar)
		nextBtn.AutoButtonColor = false
		nextBtn.BackgroundColor3 = Settings.Theme.Button
		nextBtn.BorderSizePixel = 0
		nextBtn.Font = Enum.Font.SourceSansBold
		nextBtn.Position = UDim2.new(1, -96, 0, 2)
		nextBtn.Size = UDim2.new(0, 28, 0, 18)
		nextBtn.Text = ">"
		nextBtn.TextColor3 = Settings.Theme.Text
		nextBtn.TextSize = 14

		searchStatus = Instance.new("TextLabel", searchBar)
		searchStatus.BackgroundTransparency = 1
		searchStatus.Font = Enum.Font.Code
		searchStatus.Position = UDim2.new(1, -64, 0, 0)
		searchStatus.Size = UDim2.new(0, 58, 1, 0)
		searchStatus.Text = "0"
		searchStatus.TextColor3 = Settings.Theme.PlaceholderText
		searchStatus.TextSize = 12
		searchStatus.TextXAlignment = Enum.TextXAlignment.Right

		local function hoverButton(btn)
			btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Settings.Theme.ButtonHover end)
			btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Settings.Theme.Button end)
		end
		hoverButton(prevBtn)
		hoverButton(nextBtn)

		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			rebuildSearch()
			if #searchMatches > 0 then
				jumpSearch(0)
			end
		end)
		searchBox.FocusLost:Connect(function(enterPressed)
			if enterPressed then jumpSearch(1) end
		end)
		prevBtn.MouseButton1Click:Connect(function()
			jumpSearch(-1)
		end)
		nextBtn.MouseButton1Click:Connect(function()
			jumpSearch(1)
		end)
		
		-- Buttons below the editor
		
		
		execute = Instance.new("TextButton",window.GuiElems.Content)
		execute.BackgroundTransparency = 1
		execute.Size = UDim2.new(0.5,0,0,20)
		execute.Position = UDim2.new(0,0,1,-20)
		execute.Text = "Execute"
		execute.TextColor3 = Color3.new(1,1,1)
		
		if env.loadstring then
			execute.TextColor3 = Color3.new(1,1,1)
			execute.Interactable = true
		else
			execute.TextColor3 = Color3.new(0.5,0.5,0.5)
			execute.Interactable = false
		end

		execute.MouseButton1Click:Connect(function()
			local source = codeFrame:GetText()
			env.loadstring(source)()
		end)

		clear = Instance.new("TextButton",window.GuiElems.Content)
		clear.BackgroundTransparency = 1
		clear.Size = UDim2.new(0.5,0,0,20)
		clear.Position = UDim2.new(0.5,0,1,-20)
		clear.Text = "Clear"
		clear.TextColor3 = Color3.new(1,1,1)

		clear.MouseButton1Click:Connect(function()
			codeFrame:SetText("")
			rebuildSearch()
		end)
	end
	
	ScriptViewer.ViewScript = function(scr)
		local s,source
		local cacheHit = (PreviousScr == scr and rawSourceCache ~= "")
		
		if cacheHit then
			s = true
			source = rawSourceCache
		else
			local oldtick = tick()
			s,source = pcall(env.decompile or function() end,scr)
			if s and type(source) == "string" then
				rawSourceCache = source
			else
				rawSourceCache = ""
			end
		end

		if not s or not source or source == "" then
			PreviousScr = nil
			rawSourceCache = ""
			dumpbtn.TextColor3 = Color3.new(0.5,0.5,0.5)
			source = "-- Unable to view source.\n"
			
			if Settings.ScriptViewer.ShowMoreInfo then
				source = source .. "-- Script Path: "..getPath(scr).."\n"
				if (scr.ClassName == "Script" and (scr.RunContext == Enum.RunContext.Legacy or scr.RunContext == Enum.RunContext.Server)) or not scr:IsA("LocalScript") then
					source = source .. "-- Reason: The script is not running on client. (attempt to decompile ServerScript or 'Script' with RunContext Server)\n"
				elseif not env.isdecompile() then
					source = source .. "-- Reason: Your executor does not support decompiler. (missing 'decompile' function and 'getscriptbytecode' function as fallback)\n"
				else
					source = source .. "-- Reason: Unknown Error.\n"
				end
				source = source .. "-- Executor: "..executorName.." ("..executorVersion..")"
			end
		else
			PreviousScr = scr
			dumpbtn.TextColor3 = Color3.new(1,1,1)

			local decompiled = source
			if smartViewActive and SmartDecompiler then
				decompiled = SmartDecompiler.Process(decompiled)
			end

			source = "-- Script Path: "..getPath(scr).."\n"
			
			if Settings.ScriptViewer.ShowMoreInfo and not cacheHit then
				source = source .. "-- Executor: "..executorName.." ("..executorVersion..")\n\n"
			end
			
			source = source .. decompiled
		end

		codeFrame:SetText(source)
		rebuildSearch()
		window:Show()
	end

	ScriptViewer.ViewRawCode = function(code, title)
		PreviousScr = nil
		rawSourceCache = ""
		dumpbtn.TextColor3 = Color3.fromRGB(127,127,127)

		local header = "-- Generated Code: " .. (title or "Source") .. "\n"
		header = header .. "-- Time: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n"

		codeFrame:SetText(header .. code)
		rebuildSearch()
		window:Show()
	end

	return ScriptViewer
end

-- TODO: Remove when open source
if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
