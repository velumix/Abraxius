-- Modules // Servioces 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Mince = require(ReplicatedStorage.Modules.Mince)
local Utility = require(ReplicatedStorage.Modules.Utility)

type SourceName = string

local SoundSource = require(script.SoundSource)



--- SoundHandler 2 -- Whim! 
-- MISSING: Effects, 
-- MISSING: Tracks Replacement AKA loops.! 

local SoundHandler = {
	Sources = {},
	Loops = {},
	LoopStack = {},
	MusicOverride = nil,
	
	CrossFadeTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
} 


function SoundHandler:StopAllLoopedSounds() 

end

function SoundHandler:StopLoopedSoundsOnStack() 

end

function SoundHandler:StopLoop(SourceName) 
	local ThisSource = SoundHandler.Sources[SourceName] 
	if not ThisSource then 
		warn(`There is no source by the name of '{SourceName}'!`)
		return	
	end
	
	local ThisStack = ThisSource.Stack  
	
	if not ThisSource.Paused then 
		if ThisStack and SoundHandler.LoopStack[ThisStack] == ThisSource then 
			SoundHandler.LoopStack[ThisStack] = nil 
		end
		
		ThisSource.Paused = true
		local Sound = ThisSource.ExternalLoopSound
		if Sound then
			if ThisSource.LastPendingTween then
				ThisSource.LastPendingTween:Cancel()
			end
			local FadeOut = TweenService:Create(Sound, SoundHandler.CrossFadeTweenInfo, {
				Volume = 0
			})
			ThisSource.LastPendingTween = FadeOut
			FadeOut.Completed:Once(function()
				if ThisSource.Paused and Sound.Parent then
					Sound:Stop()
					Sound.Volume = ThisSource.Volume
				end
				if ThisSource.LastPendingTween == FadeOut then
					ThisSource.LastPendingTween = nil
				end
			end)
			FadeOut:Play()
		end
	end 
end

function SoundHandler:BeginMusicOverride(SourceName, DuckScale)
	local ActiveOverride = SoundHandler.MusicOverride
	if ActiveOverride and ActiveOverride.SourceName == SourceName then
		return SoundHandler:LoopSound(SourceName)
	end
	if ActiveOverride then
		SoundHandler:EndMusicOverride(ActiveOverride.SourceName)
	end

	local MusicGroup = SoundHandler:GetSoundGroup("Music")
	if not SoundHandler.Sources[SourceName] or not MusicGroup then
		return
	end

	DuckScale = math.clamp(DuckScale or 0.28, 0, 1)
	local OriginalVolume = MusicGroup.Volume
	SoundHandler.MusicOverride = {
		SourceName = SourceName,
		MusicGroup = MusicGroup,
		OriginalVolume = OriginalVolume,
		DuckScale = DuckScale
	}

	local DuckTween = TweenService:Create(MusicGroup, SoundHandler.CrossFadeTweenInfo, {
		Volume = OriginalVolume * DuckScale
	})
	SoundHandler.MusicOverride.DuckTween = DuckTween
	DuckTween:Play()

	return SoundHandler:LoopSound(SourceName)
end

function SoundHandler:EndMusicOverride(SourceName)
	local ActiveOverride = SoundHandler.MusicOverride
	if not ActiveOverride or (SourceName and ActiveOverride.SourceName ~= SourceName) then
		return
	end

	SoundHandler.MusicOverride = nil
	if ActiveOverride.DuckTween then
		ActiveOverride.DuckTween:Cancel()
	end
	SoundHandler:StopLoop(ActiveOverride.SourceName)
	if ActiveOverride.MusicGroup and ActiveOverride.MusicGroup.Parent then
		TweenService:Create(ActiveOverride.MusicGroup, SoundHandler.CrossFadeTweenInfo, {
			Volume = ActiveOverride.OriginalVolume
		}):Play()
	end
end

