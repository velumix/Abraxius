local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)
local RagdollModule = require(Modules.RagdollModule)

local OxygenService = {
	Name = "OxygenService",
	SeaLevel = 90,
	BaseDepletionRate = 1,
	RegenerationRate = 2,
	UpdateInterval = 0.5,
	_playerStates = {},
}

function OxygenService:Setup()
	local oxygenComm = Mince:GetEvent("OxygenEvents")
	self.OxygenSync = oxygenComm:Extend("OxygenSync")
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			self:SetupCharacter(player)
		end)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:SetupCharacter(player)
		end)
	end
end

function OxygenService:SetupCharacter(player)
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = character:WaitForChild("Humanoid", 5)
	end
	if not humanoid then
		warn("Missing Humanoid for", player.Name)
		return
	end
	local function removeRegenScript(instance)
		if not instance then
			return
		end
		if instance:IsA("Script") or instance:IsA("LocalScript") then
			if instance.Name == "Health" or instance.Name == "HealthScript" then
				instance:Destroy()
			end
		end
	end

	for _, child in ipairs(character:GetChildren()) do
		removeRegenScript(child)
	end

	character.ChildAdded:Connect(removeRegenScript)

	humanoid.BreakJointsOnDeath = false

	task.wait(0.1)

	self._playerStates[player.UserId] = {
		LastSwimmingState = false,
		LastCanBreathe = true,
		LastOxygen = 30,
		LastDebugTime = 0,
	}

	humanoid.Died:Connect(function()
		RagdollModule.Ragdoll(character, 10)
		local isSwimming = player:GetAttribute("Swimming")
		if isSwimming then
			local parts = {
				"HumanoidRootPart",
				"UpperTorso",
				"LowerTorso",
				"LeftUpperArm",
				"LeftLowerArm",
				"LeftHand",
				"RightUpperArm",
				"RightLowerArm",
				"RightHand",
				"LeftUpperLeg",
				"LeftLowerLeg",
				"LeftFoot",
				"RightUpperLeg",
				"RightLowerLeg",
				"RightFoot",
			}

			for _, partName in pairs(parts) do
				local part = character:FindFirstChild(partName)
				if part and part:IsA("BasePart") then
					local bodyVelocity = Instance.new("BodyVelocity")
					bodyVelocity.Velocity = Vector3.new(0, math.random(2, 3), 0)
					bodyVelocity.MaxForce = Vector3.new(0, 1800, 0)
					bodyVelocity.P = 500
					bodyVelocity.Parent = part
					Debris:AddItem(bodyVelocity, 10)
				end
			end
		end
	end)

	character.Destroying:Connect(function()
		self._playerStates[player.UserId] = nil
	end)

	if not character:GetAttribute("Oxygen") then
		character:SetAttribute("Oxygen", 30)
	end
	if not character:GetAttribute("MaxOxygen") then
		character:SetAttribute("MaxOxygen", 30)
	end
	if not character:GetAttribute("OxygenDepletionRate") then
		character:SetAttribute("OxygenDepletionRate", self.BaseDepletionRate)
	end
	character:SetAttribute("CanBreathe", true)
	character:SetAttribute("Depth", 0)

	local current = 0

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if not character.Parent or not character:FindFirstChild("Head") then
			connection:Disconnect()
			return
		end

		current = current + dt
		if current >= self.UpdateInterval then
			self:UpdateOxygen(player, character)
			current = 0
		end
	end)
end

function OxygenService:UpdateOxygen(player, character)
	local playerState = self._playerStates[player.UserId]
	if not playerState then
		return
	end

	local isSwimming = player:GetAttribute("Swimming")
	if isSwimming == nil then
		return
	end

	local head = character:FindFirstChild("Head")
	if not head then
		return
	end

	local depth = head.Position.Y - self.SeaLevel
	character:SetAttribute("Depth", depth)

	local underwaterRegen = character:GetAttribute("UnderwaterRegen") == true
	local canBreathe = not isSwimming
	character:SetAttribute("CanBreathe", canBreathe)

	local oxygen = character:GetAttribute("Oxygen") or 0
	local maxOxygen = character:GetAttribute("MaxOxygen") or 30
	local depletionRate = character:GetAttribute("OxygenDepletionRate") or self.BaseDepletionRate

	local shouldUpdate = false

	if isSwimming then
		if underwaterRegen then
			if oxygen < maxOxygen then
				oxygen = math.min(maxOxygen, oxygen + (depletionRate * self.UpdateInterval))
				character:SetAttribute("Oxygen", oxygen)
				shouldUpdate = true
			end
		elseif oxygen > 0 then
			oxygen = math.max(0, oxygen - (depletionRate * self.UpdateInterval))
			character:SetAttribute("Oxygen", oxygen)
			shouldUpdate = true
		else
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid:TakeDamage(15 * self.UpdateInterval)
			end
			shouldUpdate = true
		end
	else
		if oxygen < maxOxygen then
			oxygen = math.min(maxOxygen, oxygen + (self.RegenerationRate * self.UpdateInterval))
			character:SetAttribute("Oxygen", oxygen)
			shouldUpdate = true
		end
	end

	local stateChanged = playerState.LastSwimmingState ~= isSwimming
		or playerState.LastCanBreathe ~= canBreathe
		or math.abs(playerState.LastOxygen - oxygen) > 0.1

	if shouldUpdate or stateChanged then
		self.OxygenSync:Fire(player, {
			Oxygen = oxygen,
			MaxOxygen = maxOxygen,
			CanBreathe = canBreathe,
			Depth = depth,
			IsSwimming = isSwimming,
		})

		playerState.LastSwimmingState = isSwimming
		playerState.LastCanBreathe = canBreathe
		playerState.LastOxygen = oxygen
	end
end

return OxygenService
