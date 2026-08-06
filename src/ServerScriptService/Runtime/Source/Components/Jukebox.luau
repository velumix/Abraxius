local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Mince = require(ReplicatedStorage.Modules.Mince)
local SoundHandler = Mince:Get("SoundHandler")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local SoundsFolder = Assets:FindFirstChild("Sounds")
local JukeboxLibrary = SoundsFolder and SoundsFolder:FindFirstChild("Jukebox")

local DEFAULT_VOLUME = 0.5
local DEFAULT_CROSSFADE = 1.5
local DEFAULT_MIN_DISTANCE = 15
local DEFAULT_MAX_DISTANCE = 150
local MAX_INTERACTION_DISTANCE = 35

local JukeboxRegistry = setmetatable({}, {__mode = "k"})

local JukeboxEvent = Mince:GetEvent("Jukebox")
local SetGenreEvent = JukeboxEvent:Extend("SetGenre")
local TogglePlaybackEvent = JukeboxEvent:Extend("TogglePlayback")
local SetShuffleEvent = JukeboxEvent:Extend("SetShuffle")
local NextTrackEvent = JukeboxEvent:Extend("NextTrack")
local RequestTracksEvent = JukeboxEvent:Extend("RequestTracks")
local PlayTrackEvent = JukeboxEvent:Extend("PlayTrack")

local Jukebox = Mince.Component {
	Tag = "Jukebox",
}

local function isSound(instance)
	return typeof(instance) == "Instance" and instance:IsA("Sound")
end

local function isGenreFolder(instance)
	return typeof(instance) == "Instance" and instance:IsA("Folder")
end

local function getProxyPart(instance)
	if not instance then
		return nil
	end

	if instance:IsA("BasePart") and instance.Name and instance.Name:lower() == "proxy" then
		return instance
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name and descendant.Name:lower() == "proxy" then
			return descendant
		end
	end

	return nil
end

local function getSpeakerParts(instance)
	local parts = {}
	if not instance then
		return parts
	end

	local function add(part)
		if part:IsA("BasePart") and part.Name and part.Name:lower() == "speaker" then
			table.insert(parts, part)
		end
	end

	if instance:IsA("BasePart") then
		add(instance)
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			add(descendant)
		end
	end

	return parts
end

local function getTrackNames(folder)
	if not folder then
		return {}
	end

	local names = {}
	for _, child in ipairs(folder:GetChildren()) do
		if isSound(child) then
			table.insert(names, child.Name)
		end
	end
	table.sort(names)
	return names
end

function Jukebox:GetWorldPosition()
	local proxy = self.ProxyPart
	if not proxy or not proxy.Parent then
		proxy = getProxyPart(self.Instance)
		self.ProxyPart = proxy
	end
	if proxy then
		return proxy.Position
	end

	local emitter = self.PrimaryEmitter
	if emitter and emitter:IsA("BasePart") then
		return emitter.Position
	end

	if self.Instance:IsA("BasePart") then
		return self.Instance.Position
	end

	if self.Instance.PrimaryPart then
		return self.Instance.PrimaryPart.Position
	end

	if self.Instance:IsA("Model") then
		local part = self.Instance:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.Position
		end
		local ok, cf = pcall(self.Instance.GetPivot, self.Instance)
		if ok and typeof(cf) == "CFrame" then
			return cf.Position
		end
	end

	return nil
end

function Jukebox:IsPlayerInRange(player)
	local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	local position = self:GetWorldPosition()
	if not position then
		return false
	end

	return (root.Position - position).Magnitude <= MAX_INTERACTION_DISTANCE
end

function Jukebox:Construct()
	self.Emitters = self:ResolveEmitters()
	self.PrimaryEmitter = self.Emitters[1]
	self.ProxyPart = getProxyPart(self.Instance)
	self.Connections = {}
	self.TrackConnections = {}
	self.Tracks = {}
	self.ActiveTrack = nil
	self.ActiveTweens = {}
	self.CurrentIndex = 0

	self.Enabled = self:GetAttributeOrDefault("JukeboxEnabled", false) == true
	self.ShuffleOverride = self:GetAttributeOrDefault("JukeboxShuffle", false)
	self.VolumeMultiplier = self:GetVolumeMultiplier()
	self:GetAttributeOrDefault("JukeboxCrossfade", DEFAULT_CROSSFADE)

	self:SetDefaultGenre()
	self:LoadGenre(self.Instance:GetAttribute("JukeboxGenre"))
	self:ConnectAttributeListeners()

	JukeboxRegistry[self.Instance] = self

	if self.Enabled and #self.Tracks > 0 then
		self:PlayNext(true)
	end
