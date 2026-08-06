-- Sound Class
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mince = require(ReplicatedStorage.Modules.Mince)

local SoundHandler = Mince:Get("SoundHandler")

local Source = {}
Source.__index = Source

function Source.new(ConfigProto, SoundGroup)
	local self = setmetatable(ConfigProto, Source)

	assert(self.SoundName, "Something went really wrong! not SoundName when source was created!")

	self.Position = 0
	self.MySoundGroup = SoundGroup

	self.Volume = self.Volume or 0.5
	self.CurrentSoundPosition = self.CurrentSoundPosition or 0

	self.SoundIDs = {}
	self.SoundInstances = {}

	local configuredSounds = ConfigProto.Sound or ConfigProto
	if type(configuredSounds) == "string" then
		configuredSounds = { configuredSounds }
	end
	for _, SoundID in ipairs(configuredSounds) do
		table.insert(self.SoundIDs, SoundID)
	end

	self.TotalSounds = #self.SoundIDs

	return self
end

function Source:PlayExternal(ExternalSound: Sound, ModifyFN)
	local SoundID = self:GetNextSoundID()
	self:ApplySoundProperties(ExternalSound, SoundID)
	if ModifyFN and ExternalSound then
		ModifyFN(ExternalSound)
	end
	ExternalSound:Play()
end

function Source:PlayNext(ModifyFN)
	local SoundID = self:GetNextSoundID()
	local SoundInstance: Sound = self:GetSoundInstance(SoundID)
	if ModifyFN and SoundInstance then
		ModifyFN(SoundInstance)
	end
	SoundInstance:Play()
	return SoundInstance
end

function Source:GetExternal(ModifyFN)
	local SoundInstance: Sound = self:GetSoundInstance(self:GetNextSoundID(), true)
	SoundInstance:SetAttribute("External", self.SoundName)
	if ModifyFN and SoundInstance then
		ModifyFN(SoundInstance)
	end
	return SoundInstance
end

function Source:NameMe()
	return `Source.{self.SoundName}`
end

function Source:ApplySoundProperties(Sound: Sound, SoundID: string)
	--[[Sound.RollOffMinDistance = 10000
	Sound.RollOffMinDistance = 10 
	Sound.RollOffMode = Enum.RollOffMode.InverseTapered]]

	Sound.Volume = self.Volume
	Sound.Looped = false
	Sound.SoundId = SoundID
	Sound.Name = self:NameMe()
	Sound.TimePosition = self.StartingTimePosition or 0
	Sound.PlaybackSpeed = self.PlaybackSpeed or 1
	Sound.SoundGroup = self.MySoundGroup
end

function Source:GetSoundInstance(SoundID: string, DontConnect)
	local SoundInstancesID = self.SoundInstances[SoundID]
	if not SoundInstancesID then
		self.SoundInstances[SoundID] = {}
		SoundInstancesID = self.SoundInstances[SoundID]
	end

	if not DontConnect then
		for _, SoundInstance: Sound in SoundInstancesID do
			if not SoundInstance.IsPlaying and not SoundInstance.Looped then
				self:ApplySoundProperties(SoundInstance, SoundID)
				return SoundInstance
			end
		end
	end

	local ThisEvents = {}
	local SoundInstance = Instance.new("Sound")
	self:ApplySoundProperties(SoundInstance, SoundID)
	SoundInstance.Parent = SoundHandler.SoundFolder

	if not DontConnect then
		local DestructTracking = function()
			local SoundIndex = table.find(SoundInstancesID, SoundInstance)
			if SoundIndex then
				table.remove(SoundInstancesID, SoundIndex)
			end

			for _, Event: RBXScriptConnection in ThisEvents do
				Event:Disconnect()
			end
		end

		ThisEvents.Destroying = SoundInstance.Destroying:Once(DestructTracking)
		ThisEvents.ChangingParent = SoundInstance.AncestryChanged:Once(DestructTracking)
		ThisEvents.BecomesLooped = SoundInstance:GetPropertyChangedSignal("Looped"):Once(DestructTracking)

		table.insert(SoundInstancesID, SoundInstance)
	end

	return SoundInstance
end

function Source:GetNextSoundID()
	return self.SoundIDs[self:GetSoundPosition()]
end

function Source:GetSoundPosition()
	if self.Shuffle then
		self.LastPosition = self.Position

		if self.TotalSounds <= 1 then
			self.Position = self.RandomClass:NextInteger(1, self.TotalSounds)
		else
			repeat
				self.Position = self.RandomClass:NextInteger(1, self.TotalSounds)
			until self.Position ~= self.LastPosition
		end
	elseif self.Random then
		self.Position = self.RandomClass:NextInteger(1, self.TotalSounds)
	else
		self.Position += 1
		if self.Position > self.TotalSounds then
			self.Position = 1
		end
	end

	return self.Position
end

return Source
