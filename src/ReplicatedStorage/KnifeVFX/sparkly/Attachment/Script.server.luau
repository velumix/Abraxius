-- RainbowParticles.lua
-- Place inside any Attachment or Part with ParticleEmitters

local parent = script.Parent
local hue = 0

game:GetService("RunService").Heartbeat:Connect(function(dt)
	hue = (hue + dt * 0.2) % 1 -- Speed: increase 0.2 to go faster

	local color = Color3.fromHSV(hue, 1, 1)
	local sequence = ColorSequence.new(color)

	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("ParticleEmitter") then
			child.Color = sequence
		end
	end
end)