local Deepcopy = require(game.ReplicatedStorage.Modules.Deepcopy)
local Snowman = require(script.Parent):inherit()
Snowman.__index = Snowman

local function RotatePointAtDist2( Origin, Angle, Dist)
	local Point = Origin + Vector3.new(0,0,Dist)
	local S, C  = math.sin(math.rad(Angle)), math.cos(math.rad(Angle))
	local X = (Point.x - Origin.X) *  C - (Point.Z - Origin.Z) * S + Origin.X
	local Z = (Point.x - Origin.X) * S + (Point.Z - Origin.Z)*  C + Origin.Z
	return Vector3.new(X, Origin.Y, Z)
end

function Snowman.new(Proto) 
	local NewEnemy = setmetatable(Proto or {} ,Snowman)
	NewEnemy:Init() 
	NewEnemy:AIStateEnemyInit()
	NewEnemy:SnowmanInit() 
	return NewEnemy
end

function Snowman:SnowmanInit() 
	self.Speed = 4
	self.RunSpeed = 4
	self.SideSpeed = 4
	self.FacesWhenDamaged = false

	self.CurrentStateList = {}
end	

function Snowman:RunAwayFromPoint(PointToFleeFrom: Vector3)
	local FleeDirection = self.Mover.Position - PointToFleeFrom
	
	FleeDirection *= Vector3.new(1, 0, 1)
	FleeDirection = FleeDirection.Unit
	
	if self.Mover and self.Mover:FindFirstChild("BodyVelocity") then
		local BodyVelocity = self.Mover:FindFirstChild("BodyVelocity")
		BodyVelocity.Velocity = FleeDirection * self.Speed
	else
		warn("No mover bodyvelocity")
	end
end

function Snowman:GetNearestPlayer()
	local NearestPlayer = nil
	local ShortestDistance = math.huge

	for _, Player in game.Players:GetPlayers() do
		if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
			local HRP = Player.Character.HumanoidRootPart
			local Distance = (self.Mover.Position - HRP.Position).Magnitude

			if Distance < ShortestDistance then
				ShortestDistance = Distance
				NearestPlayer = Player
			end
		end
	end
	return NearestPlayer
end

Snowman.AIStates = {} 

Snowman.AIStates.OnError = Snowman.State.new() 
function Snowman.AIStates.OnError:Switch() 
	self:SetState("Spawn")
end

Snowman.AIStates.Spawn = Snowman.State.new() 
function Snowman.AIStates.Spawn:Switch() 
	local Direction : Vector3= Vector3.new(math.random(0, 1), 0, math.random(0, 1)).Unit
	self:LookAt(self.Mover.Position + Direction)
	self:Rotate(-90)
	
	self:SetState("Idle")
end

Snowman.AIStates.Idle = Snowman.State.new() 
function Snowman.AIStates.Idle:Switch()  
	self.ShouldIdle = true
	self.ShouldReplicatePosition = true
	self.Mover.BodyVelocity.Velocity =  Vector3.new() 
	
	repeat task.wait()
	until not self.ShouldIdle
	self:SetState("Run")
end

function Snowman.AIStates.Idle:Update()
	local EffectDistance = 10 

	for _,Player in game.Players:GetPlayers()  do 
		local HumanoidRootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") 
		if HumanoidRootPart then 
			local Distance = (HumanoidRootPart.Position - self.Mover.Position).Magnitude

			if Distance < EffectDistance then 
				self.ShouldIdle = false
			end
		end
	end
end

Snowman.AIStates.Run = Snowman.State.new() 
function Snowman.AIStates.Run:Init() 
	self.JumpTarget = nil 
end

function Snowman.AIStates.Run:Switch() 
	self.ShouldReplicatePosition = true
	self:SendState("SetManualMode", "Run")
	while true do
		local TargetToFleeFrom = self:GetNearestPlayer().Character.HumanoidRootPart
		if (self.Mover.Position - TargetToFleeFrom.Position).Magnitude > 10 then break end
		
		local RunningDuration = 3
		task.wait(RunningDuration)
	end
	local Player = self:GetNearestPlayer()
	if not Player then return self:SetState("Idle") end
	local TargetToFleeFrom = Player.Character:FindFirstChild("HumanoidRootPart")
	
	local Distance = (TargetToFleeFrom.Position - self.Mover.Position).Magnitude
	local Offset = (TargetToFleeFrom.Position - self.Mover.Position)*Vector3.new(1,0,1)
	local Direction : Vector3= Offset.Unit
	
	self:LookAt(self.Mover.Position + Direction)
	self:Rotate(-90)
	
	self.ShouldReplicatePosition = false
	self:SetState("Idle")
end

function Snowman.AIStates.Run:Update(DeltaTime) 
	local Player = self:GetNearestPlayer()
	if not Player then return end
	local TargetToFleeFrom = Player.Character:FindFirstChild("HumanoidRootPart")
	
	if TargetToFleeFrom then
		local Distance = (self.Mover.Position - TargetToFleeFrom.Position).Magnitude
		local Offset = (self.Mover.Position - TargetToFleeFrom.Position)*Vector3.new(1,0,1)
		local Direction : Vector3= Offset.Unit
		self:LookAt(self.Mover.Position + Direction)
		self:Rotate(-90)

		self.Mover.BodyVelocity.Velocity = Direction  * self.RunSpeed
	else 
		self.Mover.BodyVelocity.Velocity =  Vector3.new() 
	end
end

return Snowman