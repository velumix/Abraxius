local ConfettiModule = {}

local ConfettiTemplate = script.Confetti

local function display(char:Model, dur:number)
	local confetti = ConfettiTemplate:Clone(); confetti.Parent = char.HumanoidRootPart
	for _, child in ipairs(confetti:GetChildren()) do
		if child:IsA("ParticleEmitter") then child:Emit(child:GetAttribute("EmitCount") or 20) end
	end
	game:GetService("Debris"):AddItem(confetti, dur)
end

if game:GetService("RunService"):IsServer() then
	function ConfettiModule.Emit(Plr:Player, Duration: number)
		local char = Plr.Character
		if not char then warn("Couldn't find "..tostring(Plr).." character") return end
		Duration = tonumber(Duration or 1) or 1
		
		display(char,Duration)
	end
	return ConfettiModule
end

local plr = game.Players.LocalPlayer
local char = plr.Character

local ScreenModuleHolder = require(script.Screen)
local Screen = ScreenModuleHolder.new()

plr.CharacterAdded:Connect(function(c)
	char = c
end)

function ConfettiModule.Emit(Duration:number)
	Duration = tonumber(Duration or 1) or 1
	display(char,Duration)
	Screen:Emit(100)
end

return ConfettiModule