end

function Jukebox:GetAttributeOrDefault(attributeName, defaultValue)
	local current = self.Instance:GetAttribute(attributeName)
	if current == nil then
		self.Instance:SetAttribute(attributeName, defaultValue)
		return defaultValue
	end
	return current
end

function Jukebox:SetDefaultGenre()
	local current = self.Instance:GetAttribute("JukeboxGenre")
	if current and self:GetGenreFolder(current) then
		return
	end

	local firstGenre = self:GetDefaultGenre()
	if firstGenre then
		self.Instance:SetAttribute("JukeboxGenre", firstGenre)
	else
		self.Instance:SetAttribute("JukeboxGenre", "")
	end
end

function Jukebox:GetDefaultGenre()
	if not JukeboxLibrary then
		return nil
	end

	local genres = {}
	for _, child in ipairs(JukeboxLibrary:GetChildren()) do
		if isGenreFolder(child) then
			table.insert(genres, child.Name)
		end
	end
	table.sort(genres)

	return genres[1]
end

function Jukebox:GetGenreFolder(genreName)
	if not genreName or genreName == "" or not JukeboxLibrary then
		return nil
	end

	local folder = JukeboxLibrary:FindFirstChild(genreName)
	return isGenreFolder(folder) and folder or nil
end

function Jukebox:GetTrackNamesForGenre(genreName)
	if not genreName or genreName == "" then
		return {}
	end

	local folder = self:GetGenreFolder(genreName)
	return getTrackNames(folder)
end

function Jukebox:GetTrackIndexByName(trackName)
	if typeof(trackName) ~= "string" or trackName == "" then
		return nil
	end

	for index, track in ipairs(self.Tracks) do
		if track.Name == trackName then
			return index
		end
	end

	return nil
end

function Jukebox:SetGenre(genreName)
	if typeof(genreName) ~= "string" then
		return
	end

	local folder = self:GetGenreFolder(genreName)
	if not folder then
		return
	end

	local current = self.Instance:GetAttribute("JukeboxGenre")
	if current == folder.Name then
		return
	end

	self.Instance:SetAttribute("JukeboxGenre", folder.Name)
end

function Jukebox:SetEnabledState(desiredState)
	local newState
	if typeof(desiredState) == "boolean" then
		newState = desiredState
	else
		newState = not self.Enabled
	end

	if (self.Instance:GetAttribute("JukeboxEnabled") == true) == newState then
		return
	end

	self.Instance:SetAttribute("JukeboxEnabled", newState)
end

function Jukebox:SetShuffleState(desiredState)
	local current = self.Instance:GetAttribute("JukeboxShuffle") == true
	local newState
	if typeof(desiredState) == "boolean" then
		newState = desiredState
	else
		newState = not current
	end

	if current == newState then
		return
	end

	self.Instance:SetAttribute("JukeboxShuffle", newState)
end

function Jukebox:CreateVoices(template)
	local voices = {}
	local emitters = self.Emitters or {SoundService}

	for _, emitter in ipairs(emitters) do
		local parent = emitter
		if not parent or not parent.Parent then
			parent = SoundService
		end

		local clone = template:Clone()
		clone.Parent = parent
		local baseVolume = template.Volume ~= nil and template.Volume or DEFAULT_VOLUME
		local targetVolume = baseVolume * self.VolumeMultiplier
		clone:SetAttribute("BaseVolume", baseVolume)
		clone:SetAttribute("TargetVolume", targetVolume)
		clone.Volume = targetVolume
		clone.RollOffMode = template.RollOffMode or Enum.RollOffMode.Linear
		clone.RollOffMinDistance = template.RollOffMinDistance and template.RollOffMinDistance > 0 and template.RollOffMinDistance or DEFAULT_MIN_DISTANCE
		clone.RollOffMaxDistance = template.RollOffMaxDistance and template.RollOffMaxDistance > 0 and template.RollOffMaxDistance or DEFAULT_MAX_DISTANCE
		clone.Archivable = false

		table.insert(voices, clone)
	end

	return voices
