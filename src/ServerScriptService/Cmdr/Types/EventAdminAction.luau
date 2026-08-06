--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local CmdrEventScope = require(ReplicatedStorage.Util.CmdrEventScope)

return function(cmdr)
	local IS_SERVER = RunService:IsServer()

	local manifest: { [string]: { [string]: string } } = {}
	local manifestReady = false

	local function fetch(): boolean
		local ok, result = pcall(function()
			local svc = Knit.GetService("EventService") :: any
			return svc:GetEventAdminSignals()
		end)
		if ok and typeof(result) == "table" then
			manifest = result
			manifestReady = true
			return true
		end
		return false
	end

	if not IS_SERVER then
		task.spawn(function()
			while not manifestReady do
				if fetch() then break end
				task.wait(2)
			end
		end)
	end

	local function scopedActions(): { string }
		local scope = CmdrEventScope.lastEvent
		local out: { string } = {}
		if scope then
			local actions = manifest[scope]
			if typeof(actions) == "table" then
				for action in actions do
					table.insert(out, action)
				end
			end
		else
			local seen: { [string]: boolean } = {}
			for _, actions in manifest do
				if typeof(actions) ~= "table" then continue end
				for action in actions do
					if not seen[action] then
						seen[action] = true
						table.insert(out, action)
					end
				end
			end
		end
		table.sort(out)
		return out
	end

	local typeDef = {
		Transform = function(text)
			if IS_SERVER then return { text } end
			local lower = text:lower()
			local matches = {}
			for _, action in scopedActions() do
				if action:lower():sub(1, #lower) == lower then
					table.insert(matches, action)
				end
			end
			return matches
		end,
		Validate = function(matches)
			return #matches >= 1, "No admin action matches that name."
		end,
		Autocomplete = function(matches)
			return matches
		end,
		Parse = function(matches)
			return matches[1]
		end,
	}

	cmdr:RegisterType("eventAdminAction", typeDef)
end
