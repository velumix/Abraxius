local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ModifierUtils = require(script.Parent:WaitForChild("ModifierUtils"))
local StudsConverter = require(ServerStorage:WaitForChild("StudsConverter"))

local PaintMutationEffects = {}

local EFFECT_NAMES = { "BigHead", "TinyBody", "LowGravity", "SuperJump", "ForcedBrightColor" }
local playerCaches = {}

function PaintMutationEffects.getRandomEffectName(exclude: string?): string
	if #EFFECT_NAMES <= 1 then
		return EFFECT_NAMES[1]
	end
	local pick
	repeat
		pick = EFFECT_NAMES[math.random(1, #EFFECT_NAMES)]
	until pick ~= exclude
	return pick
end

function PaintMutationEffects.getEffectNames(): { string }
	return table.clone(EFFECT_NAMES)
end

function PaintMutationEffects.apply(player: Player, effectName: string)
	PaintMutationEffects.reset(player)
	local cache = { effect = effectName }
	playerCaches[player] = cache

	local character = player.Character
	if not character then
		print(`[PaintMutationEffects] {player.Name} has no character, skipping {effectName}`)
		return
	end
	print(`[PaintMutationEffects] applying {effectName} to {player.Name}`)

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if effectName == "BigHead" then
		local headScale = humanoid and humanoid:FindFirstChild("HeadScale")
		if headScale and headScale:IsA("NumberValue") then
			cache.headScale = headScale.Value
			headScale.Value = 1.5
		else
			local head = character:FindFirstChild("Head")
			local torso = character:FindFirstChild("Torso")
			local neck = torso and torso:FindFirstChild("Neck")
			local mesh = head and head:FindFirstChildOfClass("SpecialMesh")
			if head and head:IsA("BasePart") and neck and neck:IsA("Motor6D") then
				cache.headSize = head.Size
				cache.neckC1 = neck.C1
				cache.meshScale = mesh and mesh.Scale
				head.Size = head.Size * 1.5
				if mesh then
					mesh.Scale = mesh.Scale * 1.5
				end
				neck.C1 = CFrame.new(0, -head.Size.Y / 2, 0) * neck.C1.Rotation
			else
				local ok = pcall(function()
					character:ScaleTo(1.5)
				end)
				if not ok then
					warn(`[PaintMutationEffects] BigHead failed for {player.Name}`)
				end
			end
		end
	elseif effectName == "TinyBody" then
		local ok, currentScale = pcall(function()
			return character:GetScale()
		end)
		cache.modelScale = ok and currentScale or 1
		if humanoid then
			cache.walkSpeed = humanoid.WalkSpeed
			cache.hipHeight = humanoid.HipHeight
			cache.jumpPower = humanoid.JumpPower
			cache.jumpHeight = humanoid.JumpHeight
			humanoid.WalkSpeed = humanoid.WalkSpeed * 1.5
			humanoid.HipHeight = humanoid.HipHeight * 0.5
			humanoid.JumpPower = 90
			humanoid.JumpHeight = 18
		end
		pcall(function()
			character:ScaleTo(0.5)
		end)
	elseif effectName == "LowGravity" then
		cache.gravity = workspace.Gravity
		workspace.Gravity = 22
	elseif effectName == "SuperJump" then
		if humanoid then
			cache.jumpPower = humanoid.JumpPower
			cache.jumpHeight = humanoid.JumpHeight
			humanoid.JumpPower = 120
			humanoid.JumpHeight = 25
		end
	elseif effectName == "ForcedBrightColor" then
		local color = ModifierUtils.randomBrightColor()
		cache.color = color
		cache.colors = {}

		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				cache.colors[part] = part.Color
				StudsConverter.paintPart(part, color)
			end
		end
	end
end

function PaintMutationEffects.reset(player: Player)
	local cache = playerCaches[player]
	if not cache then
		return
	end
	print(`[PaintMutationEffects] resetting {cache.effect} for {player.Name}`)
	playerCaches[player] = nil

	local character = player.Character
	if not character then
		return
	end

	if cache.effect == "BigHead" then
		if cache.headScale then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local headScale = humanoid and humanoid:FindFirstChild("HeadScale")
			if headScale and headScale:IsA("NumberValue") then
				headScale.Value = cache.headScale
			end
		elseif cache.headSize then
			local head = character:FindFirstChild("Head")
			local torso = character:FindFirstChild("Torso")
			local neck = torso and torso:FindFirstChild("Neck")
			local mesh = head and head:FindFirstChildOfClass("SpecialMesh")
			if head and head:IsA("BasePart") then
				head.Size = cache.headSize
			end
			if mesh and cache.meshScale then
				mesh.Scale = cache.meshScale
			end
			if neck and neck:IsA("Motor6D") and cache.neckC1 then
				neck.C1 = cache.neckC1
			end
		else
			pcall(function()
				character:ScaleTo(cache.modelScale or 1)
			end)
		end
	elseif cache.effect == "TinyBody" then
		pcall(function()
			character:ScaleTo(cache.modelScale or 1)
		end)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if cache.walkSpeed then
				humanoid.WalkSpeed = cache.walkSpeed
			end
			if cache.hipHeight then
				humanoid.HipHeight = cache.hipHeight
			end
			if cache.jumpPower then
				humanoid.JumpPower = cache.jumpPower
			end
			if cache.jumpHeight then
				humanoid.JumpHeight = cache.jumpHeight
			end
		end
	elseif cache.effect == "LowGravity" then
		if cache.gravity then
			workspace.Gravity = cache.gravity
		end
	elseif cache.effect == "SuperJump" then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if cache.jumpPower then
				humanoid.JumpPower = cache.jumpPower
			end
			if cache.jumpHeight then
				humanoid.JumpHeight = cache.jumpHeight
			end
		end
	elseif cache.effect == "ForcedBrightColor" then
		if cache.colors then
			for part, color in pairs(cache.colors) do
				if part and part.Parent then
					part.Color = color
					local tex = part:FindFirstChild("StudsCamoTexture")
					if tex and tex:IsA("Texture") then
						tex.Color3 = color
					end
				end
			end
		end
	end
end

function PaintMutationEffects.resetAll()
	local players = {}
	for player in pairs(playerCaches) do
		table.insert(players, player)
	end
	for _, player in ipairs(players) do
		PaintMutationEffects.reset(player)
	end
end

Players.PlayerRemoving:Connect(function(player)
	playerCaches[player] = nil
end)

return PaintMutationEffects
