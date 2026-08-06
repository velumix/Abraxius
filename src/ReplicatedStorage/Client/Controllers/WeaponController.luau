--!strict
-- @author Velumix
-- @version 0.0.1
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Knit = require(ReplicatedStorage.Modules.Knit) :: typeof(require(ReplicatedStorage.Modules.Knit.KnitClient))
local Signal = require(ReplicatedStorage.Modules.Signal)
local WeaponComponent = require(ReplicatedStorage.Client.Components.WeaponComponent)

local WeaponController = Knit.CreateController({
	Name = "WeaponController",
})

WeaponController.ComponentStarted = Signal.new()
WeaponController.ComponentStopped = Signal.new()

function WeaponController:GetComponent(tool: Tool)
	return WeaponComponent:FromInstance(tool)
end

local function renderImpact(position: Vector3, normal: Vector3, isCharacter: boolean, color: Color3)
	print("[WeaponDebug][Client] renderImpact received", position, normal, isCharacter, color)
	local source = ReplicatedStorage.Assets.Bullets:FindFirstChild("Bullet")
	if not source or not source:IsA("Part") then
		warn("[WeaponDebug][Client] ReplicatedStorage.Assets.Bullets.Bullet is missing or not a Part")
		return
	end
	local impact = source:Clone()
	impact.Name = if isCharacter then "BloodImpact" else "BulletImpact"
	impact.Anchored = true
	impact.CanCollide = false
	impact.CanQuery = false
	impact.CanTouch = false
	impact.CFrame = CFrame.new(position + normal * 0.04)
	impact.Transparency = if isCharacter then 1 else 0
	impact.Color = if isCharacter then Color3.fromRGB(130, 0, 0) else Color3.fromRGB(57, 57, 57)
	impact.Parent = workspace
	print("[WeaponDebug][Client] Impact clone created", impact:GetFullName())
	local sound = impact:FindFirstChild("Impact")
	if sound and sound:IsA("Sound") then
		sound:Play()
		print("[WeaponDebug][Client] Impact sound played")
	else
		warn("[WeaponDebug][Client] Impact sound missing")
	end
	local emitter = impact:FindFirstChild(if isCharacter then "BloodHit" else "Concret")
	if emitter and emitter:IsA("ParticleEmitter") then
		emitter.Color = ColorSequence.new(color)
		emitter:Emit(if isCharacter then 30 else 50)
		print("[WeaponDebug][Client] Impact emitter fired", emitter.Name)
	else
		warn("[WeaponDebug][Client] Impact emitter missing", isCharacter and "BloodHit" or "Concret")
	end
	Debris:AddItem(impact, if isCharacter then 1 else 8)
end

function WeaponController:KnitStart()
	local service = Knit.GetService("WeaponService")
	service.WeaponImpact:Connect(renderImpact)
	WeaponComponent.Started:Connect(function(component)
		self.ComponentStarted:Fire(component)
	end)
	WeaponComponent.Stopped:Connect(function(component)
		self.ComponentStopped:Fire(component)
	end)
end

return WeaponController
