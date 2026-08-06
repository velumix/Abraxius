local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = game:GetService("Players").LocalPlayer
local Modules = ReplicatedStorage.Modules

local Mince = require(Modules.Mince)
local Scheduler = Mince.Scheduler.getDefault()

local Emitter = Mince.Component({
	Tag = "Emitter",
})

local ActiveEmitters = {}

function Emitter:Construct()
	self.Attributes = self.Instance:GetAttributes()
	self.ParticleEmitter = self.Instance:FindFirstChildWhichIsA("ParticleEmitter")

	if self.ParticleEmitter then
		if not self.Attributes.Frequency then
			error("No Frequency Attribute found on Emitter")
		end

		self.FrequencyMin = self.Attributes.Frequency.X
		self.FrequencyMax = self.Attributes.Frequency.Y
		self.Amount = self.Attributes.Amount
	end

	self.Sound = self.Instance:FindFirstChildWhichIsA("Sound")

	if self.Sound then
		self.Sound.Looped = true
	end

	self.SwimmingConnection = Player:GetAttributeChangedSignal("Swimming"):Connect(function()
		local isSwimming = Player:GetAttribute("Swimming") or false
		if isSwimming and self.Sound then
			self.Sound:Play()
		elseif not isSwimming and self.Sound then
			self.Sound:Stop()
		end
	end)

	if self.ParticleEmitter then
		self.ParticleEmitter.Rate = 0

		ActiveEmitters[self.Instance] = Scheduler:every(0.2, function()
			local sound = self.Sound
			if sound and sound.TimeLength > 0 then
				local halfway = sound.TimeLength * 0.4
				if sound.TimePosition >= halfway then
					self.ParticleEmitter.Rate = 20
				else
					self.ParticleEmitter.Rate = 0
				end
			end
		end, Mince.TaskScheduler.Priority.LOW, `Emitter_{self.Instance.Name}`)
	end
end

function Emitter:Removing()
	local scheduledTask = ActiveEmitters[self.Instance]
	if scheduledTask then
		Scheduler:cancel(scheduledTask)
		ActiveEmitters[self.Instance] = nil
	end
	if self.SwimmingConnection then
		self.SwimmingConnection:Disconnect()
		self.SwimmingConnection = nil
	end
end

return Emitter
