local Maid = require(script.Maid)
local EnemyContents = require(script.EnemyContents) 

local BaseEnemy = {} 
BaseEnemy.__index = BaseEnemy

function BaseEnemy.new(Proto) 
	local NewEnemy = setmetatable(Proto or {} ,BaseEnemy)
	NewEnemy:Init() 
	return NewEnemy
end

function BaseEnemy:inherit() 
	local InheritEnemy = {}
	setmetatable(InheritEnemy, self)
	InheritEnemy.__index = InheritEnemy
	return InheritEnemy
end 

function BaseEnemy:Init() 
	local Properties = {
		ClassName = "BaseEnemy",
		-- Base Class Settings 
		DestroyAfterDeathTime = 5,
		StartTargetingAfter = 2,
		LockTargetRange = 10, 
		TargetCheckRate = 0.2, 
		ShiftLookDistance = 0.1,
		TargetPlayerArray = {},
		UpdateStack = {},
		DoesTargeting = true,
		StackUpdate = true,
		FacesWhenDamaged = true, 
		ShouldReplicatePosition = true,
		LastProjectileCount = 0,
		
		
		Events = {}, 
		
		-- Standard Enemy Vlaues 
		Speed = 0,
		Dead = false,
		Health = 100,
		MaxHealth = 100,
		Invulnerable = false,
		LastDamaged = tick()-1000000,
		EnemyImpacts = {},

		-- Targeting // Rotaiotn -- 
		Rotation = 0,
		EaseAngle = 0,
		ProjectionCompesationStuds = 0.4,
		LastTargetCheck =tick()-10000000, 
	} 

	for Name,Value in pairs(Properties) do 
		self[Name] = Value 
	end 


	if not self.Damage then self.Damage = 0 end 

	self.Maid = Maid.new() 
	self._Update = function() end
	self.Y_CANCEL = Vector3.new(1,0,1)

	Properties = nil -- Cleanup values!
end

function BaseEnemy:SetHealthExtent(Health) 
	self.Health = Health
	self.MaxHealth = Health
end

function BaseEnemy:CreateEnemyController(InheritedValues) 
	local Defaults = {
		Level = 0, 
		Health = 0, 
	}

	local Target = Instance.new("ObjectValue") 
	Target.Name = "Target"
	
	local EnemyController = Instance.new("Configuration") 
	Target.Parent = EnemyController

	for Name,Value in Defaults do 
		EnemyController:SetAttribute(Name,Value)
	end
	
	if InheritedValues then 
		for Name,Value in InheritedValues do 
			EnemyController:SetAttribute(Name,Value)
		end
	end

	EnemyController:SetAttribute("Health",self.Health)
	EnemyController:SetAttribute("MaxHealth",self.Health)

	local Replicate = Instance.new("RemoteEvent") 
	Replicate.Name = "Replication"
	Replicate.Parent = EnemyController

	self.ReplicationEvent = Replicate
	self.TargetValue = Target	

	self.EnemyController = EnemyController 

	return EnemyController
end

function BaseEnemy:SetupMover(TargetPosition, Anchored) 
	local Mover = script.EnemyMover:Clone()

	if Anchored == nil then Anchored = false end 


	self.MoverOrginPosition = TargetPosition
	self.Mover = Mover
	self.Attachment = Mover.Attachment 
	self.AlignOrientation = Mover.AlignOrientation

	self.MoverGroundOffset = Mover.Size * Vector3.yAxis * 0.5 

	Mover.Anchored = true 
	Mover.Parent = game.Workspace.Camera
	Mover.CFrame = CFrame.new(TargetPosition + ((Mover.Size * Vector3.yAxis)/2) )

	task.wait()
	Mover.Anchored = false 
	Mover:SetNetworkOwner(nil)

	Mover.Anchored = Anchored
	Mover.CollisionGroup = "Players"

	Mover.Destroying:Connect(function() 
		self:Kill(true) 
	end)


	self.LastPosition = TargetPosition

	for _,BasePart : BasePart in Mover:GetDescendants() do 
		if BasePart:IsA("BasePart") then
			BasePart:SetNetworkOwner(nil)
			BasePart.CollisionGroup = "Players"
		end 
	end

	return Mover
end


