local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Cmdr = require(ServerScriptService.ServerPackages.Cmdr) :: any
local Knit = require(ReplicatedStorage.Packages.Knit)

local cmdrFolder = ServerScriptService.Cmdr
local commands = cmdrFolder.Commands
local types = cmdrFolder.Types
local hooks = cmdrFolder.Hooks

local CmdrService = Knit.CreateService({
	Name = "CmdrService",
	Client = {},
})

function CmdrService:KnitInit()
	local function tryRegister(label, fn)
		local ok, err = pcall(fn)
		if not ok then
			warn(`[CmdrService] {label} registration issue (continuing): {err}`)
		end
	end

	-- Register each group in its own pcall, and types BEFORE commands, so one bad
	-- command module (e.g. a work-in-progress) can't abort type or command registration.
	tryRegister("default commands", function()
		-- Exclude Cmdr's built-in "announce" so our own announce command (with the
		-- server/global scope + ADMIN toast) is the only one registered.
		Cmdr:RegisterDefaultCommands(function(command)
			return command.Name ~= "announce"
		end)
	end)
	tryRegister("types", function()
		Cmdr:RegisterTypesIn(types)
	end)
	tryRegister("commands", function()
		Cmdr:RegisterCommandsIn(commands)
	end)
	tryRegister("hooks", function()
		Cmdr:RegisterHooksIn(hooks)
	end)
end

function CmdrService:KnitStart()
	--
end

return CmdrService
