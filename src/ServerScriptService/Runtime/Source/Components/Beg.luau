local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local Mince = require(ReplicatedStorage.Modules.Mince)
local RagdollModule = require(ReplicatedStorage.Modules.RagdollModule)
local SoundIds = require(ReplicatedStorage.Runtime.Config.Shared.Sounds).Ids.Gameplay.Beg

local REWARD_AMOUNT = 1000
local COOLDOWN_SECONDS = 0.25
local MAX_STREAK = 9
local RAGDOLL_SECONDS = 5
local TOSS_SPEED = 150
local TOSS_UP = 220
local EXPLODE_CHANCE = 0.05
local FALL_DAMAGE = 25

local Beg = Mince.Component({
	Tag = "Beg",
})

function Beg:Construct()
	self.CurrencyService = Mince:Get("CurrencyService")
	self.LastClaimByUserId = {}
	self.ClaimStreakByUserId = {}
	self.VisualPart = self:GetVisualPart()
	if self.VisualPart then
		self.VisualPart.Material = Enum.Material.Neon
		self.VisualPart.Color = Color3.fromHSV(0, 1, 1)
		self.Sound = Instance.new("Sound")
		self.Sound.Name = "BegSound"
		self.Sound.SoundId = SoundIds.Activate
		self.Sound.Volume = 1
		self.Sound.RollOffMaxDistance = 40
		self.Sound.Parent = self.VisualPart
		self.RainbowConnection = RunService.Heartbeat:Connect(function()
			local hue = (os.clock() * 0.15) % 1
			self.VisualPart.Color = Color3.fromHSV(hue, 1, 1)
		end)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Totally Legit Funds"
	prompt.ActionText = "Yoink 1k"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = self.Instance

	self.Prompt = prompt

	self.Prompt.Triggered:Connect(function(player)
		self:OnClaim(player)
	end)
end

function Beg:GetVisualPart()
	if self.Instance:IsA("BasePart") then
		return self.Instance
	end
	if self.Instance:IsA("Model") then
		local primary = self.Instance.PrimaryPart
		if primary and primary:IsA("BasePart") then
			return primary
		end
		return self.Instance:FindFirstChildWhichIsA("BasePart")
	end
	return nil
end

function Beg:GetCharacterRootPart(character)
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return character:FindFirstChildWhichIsA("BasePart")
end

function Beg:PlayGroundOof(rootPart, character)
	if not rootPart or not character then
		return
	end
	local played = false
	local connection
	connection = rootPart.Touched:Connect(function(hit)
		if played then
			return
		end
		if not hit or not hit:IsA("BasePart") then
			return
		end
		if hit:IsDescendantOf(character) then
			return
		end
		if rootPart.AssemblyLinearVelocity.Y > -5 then
			return
		end
		played = true
		local oofSound = Instance.new("Sound")
		oofSound.Name = "ID1"
		oofSound.SoundId = SoundIds.ImpactPrimary
		oofSound.Volume = 1
		oofSound.RollOffMaxDistance = 60
		oofSound.Parent = rootPart
		oofSound:Play()
		Debris:AddItem(oofSound, 3)
		local extraSound = Instance.new("Sound")
		extraSound.Name = "ID2"
		extraSound.SoundId = SoundIds.ImpactSecondary
		extraSound.Volume = 1
		extraSound.RollOffMaxDistance = 60
		extraSound.Parent = rootPart
		extraSound:Play()
		Debris:AddItem(extraSound, 3)
		if connection then
			connection:Disconnect()
		end
	end)
	task.delay(5, function()
		if connection then
			connection:Disconnect()
		end
	end)
end

