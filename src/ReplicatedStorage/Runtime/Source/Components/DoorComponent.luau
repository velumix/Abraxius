-- Modules // Services -- 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer

local Maid = require(ReplicatedStorage.Modules.Maid)
local Mince = require(ReplicatedStorage.Modules.Mince)
local ModelTween = require(ReplicatedStorage.Modules.ModelTween)

local DoorComponent = Mince.Component {
    Tag = "Door",
	DirectionCancel = Vector3.new(0,0,1),
	DoorTweens = {
		["Default"] = {
			[1] =  TweenInfo.new(1,Enum.EasingStyle.Bounce),
			[2] = TweenInfo.new(0.8,Enum.EasingStyle.Bounce),
			[3] = TweenInfo.new(0.5,Enum.EasingStyle.Bounce),
			[4] = TweenInfo.new(0.2,Enum.EasingStyle.Bounce),	
			["Close"] = TweenInfo.new(1,Enum.EasingStyle.Bounce)
		},
		["Heavy"] = {
			[1] = TweenInfo.new(0.7,Enum.EasingStyle.Sine),
			[2] = TweenInfo.new(0.5,Enum.EasingStyle.Sine),
			[3] = TweenInfo.new(0.3,Enum.EasingStyle.Sine),
			[4] = TweenInfo.new(0.1,Enum.EasingStyle.Sine),
			["Close"] = TweenInfo.new(1,Enum.EasingStyle.Sine),
		},
		["Swing"] = {
			[1] = TweenInfo.new(0.8,Enum.EasingStyle.Circular),
			[2] = TweenInfo.new(0.8,Enum.EasingStyle.Circular),
			[3] = TweenInfo.new(0.8,Enum.EasingStyle.Circular),
			[4] = TweenInfo.new(0.8,Enum.EasingStyle.Circular),	
			["Close"] = TweenInfo.new(3,Enum.EasingStyle.Elastic),
		}
	},
	
	HitSpeed =20,	
	Angle = 90,  
	
	CreationParents = { workspace }

}

function DoorComponent:CloseDoor(Direction)  
	for _,BasePart : BasePart in self.Door:GetDescendants() do 
		if BasePart:IsA("BasePart") then 
			BasePart.CanCollide = false  
		end
	end

	if self.LastTween then 
		self.LastTween.Stop() 
		self.LastTween = nil 
	end

	task.wait(); 

	local ClosedDoorPivot : CFrame = self.ClosedDoorPivot
	local ThisTween = ModelTween.new(self.Door, DoorComponent.DoorTweens[self.Type or "Default"].Close, ClosedDoorPivot)
	ThisTween.Play()

	ThisTween.Finished:Connect(function() 
		for _,BasePart : BasePart in self.Door:GetDescendants() do 
			if BasePart:IsA("BasePart") then 
				BasePart.CanCollide = true  
			end
		end
	end)

	local SoundPlayed = false 
	ThisTween.Tick:Connect(function(_,Value)
		if not SoundPlayed and Value >= 0.85 then 
			SoundPlayed = true 
		end
	end)

	self.LastTween = ThisTween
	self.DoorState = "Closed"
end