function BaseEnemy:Kill(ForceKill) 
	if self.Dead then return end 
	if self.Invulnerable then return end 
	if self.UponDyingCallback and not ForceKill then self.UponDyingCallback() end 

	-- Only rpelicate what needs to be replicated
	self.EnemyController:SetAttribute("Dead", true)
	self.Health = 0
	
	self:SendState("Dead")
	self:Replicate() 
	self:RidTarget()
	self.Dead = true 
	self.Mover.Anchored = true 
	self.Mover.CanCollide = false 
	self.LockEnemyFromUpdating = true 
	self.LockEnemyFromReplicating = true 
	
	self:Call("Death")

	local DeathFunction = function() 
		if self.EnemyController then 
			self.EnemyController:Destroy() 
		end
		if self.Mover then 
			self.Mover:Destroy() 
		end
		self = nil	
	end

	task.delay(self.DestroyAfterDeathTime ,DeathFunction)
end

function BaseEnemy:TakeDamage(Damage, Origin, IsCritical) 
	if IsCritical then 
		Damage *= 2
	end

	if not self.Invulnerable then 
		self.Health -= Damage
	end 

	self:Call("Hit")
	self.LastDamaged = tick() 
	self.EnemyController:SetAttribute("Health", math.round(self.Health)) -- Attribute set after aysnc stuff!

	if self.FacesWhenDamaged then 
		if Origin then 
			self:LookAt(Origin)
		end
	end

	if self.Health <= 0 then  
		if Origin then 
			self:LookAt(Origin)
		end
		self:CreateIndicator(`FATAL {math.round(Damage)}`)
		self:Kill()
	else 
		self:SendState("Damaged")

		if IsCritical then 
			self:CreateIndicator(`CRIT {math.round(Damage)}`,Color3.new(0.580392, 0.160784, 1))
		else 
			self:CreateIndicator(math.round(Damage))
		end


		if self.FacesWhenDamaged then 
			self:Replicate(Origin) 	
		else 
			self:Replicate()
		end
	end
end

function BaseEnemy:SendState(State, ...) 
	for _,Player in self:GetTargets() do
		self.ReplicationEvent:FireClient(Player, "G", State, ...)
	end	
end

function BaseEnemy:CreateIndicator(Text,Color) 
	for _,Player in self:GetTargets() do
		self.ReplicationEvent:FireClient(Player, "I", Text, Color)	
	end
end

function BaseEnemy:IndicateMiss() 
	self:CreateIndicator("Miss",Color3.new(1,1,1))
end

function BaseEnemy:CreateImpact(Position, ImpactTime, IsServerDamaged) 
	local EnemyImpact = {
		ImpactTime = ImpactTime,
		EndingTimestamp = game.Workspace:GetServerTimeNow() + ImpactTime,
		Position = Position,
		Telegraphed = true, 
		Name = "Default",
		Radius = 5,
		BufferRadius = 0,
		Damage = 10,
		ImpactEffector = Vector3.new(1, 1, 1),
	} 

	

	EnemyImpact.ImpactFn = function() 
		for _,Player : Player in self:GetTargets() do
			local HumanoidRootPart : BasePart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") 
			local Humanoid : Humanoid = Player.Character and Player.Character:FindFirstChild("Humanoid")
			if HumanoidRootPart and Humanoid then 
				local Distance = (
					(HumanoidRootPart.Position * EnemyImpact.ImpactEffector) - 
						((EnemyImpact.HitPosition or EnemyImpact.Position) * EnemyImpact.ImpactEffector)
				).Magnitude 
					
				if Distance < EnemyImpact.Radius-EnemyImpact.BufferRadius then
					warn("------>", Distance, EnemyImpact.Damage)
					Humanoid:TakeDamage(EnemyImpact.Damage)
				end
			end
		end

		EnemyImpact = nil 
	end 

	if IsServerDamaged then task.delay(ImpactTime, EnemyImpact.ImpactFn) end 
	
	
	table.insert(self.EnemyImpacts, EnemyImpact)
	return EnemyImpact
end

function BaseEnemy:PositionShouldReplicate(Bool)
	if Bool then 
		if not self.ShouldReplicatePosition then 
			self.ShouldReplicatePosition = true 
			self.LastReplicatedPosition += Vector3.one * 0.001
		end
	else 
		self.ShouldReplicatePosition = false 
	end