end

function Jukebox:CancelTweens()
	for _, tween in ipairs(self.ActiveTweens or {}) do
		if tween then
			tween:Cancel()
		end
	end
	self.ActiveTweens = {}
end

function Jukebox:PlayVoice(voice, targetVolume, fadeTime)
	if not voice then
		return
	end

	voice.TimePosition = 0
	voice.Volume = 0
	voice:Play()

	if fadeTime <= 0 then
		voice.Volume = targetVolume
		return
	end

	local tween = TweenService:Create(voice, TweenInfo.new(fadeTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Volume = targetVolume,
	})
	tween:Play()
	table.insert(self.ActiveTweens, tween)
end

function Jukebox:FadeVoice(voice, duration)
	if not voice then
		return
	end

	if duration <= 0 then
		voice.Volume = 0
		voice:Stop()
		return
	end

	local tween = TweenService:Create(voice, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Volume = 0,
	})
	tween.Completed:Connect(function()
		if voice.Volume == 0 then
			voice:Stop()
		end
	end)
	tween:Play()
end

function Jukebox:FadeTrack(track, duration)
	if not track or not track.Voices then
		return
	end

	for _, voice in ipairs(track.Voices) do
		self:FadeVoice(voice, duration)
	end
end

function Jukebox:SkipTrack()
	if not self.Enabled or #self.Tracks == 0 then
		return
	end

	if self.CurrentIndex == 0 then
		self:PlayNext(true)
	else
		self:PlayNext(false)
	end
end

function Jukebox:ResolveEmitters()
	local speakers = getSpeakerParts(self.Instance)
	if #speakers > 0 then
		return speakers
	end

	local fallback
	if self.Instance:IsA("BasePart") then
		fallback = self.Instance
	elseif self.Instance.PrimaryPart then
		fallback = self.Instance.PrimaryPart
	elseif self.Instance:IsA("Model") then
		fallback = self.Instance:FindFirstChildWhichIsA("BasePart", true)
	end

	fallback = fallback or SoundService
	return { fallback }
end

function Jukebox:LoadGenre(genreName)
	local folder = self:GetGenreFolder(genreName)
	if not folder then
		self:CleanupTracks()
		self.CurrentGenre = nil
		if genreName and genreName ~= "" then
			warn(("Jukebox genre '%s' has no sounds"):format(genreName))
		end
		return
	end

	self.CurrentGenre = folder.Name
	self:RebuildTracks(folder)
end

function Jukebox:RebuildTracks(folder)
	self:CleanupTracks()

	for _, child in ipairs(folder:GetChildren()) do
		if not isSound(child) then
			continue
		end

		local voices = self:CreateVoices(child)
		if #voices == 0 then
			continue
		end

		local track = {
			Name = child.Name,
			Voices = voices,
			Connections = {},
		}

		local primary = voices[1]
		if primary then
			local connection = primary.Ended:Connect(function()
				if self.ActiveTrack == track and self.Enabled then
					self:PlayNext()
				end
			end)
			table.insert(track.Connections, connection)
			table.insert(self.TrackConnections, connection)
		end

		table.insert(self.Tracks, track)
	end

	self.CurrentIndex = 0

	if #self.Tracks == 0 then
		warn(("Jukebox genre '%s' does not contain any Sound instances"):format(folder:GetFullName()))
	end
end

