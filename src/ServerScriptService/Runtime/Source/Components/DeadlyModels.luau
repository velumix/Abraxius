local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage.Modules

local Mince = require(Modules.Mince)
local Scheduler = Mince.Scheduler.getDefault()

local DeadlyModels = Mince.Component({
	Tag = "Deadly",
	DPS = 25,
	Rate = 0.5,
})

function DeadlyModels:Construct()
	self.Model = self.Instance
	self.Connections = {}
	self.CharactersInContact = {}
	self.TouchingParts = {}

	for _, part in self.Model:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(
				self.Connections,
				part.Touched:Connect(function(otherPart)
					local character = otherPart.Parent
					if not character then
						return
					end

					local player = Players:GetPlayerFromCharacter(character)
					if player then
						if not self.TouchingParts[otherPart] then
							self.TouchingParts[otherPart] = character
							self.CharactersInContact[character] = (self.CharactersInContact[character] or 0) + 1
						end
					end
				end)
			)

			table.insert(
				self.Connections,
				part.TouchEnded:Connect(function(otherPart)
					local character = self.TouchingParts[otherPart]
					if character then
						self.TouchingParts[otherPart] = nil
						if self.CharactersInContact[character] then
							self.CharactersInContact[character] = self.CharactersInContact[character] - 1
							if self.CharactersInContact[character] <= 0 then
								self.CharactersInContact[character] = nil
							end
						end
					end
				end)
			)
		end
	end

	self.DamageTask = Scheduler:every(self.Rate, function()
		self:_DamageTick()
	end, Mince.TaskScheduler.Priority.HIGH, `Deadly_{self.Model.Name}`)
end

function DeadlyModels:_DamageTick()
	local damagePerTick = self.DPS * self.Rate
	for character in pairs(self.CharactersInContact) do
		if character.Parent then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid:TakeDamage(damagePerTick)
			elseif humanoid and humanoid.Health <= 0 then
				self.CharactersInContact[character] = nil
			end
		else
			self.CharactersInContact[character] = nil
		end
	end
end

function DeadlyModels:Removing()
	if self.DamageTask then
		Scheduler:cancel(self.DamageTask)
		self.DamageTask = nil
	end

	for _, conn in ipairs(self.Connections) do
		conn:Disconnect()
	end

	self.Connections = {}
	self.CharactersInContact = {}
	self.TouchingParts = {}
end

return DeadlyModels