function SoundHandler:LoopSound(SourceName : SourceName) 
	local ThisSource = SoundHandler.Sources[SourceName] 
	if not ThisSource then 
		warn(`There is no source by the name of '{ThisSource}'!`)
		return	
	end
	
	SoundHandler.Loops[ThisSource.SoundName] = ThisSource
	
	ThisSource.ExternalLoopSound = ThisSource.ExternalLoopSound or ThisSource:GetExternal(function(Sound : Sound) 
		Sound.Looped = true 
	end)

	
	if not ThisSource.Paused then
		ThisSource.Paused = true
	end 
	
	local ThisStack = ThisSource.Stack  
	if ThisSource.IgnoreStack or not ThisStack then 
		if ThisSource.Paused then
			if ThisSource.LastPendingTween then
				ThisSource.LastPendingTween:Cancel()
				ThisSource.LastPendingTween = nil
			end
			ThisSource.Paused = false 
			ThisSource:PlayExternal(ThisSource.ExternalLoopSound, function(Sound : Sound)
				Sound.Looped = true 
				Sound:Resume()
				Sound.Volume = 0 
				local FadeIn = TweenService:Create(Sound, SoundHandler.CrossFadeTweenInfo, {
					Volume = ThisSource.Volume 
				})
				ThisSource.LastPendingTween = FadeIn
				FadeIn:Play()
			end)
		end
		return ThisSource.ExternalLoopSound
	end


	local ActiveSource = SoundHandler.LoopStack[ThisStack]
	if not ThisSource.Overplay then 
		if ActiveSource == ThisSource then 
			return ThisSource.ExternalLoopSound -- Returns to prevent overplay!
		end
	end

	if ActiveSource and ActiveSource ~= ThisSource then 		-- If the current active track is playing th stop it  
		if not ActiveSource.Paused then 
			warn("Pause->", ActiveSource.ExternalLoopSound.Name)
			ActiveSource.Paused = true 
			TweenService:Create(ActiveSource.ExternalLoopSound, SoundHandler.CrossFadeTweenInfo,{
				Volume = 0,
				Playing = false
			}):Play()
		end 
	end

	if ThisSource.Paused then 	-- Only play if not already playinhg 
		if ThisSource.LastPendingTween then
			ThisSource.LastPendingTween:Cancel()
			ThisSource.LastPendingTween = nil
		end
		ThisSource.Paused = false 
		ThisSource:PlayExternal(ThisSource.ExternalLoopSound, function(Sound : Sound)
			Sound.Looped = true 
			Sound:Resume()
			Sound.Volume = 0 
			TweenService:Create(Sound, SoundHandler.CrossFadeTweenInfo, {
				Volume = ThisSource.Volume 
			}):Play() 
		end)
	end
	
	SoundHandler.LoopStack[ThisStack] = ThisSource -- Assign it to th enew active track s
	
	return ThisSource.ExternalLoopSound
end

function SoundHandler:GetLoop(SourceName : SourceName)
	local ThisSource = SoundHandler.Sources[SourceName] 
	if not ThisSource then 
		warn(`There is no source by the name of '{ThisSource}'!`)
		return	
	end
	
	return ThisSource:GetExternal(function(Sound : Sound) 
		Sound.Looped = true 
	end)
end

function SoundHandler:IsExternal(ExternalSound)
	if typeof(ExternalSound) == "Instance" and ExternalSound:IsA("Sound") and ExternalSound:GetAttribute("External") then
		return SoundHandler.Sources[ExternalSound:GetAttribute("External")]
	end
end

function SoundHandler:PlaySound(SourceName : SourceName | Sound, ModifyFn : (Sound) -> ())
	local ExternalSource = SoundHandler:IsExternal(SourceName) 
	if ExternalSource then 
		ExternalSource:PlayExternal(SourceName)
		return
	end
	
	local ThisSource = SoundHandler.Sources[SourceName] 
	if not ThisSource then 
		warn(`There is no source by the name of '{SourceName}'!`)
		return	
	end
	
	return ThisSource:PlayNext(ModifyFn) 
end

function SoundHandler:PlaySoundAt(SourceName : SourceName, Parent : Instance, ModifyFn : (Sound) -> ())
	assert(Utility.AssertTypes(SourceName, "string")) 
	
	local ThisSource = SoundHandler.Sources[SourceName] 
	if not ThisSource then 
		warn(`There is no source by the name of '{ThisSource}'!`)
		return	
	end
	
	
	local ExistingSound : Sound = Parent:FindFirstChild(ThisSource:NameMe())
	if ExistingSound then 
		ThisSource:PlayExternal(ExistingSound, ModifyFn)
		return 
	end
	
	local SoundInstance : Sound= ThisSource:GetExternal() 	
	SoundInstance.Parent = Parent
	ThisSource:PlayExternal(SoundInstance, ModifyFn)
	return SoundInstance
