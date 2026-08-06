local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Modules = ReplicatedStorage.Modules

local Mince = require(Modules.Mince)
local Component = Mince.Component

local AreaSoundConfig = require(ReplicatedStorage.Runtime.Config.Shared.Sounds).Areas

local AreaController = {
	Name = "AreaController",
	Connections = {},
	Components = {},
	CurrentSettings = {},

	MusicPlaylist = {},
	AmbiancePlaylist = {},
	CurrentMusicIndex = 1,
	CurrentAmbianceIndex = 1,
	MusicTrackConnection = nil,
	AmbianceTrackConnection = nil,

	CurrentMusic = nil,
	CurrentAmbiance = nil,

	RoomMusicStates = {},
	RoomAmbianceStates = {},
	TimeoutDuration = 8,
	ActiveFades = {},
	LastAreaChange = 0,
	AreaChangeDebounce = 0.2,
	CurrentRoom = nil,
	CurrentAudibleMusic = nil,
}

local Area = Component({ Tag = "Area" })

function Area:Construct()
	self.Part = self.Instance
	self.Instance.Transparency = 1
	AreaController.Components[self.Instance] = self
end

function AreaController:LoadAreaSettings(areaName)
	local areaData = AreaSoundConfig[areaName]
	if not areaData then
		return AreaSoundConfig.DefaultSettings
	end

	local settings = table.clone(AreaSoundConfig.DefaultSettings)

	if areaData.Settings then
		for key, value in pairs(areaData.Settings) do
			settings[key] = value
		end
	end

	return settings
end

function AreaController:ShuffleTracks(tracks)
	local trackList = {}

	for _, track in pairs(tracks) do
		table.insert(trackList, track)
	end

	for i = #trackList, 2, -1 do
		local j = math.random(i)
		trackList[i], trackList[j] = trackList[j], trackList[i]
	end

	return trackList
end

function AreaController:DetectCurrentArea()
	if not self.Character or not self.Character:FindFirstChild("HumanoidRootPart") then
		return nil
	end

	local playerPosition = self.Character:GetPivot().Position

	for instance in pairs(self.Components) do
		if instance and instance.Parent then
			local part = instance
			local min = part.Position - part.Size / 2
			local max = part.Position + part.Size / 2

			if
				playerPosition.X >= min.X
				and playerPosition.X <= max.X
				and playerPosition.Y >= min.Y
				and playerPosition.Y <= max.Y
				and playerPosition.Z >= min.Z
				and playerPosition.Z <= max.Z
			then
				return part.Name
			end
		end
	end

	return nil
end

function AreaController:GetAreaInstance(areaName)
	for instance, _ in pairs(self.Components) do
		if instance and instance.Parent and instance.Name == areaName then
			return instance
		end
	end
	return nil
end

function AreaController:StartAreaMonitoring()
	if not self.AreaMonitoringEnabled then
		return
	end

	task.spawn(function()
		while self.AreaMonitoringEnabled and self.Character do
			task.wait(0.1)

			if self.Character and self.Character:FindFirstChild("HumanoidRootPart") then
				local currentArea = Player:GetAttribute("Area")
				local detectedArea = self:DetectCurrentArea()

				if currentArea ~= detectedArea then
					local now = tick()
					if now - self.LastAreaChange >= self.AreaChangeDebounce then
						self.LastAreaChange = now
						self:HandleAreaChange(detectedArea)
					end
				end
			end
		end
	end)
end