end

function BaseEnemy:GetDirectionVector()
	return CFrame.Angles(0,math.rad(self.Rotation),0).LookVector
end

function BaseEnemy:SetRotation(Rotation) 
	self.Rotation = Rotation 
end

function BaseEnemy:LookAt(LookPosition, Ease)
	local Angle = math.deg(math.atan2(self.Mover.Position.X-LookPosition.X, self.Mover.Position.Z-LookPosition.Z))

	self.Rotation = Angle 
end



function BaseEnemy:AutoLook() 
	local Distance =(self.LastPosition - self.Mover.Position).Magnitude

	if Distance > (self.ShiftLookDistance * self.NormalizedDelta)then 
		local Angle = math.deg(math.atan2(self.LastPosition.X-self.Mover.Position.X, self.LastPosition.Z-self.Mover.Position.Z))

		self.Rotation = Angle 
	end
end

function BaseEnemy:Call(Index,...)
	local Connected = self.Events[Index] 

	if Connected then 
		for Connection,CallbackFn in Connected do 
			task.defer(CallbackFn, ...) 
		end
	end
end

function BaseEnemy:On(Index,CallbackFn)
	self.Events[Index] = {} 

	local Connection = newproxy(false)
	self.Events[Index][Connection] = CallbackFn

	return {
		Disconnect = function() 
			self.Events[Index][Connection] = nil 
			Connection = nil 
		end,
	}
end


function BaseEnemy:Rotate(Angle) 
	self.Rotation += Angle 
	self.Rotation = self.Rotation % 360 
end

function BaseEnemy:GetProjectedPosition(Target, Mult) 
	if Target then 
		if Target.AssemblyLinearVelocity == Vector3.zero then
			return Target.Position
		end 
		local ProjectedPosition = Target.Position + (Target.AssemblyLinearVelocity.Unit * Vector3.new(1,0,1) * self.ProjectionCompesationStuds * (Mult or 1))

		return ProjectedPosition
	end
end

function BaseEnemy:GetProjectedTargetPosition(Mult) 
	if self.TargetHRP then 
		if self.TargetHRP.AssemblyLinearVelocity == Vector3.zero then 
			return self.TargetHRP.Position
		end
		local ProjectedPosition = self.TargetHRP.Position + (self.TargetHRP.AssemblyLinearVelocity.Unit * self.ProjectionCompesationStuds * (Mult or 1))

		return ProjectedPosition
	end
end


-- Player Effecting Util 

function BaseEnemy:KnockbackPlayer(Player,Origin,Intensity,Y_FORCE) 
	local Character = Player.Character 
	local HumanoidRootPart = Character and Character:FindFirstChild("HumanoidRootPart")  

	Intensity += 1 
	if HumanoidRootPart then 
		local BodyVelocity = Instance.new("BodyVelocity", HumanoidRootPart)
		BodyVelocity.MaxForce = Vector3.new(math.huge,math.huge,math.huge)
		BodyVelocity.P = 300

		local Angle = (((HumanoidRootPart.Position - Origin) * Vector3.new(10,0,10)).Unit * (7*Intensity)) + Vector3.new(0,(Y_FORCE or 0.5)*Intensity,0)
		BodyVelocity.Velocity = Angle 
		game:GetService("Debris"):AddItem(BodyVelocity,.3)
	end
end


function BaseEnemy:SetTarget(Player : Player | {Player : Player}) 
	if not Player then 
		warn("Can't set target when target is nil!")
		return 
	end
	
	
	if typeof(Player) == "table" then 
		self:RidTarget() 
		self:__SetTarget(Player.Player)
		return 
	end 
	
	
	self:RidTarget() 
	self:__SetTarget(Player)
end

