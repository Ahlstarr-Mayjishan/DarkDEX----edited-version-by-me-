--!strict
--[[
	Nil Instance Menu Module
	Registers options to scan and manage unparented (nil) instances.
]]
local Main, Lib, Apps, Settings
local function initDeps(data)
	Main, Lib, Apps, Settings = data.Main, data.Lib, data.Apps, data.Settings
end

local function initAfterMain()
end

local function main()
	return function(context, data)
		local Explorer = data.Explorer

		context:Register("REFRESH_NIL",{Name = "Refresh Nil Instances", OnClick = function()
			Explorer.RefreshNilInstances()
		end})

		context:Register("HIDE_NIL",{Name = "Hide Nil Instances", OnClick = function()
			Explorer.HideNilInstances()
		end})
	end
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main
}
