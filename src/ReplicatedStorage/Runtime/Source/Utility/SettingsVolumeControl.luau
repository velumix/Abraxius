local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mince = require(ReplicatedStorage.Modules.Mince)

local Settings = Mince:Get("Settings") 
local SoundHandler = Mince:Get("SoundHandler")

local Connec = {} 

function Connec:Setup() 
	if true then return end 
	Settings:SettingChanged("SFXVol"):Connect(function(Value) 
		SoundHandler:ModifySoundVolumeOf("SFX", Value)
	end) 
	Settings:SettingChanged("MusicVol"):Connect(function(Value)
		SoundHandler:ModifySoundVolumeOf("Music", Value)
	end)
end

return Connec