function BaseEnemy:__SetTarget(Player : Player)
	local HumanoidRootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")  
	local Humanoid = Player.Character and Player.Character:FindFirstChild("Humanoid") 

	if HumanoidRootPart and Humanoid then
		if self.__TargetListenDestroyingConnection then 
			self.__TargetListenDestroyingConnection:Disconnect() 
		end
		if self.__TargetListenDeathConnection then 
			self.__TargetListenDeathConnection:Disconnect() 
		end

		local __TargetAttachment = HumanoidRootPart:FindFirstChild("TargetAttachment") 
		if __TargetAttachment == nil  then 
			__TargetAttachment = Instance.new("Attachment")
			__TargetAttachment.Name = "TargetAttachment"
			__TargetAttachment.Parent = HumanoidRootPart
		end
		self.TargetAttachment = __TargetAttachment


		self.TargetHumanoid = Humanoid
		self.TargetHRP = HumanoidRootPart
		self.Target = Player 
		self.TargetCharacter = Player.Character
		self.TargetValue.Value = Player

		self.__TargetListenDeathConnection = Humanoid.Died:Once(function() 
			if self.TargetHumanoid == Humanoid then 
				self:RidTarget()
			end
		end)
		self.__TargetListenDestroyingConnection = Player.Character.Destroying:Once(function() 
			if self.TargetHRP == HumanoidRootPart then 
				self:RidTarget() 
			end
		end)
	end
end 

function BaseEnemy:ValidateTarget() 
	if self.Target then 
		for _, Player in self.TargetPlayerArray do  
			if Player == self.Target then 
				return 
			end 
		end
		self:RidTarget() 
	end
end

function BaseEnemy:CheckTargetExistance() 
	if not self.TargetHRP or self.TargetHRP.Parent == nil then 
		self.Target = nil 
	end
end


function BaseEnemy:TargetCheck() 
	if self.Target then 
		-- Prevent from reading a non-existant target
		self:CheckTargetExistance() 
		if not self.Target then 
			return self:TargetCheck() -- Try again
		end

		local Distance = (self.TargetHRP.Position - self.Mover.Position).Magnitude
		self.SavedTargetDistance = Distance
		if self.SavedTargetDistance < self.LockTargetRange then 
			return -- Prevent the trarget from switching
		end
	end

	local GreatestDistance , ClosestPlayer = math.huge , nil 
	for _,Player in self.TargetPlayerArray do 
		local HumanoidRootPart : BasePart= Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") 
		if HumanoidRootPart then 
			local Distance = (HumanoidRootPart.Position - self.Mover.Position).Magnitude

			if Distance < GreatestDistance then 
				GreatestDistance = Distance 
				ClosestPlayer = Player
			end
		end 
	end 

	-- You've now found the closest player!
	if ClosestPlayer then 
		self:__SetTarget(ClosestPlayer)
	end
end

function BaseEnemy:RidTarget() 
	self.TargetHumanoid = nil 
	self.TargetHRP = nil 
	self.Target = nil 
	self.TargetCharacter = nil 
	self.TargetValue.Value = nil 

	-- Reileve connections bceause they are no-longer needed.
	if self.__TargetListenDestroyingConnection then 
		self.__TargetListenDestroyingConnection:Disconnect() 
	end
	if self.__TargetListenDeathConnection then 
		self.__TargetListenDeathConnection:Disconnect() 
	end
end