end

function SoundHandler:GetSound(SourceName : SourceName, ModifyFn : (Sound) -> ())
	local ThisSource = SoundHandler.Sources[SourceName] 
	if not ThisSource then 
		warn(`There is no source by the name of '{ThisSource}'!`)
		return	
	end

	return ThisSource:GetExternal(ModifyFn)  
end


function SoundHandler:ModifySoundVolumeOf(SoundGroupName : string, Volume)
	local SoundGroup = Mince.Config.Sounds.SoundGroups[SoundGroupName] 
	if not SoundGroup then 
		error(`There is no soundgroup by the name of '{SoundGroupName}' are you sure it has been configured?`)
	end

	local TargetVolume = 0.5 * Volume
	local ActiveOverride = SoundHandler.MusicOverride
	if SoundGroupName == "Music" and ActiveOverride then
		ActiveOverride.OriginalVolume = TargetVolume
		SoundGroup.Volume = TargetVolume * ActiveOverride.DuckScale
	else
		SoundGroup.Volume = TargetVolume
	end
	if SoundGroupName == "Music" then
		local MerchantMusicGroup = Mince.Config.Sounds.SoundGroups.MerchantMusic
		if MerchantMusicGroup then
			MerchantMusicGroup.Volume = TargetVolume
		end
	end
end
 
function SoundHandler:CreateSourceFromConfig(SoundTable, SoundGroup) 
	SoundHandler.Sources[SoundTable.SoundName] = SoundSource.new(SoundTable, SoundGroup)
end

function SoundHandler:GetSoundGroup(SoundGroupName : string) 
	local SoundGroup = Mince.Config.Sounds.SoundGroups[SoundGroupName] 
	if not SoundGroup then 
		error(`There is no soundgroup by the name of '{SoundGroupName}' are you sure it has been configured?`)
	end
	
	return SoundGroup
end

function SoundHandler:SearchSourceTableGroupForConfig(SourceTableGroup, InheritName, SoundGroup) 
	for SoundName, DeepSourceTableGroup in SourceTableGroup do 
		if type(DeepSourceTableGroup) ~= "table" then continue end 
		local NewSoundName = InheritName .. ".".. SoundName 
		
		if DeepSourceTableGroup.Sound or DeepSourceTableGroup[1] then
			DeepSourceTableGroup.SoundName = NewSoundName
			
			SoundHandler:CreateSourceFromConfig(DeepSourceTableGroup, SoundGroup)
		else 
			SoundHandler:SearchSourceTableGroupForConfig(DeepSourceTableGroup, NewSoundName, SoundGroup)
		end
	end
end

function SoundHandler:SetupSoundGroups() 
	for _, SoundGroup : SoundGroup in Mince.Config.Sounds.SoundGroups do 
		local EffectSoundGroup = Instance.new("SoundGroup") 
		EffectSoundGroup.Name = "Effect"
		EffectSoundGroup.Parent = SoundGroup 
	end
end

function SoundHandler:LoadSoundsFromConfig() 
	for GroupName, SourceGroupRoot in Mince.Config.Sounds.Sources do
		local SoundGroup = SoundHandler:GetSoundGroup(GroupName) 
		
		if not SoundGroup then 
			warn(`SourceGroupRoot Sources by the name of '{GroupName}' did not load because it doesn't have a SoundGroup!`)
			continue 
		end
		
		
		for SoundName, SourceTableGroup in SourceGroupRoot do 
			SourceTableGroup.SoundName = SoundName
			 
			if SourceTableGroup.Collection then 
				SoundHandler:SearchSourceTableGroupForConfig(SourceTableGroup, SoundName, SoundGroup)
			else 
				SoundHandler:CreateSourceFromConfig(SourceTableGroup, SoundGroup)
			end
		end
	end
end

function SoundHandler:Init() 
	local SoundInstances = Instance.new("Folder")
	SoundInstances.Name = "__SoundInstances" 
	SoundInstances.Parent = game.Workspace
	
	SoundHandler.SoundFolder = SoundInstances
	
	SoundHandler:SetupSoundGroups()
	SoundHandler:LoadSoundsFromConfig()
end

SoundHandler:Init()
return SoundHandler
