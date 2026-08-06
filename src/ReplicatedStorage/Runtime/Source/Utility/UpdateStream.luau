-- Modules // SErvices 
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService('Players')

local LocalPlayer = Players.LocalPlayer

local SpatialHash = require(ReplicatedStorage.Modules.SpatialHash)


local UpdateStream = {
	PartRegistry = {},
	SpatialMap = SpatialHash.NewMap(20), 
	UpdateInterval = 0.2,
	Accumulator = 0,
} 

function UpdateStream:Register(Component, Part : Part | Model) 
	assert(Component.Start, "In order to be registered with the updatestream, you need a START method!")
	assert(Component.Stop, "In order to be registered with the updatestream, you need a STOP method!")
	
	if not Part:IsA("BasePart")  then 
		if Part:IsA("Model") then 
			Part = Part.PrimaryPart or Part:FindFirstChildWhichIsA("BasePart", true)
		else 
			Part = Part:FindFirstChildWhichIsA("BasePart", true)
		end
	end
	
	if (not Part) or (not Part:IsA("BasePart")) then 
		error("Failure to register!")
	end
	
	UpdateStream.PartRegistry[Part] = Component 
	UpdateStream.PartRegistry[Component] = Part
	
	UpdateStream.SpatialMap.Add(Part)
end

function UpdateStream:Remove(Component) 
	local ThisPart = UpdateStream.PartRegistry[Component] 
	if not ThisPart then return end 
	
	task.defer(function() 
		Component:Stop() 
	end)
	
	UpdateStream.SpatialMap.Detach(ThisPart)
	
	UpdateStream.PartRegistry[ThisPart] = nil 
	UpdateStream.PartRegistry[Component] = nil
end

function UpdateStream:UpdateAll(DeltaTime) 
	if not UpdateStream.HumanoidRootPart then return end 

	local PlayerPosition = UpdateStream.HumanoidRootPart.Position 
	local Load = function(Part : BasePart) 
		local Component = UpdateStream.PartRegistry[Part] 
		if not Component then return end 
		
		task.defer(function() 
			Component:Start() 
		end)
	end

	local Deload = function(Part : BasePart) 
		local Component = UpdateStream.PartRegistry[Part]  
		if not Component then return end 
		
		task.defer(function() 
			Component:Stop() 
		end)
	end

	UpdateStream.SpatialMap:StreamFromPosition(PlayerPosition, 2,
		Deload, Load
	)
end

function UpdateStream.NewCharacter(Character)
	local Humanoid : Humanoid = Character:WaitForChild("Humanoid")


	UpdateStream.HumanoidRootPart = Character:WaitForChild("HumanoidRootPart") :: BasePart

	Humanoid.Died:Connect(function() 
		UpdateStream.HumanoidRootPart = nil
	end)
end


function UpdateStream:Setup() 
	LocalPlayer.CharacterAdded:Connect(UpdateStream.NewCharacter)
	RunService.Heartbeat:Connect(function(DeltaTime)
		UpdateStream.Accumulator += DeltaTime
		if UpdateStream.Accumulator < UpdateStream.UpdateInterval then
			return
		end

		local elapsed = UpdateStream.Accumulator
		UpdateStream.Accumulator = 0
		UpdateStream:UpdateAll(elapsed)
	end)

	-- Catch-ups
	if LocalPlayer.Character then 
		UpdateStream.NewCharacter(LocalPlayer.Character)
	end
end


return UpdateStream
