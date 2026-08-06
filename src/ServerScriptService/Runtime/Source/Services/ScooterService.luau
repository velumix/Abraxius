local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)
local StoreItems = require(ReplicatedStorage.Runtime.Config.StoreItems)

local SpeedBoostService = require(ServerStorage.Modules.Services.SpeedBoostService)

local function getToolSpeedMultiplier(itemData)
	local stats = itemData and itemData.Stats
	if not stats then
		return nil
	end

	local multiplier = stats.SwimSpeedMultiplier or stats.SpeedMultiplier
	if typeof(multiplier) == "number" then
		return math.max(multiplier, 0)
	end

	local swimSpeed = stats.SwimSpeed
	if typeof(swimSpeed) == "number" then
		return math.max(1 + swimSpeed, 0)
	end

	return nil
end

local ScooterService = {
	Name = "ScooterService",
	ActiveScooters = {},

	ScooterEvent = nil,
	Register = nil,
	Unregister = nil,
	UpdateSpeed = nil,
}

function ScooterService:UpdateScooterRotation(player, rotationSpeed)
	local scooterData = self.ActiveScooters[player]
	if not scooterData then
		return
	end
	scooterData.RotationSpeed = rotationSpeed
end

function ScooterService:RegisterScooter(player, tool)
	if not tool then return end

	local hasTag = CollectionService:HasTag(tool, "SingleDPV")
	local isScooter = tool.Name == "Scooter"

	if not (hasTag or isScooter) then
		return
	end

	if not (player and player:GetAttribute("Swimming") == true) then
		local character = player and player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:UnequipTools()
		end
		return
	end

	local rotationAttachment = tool:FindFirstChild("Rotation", true)
	local emitter = tool:FindFirstChild("Emitter", true)

	if not rotationAttachment or not rotationAttachment:IsA("Attachment") then
		warn("Rotation attachment not found")
		return
	end

	if not emitter or not emitter:IsA("ParticleEmitter") then
		warn("Emitter not found")
		return
	end

	local toolMultiplier = tool:GetAttribute("ToolSwimSpeedMultiplier")
	if typeof(toolMultiplier) ~= "number" then
		local storeItemName = tool:GetAttribute("StoreItemName") or tool.Name
		local toolData = StoreItems.Categories.Tools and StoreItems.Categories.Tools[storeItemName]
		toolMultiplier = getToolSpeedMultiplier(toolData) or 2.5
		tool:SetAttribute("ToolSwimSpeedMultiplier", toolMultiplier)
	end

	self.ActiveScooters[player] = {
		Tool = tool,
		RotationAttachment = rotationAttachment,
		Emitter = emitter,
		RotationSpeed = 0,
		OriginalCFrame = rotationAttachment.CFrame,
		BoostMultiplier = toolMultiplier,
	}
	SpeedBoostService:Apply(player, tool, self.ActiveScooters[player].BoostMultiplier)
end

function ScooterService:UnregisterScooter(player)
	local scooterData = self.ActiveScooters[player]
	if scooterData then
		scooterData.RotationAttachment.CFrame = scooterData.OriginalCFrame
		SpeedBoostService:Clear(player, scooterData.Tool or player)
		self.ActiveScooters[player] = nil
	end
end

function ScooterService:UpdateRotations(dt)
	for player, scooterData in self.ActiveScooters do
		if scooterData.RotationAttachment and scooterData.RotationAttachment.Parent then
			local rotationAngle = math.rad(scooterData.RotationSpeed * dt * 60)
			scooterData.RotationAttachment.CFrame = scooterData.RotationAttachment.CFrame * CFrame.Angles(rotationAngle, 0, 0)

			if scooterData.Emitter then
				scooterData.Emitter.Rate = scooterData.RotationSpeed
			end
		else
			self.ActiveScooters[player] = nil
		end
	end
end

function ScooterService:GameStart()
	self.ScooterEvent = Mince:GetEvent("Scooter")

	self.Register = self.ScooterEvent:Extend("Register")
	self.Unregister = self.ScooterEvent:Extend("Unregister")
	self.UpdateSpeed = self.ScooterEvent:Extend("UpdateSpeed")

	self.Register.Event:Connect(function(player, tool)
		self:RegisterScooter(player, tool)
	end)

	self.Unregister.Event:Connect(function(player)
		self:UnregisterScooter(player)
	end)

	self.UpdateSpeed.Event:Connect(function(player, rotationSpeed)
		self:UpdateScooterRotation(player, rotationSpeed)
	end)

	RunService.Heartbeat:Connect(function(dt)
		self:UpdateRotations(dt)
	end)
end

function ScooterService:Cleanup()
	self.ActiveScooters = {}
end

return ScooterService
