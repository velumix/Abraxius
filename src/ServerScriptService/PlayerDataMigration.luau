local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local Sift = require(ReplicatedStorage.Packages.Sift)
local ProfileTemplate = require(ServerScriptService.Modules.ProfileTemplate)
local LegacyImport = require(ServerScriptService.Modules.LegacyImport)

local NEW_STORE_NAME = "PlayerData_PS"

local function profileKey(userId)
	return tostring(userId)
end

local PlayerDataStore = ProfileStore.New(NEW_STORE_NAME, ProfileTemplate)

local Migration = {}

Migration.NewStoreName = NEW_STORE_NAME
Migration.Template = ProfileTemplate

function Migration.MigrateUserId(userId, force)
	if type(userId) ~= "number" then
		return false, "userId must be a number"
	end
	
	local profile = PlayerDataStore:StartSessionAsync(profileKey(userId), {})
	if profile == nil then
		return false, "Could not start ProfileStore session (store closing or key locked)"
	end
	
	profile:AddUserId(userId)
	profile:Reconcile()
	
	local data = profile.Data
	
	if data.Migration.FromLegacy == true and force ~= true then
		local snapshot = Sift.Dictionary.copyDeep(data)
		profile:EndSession()
		return true, `Already migrated at {data.Migration.At}; left untouched`, snapshot
	end
	
	local sources = LegacyImport.Apply(userId, data)
	
	data.SchemaVersion = ProfileTemplate.SchemaVersion
	data.Migration.FromLegacy = true
	data.Migration.At = os.time()
	data.Migration.Sources = sources
	
	local snapshot = Sift.Dictionary.copyDeep(data)
	profile:EndSession()
	return true, "Migrated", snapshot
end

function Migration.MigratePlayer(player, force)
	return Migration.MigrateUserId(player.UserId, force)
end

function Migration.Inspect(userId)
	local profile = PlayerDataStore:GetAsync(profileKey(userId))
	return profile and profile.Data or nil
end

return Migration