function BaseEnemy:GetRandomPlayer()
	local Players = self:GetTargets()
	local Player : Player = Players[math.random(1, #Players)] 
	
	local HumanoidRootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")  
	local Humanoid = Player.Character and Player.Character:FindFirstChild("Humanoid") 
	
	if HumanoidRootPart and Humanoid then 
		return {
			Player = Player, 
			HRP = HumanoidRootPart, 
			Humanoid = Humanoid 
		}
	end 
end

function BaseEnemy:FindFarthestPlayer() 
	local GreatestDistance, FarthestPlayer = -1, nil
	for _, Player in self.TargetPlayerArray do
		local HumanoidRootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
		if HumanoidRootPart then
			local Distance = (HumanoidRootPart.Position - self.Mover.Position).Magnitude

			if Distance > GreatestDistance then -- Corrected comparison
				GreatestDistance = Distance
				FarthestPlayer = Player
			end
		end
	end
	
	if not FarthestPlayer then return end 

	local HumanoidRootPart = FarthestPlayer.Character and FarthestPlayer.Character:FindFirstChild("HumanoidRootPart")  
	local Humanoid = FarthestPlayer.Character and FarthestPlayer.Character:FindFirstChild("Humanoid") 
	
	if HumanoidRootPart and Humanoid then 
		return {
			Player = FarthestPlayer, 
			HRP = HumanoidRootPart, 
			Humanoid = Humanoid 
		}
	end 
end

function BaseEnemy:ConvEnemyImpacts()
	local BoolToInt = {[true]=1,[false]=0}
	local Resolution = 10
	local Data = "" 

	for _,EnemyImpact in self.EnemyImpacts do 
		local X = math.round(EnemyImpact.Position.X*Resolution)
		local Y = math.round(EnemyImpact.Position.Y*Resolution)
		local Z = math.round(EnemyImpact.Position.Z*Resolution)
		Data ..= string.pack("I1bI1i2i2i2I2I1n", EnemyImpact.Radius, 
			BoolToInt[EnemyImpact.Telegraphed], 
			EnemyContents.EffectNames[EnemyImpact.Name], 
			X, Y, Z, EnemyImpact.Damage, math.round(EnemyImpact.ImpactEffector.Y*Resolution),  EnemyImpact.EndingTimestamp)
	end

	return Data 
end

function BaseEnemy:ConvPosition() 
	local PositionOffset = self.Mover.Position - ((Vector3.yAxis * self.Mover.Size)/2)
	local Resolution = 10
	local X = math.round(PositionOffset.X*Resolution)
	local Y = math.round(PositionOffset.Y*Resolution)
	local Z = math.round(PositionOffset.Z*Resolution)
	return Vector2int16.new(X,Y) , Vector2int16.new(Z,math.round(self.Rotation*Resolution))
end


function BaseEnemy:Update(DeltaTime) 
	if self.LockEnemyFromUpdating then return end
	local CurrentTick = tick() 
	if self.DoesTargeting then 
		local TimeSenceLastTargetCheck = CurrentTick-self.LastTargetCheck 
		if self.Target == nil or TimeSenceLastTargetCheck > self.TargetCheckRate then
			self.LastTargetCheck = CurrentTick
			self:TargetCheck() 
		end
	end

	self.NormalizedDelta = DeltaTime * 60 

	local OrginDistance = (self.MoverOrginPosition - self.Mover.Position).Magnitude
	if OrginDistance > 500 then 
		warn("IS TO FAR AWAY FORM ORIGIN")
		self:Kill()
	end 
	
	if self.StackUpdate then 
		for _,UpdateMethod in self.UpdateStack do 
			UpdateMethod(self, DeltaTime)
		end
	end
	
	self:_Update(DeltaTime)

	self.LastPosition = self.Mover.Position
end


function BaseEnemy:ReplicateToPlayer(Player) 
	self.ReplicationEvent:FireClient(Player, "_", self:ConvPosition())	
	if #self.EnemyImpacts > 0  then
		self.ReplicationEvent:FireClient(Player,"E",self:ConvEnemyImpacts())
	end 
end

function BaseEnemy:Replicate(...)
	if self.LockEnemyFromReplicating then return end 

	local ProjectileCount = 0 
	for _,Player in self:GetTargets() do

		if self.ShouldReplicatePosition and self.LastReplicatedPosition ~= self.Mover.Position or
			self.LastReplicatedRotation ~= self.Rotation and self.ShouldReplicatePosition  then 
			--warn(self.LastReplicatedPosition,self.Mover.Position)
			self.ReplicationEvent:FireClient(Player, "_", self:ConvPosition())	
		end

		if #self.EnemyImpacts > 0  then
			self.ReplicationEvent:FireClient(Player, "E", self:ConvEnemyImpacts())
		end
	end

	if self.EnemyImpacts then 
		self.EnemyImpacts = {}
	end

	self.LastProjectileCount = ProjectileCount
	self.LastReplicatedRotation = self.Rotation
	self.LastReplicatedPosition = self.Mover.Position 
	self.LastReplicatedState = self.State  
end

function BaseEnemy:GetTargets() 
	if self.Dead then 
		return {} 	
	end 
	return self.TargetPlayerArray
end 

function BaseEnemy:SetTargets(TargetList : {Player}) 
	self.TargetPlayerArray = TargetList 
	self:ValidateTarget() 
end

return BaseEnemy
