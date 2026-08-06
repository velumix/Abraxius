local SoundService = game:GetService("SoundService")

local SOUND_ID = "rbxassetid://104000340117740"

local AdminAnnounceSound = {}

function AdminAnnounceSound.Play()
	local sound = Instance.new("Sound")
	sound.Name = "AdminAnnounceSound"
	sound.SoundId = SOUND_ID
	sound.Volume = 1

	local sfxGroup = SoundService:FindFirstChild("SFX")
	if sfxGroup then
		sound.SoundGroup = sfxGroup
	end

	sound.Parent = SoundService
	sound:Play()

	task.delay((sound.TimeLength > 0 and sound.TimeLength or 5) + 0.5, function()
		if sound and sound.Parent then
			sound:Destroy()
		end
	end)
end

return AdminAnnounceSound
