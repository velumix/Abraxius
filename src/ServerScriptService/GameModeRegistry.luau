local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameModeConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameModeConfig"))

local GameModeRegistry = {}

local modes = {}
local loaded = false

local function load()
	if loaded then
		return
	end
	loaded = true
	local folder = ServerScriptService:WaitForChild("GameModes")
	local IGameMode = require(folder:WaitForChild("IGameMode"))
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("ModuleScript") and child.Name ~= "IGameMode" then
			local ok, mod = pcall(require, child)
			if not ok then
				warn("[GameModeRegistry] failed to require '" .. child.Name .. "': " .. tostring(mod))
			else
				local valid, err = IGameMode.validate(mod)
				if not valid then
					warn("[GameModeRegistry] '" .. child.Name .. "' is not a valid game mode: " .. tostring(err))
				elseif modes[mod.id] then
					warn("[GameModeRegistry] duplicate mode id '" .. mod.id .. "' from '" .. child.Name .. "'")
				else
					modes[mod.id] = mod
				end
			end
		end
	end
end

function GameModeRegistry.get(id)
	load()
	return modes[id]
end

function GameModeRegistry.exists(id)
	load()
	return modes[id] ~= nil
end

function GameModeRegistry.getDefaultId()
	local def = GameModeConfig.getDefault()
	return def and def.id or nil
end

function GameModeRegistry.getVotableIds()
	load()
	local out = {}
	for _, cfg in ipairs(GameModeConfig.getVotable()) do
		if modes[cfg.id] then
			table.insert(out, cfg.id)
		end
	end
	return out
end

return GameModeRegistry