function AreaController:HandleAreaChange(detectedArea)
	Player:SetAttribute("Area", detectedArea)
	_G.UI.AnnounceArea(detectedArea, nil, 3)

	local previousRoom = self.CurrentRoom
	self.CurrentRoom = detectedArea

	if self.CurrentAudibleMusic and previousRoom ~= detectedArea then
		self:MuteRoomMusic(self.CurrentAudibleMusic, 1)
	end

	if detectedArea then
		local instance = self:GetAreaInstance(detectedArea)
		if instance then
			local Music = instance:GetAttribute("Music")

			if Music and self.SoundTracks[Music] then
				local roomState = self:GetOrCreateRoomMusicState(Music)

				if roomState.IsMuted then
					self:UnmuteRoomMusic(Music, 1)
					self.CurrentAudibleMusic = Music
				elseif not roomState.IsPlaying then
					local musicSettings = self:LoadAreaSettings(Music)
					local musicTracks = self.SoundTracks[Music]

					if musicSettings.PlayOrder == "Shuffle" then
						musicTracks = self:ShuffleTracks(musicTracks)
					end

					roomState.Playlist = musicTracks
					roomState.CurrentIndex = 1
					roomState.Settings = musicSettings
					roomState.IsPlaying = true
					roomState.IsMuted = false

					local currentTrack = roomState.Playlist[roomState.CurrentIndex]
					if currentTrack then
						currentTrack.Volume = 0
						currentTrack:Play()
						self:FadeIn(currentTrack, 1.2, musicSettings.Volume or 0.5)

						if roomState.TrackConnection then
							roomState.TrackConnection:Disconnect()
						end

						roomState.TrackConnection = currentTrack.Ended:Connect(function()
							self:NextRoomMusicTrack(Music)
						end)
					end
					self.CurrentAudibleMusic = Music
				elseif not roomState.IsMuted then
					self.CurrentAudibleMusic = Music
				end
			else
				self.CurrentAudibleMusic = nil
			end
		end
	else
		self.CurrentAudibleMusic = nil
	end
end

function AreaController:StopAreaMonitoring()
	self.AreaMonitoringEnabled = false
end

function AreaController:CleanupConnections()
	for _, connection in pairs(self.Connections) do
		if connection then
			connection:Disconnect()
		end
	end
	self.Connections = {}
end

function AreaController:CancelTimeout(timeoutTable, areaName)
	if timeoutTable[areaName] then
		if timeoutTable[areaName].Timer then
			task.cancel(timeoutTable[areaName].Timer)
		end
		timeoutTable[areaName] = nil
	end
end

function AreaController:GetOrCreateRoomMusicState(roomName)
	if not self.RoomMusicStates[roomName] then
		self.RoomMusicStates[roomName] = {
			Playlist = {},
			CurrentIndex = 1,
			IsPlaying = false,
			IsMuted = false,
			TrackConnection = nil,
			Settings = nil,
		}
	end
	return self.RoomMusicStates[roomName]
end

function AreaController:MuteRoomMusic(roomName, fadeTime)
	local roomState = self.RoomMusicStates[roomName]
	if roomState then
		if roomState.IsPlaying and not roomState.IsMuted then
			local currentTrack = roomState.Playlist[roomState.CurrentIndex]
			if currentTrack and currentTrack.Playing then
				self:FadeOut(currentTrack, fadeTime or 1, false)
				roomState.IsMuted = true

				local timer = task.delay(self.TimeoutDuration, function()
					if roomState.IsMuted then
						currentTrack:Stop()
						roomState.IsPlaying = false
						roomState.IsMuted = false
					end
				end)
				roomState.TimeoutTimer = timer
			end
		end
	end
end

function AreaController:UnmuteRoomMusic(roomName, fadeTime)
	local roomState = self.RoomMusicStates[roomName]
	if roomState and roomState.IsMuted then
		if roomState.TimeoutTimer then
			task.cancel(roomState.TimeoutTimer)
			roomState.TimeoutTimer = nil
		end

		local currentTrack = roomState.Playlist[roomState.CurrentIndex]
		if currentTrack and currentTrack.Playing then
			local targetVolume = roomState.Settings and roomState.Settings.Volume or 0.5
			self:FadeIn(currentTrack, fadeTime or 1, targetVolume)
			roomState.IsMuted = false
		end
	end
end

function AreaController:StartMusicTimeout(areaName, track, settings)
	self:CancelTimeout(self.MusicTimeouts, areaName)

	local timer = task.delay(self.TimeoutDuration, function()
		if track and track.Playing then
			track:Stop()
		end
		self.MusicTimeouts[areaName] = nil
	end)

	self.MusicTimeouts[areaName] = {
		Timer = timer,
		Track = track,
		Settings = settings,
	}
