local ReplicatedFirst = game:GetService("ReplicatedFirst")
ReplicatedFirst:RemoveDefaultLoadingScreen()

local Runtime = script.Parent
local Signal = require(Runtime.Signal)
local LightRunner = require(Runtime.LightRunner)
_G.LightRunner = LightRunner

LightRunner.Signal = Signal
LightRunner.Settings = Runtime.Settings:GetAttributes()
LightRunner:Load(Runtime.Source)