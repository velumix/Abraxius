local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage.Runtime.Config.Shared.Sounds)

local SFX = SoundConfig.Ids.UI
local DEFAULT_VOLUME = SoundConfig.Defaults.UIVolume
local SoundCache = {}

local function getSFXGroup()
	local masterGroup = SoundService:FindFirstChild("Master")
	if not masterGroup then
		return nil
	end

	local sfxGroup = masterGroup:FindFirstChild("SFX")
	if sfxGroup and sfxGroup:IsA("SoundGroup") then
		return sfxGroup
	end

	return nil
end

local function getSound(kind, soundId)
	local sound = SoundCache[kind]

	if sound then
		if sound.Parent ~= SoundService then
			sound.Parent = SoundService
		end
		if sound.SoundId ~= soundId then
			sound.SoundId = soundId
		end
	else
		sound = Instance.new("Sound")
		sound.Name = "UISound_" .. kind
		sound.Archivable = false
		sound.Volume = DEFAULT_VOLUME
		sound.SoundId = soundId
		sound.Parent = SoundService
		SoundCache[kind] = sound
	end

	sound.SoundGroup = getSFXGroup()
	sound.Volume = DEFAULT_VOLUME

	return sound
end

local UIAudio = {}

function UIAudio.PlayNotification(kind)
	local cacheKey = kind or "Info"
	local id = SFX[cacheKey] or SFX.Info
	local sound = getSound(cacheKey, id)

	if sound.IsPlaying then
		sound:Stop()
	end

	sound.TimePosition = 0
	sound:Play()
end

return UIAudio