function Beg:Explode(rootPart, character)
	if not rootPart or not character then
		return
	end
	local played = false
	local connection
	connection = rootPart.Touched:Connect(function(hit)
		if played then
			return
		end
		if not hit or not hit:IsA("BasePart") then
			return
		end
		if hit:IsDescendantOf(character) then
			return
		end
		if rootPart.AssemblyLinearVelocity.Y > -5 then
			return
		end
		played = true
		local explosion = Instance.new("Explosion")
		explosion.Position = rootPart.Position
		explosion.BlastRadius = 0
		explosion.BlastPressure = 0
		explosion.DestroyJointRadiusPercent = 0
		explosion.Parent = workspace
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
		end
		if connection then
			connection:Disconnect()
		end
	end)
	task.delay(5, function()
		if connection then
			connection:Disconnect()
		end
	end)
end

function Beg:OnClaim(player)
	local now = os.clock()
	local lastClaim = self.LastClaimByUserId[player.UserId]
	if lastClaim and (now - lastClaim) < COOLDOWN_SECONDS then
		return
	end
	self.LastClaimByUserId[player.UserId] = now

	if self.Sound then
		self.Sound:Play()
	end
	self.CurrencyService:GiveEcoPoints(player, REWARD_AMOUNT, "Test Beg Prompt")
	self.CurrencyService:GiveCurrency(player, REWARD_AMOUNT, "Test Beg Prompt")

	local streak = (self.ClaimStreakByUserId[player.UserId] or 0) + 1
	self.ClaimStreakByUserId[player.UserId] = streak
	local exploded = false
	if math.random() < EXPLODE_CHANCE then
		local character = player.Character
		local rootPart = self:GetCharacterRootPart(character)
		local sourcePart = self.VisualPart
		if not sourcePart and self.Instance:IsA("BasePart") then
			sourcePart = self.Instance
		end
		if rootPart and sourcePart then
			local offset = rootPart.Position - sourcePart.Position
			local direction = offset.Magnitude > 0.01 and offset.Unit or Vector3.new(1, 0, 0)
			local impulse = (direction * TOSS_SPEED + Vector3.new(0, TOSS_UP, 0)) * rootPart.AssemblyMass
			rootPart:ApplyImpulse(impulse)
			self:Explode(rootPart, character)
			exploded = true
		end
	end
	if streak > MAX_STREAK then
		if exploded then
			return
		end
		self.ClaimStreakByUserId[player.UserId] = 0
		local character = player.Character
		if character then
			RagdollModule.Ragdoll(character, 0, nil, true)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid:TakeDamage(FALL_DAMAGE)
			end
			local rootPart = self:GetCharacterRootPart(character)
			local sourcePart = self.VisualPart
			if not sourcePart and self.Instance:IsA("BasePart") then
				sourcePart = self.Instance
			end
			if rootPart and sourcePart then
				local tossSound = Instance.new("Sound")
				tossSound.Name = "BegTossSound"
				tossSound.SoundId = SoundIds.Toss
				tossSound.Volume = 1
				tossSound.RollOffMaxDistance = 60
				tossSound.Parent = rootPart
				tossSound:Play()
				Debris:AddItem(tossSound, 3)

				local offset = rootPart.Position - sourcePart.Position
				local direction = offset.Magnitude > 0.01 and offset.Unit or Vector3.new(1, 0, 0)
				local impulse = (direction * TOSS_SPEED + Vector3.new(0, TOSS_UP, 0)) * rootPart.AssemblyMass
				rootPart:ApplyImpulse(impulse)
				self:PlayGroundOof(rootPart, character)
			end
			local ragdollCharacter = character
			task.delay(RAGDOLL_SECONDS, function()
				if player.Character == ragdollCharacter then
					RagdollModule.UnRagdoll(ragdollCharacter)
				end
			end)
		end
	end
end

function Beg:Destroy()
	if self.RainbowConnection then
		self.RainbowConnection:Disconnect()
		self.RainbowConnection = nil
	end
	if self.Sound then
		self.Sound:Destroy()
		self.Sound = nil
	end
	if self.Prompt then
		self.Prompt:Destroy()
	end
end

return Beg