function Jukebox:ConnectAttributeListeners()
	local enabledConn = self.Instance:GetAttributeChangedSignal("JukeboxEnabled"):Connect(function()
		local enabled = self.Instance:GetAttribute("JukeboxEnabled") == true
		if enabled == self.Enabled then
			return
		end

		self.Enabled = enabled
		if enabled then
			self:PlayNext(true)
		else
			self:StopPlayback(true)
		end
	end)

	table.insert(self.Connections, enabledConn)

	local genreConn = self.Instance:GetAttributeChangedSignal("JukeboxGenre"):Connect(function()
		local genre = self.Instance:GetAttribute("JukeboxGenre")
		if genre == self.CurrentGenre then
			return
		end

		self:StopPlayback(true)
		self:LoadGenre(genre)

		if self.Enabled and #self.Tracks > 0 then
			self:PlayNext(true)
		end
	end)
	table.insert(self.Connections, genreConn)

	local shuffleConn = self.Instance:GetAttributeChangedSignal("JukeboxShuffle"):Connect(function()
		self.ShuffleOverride = self.Instance:GetAttribute("JukeboxShuffle")
	end)
	table.insert(self.Connections, shuffleConn)

	local volumeConn = self.Instance:GetAttributeChangedSignal("JukeboxVolumeMultiplier"):Connect(function()
		self.VolumeMultiplier = self:GetVolumeMultiplier()
		self:ApplyVolumeMultiplier()
	end)
	table.insert(self.Connections, volumeConn)

	local crossfadeConn = self.Instance:GetAttributeChangedSignal("JukeboxCrossfade"):Connect(function()
		if self.ActiveTrack then
			self:StartTrack(self.ActiveTrack, true)
		end
	end)
	table.insert(self.Connections, crossfadeConn)
end

function Jukebox:GetVolumeMultiplier()
	local multiplier = self.Instance:GetAttribute("JukeboxVolumeMultiplier")
	if typeof(multiplier) == "number" then
		return math.max(multiplier, 0)
	end

	self.Instance:SetAttribute("JukeboxVolumeMultiplier", 1)
	return 1
end

function Jukebox:GetCrossfadeTime()
	local value = self.Instance:GetAttribute("JukeboxCrossfade")
	if typeof(value) == "number" and value >= 0 then
		return value
	end
	return DEFAULT_CROSSFADE
end

function Jukebox:IsShuffleEnabled()
	if typeof(self.ShuffleOverride) == "boolean" then
		return self.ShuffleOverride
	end
	return false
end

function Jukebox:PlayNext(forceRestart)
	if not self.Enabled or #self.Tracks == 0 then
		return
	end

	local nextIndex
	if forceRestart or self.CurrentIndex == 0 then
		nextIndex = 1
	else
		nextIndex = self:GetNextIndex()
	end

	self:PlayIndex(nextIndex)
end