end

function AreaController:StartAmbianceTimeout(areaName, track, settings)
	self:CancelTimeout(self.AmbianceTimeouts, areaName)

	local timer = task.delay(self.TimeoutDuration, function()
		if track and track.Playing then
			track:Stop()
		end
		self.AmbianceTimeouts[areaName] = nil
	end)

	self.AmbianceTimeouts[areaName] = {
		Timer = timer,
		Track = track,
		Settings = settings,
	}
end

function AreaController:CancelActiveFade(sound)
	if self.ActiveFades[sound] then
		self.ActiveFades[sound]:Cancel()
		self.ActiveFades[sound] = nil
	end
end

function AreaController:FadeOut(sound, fadeTime, stopAfter)
	fadeTime = fadeTime or 1.5
	local originalVolume = sound.Volume

	self:CancelActiveFade(sound)

	if not sound.Playing or sound.Volume <= 0 then
		if stopAfter then
			sound:Stop()
		end
		return
	end

	local fadeInfo = TweenInfo.new(fadeTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	local tween = TweenService:Create(sound, fadeInfo, { Volume = 0 })
	self.ActiveFades[sound] = tween

	tween:Play()

	tween.Completed:Connect(function()
		self.ActiveFades[sound] = nil
		if stopAfter then
			sound:Stop()
			sound.Volume = originalVolume
		end
	end)

	return tween
end

function AreaController:FadeIn(sound, fadeTime, targetVolume)
	fadeTime = fadeTime or 1.5
	targetVolume = targetVolume or 0.5

	self:CancelActiveFade(sound)

	local effectiveTargetVolume = targetVolume

	if not sound.Playing then
		sound.Volume = 0
		sound:Play()
	elseif sound.Volume >= effectiveTargetVolume then
		return
	end

	local fadeInfo = TweenInfo.new(fadeTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	local tween = TweenService:Create(sound, fadeInfo, { Volume = effectiveTargetVolume })
	self.ActiveFades[sound] = tween

	tween:Play()

	tween.Completed:Connect(function()
		self.ActiveFades[sound] = nil
	end)

	return tween
end

function AreaController:CrossfadeToTrack(newSound, fadeTime, targetVolume)
	fadeTime = fadeTime or 1
	targetVolume = targetVolume or 0.5

	if self.MusicPlaylist and self.MusicPlaylist[self.CurrentMusicIndex] then
		local currentTrack = self.MusicPlaylist[self.CurrentMusicIndex]
		if currentTrack and currentTrack.Playing and currentTrack ~= newSound then
			self:FadeOut(currentTrack, fadeTime, true)
		end
	end

	return self:FadeIn(newSound, fadeTime, targetVolume)
end

function AreaController:NextRoomMusicTrack(roomName)
	local roomState = self.RoomMusicStates[roomName]
	if not roomState or not roomState.IsPlaying then
		return
	end

	roomState.CurrentIndex = roomState.CurrentIndex + 1
	if roomState.CurrentIndex > #roomState.Playlist then
		if roomState.Settings.Loop ~= false then
			roomState.CurrentIndex = 1
		else
			roomState.IsPlaying = false
			return
		end
	end

	local currentTrack = roomState.Playlist[roomState.CurrentIndex]
	if currentTrack then
		currentTrack.Volume = 0
		currentTrack:Play()

		local targetVolume = roomState.IsMuted and 0 or (roomState.Settings.Volume or 0.5)
		if not roomState.IsMuted then
			self:FadeIn(currentTrack, 1.2, targetVolume)
		end

		if roomState.TrackConnection then
			roomState.TrackConnection:Disconnect()
		end

		roomState.TrackConnection = currentTrack.Ended:Connect(function()
			self:NextRoomMusicTrack(roomName)
		end)
	end
end

function AreaController:ClearMusicPlaylist(fadeOut)
	if self.MusicPlaylist and fadeOut then
		local currentTrack = self.MusicPlaylist[self.CurrentMusicIndex]
		if currentTrack and currentTrack.Playing then
			self:FadeOut(currentTrack, 1, true)
		end
	elseif self.MusicPlaylist then
		for _, Sound in self.MusicPlaylist do
			Sound:Stop()
		end
	end

	if self.MusicTrackConnection then
		self.MusicTrackConnection:Disconnect()
		self.MusicTrackConnection = nil
	end

	self.MusicPlaylist = {}
	self.CurrentMusicIndex = 1
	self.CurrentMusic = nil
end

function AreaController:ClearAmbiancePlaylist(fadeOut)
	if self.AmbiancePlaylist and fadeOut then
		local currentTrack = self.AmbiancePlaylist[self.CurrentAmbianceIndex]
		if currentTrack and currentTrack.Playing then
			self:FadeOut(currentTrack, 1, true)
		end
	elseif self.AmbiancePlaylist then
		for _, Sound in self.AmbiancePlaylist do
			Sound:Stop()
		end
	end

	if self.AmbianceTrackConnection then
		self.AmbianceTrackConnection:Disconnect()
		self.AmbianceTrackConnection = nil
	end

	self.AmbiancePlaylist = {}
	self.CurrentAmbianceIndex = 1
	self.CurrentAmbiance = nil
end

function AreaController:ClearPlaylist(fadeOut)
	self:ClearMusicPlaylist(fadeOut)
	self:ClearAmbiancePlaylist(fadeOut)
end

function AreaController:StartMusicPlaylist(Sounds, settings)
	self.MusicPlaylist = Sounds
	self.CurrentMusicIndex = 1

	if #Sounds > 0 then
		self:PlayCurrentMusicTrack(settings)
	end
end

function AreaController:StartAmbiancePlaylist(Sounds, settings)
	self.AmbiancePlaylist = Sounds
	self.CurrentAmbianceIndex = 1

	if #Sounds > 0 then
		self:PlayCurrentAmbianceTrack(settings)
	end
end

function AreaController:PlayCurrentMusicTrack(settings)
	if self.MusicPlaylist and self.MusicPlaylist[self.CurrentMusicIndex] then
		local currentTrack = self.MusicPlaylist[self.CurrentMusicIndex]

		currentTrack.Volume = 0
		currentTrack:Play()
		self:FadeIn(currentTrack, 1.2, settings.Volume or 0.5)

		if self.MusicTrackConnection then
			self.MusicTrackConnection:Disconnect()
		end

		self.MusicTrackConnection = currentTrack.Ended:Connect(function()
			self:NextMusicTrack(settings)
		end)
	end
end

function AreaController:PlayCurrentAmbianceTrack(settings)
	if self.AmbiancePlaylist and self.AmbiancePlaylist[self.CurrentAmbianceIndex] then
		local currentTrack = self.AmbiancePlaylist[self.CurrentAmbianceIndex]

		currentTrack.Volume = 0
		currentTrack:Play()
		self:FadeIn(currentTrack, 1.2, settings.Volume or 0.3)

		if self.AmbianceTrackConnection then
			self.AmbianceTrackConnection:Disconnect()
		end

		self.AmbianceTrackConnection = currentTrack.Ended:Connect(function()
			self:NextAmbianceTrack(settings)
		end)
	end
end

function AreaController:NextMusicTrack(settings)
	if not self.MusicPlaylist or #self.MusicPlaylist == 0 then
		return
	end

	local currentTrack = self.MusicPlaylist[self.CurrentMusicIndex]
	if currentTrack and currentTrack.Playing then
		self:FadeOut(currentTrack, settings.CrossfadeTime or 1, true)
	end

	self.CurrentMusicIndex = self.CurrentMusicIndex + 1
	if self.CurrentMusicIndex > #self.MusicPlaylist then
		if settings.Loop ~= false then
			self.CurrentMusicIndex = 1
		else
			return
		end
	end

	self:PlayCurrentMusicTrack(settings)
end

function AreaController:NextAmbianceTrack(settings)
	if not self.AmbiancePlaylist or #self.AmbiancePlaylist == 0 then
		return
	end

	local currentTrack = self.AmbiancePlaylist[self.CurrentAmbianceIndex]
	if currentTrack and currentTrack.Playing then
		self:FadeOut(currentTrack, settings.CrossfadeTime or 1, true)
	end

	self.CurrentAmbianceIndex = self.CurrentAmbianceIndex + 1
	if self.CurrentAmbianceIndex > #self.AmbiancePlaylist then
		if settings.Loop ~= false then
			self.CurrentAmbianceIndex = 1
		else
			return
		end
	end

	self:PlayCurrentAmbianceTrack(settings)
end

function AreaController:Start()
	self.SoundTracks = {}

	self.MusicPlaylist = {}
	self.AmbiancePlaylist = {}
	self.CurrentMusicIndex = 1
	self.CurrentAmbianceIndex = 1
	self.MusicTrackConnection = nil
	self.AmbianceTrackConnection = nil

	self.CurrentMusic = nil
	self.CurrentAmbiance = nil

	self.RoomMusicStates = {}
	self.RoomAmbianceStates = {}
	self.ActiveFades = {}
	self.LastAreaChange = 0
	self.CurrentRoom = nil
	self.CurrentAudibleMusic = nil

	self.CurrentSettings = AreaSoundConfig.DefaultSettings

	self.AreaMonitoringEnabled = true

	for Name, AreaData in AreaSoundConfig do
		if Name ~= "DefaultSettings" and AreaData.Tracks then
			self.SoundTracks[Name] = {}

			local settings = self:LoadAreaSettings(Name)

			for Order, SoundId in AreaData.Tracks do
				local Sound = Instance.new("Sound")
				Sound.SoundId = SoundId
				Sound.Volume = 0
				Sound.Name = Name .. "_Track" .. Order
				Sound.Parent = SoundService

				local masterGroup = SoundService:FindFirstChild("Master")
				if masterGroup then
					local musicGroup = masterGroup:FindFirstChild("Music")
					if musicGroup and musicGroup:IsA("SoundGroup") then
						Sound.SoundGroup = musicGroup
					end
				end
				self.SoundTracks[Name][Order] = Sound

				if not Sound.IsLoaded then
					Sound.Loaded:Wait()
				end
			end
		end
	end

	self.Character = Player.Character
	if not self.Character then
		self.Character = Player.CharacterAdded:Wait()
	end

	self.Connections.CharacterAdded = Player.CharacterAdded:Connect(function(character)
		self.Character = character

		task.spawn(function()
			repeat
				task.wait()
			until self.Character and self.Character:FindFirstChild("HumanoidRootPart")

			local detectedArea = self:DetectCurrentArea()
			if not Player:GetAttribute("Swimming") then
				self:HandleAreaChange(detectedArea)
			end
		end)
	end)

	self.Connections.SwimmingChanged = Player:GetAttributeChangedSignal("Swimming"):Connect(function()
		local isSwimming = Player:GetAttribute("Swimming")

		if isSwimming then
			self:ClearPlaylist(true)
		else
			local detectedArea = self:DetectCurrentArea()
			self:HandleAreaChange(detectedArea)
		end
	end)
end

function AreaController:GameStart()
	task.spawn(function()
		self:Start()

		while true do
			local allLoaded = true
			for _, soundList in pairs(self.SoundTracks) do
				for _, sound in pairs(soundList) do
					if not sound.IsLoaded then
						allLoaded = false
						break
					end
				end
				if not allLoaded then
					break
				end
			end

			if allLoaded then
				local detectedArea = self:DetectCurrentArea()
				if not Player:GetAttribute("Swimming") then
					self:HandleAreaChange(detectedArea)
				end

				self:StartAreaMonitoring()
				break
			else
				task.wait()
			end
		end
	end)
end

return AreaController
