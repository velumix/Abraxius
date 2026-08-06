-- Modules // Services 
local ReplicatedStorage = game:GetService("ReplicatedStorage") 
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Mince = require(ReplicatedStorage.Modules.Mince)

local RaceManager = Mince:Get("RaceManager")

local DoorComponent = Mince.Component {
	Tag = "Door",
	
	DoorCloseWait = 2,
	DoorAllowWait = 1,
	CheckDoorRate = 0.5, 
	DirectionCancel = Vector3.new(0,0,1),
	
	AllowedSpeeds = {
		[1]=true,[2]=true,[3]=true,[4]=true
	}, 
	AllowedDirections = {
		["Front"] = true, 
		["Back"] = true 
	}, 
	
	CreationParents = {game.Workspace},
	CommunicationMethods = {"OpenDoor"}
}

function DoorComponent:Update(DeltaTime) 
	if self.DoorOpen  then 
		self.CheckDoorTime += DeltaTime 

		if self.CheckDoorTime > self.CheckDoorRate then 
			self.CheckDoorTime = 0 

			local Hitbox : BasePart = self.Hitbox  
			local TouchingParts = workspace:GetPartsInPart(Hitbox)

			for _,BasePart in TouchingParts do 
				if BasePart:IsA("BasePart") then 
					if BasePart.Name == "HumanoidRootPart" and BasePart.Parent  and BasePart.Parent:IsA("Model") then 
						self.CloseDoorTimer = self.DoorCloseWait
					end
				end
			end
		end

		self.CloseDoorTimer -= DeltaTime 

		if self.CloseDoorTimer < 0 then

			self.Instance:SetAttribute("DoorOpen", false)
		end
	else 
		self.AllowDoorTimer -= DeltaTime
		if self.AllowDoorTimer < 0 then 
			if not self.DoorCanOpen then 
				self.Instance:SetAttribute("DoorCanOpen", true)
			end
		end
	end
end

function DoorComponent:OpenDoor(Player : Player, Direction, Speed)
	warn(Player, Direction, Speed)
	if not self.AllowedDirections[Direction] or not self.AllowedSpeeds[Speed] then return end 
	if self.DoorOpen then 
		return 
	end
	
	
	
	self.AllowDoorTimer = self.DoorAllowWait 
	self.CloseDoorTimer = self.DoorCloseWait

	self.Instance:SetAttribute("Speed",       Speed)
	self.Instance:SetAttribute("Direction",   Direction)
	self.Instance:SetAttribute("DoorOpen",    true)
	self.Instance:SetAttribute("DoorCanOpen", false)
end

function DoorComponent:Construct() 
	self.Hitbox = self.Instance:WaitForChild("Hitbox") 

	self.CheckDoorTime = 0 
	self.AllowDoorTimer = 0 
	self.CloseDoorTimer = 0 
	
	RunService.Heartbeat:Connect(function(DeltaTime) 
		self:Update(DeltaTime)
	end)
end

return DoorComponent