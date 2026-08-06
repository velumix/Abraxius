local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = script:FindFirstChild("Shared")
	or ReplicatedStorage:WaitForChild("CmdrClient"):WaitForChild("Shared")
local Util = require(shared:WaitForChild("Util"))

if RunService:IsServer() == false then
	error("Cmdr server module is somehow running on a client!")
end

local Cmdr do
	Cmdr = setmetatable({
		ReplicatedRoot = nil;
		RemoteFunction = nil;
		RemoteEvent = nil;
		Util = Util;
		DefaultCommandsFolder = script:FindFirstChild("BuiltInCommands") or script:FindFirstChild("Server commands");
	}, {
		__index = function (self, k)
			local r = self.Registry[k]
			if r and type(r) == "function" then
				return function (_, ...)
					return r(self.Registry, ...)
				end
			end
		end
	})

	Cmdr.Registry = require(shared.Registry)(Cmdr)
	Cmdr.Dispatcher = require(shared.Dispatcher)(Cmdr)

	local initSuccess, initErr = pcall(function()
		require(script.Initialize)(Cmdr)
	end)
	if not initSuccess then
		error("Cmdr Initialize failed: " .. tostring(initErr))
	end
end

-- Handle command invocations from the clients.
Cmdr.RemoteFunction.OnServerInvoke = function (player, text, options)
	if #text > 100_000 then
		return "Input too long"
	end

	return Cmdr.Dispatcher:EvaluateAndRun(text, player, options)
end

return Cmdr