function Jukebox:GetNextIndex()
	if self:IsShuffleEnabled() and #self.Tracks > 1 then
		local candidate = self.CurrentIndex
		repeat
			candidate = math.random(1, #self.Tracks)
		until candidate ~= self.CurrentIndex
		return candidate
	end

	local nextIndex = self.CurrentIndex + 1
	if nextIndex > #self.Tracks then
		nextIndex = 1
	end

	return nextIndex
end

function Jukebox:PlayIndex(index)
	local track = self.Tracks[index]
	if not track then
		return
	end

	self.CurrentIndex = index
	self:StartTrack(track)
end

function Jukebox:PlayTrackByName(trackName)
	local targetIndex = self:GetTrackIndexByName(trackName)
	if not targetIndex then
		return false
	end

	if not self.Enabled then
		self:SetEnabledState(true)
	end

	self:PlayIndex(targetIndex)
	return true
end

function Jukebox:StartTrack(track, instant)
	self:CancelTweens()

	if self.ActiveTrack and self.ActiveTrack ~= track then
		self:FadeTrack(self.ActiveTrack, self:GetCrossfadeTime())
	end

	self.ActiveTrack = track
	self.Instance:SetAttribute("JukeboxTrack", track and track.Name or nil)

	if not track or not track.Voices then
		return
	end

	local fadeTime = instant and 0 or self:GetCrossfadeTime()
	for _, voice in ipairs(track.Voices) do
		local targetVolume = voice:GetAttribute("TargetVolume") or (voice.Volume or DEFAULT_VOLUME)
		self:PlayVoice(voice, targetVolume, fadeTime)
	end
end

function Jukebox:StopPlayback(resetIndex)
	self:CancelTweens()

	if self.ActiveTrack then
		self:FadeTrack(self.ActiveTrack, self:GetCrossfadeTime())
		self.ActiveTrack = nil
	end

	if resetIndex then
		self.CurrentIndex = 0
	end

	self.Instance:SetAttribute("JukeboxTrack", nil)
end

function Jukebox:ApplyVolumeMultiplier()
	self:CancelTweens()

	for _, track in ipairs(self.Tracks) do
		if track.Voices then
			for _, voice in ipairs(track.Voices) do
				local baseVolume = voice:GetAttribute("BaseVolume") or DEFAULT_VOLUME
				local newTarget = baseVolume * self.VolumeMultiplier
				voice:SetAttribute("TargetVolume", newTarget)

				if track == self.ActiveTrack then
					local tween = TweenService:Create(voice, TweenInfo.new(math.max(self:GetCrossfadeTime() * 0.5, 0.1), Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
						Volume = newTarget,
					})
					tween:Play()
					table.insert(self.ActiveTweens, tween)
				else
					voice.Volume = newTarget
				end
			end
		end
	end
end

function Jukebox:CleanupTracks()
	self:CancelTweens()

	for _, connection in ipairs(self.TrackConnections) do
		connection:Disconnect()
	end
	self.TrackConnections = {}

	for _, track in ipairs(self.Tracks) do
		if track.Voices then
			for _, voice in ipairs(track.Voices) do
				voice:Destroy()
			end
		end
	end
	self.Tracks = {}
	self.ActiveTrack = nil
	self.CurrentIndex = 0
	self.Instance:SetAttribute("JukeboxTrack", nil)
end

function Jukebox:Destruct()
	self:StopPlayback(true)

	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	self.Connections = {}

	self:CleanupTracks()
	JukeboxRegistry[self.Instance] = nil
end

local function getValidatedComponent(player, targetInstance)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return nil
	end

	local component = targetInstance and JukeboxRegistry[targetInstance]
	if not component then
		return nil
	end

	if not component:IsPlayerInRange(player) then
		return nil
	end

	return component
end

SetGenreEvent.Event:Connect(function(player, targetInstance, genreName)
	local component = getValidatedComponent(player, targetInstance)
	if not component then
		return
	end

	component:SetGenre(genreName)
end)

TogglePlaybackEvent.Event:Connect(function(player, targetInstance, desiredState)
	local component = getValidatedComponent(player, targetInstance)
	if not component then
		return
	end

	component:SetEnabledState(desiredState)
end)

SetShuffleEvent.Event:Connect(function(player, targetInstance, desiredState)
	local component = getValidatedComponent(player, targetInstance)
	if not component then
		return
	end

	component:SetShuffleState(desiredState)
end)

NextTrackEvent.Event:Connect(function(player, targetInstance)
	local component = getValidatedComponent(player, targetInstance)
	if not component then
		return
	end

	component:SkipTrack()
end)

PlayTrackEvent.Event:Connect(function(player, targetInstance, genreName, trackName)
	local component = getValidatedComponent(player, targetInstance)
	if not component then
		return
	end

	if typeof(trackName) ~= "string" or trackName == "" then
		return
	end

	local desiredGenre = typeof(genreName) == "string" and genreName ~= "" and genreName or component.Instance:GetAttribute("JukeboxGenre")
	if desiredGenre and desiredGenre ~= component.Instance:GetAttribute("JukeboxGenre") then
		component:SetGenre(desiredGenre)
		if component.CurrentGenre ~= desiredGenre then
			component:LoadGenre(desiredGenre)
		end
	end

	local success = component:PlayTrackByName(trackName)
	if not success then
		local resolvedGenre = component.Instance:GetAttribute("JukeboxGenre")
		local trackNames = component:GetTrackNamesForGenre(resolvedGenre)
		RequestTracksEvent:Fire(player, targetInstance, resolvedGenre, trackNames)
	end
end)

RequestTracksEvent.Event:Connect(function(player, targetInstance, genreName)
	local component = getValidatedComponent(player, targetInstance)
	if not component then
		return
	end

	local resolvedGenre = typeof(genreName) == "string" and genreName ~= "" and genreName or component.Instance:GetAttribute("JukeboxGenre")
	local trackNames = component:GetTrackNamesForGenre(resolvedGenre)
	RequestTracksEvent:Fire(player, targetInstance, resolvedGenre, trackNames)
end)

return Jukebox
