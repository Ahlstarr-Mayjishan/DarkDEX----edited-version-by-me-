--!strict
--[[
	Interaction Menu Module
	Registers interaction actions: remote interception, prompt/click firing, animations and tweens.
]]
local Main, Lib, Apps, Settings
local function initDeps(data)
	Main, Lib, Apps, Settings = data.Main, data.Lib, data.Apps, data.Settings
end

local function initAfterMain()
end

local function main()
	return function(context, data)
		local selection = data.selection
		local Explorer = data.Explorer
		local env = data.env
		local ensureTool = data.ensureTool
		local remote_blocklist = data.remote_blocklist
		local plr = data.plr
		local RemoteUsageMap = data.RemoteUsageMap

		local ClassFire = {
			RemoteEvent = "FireServer",
			RemoteFunction = "InvokeServer",
			UnreliableRemoteEvent = "FireServer",

			BindableRemote = "Fire",
			BindableFunction = "Invoke",
		}

		context:Register("BLOCK_REMOTE",{Name = "Block From Firing", IconMap = Explorer.MiscIcons, Icon = "Delete", DisabledIcon = "Empty", OnClick = function()
			local sList = selection.List
			for i, list in sList do
				local obj = list.Obj
				if not remote_blocklist[obj] then
					local functionToHook = ClassFire[obj.ClassName]
					remote_blocklist[obj] = true
					local old; old = env.hookmetamethod((oldgame or game), "__namecall", function(self, ...)
						if remote_blocklist[obj] and self == obj and getnamecallmethod() == functionToHook then
							return nil
						end
						return old(self,...)
					end)
					if Settings.RemoteBlockWriteAttribute then
						obj:SetAttribute("IsBlocked", true)
					end
				end
			end
		end})

		context:Register("UNBLOCK_REMOTE",{Name = "Unblock", IconMap = Explorer.MiscIcons, Icon = "Play", DisabledIcon = "Empty", OnClick = function()
			local sList = selection.List
			for i, list in sList do
				local obj = list.Obj
				if remote_blocklist[obj] then
					remote_blocklist[obj] = nil
					if Settings.RemoteBlockWriteAttribute then
						list.Obj:SetAttribute("IsBlocked", false)
					end
				end
			end
		end})

		context:Register("VIEW_REMOTE_USAGE",{Name = "Remote Usage Map", IconMap = Explorer.MiscIcons, Icon = "ExploreData", DisabledIcon = "Empty", OnClick = function()
			local remote = selection.List[1] and selection.List[1].Obj
			if remote and ensureTool(RemoteUsageMap) then RemoteUsageMap.ShowForRemote(remote) end
		end})

		context:Register("FUZZ_REMOTE",{Name = "Fuzz Remote", IconMap = Explorer.MiscIcons, Icon = "CallRemote", DisabledIcon = "Empty", OnClick = function()
			local remote = selection.List[1] and selection.List[1].Obj
			if remote and Apps.RemoteFuzzer then Apps.RemoteFuzzer.Generate(remote) end
		end})

		context:Register("FIRE_CLICKDETECTOR",{Name = "Fire ClickDetector", OnClick = function()
			local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if not hrp then return end
			for _, v in ipairs(selection.List) do if v.Obj and v.Obj:IsA("ClickDetector") then fireclickdetector(v.Obj) end end
		end})

		context:Register("FIRE_PROXIMITYPROMPT",{Name = "Fire ProximityPrompt", OnClick = function()
			local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if not hrp then return end
			for _, v in ipairs(selection.List) do if v.Obj and v.Obj:IsA("ProximityPrompt") then fireproximityprompt(v.Obj) end end
		end})

		local OldAnimation = { Current = nil }
		context:Register("PLAY_TWEEN",{Name = "Play Tween", IconMap = Explorer.MiscIcons, Icon = "Play", OnClick = function()
			local sList = selection.List

			for i = 1, #sList do
				local node = sList[i]
				local Obj = node.Obj

				if Obj:IsA("Tween") then Obj:Play() end
			end
		end})

		context:Register("LOAD_ANIMATION",{Name = "Load Animation", IconMap = Explorer.MiscIcons, Icon = "Play", OnClick = function()
			local sList = selection.List

			local Humanoid = plr.Character and plr.Character:FindFirstChild("Humanoid")
			if not Humanoid then return end

			for i = 1, #sList do
				local node = sList[i]
				local Obj = node.Obj

				if Obj:IsA("Animation") then
					if OldAnimation.Current then OldAnimation.Current:Stop() end
					OldAnimation.Current = Humanoid:LoadAnimation(Obj)
					OldAnimation.Current:Play()
					break
				end
			end
		end})

		context:Register("STOP_ANIMATION",{Name = "Stop Animation", IconMap = Explorer.MiscIcons, Icon = "Pause", OnClick = function()
			local sList = selection.List

			local Humanoid = plr.Character and plr.Character:FindFirstChild("Humanoid")
			if not Humanoid then return end

			for i = 1, #sList do
				local node = sList[i]
				local Obj = node.Obj

				if Obj:IsA("Animation") then
					if OldAnimation.Current then OldAnimation.Current:Stop() end
					Humanoid:LoadAnimation(Obj):Stop()
					break
				end
			end
		end})
	end
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main
}