function DoorComponent:OpenDoor(Direction) 
	local Direction = self.Direction
	if self.DoorState ~= "Closed" then 
		return -- Door is already open so why woulud it open again 
	end

	self.DoorState = Direction 

	for _,BasePart : BasePart in self.Door:GetDescendants() do 
		if BasePart:IsA("BasePart") then 
			BasePart.CanCollide = false 
		end
	end

	local DoorTween = DoorComponent.DoorTweens[self.Type or "Default"][self.Speed or 1]

	if self.LastTween then 
		self.LastTween.Skip()
		self.LastTween = nil  
	end

	if Direction == "Front" then 
		local ClosedDoorPivot : CFrame = self.ClosedDoorPivot
		local RX,RY,RZ = ClosedDoorPivot:ToOrientation()
		local NewAngle = (math.deg(RY) + self.Angle) % 360 
		local EndCFrame = CFrame.new(self.ClosedDoorPivot.Position) * CFrame.fromOrientation(RX, math.rad(NewAngle) ,RZ)

		self.LastTween = ModelTween.new(self.Door,DoorTween,EndCFrame)
		self.LastTween.Play()
	elseif Direction == "Back" then 
		local ClosedDoorPivot : CFrame = self.ClosedDoorPivot
		local RX,RY,RZ = ClosedDoorPivot:ToOrientation()
		local NewAngle = (math.deg(RY) - self.Angle) % 360 
		local EndCFrame = CFrame.new(self.ClosedDoorPivot.Position) * CFrame.fromOrientation(RX, math.rad(NewAngle) ,RZ)

		self.LastTween = ModelTween.new(self.Door,DoorTween,EndCFrame)
		self.LastTween.Play()

	end

	if not self.LastTween then 
		warn()
		return 
	end

	local SoundPlayed = false 
	self.LastTween.Tick:Connect(function(_,Value)
		if not SoundPlayed and Value >= 0.85 then 
			SoundPlayed = true 
		end
	end)

	self.LastTween.Finished:Connect(function() 
		self.LastTween = nil 

		for _,BasePart : BasePart in self.Door:GetDescendants() do 
			if BasePart:IsA("BasePart") then 
				BasePart.CanCollide = true  
			end
		end

		self:ManuallyDetectTouching() 
	end)

end


function DoorComponent:ManuallyDetectTouching() 
	local TouchingParts = game.Workspace:GetPartsInPart(self.Hitbox) 

	for _,Part in TouchingParts do 
		self:HandleTouch(Part)
	end
end

function DoorComponent:HandleTouch(Part) 
	if self.Debounce then return end 
	if Part.Parent and Part.Parent == Player.Character then else return end 
	self.Debounce = true 
	
	if not self.DoorCanOpen then 
		self.Debounce = false 
		return 
	end

	local WalkVelocity = Part.AssemblyLinearVelocity 
	local WalkMagintude = WalkVelocity.Magnitude 

	local Speeds = {0, 20,25.5,30}
	local Speed 
	for SpeedNum,WalkSpeed in Speeds do
		if WalkMagintude > WalkSpeed then 
			Speed = SpeedNum
		end
	end 

	local Direction = self.Hitbox.CFrame:ToObjectSpace(Part.CFrame).Position  				
	local AttackDirection = (Direction *  self.DirectionCancel).Unit.Z  
	local Direction = "Front" 
	if AttackDirection < 0 then 
		Direction = "Back"
	end 
	
	warn(Direction, Speed)

	self.Server:OpenDoor(Direction, Speed)
	self.DoorOpen = true 
	self.Direction = Direction
	self.Speed = Speed 
	self:OpenDoor() 


	task.wait(0.5) -- Prevent from being touched again for a while 
	self.Debounce = false
end

function DoorComponent:Construct()
	self.Maid = Maid.new() 

	self.Door = self.Instance:WaitForChild("Door")
	self.Hitbox = self.Instance:WaitForChild("Hitbox")
	
	self.Hitbox.CanCollide = false 
	self.Hitbox.CanQuery = true 
	self.Hitbox.CanTouch = true 
	
	if self.ReverseAngle then 
		self.Angle *= -1
	end
	
	self.DoorCanOpen = true 

	self.ClosedDoorPivot = self.Door:GetPivot() 
	self.DoorState = "Closed"

	-- because the server now sets it to be uncollideable
	for _,BasePart : BasePart in self.Door:GetDescendants() do 
		if BasePart:IsA("BasePart") then 
			BasePart.CanCollide = true 
		end
	end
	
	self.Maid:Add(self.Instance:GetAttributeChangedSignal("DoorCanOpen"):Connect(function() 
		task.wait() 
		if self.DoorCanOpen then
			self:ManuallyDetectTouching() 
		end
	end))
	
	self.Maid:Add(self.Instance:GetAttributeChangedSignal("DoorOpen"):Connect(function() 
		task.wait() 
		if self.DoorOpen then 
			self:OpenDoor(self.Direction) 
		else  
			self.Debounce = false  
			self:CloseDoor(self.Direction) 
		end
	end))
	
	self.Maid:Add(self.Hitbox.Touched:Connect(function(...)
		self:HandleTouch(...)
	end))
end

return DoorComponent

