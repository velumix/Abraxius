local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ConfigService = game:GetService("ConfigService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local AdminService = Knit.CreateService({
	Name = "AdminService",
	Client = {},
})

local REFRESH_INTERVAL = 60

local adminSet = {}
local lastFetch = 0

local function createLookupTable(list)
	adminSet = {}
	for _, id in list do
		adminSet[id] = true
	end

	ReplicatedStorage:SetAttribute("CMDR_Loaded", true)
end

local function refreshConfig()
	local ok, snapshot = pcall(function()
		return ConfigService:GetConfigAsync()
	end)

	if not ok or not snapshot then
		ReplicatedStorage:SetAttribute("CMDR_Loaded", true)
		return
	end

	local admins = snapshot:GetValue("admin_ids") or {}
	createLookupTable(admins)
	lastFetch = os.clock()
end

local function ensureFresh()
	if os.clock() - lastFetch > REFRESH_INTERVAL then
		refreshConfig()
	end
end

function AdminService:IsAdmin(player: Player): boolean
	local allowed = RunService:IsStudio() or adminSet[player.UserId] == true
	ensureFresh()
	return allowed
end

function AdminService.Client:IsAdmin(player: Player): boolean
	return self.Server:IsAdmin(player)
end

function AdminService:KnitInit()
	refreshConfig()
end

function AdminService:KnitStart()
	--
end

return AdminService
