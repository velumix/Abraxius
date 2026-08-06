local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local prodGameId = 9977954973
local devGameId = 10383935394

local gameId = game.GameId
local placeId = game.PlaceId

-- [gameId][placeId]
local envs = {
	[prodGameId] = { -- Prod
		Main = 78724049937437,
		MapBuilder = 135214010254000,
	},
	[devGameId] = { -- Dev
		Main = 71032741659698,
		MapBuilder = 89269612631048,
	},
}

local GetEnv = {}

function GetEnv:GetEnvConfig()
	return envs[gameId]
end

function GetEnv:GetPlaceIdByName(name: string): number
	if not envs[gameId] then
		warn("Could not locate env config for gameId:", gameId)
		return
	end

	return envs[gameId][name]
end

function GetEnv:isMain()
	if not envs[gameId] then
		warn("Could not locate env config for gameId:", gameId)
		return
	end
	
	return envs[gameId].Main == placeId
end

function GetEnv:isMapBuilder()
	if not envs[gameId] then
		warn("Could not locate env config for gameId:", gameId)
		return
	end
	
	return envs[gameId].MapBuilder == placeId
end

function GetEnv:isProdEnv()
	return gameId == prodGameId
end

function GetEnv:isDevEnv()
	return gameId == devGameId
end

function GetEnv:IsPrivateServer()
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0
end

return GetEnv