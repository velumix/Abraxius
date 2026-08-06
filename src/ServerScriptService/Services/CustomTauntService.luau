local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))

local CustomTauntService = Knit.CreateService({
	Name = "CustomTauntService",
	Client = {
		OwnershipChanged = Knit.CreateSignal(),
		SoundIdChanged = Knit.CreateSignal(),
	},
})

local GAMEPASS_ID = Constants.Gamepasses.CUSTOM_TAUNT

local ownershipCache = {}
local dataSvc

local function dataService()
	if not dataSvc then
		dataSvc = Knit.GetService("DataService")
	end
	return dataSvc
end

function CustomTauntService:_checkOwnership(player: Player): boolean
	local cached = ownershipCache[player]
	if cached == true then
		return true
	end

	-- In Studio (team test / local play), skip the gamepass check so devs can test the feature.
	if RunService:IsStudio() then
		ownershipCache[player] = true
		self.Client.OwnershipChanged:Fire(player, true)
		return true
	end

	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_ID)
	end)

	if not ok then
		warn("[CustomTauntService] ownership check failed for " .. player.Name .. ": " .. tostring(owns))
	end

	local result = ok and owns == true
	if result then
		ownershipCache[player] = true
	end
	self.Client.OwnershipChanged:Fire(player, result)
	return result
end

function CustomTauntService:IsOwner(player: Player): boolean
	return self:_checkOwnership(player)
end

function CustomTauntService:GetSoundId(player: Player): string
	local svc = dataService()
	return svc and svc:GetCustomTauntSoundId(player) or ""
end

local MAX_TAUNT_SECONDS = 10

local function loadSoundDuration(assetId: number): (boolean, number?, string?)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. assetId
	sound.Volume = 0
	sound.Parent = SoundService

	local loaded = false
	local conn = sound.Loaded:Connect(function()
		loaded = true
	end)

	local start = os.clock()
	while not loaded and sound.TimeLength <= 0 and (os.clock() - start) < 5 do
		task.wait(0.05)
	end

	conn:Disconnect()
	local duration = sound.TimeLength
	sound:Destroy()

	if duration <= 0 then
		return false, nil, "Could not load sound duration."
	end
	return true, duration
end

local function validateSound(soundId: string): (boolean, string?)
	local numId = tonumber(soundId)
	if not numId then
		return false, "Sound ID must be a number."
	end

	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(numId, Enum.InfoType.Asset)
	end)

	if not ok or typeof(info) ~= "table" then
		return false, "Could not get sound info."
	end

	local assetTypeId = info.AssetTypeId
	if assetTypeId ~= Enum.AssetType.Audio.Value then
		return false, "That asset is not an audio file."
	end

	local durationOk, duration, err = loadSoundDuration(numId)
	if not durationOk then
		return false, err or "Failed to load sound."
	end

	if duration > MAX_TAUNT_SECONDS then
		return false, string.format("Sound is %.1f seconds. Max allowed is %d seconds.", duration, MAX_TAUNT_SECONDS)
	end

	return true
end

function CustomTauntService:SetSoundId(player: Player, soundId: string): (boolean, string)
	if not self:_checkOwnership(player) then
		return false, "GAMEPASS_REQUIRED"
	end

	soundId = tostring(soundId or "")
	-- strip rbxassetid:// prefix and whitespace
	soundId = soundId:gsub("rbxassetid://", ""):gsub("%s", "")

	if soundId == "" then
		-- clearing is allowed
	else
		local valid, err = validateSound(soundId)
		if not valid then
			return false, err or "Invalid sound."
		end
	end

	local svc = dataService()
	if not svc then
		return false, "Data service not available."
	end

	svc:SetCustomTauntSoundId(player, soundId)
	self.Client.SoundIdChanged:Fire(player, soundId)

	if soundId == "" then
		return true, "Custom taunt cleared."
	end
	return true, "Custom taunt saved."
end

function CustomTauntService.Client:GetStatus(player: Player)
	local svc = self.Server
	return {
		owner = svc:IsOwner(player),
		soundId = svc:GetSoundId(player),
		seenTauntInfo = dataService():GetFlag(player, "SeenTauntInfo") == true,
	}
end

function CustomTauntService.Client:HasSeenTauntInfo(player: Player): boolean
	return dataService():GetFlag(player, "SeenTauntInfo") == true
end

function CustomTauntService.Client:MarkTauntInfoSeen(player: Player)
	dataService():SetFlag(player, "SeenTauntInfo", true)
end

function CustomTauntService.Client:SetSoundId(player: Player, soundId: string)
	return self.Server:SetSoundId(player, soundId)
end

Players.PlayerRemoving:Connect(function(player)
	ownershipCache[player] = nil
end)

return CustomTauntService
