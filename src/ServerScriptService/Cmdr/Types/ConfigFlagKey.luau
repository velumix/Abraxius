local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)

return function(registry)
	local Util = registry.Cmdr.Util

	local clientCachedKeys: { string } = {}

	-- Transform can't yield; warm cache in background
	if not RunService:IsServer() then
		task.spawn(function()
			local ok, keys = pcall(function()
				return Knit.GetService("ConfigParamService"):GetFlagKeys()
			end)
			if ok and typeof(keys) == "table" then
				clientCachedKeys = keys
			end
		end)
	end

	local function getKeys(): { string }
		if RunService:IsServer() then
			return Knit.GetService("ConfigParamService"):GetFlagKeys()
		else
			return clientCachedKeys
		end
	end

	registry:RegisterType("configFlagKey", {
		Transform = function(text)
			local findKey = Util.MakeFuzzyFinder(getKeys())
			return findKey(text)
		end,

		Validate = function(keys)
			return #keys > 0, "No config flag with that key found."
		end,

		Autocomplete = function(keys)
			return keys
		end,

		Parse = function(keys)
			return keys[1]
		end,
	})
end