local Deepcopy = require(game.ReplicatedStorage.Modules.Deepcopy)
local Boss = require(script.Parent):inherit()
Boss.__index = Boss


local function RotatePointAtDist2( Origin, Angle, Dist)
	local Point = Origin + Vector3.new(0,0,Dist)
	local S, C  = math.sin(math.rad(Angle)), math.cos(math.rad(Angle))
	local X = (Point.x - Origin.X) *  C - (Point.Z - Origin.Z) * S + Origin.X
	local Z = (Point.x - Origin.X) * S + (Point.Z - Origin.Z)*  C + Origin.Z
	return Vector3.new(X, Origin.Y, Z)
end

function Boss.new(Proto) 
	local NewEnemy = setmetatable(Proto or {} ,Boss)
	NewEnemy:Init() 
	NewEnemy:AIStateEnemyInit()
	NewEnemy:BossInit() 
	return NewEnemy
end

function Boss:BossInit() 
	self.Speed = 13
	self.RunSpeed = 35
	self.SideSpeed = 40 
	self.FacesWhenDamaged = false
	
	self.Phases = {
		{"SpikeJump", "WalkStomp", "HeadDrop", "SpikeLine", "PumpkinRain", "StompStalk"},
		{"TargetSpikes", "SuperJump", "JumpTarget", "SuperStompStalk"}
	} 
	-- JumpTarget, SuperJump
	self.Phase = 1 
	
	self.CurrentStateList = {}
end	


function Boss:GetSwitchState() 
	if self.CurrentPhase ~= self.Phase then 
		self.CurrentStateList = {}
	end
	
	local ThisStateList = self.Phases[self.Phase]
	local TotalCount = #self.CurrentStateList
	if TotalCount <= 0 then 
		self.CurrentPhase = self.Phase
		self.CurrentStateList = Deepcopy(ThisStateList)
	end

	-- Get State and remove it from the list!
	local TotalCount = #self.CurrentStateList 
	local State = self.CurrentStateList[math.random(1,TotalCount)]
	table.remove(self.CurrentStateList,table.find(self.CurrentStateList,State))
	
	return State
end


Boss.AIStates = {} 

Boss.AIStates.OnError = Boss.State.new() 
function Boss.AIStates.OnError:Switch() 
	self:SetState("Spawn")
end

Boss.AIStates.Spawn = Boss.State.new() 
function Boss.AIStates.Spawn:Switch() 
	if self.Health < self.MaxHealth * 0.45 and self.Phase == 1 then 
		self.Phase = 2 
		self:SendState("PlayTrack", "Boss_Music_Phase_2", true)
	end
	
	warn("Phase->", self.Phase)
	
	task.wait(1)
	self:SetState(self:GetSwitchState())	
end

Boss.AIStates.TargetSpikes = Boss.State.new() 
function Boss.AIStates.TargetSpikes:Switch()  
	local PauseDuration = 3
	local AppearTime = 0.15

	local TelegraphRandom = 0.4
	local TelegraphTime = 1 

	local YOffset = Vector3.new(0, 5, 0)

	local Waves = 5 
	
	
	local ThisRandom = Random.new(os.time()) 

	local DistancePerRound = 7

	self:PositionShouldReplicate(true)
	self.Mover.BodyVelocity.Velocity =  Vector3.new() 
	self:Replicate()  
	
	
	local MaxExtra = 20 
	local ThisPerPlayer = math.max(1, math.round(MaxExtra / #self:GetTargets()))  
	
	for I=1, Waves do 


		local YOffset = Vector3.yAxis * 3
		local RaycastResult : RaycastResult = game.Workspace:Raycast(self.Mover.Position+YOffset,-Vector3.yAxis * 10,self.RaycastParams) 
		if not RaycastResult then 
			self:SetState("Spawn")
			return 
		end

		local Impact = self:CreateImpact(RaycastResult.Position , 0.6)
		Impact.HitPosition = RaycastResult.Position + self.MoverGroundOffset
		Impact.Radius = 3
		Impact.Telegraphed = true
		Impact.Name = "Stomp"
		Impact.Damage = self.Damage

		local Origin = RaycastResult.Position + self.MoverGroundOffset
		local Distance = 10+ (I * DistancePerRound)
	
		local TotalRounds = I * 2  

		for G=1, TotalRounds do 
			local Angle = (G/TotalRounds) * 360
			local ProjectedPosition = RotatePointAtDist2(Origin, Angle, Distance) + RotatePointAtDist2(Vector3.zero, math.random(1, 360), Distance/2) 

			ProjectedPosition += ThisRandom:NextUnitVector() * Vector3.new(1,0,1) * 1

			local RaycastResult : RaycastResult = game.Workspace:Raycast(ProjectedPosition+YOffset,-Vector3.yAxis * 10,self.RaycastParams) 

			if RaycastResult then 


				local Impact = self:CreateImpact(RaycastResult.Position  , TelegraphTime + (math.random() * TelegraphRandom) )
				Impact.HitPosition = RaycastResult.Position + self.MoverGroundOffset
				Impact.Radius = 7
				Impact.Telegraphed = true
				Impact.Name = "TreeSpike"
				Impact.Damage = self.Damage * 0.25
				Impact.ImpactEffector = Vector3.new(1, 0, 1)
			end
		end
		

		for _, Player in self:GetTargets() do
			local HumanoidRootPart : BasePart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")  
			if not HumanoidRootPart then continue end

			for Position=1, ThisPerPlayer do 
				local ThisStartingPosition = self:GetProjectedPosition(HumanoidRootPart, 50)  +  RotatePointAtDist2(Vector3.zero, math.random(1, 360), math.random(1, 20))
				local RaycastResult : RaycastResult = game.Workspace:Raycast(ThisStartingPosition+YOffset, -Vector3.yAxis * 10, self.RaycastParams) 
				if not RaycastResult then
					continue; 
				end		 

				local Impact = self:CreateImpact(RaycastResult.Position, 0.3 + TelegraphTime * (Position/ThisPerPlayer))
				Impact.HitPosition = RaycastResult.Position + self.MoverGroundOffset
				Impact.Radius = 7
				Impact.Telegraphed = true
				Impact.Name = "TreeSpike"
				Impact.Damage = self.Damage * 0.5
				Impact.ImpactEffector = Vector3.new(1, 0, 1)
			end
		end

		task.wait(PauseDuration)
	end


	self:SetState("Spawn")
end

Boss.AIStates.SuperStompStalk = Boss.State.new() 
function Boss.AIStates.SuperStompStalk:Init() 
	self.JumpTarget = nil 
end

function Boss.AIStates.SuperStompStalk:Switch() 
	-- Knockback all playres.
	local EffectDistance = 30 
	for _,Player in self:GetTargets()  do 
		local HumanoidRootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") 
		if HumanoidRootPart then 
			local Distance = (HumanoidRootPart.Position - self.Mover.Position).Magnitude

			if Distance < EffectDistance then 
				local EffectDecimal = 1+math.clamp(1-(Distance/EffectDistance),0,1)
				self:KnockbackPlayer(Player,self.Mover.Position,EffectDecimal * 5,5) 
			end
		end
	end


	task.wait(1)


	local StompDuration = 0.55
	local WalkDuration = 2

	local YOffset = Vector3.yAxis * 3
	local MaxImpacts , TotalImpacts = 6 ,0


	self:SendState("SetManualMode", "Run")
	repeat 
		TotalImpacts += 1
		self.ShouldReplicatePosition = true 
		self.JumpTarget = true

		-- Walk And remove the walk duration 
		self.CurrentYeildingThread = coroutine.running() 
		self.ResumingThreadWaiting = task.delay(WalkDuration, function() 
			task.spawn(self.CurrentYeildingThread)
		end)
		coroutine.yield()
		self.CurrentYeildingThread = nil 


		self.ShouldReplicatePosition = false 
		self.JumpTarget = false 

		-- Raycast and if not met return to the spawnstate.
		local RaycastResult : RaycastResult = game.Workspace:Raycast(self.Mover.Position+YOffset,-Vector3.yAxis * 10,self.RaycastParams) 
		if not RaycastResult then 
			break;
		end

		task.wait(0.5)
		local Impact = self:CreateImpact(RaycastResult.Position , StompDuration)
		Impact.HitPosition = RaycastResult.Position + self.MoverGroundOffset
		Impact.Radius = 16
		Impact.Telegraphed = true
		Impact.Name = "Stomp"
		Impact.Damage = self.Damage

		task.wait(StompDuration+ 0.1)
	until TotalImpacts > MaxImpacts


	self.ShouldReplicatePosition = true
	self:SetState("Spawn")
end

function Boss.AIStates.SuperStompStalk:Update(DeltaTime) 
	if self.JumpTarget and self.TargetHRP then
		local Distance = (self.TargetHRP.Position-self.Mover.Position).Magnitude
		local Offset = (self.TargetHRP.Position-self.Mover.Position)*Vector3.new(1,0,1)
		local Direction : Vector3= Offset.Unit
		self:AutoLook()


		if Distance < 15 and self.CurrentYeildingThread then 
			if coroutine.status(self.ResumingThreadWaiting) == "suspended" and 
				coroutine.status(self.CurrentYeildingThread) == "suspended" then  
				task.cancel(self.ResumingThreadWaiting)
				task.spawn(self.CurrentYeildingThread)
				self.CurrentYeildingThread = nil 
				return 
			end
		end 


		self.Mover.BodyVelocity.Velocity = Direction  * self.RunSpeed
	else 
		self.Mover.BodyVelocity.Velocity =  Vector3.new() 
	end
end

Boss.AIStates.SuperJump = Boss.State.new() 
function Boss.AIStates.SuperJump:Switch() 
	local JumpDuration = 2.5
	local YOffset = Vector3.yAxis * 3

	self:PositionShouldReplicate(true)
	self:Replicate() 
	self.ShouldReplicatePosition = false

	local YOffset = Vector3.yAxis * 3
	local RaycastResult : RaycastResult = game.Workspace:Raycast(self.Mover.Position+YOffset,-Vector3.yAxis * 10,self.RaycastParams) 
	if not RaycastResult then 
		self.ShouldReplicatePosition = true
		self:SetState("Spawn")
		return 
	end

	local Impact = self:CreateImpact(RaycastResult.Position ,JumpDuration)
	Impact.HitPosition = RaycastResult.Position + self.MoverGroundOffset
	Impact.Radius = 35
	Impact.Telegraphed = true
	Impact.Name = "SuperJump"
	Impact.Damage = self.Damage * 2

	task.wait(JumpDuration)

	self.ShouldReplicatePosition = true
	self:SetState("Spawn")
end

Boss.AIStates.JumpTarget = Boss.State.new() 
function Boss.AIStates.JumpTarget:Switch() 
	local JumpDuration = 1.3	
	local WalkDuration = 0.5
	local Waves = 4 

	local ThisRandom = Random.new(os.time()) 

	self.ShouldReplicatePosition = true

	for _=1,Waves do 
		if math.random(1,2) == 1 then 
			self:SetTarget(self:FindFarthestPlayer())
		end
		if not self.Target then 
			continue
		end
		
		self.Mover.BodyVelocity.Velocity =  Vector3.new() 
		self:LookAt(self.TargetHRP.Position)
		self:Replicate() 
		self:PositionShouldReplicate(false)
		self.Invulnerable = true 

		local YOffset = Vector3.yAxis * 3
		local RaycastResult : RaycastResult = game.Workspace:Raycast(self.TargetHRP.Position+YOffset + (ThisRandom:NextUnitVector() * Vector3.new(0.2, 0, 0.2) ),-Vector3.yAxis * 20,self.RaycastParams) 
		if not RaycastResult then
			self.Invulnerable = false 
			continue
		end
		
		task.wait(1)

		local Impact = self:CreateImpact(RaycastResult.Position ,JumpDuration)
		Impact.HitPosition = RaycastResult.Position + self.MoverGroundOffset
		Impact.Radius = 18
		Impact.Telegraphed = true
		Impact.Name = "AirJump"
		Impact.Damage = self.Damage
		
		self.Mover.Position = Impact.HitPosition
		self:SendState("Face")
		self:Replicate(self.TargetHRP.Position) 

		task.wait(JumpDuration)
		self.Invulnerable = false 
		self:PositionShouldReplicate(true)
		self:Replicate() 

		task.wait(WalkDuration)
	end

	self.Invulnerable = false 
	self.ShouldReplicatePosition = true
	self:SetState("Spawn")
end



Boss.AIStates.StompStalk = Boss.State.new() 
function Boss.AIStates.StompStalk:Init() 
	self.JumpTarget = nil 
end

function Boss.AIStates.StompStalk:Switch() 
	-- Knockback all playres.
	local EffectDistance = 30 
	for _,Player in self:GetTargets()  do 
		local HumanoidRootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") 
		if HumanoidRootPart then 
			local Distance = (HumanoidRootPart.Position - self.Mover.Position).Magnitude

			if Distance < EffectDistance then 
				local EffectDecimal = 1+math.clamp(1-(Distance/EffectDistance),0,1)
				self:KnockbackPlayer(Player,self.Mover.Position,EffectDecimal * 5,5) 
			end
		end
	end


	task.wait(1)
	
	
	local StompDuration = 0.7
	local WalkDuration = 2

	local YOffset = Vector3.yAxis * 3
	local MaxImpacts , TotalImpacts = 6 ,0
	

	self.LastStalkSwitchOn = tick() -1000
	self.LastSendStalkMode = "Walk"
	self:SendState("SetManualMode", nil)
	self:SendState("SetManualMode", self.LastSendStalkMode)
	repeat 
		TotalImpacts += 1
		self.ShouldReplicatePosition = true 
		self.JumpTarget = true

		-- Walk And remove the walk duration 
		self.CurrentYeildingThread = coroutine.running() 
		self.ResumingThreadWaiting = task.delay(WalkDuration, function() 
			task.spawn(self.CurrentYeildingThread)
		end)
		coroutine.yield()
		self.CurrentYeildingThread = nil 
		
		
		self.ShouldReplicatePosition = false 
		self.JumpTarget = false 

		-- Raycast and if not met return to the spawnstate.
		local RaycastResult : RaycastResult = game.Workspace:Raycast(self.Mover.Position+YOffset,-Vector3.yAxis * 10,self.RaycastParams) 
		if not RaycastResult then 
			break;
		end

		task.wait(0.5)
		local Impact = self:CreateImpact(RaycastResult.Position , StompDuration)
		Impact.HitPosition = RaycastResult.Position + self.MoverGroundOffset
		Impact.Radius = 13
		Impact.Telegraphed = true
		Impact.Name = "Stomp"
		Impact.Damage = self.Damage

		task.wait(StompDuration+ 0.1)
	until TotalImpacts > MaxImpacts


	self.ShouldReplicatePosition = true
	self:SetState("Spawn")
end

function Boss.AIStates.StompStalk:Update(DeltaTime) 
	if self.JumpTarget and self.TargetHRP then
		local Distance = (self.TargetHRP.Position-self.Mover.Position).Magnitude
		local Offset = (self.TargetHRP.Position-self.Mover.Position)*Vector3.new(1,0,1)
		local Direction : Vector3= Offset.Unit
		self:AutoLook()
		
		
		local AllowSwitch = true 
		local Time = tick() - self.LastStalkSwitchOn 
		if Time < 1 then 
			AllowSwitch = false 	
		end 
		
		if Distance > 40 then  
			if AllowSwitch then 
				self.StalkMode = "Run"
				self.LastStalkSwitchOn = tick() 
				self:SendState("SetManualMode", "Run")
			end
		elseif Distance < 10 and self.CurrentYeildingThread then 
			if coroutine.status(self.ResumingThreadWaiting) == "suspended" and 
				coroutine.status(self.CurrentYeildingThread) == "suspended" then  
				task.cancel(self.ResumingThreadWaiting)
				task.spawn(self.CurrentYeildingThread)
				self.CurrentYeildingThread = nil 
			end
		else
			if AllowSwitch then 
				self.StalkMode = "Walk"
				self.LastStalkSwitchOn = tick() 
				self:SendState("SetManualMode", "Walk")
			end
		end
		
		
		if self.StalkMode == "Walk" then
			self.Mover.BodyVelocity.Velocity = Direction  * self.Speed  
		elseif self.StalkMode == "Run" then 
			self.Mover.BodyVelocity.Velocity = Direction  * self.RunSpeed 
		end
		
		
	else 
		self.Mover.BodyVelocity.Velocity =  Vector3.new() 
	end
end


Boss.AIStates.PumpkinRain = Boss.State.new() 
function Boss.AIStates.PumpkinRain:Switch()  
	local PauseDuration = 3
	local AppearTime = 0.5
	
	local TelegraphTime = 2.5
	
	local YOffset = Vector3.new(0, 5, 0)
	
	local MaxExtra = 30 
	local ThisPerPlayer = math.max(1, math.round(MaxExtra / #self:GetTargets()))  
	
	local Waves = 5 
	
	self:PositionShouldReplicate(true)
	self.Mover.BodyVelocity.Velocity =  Vector3.new() 
	self:Replicate()  
	for _=1, Waves do 
		
		
		self:SendState("Special")
		
		if self.TargetHRP then 
			self:LookAt(self.TargetHRP.Position)
			self:Replicate() 
		end
		
		for _, Player in self:GetTargets() do
			local HumanoidRootPart : BasePart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")  
			if not HumanoidRootPart then continue end 
			
			for Position=1, ThisPerPlayer do 
				local ThisStartingPosition = HumanoidRootPart.Position + RotatePointAtDist2(Vector3.zero, math.random(1, 360), math.random(10, 30))
				local RaycastResult : RaycastResult = game.Workspace:Raycast(ThisStartingPosition +YOffset, -Vector3.yAxis * 20, self.RaycastParams) 
				if not RaycastResult then
					continue; 
				end		 
				
				local Impact = self:CreateImpact(RaycastResult.Position, TelegraphTime * (Position/ThisPerPlayer))
				Impact.HitPosition = RaycastResult.Position + self.MoverGroundOffset
				Impact.Radius = 5
				Impact.Telegraphed = true
				Impact.Name = "PumpkinDrop"
				Impact.Damage = self.Damage * 0.5
				Impact.ImpactEffector = Vector3.new(1, 0, 1)
			end
			
			task.wait() 
		end
		
		task.wait(PauseDuration)
	end
	
	
	self:SetState("Spawn")
end

Boss.AIStates.SpikeLine = Boss.State.new() 
function Boss.AIStates.SpikeLine:Switch()  
	local PauseDuration = 1.7
	local MaxLineLength = 30 
	
	local TelegraphTime = 0.5
	local AppearTime = 0.01
	
	local Waves = 7 
	
	self:PositionShouldReplicate(true)
	self.Invulnerable = false 
	
	for _=1, Waves do 
		if not self.Target then
			self:TargetCheck() -- Force target check if you can't find one! 
		end
		
		if not self.Target then 
			warn("------>")
			self:SetState("Spawn")
			return 
		end
		
		local TargetPosition = self.TargetHRP.Position
		
		self.Mover.BodyVelocity.Velocity =  Vector3.new() 
		self:LookAt(TargetPosition)
		self:Replicate() 
		self:SendState("PlayAnimation", "Waft")  
		
		task.wait(0.3)
		  
		local Direction = (TargetPosition - self.Mover.Position).Unit  * Vector3.new(1, 0, 1)
		
		for Position=1, MaxLineLength do 
			local YOffset = Vector3.yAxis * 3
			local ThisStartingPosition = self.Mover.Position + (Direction * Position * 10) 
			local RaycastResult : RaycastResult = game.Workspace:Raycast(ThisStartingPosition+YOffset, -Vector3.yAxis * 10, self.RaycastParams) 
			if not RaycastResult then
				break; 
			end
			
			local Impact = self:CreateImpact(RaycastResult.Position, TelegraphTime + (Position*AppearTime))
			Impact.HitPosition = RaycastResult.Position + self.MoverGroundOffset
			Impact.Radius = 7
			Impact.Telegraphed = true
			Impact.Name = "TreeSpike"
			Impact.Damage = self.Damage * 0.25
			Impact.ImpactEffector = Vector3.new(1, 0, 1)
		
		end
		
		
		task.wait(PauseDuration) 
	end
	
	self:SetState("Spawn")
end


Boss.AIStates.HeadDrop = Boss.State.new() 
function Boss.AIStates.HeadDrop:Switch() 
	local JumpDuration = 1.3	
	local PauseDuration = 0.1
	local Waves = 7 

	self:PositionShouldReplicate(true)
	self.Invulnerable = false 
	warn("start!")

	for _=1, Waves do 
		self:SetTarget(self:GetRandomPlayer())
		
		if not self.Target then 
			warn("------>no target")
			self:SetState("Spawn")
			return 
		end

		self.Mover.BodyVelocity.Velocity =  Vector3.new() 
		self:LookAt(self.TargetHRP.Position)
		self:Replicate() 
		self:PositionShouldReplicate(false)

		local ThisStartingPosition = self.TargetHRP.Position + Vector3.new(0, 5, 0) 
		local RaycastResult : RaycastResult = game.Workspace:Raycast(ThisStartingPosition, -Vector3.yAxis * 20, self.RaycastParams) 
		if not RaycastResult then
			continue; 
		end
		
		
		local Distance = (self.TargetHRP.Position - self.Mover.Position).Magnitude
		local ThisDuration = 0.9 + (Distance * 0.01) 
		local Impact = self:CreateImpact(RaycastResult.Position, ThisDuration)
		Impact.HitPosition = RaycastResult.Position + self.MoverGroundOffset
		Impact.Radius = 12
		Impact.Telegraphed = true
		Impact.Name = "ThrowHead"
		Impact.Damage = self.Damage
		Impact.ImpactEffector = Vector3.new(1, 0.3, 1)
		self:Replicate(self.TargetHRP.Position) 

		task.wait(ThisDuration)

		self:PositionShouldReplicate(true)
		self:Replicate() 

		task.wait(PauseDuration)
	end
	
	self.ShouldReplicatePosition = true
	self:SetState("Spawn")
end

Boss.AIStates.SpikeJump = Boss.State.new() 
function Boss.AIStates.SpikeJump:Switch() 
	local JumpDuration = 0.6
	local TelegraphTime = 0.5
	local TelegraphRandom =  0.8
	local Cooldown = 1.2
	local YOffset = Vector3.yAxis * 3
	
	local ThisRandom = Random.new(os.clock())

	
	local Rounds = 6 
	local TotalRounds = 5
	local DistancePerRound = 5
	
	-- Knockback all playres.
	local EffectDistance = 18 
	for _,Player in self:GetTargets()  do 
		local HumanoidRootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") 
		if HumanoidRootPart then 
			local Distance = (HumanoidRootPart.Position - self.Mover.Position).Magnitude
			
			if Distance < EffectDistance then 
				local EffectDecimal = 1+math.clamp(1-(Distance/EffectDistance),0,1)
				self:KnockbackPlayer(Player,self.Mover.Position,EffectDecimal * 5,5) 
			end
		end
	end

	
	task.wait(1)
	
	for I=2, Rounds do 
		
		self:PositionShouldReplicate(true)
		self:Replicate() 
		self.ShouldReplicatePosition = false
		
		local YOffset = Vector3.yAxis * 3
		local RaycastResult : RaycastResult = game.Workspace:Raycast(self.Mover.Position+YOffset,-Vector3.yAxis * 10,self.RaycastParams) 
		if not RaycastResult then 
			self.ShouldReplicatePosition = true
			self:SetState("Spawn")
			return 
		end
		task.wait(0.1)

		--[[[local Impact = self:CreateImpact(RaycastResult.Position ,JumpDuration)
		Impact.HitPosition = RaycastResult.Position + self.MoverGroundOffset
		Impact.Radius = 5
		Impact.Telegraphed = true
		Impact.Name = "SmallJump"
		Impact.Damage = self.Damage * 0.5]]
		
		local Impact = self:CreateImpact(RaycastResult.Position , 0.6)
		Impact.HitPosition = RaycastResult.Position + self.MoverGroundOffset
		Impact.Radius = 3
		Impact.Telegraphed = true
		Impact.Name = "Stomp"
		Impact.Damage = self.Damage
		
		local Origin = RaycastResult.Position + self.MoverGroundOffset
		local Distance = 10+(I * DistancePerRound)
		
		for G=1, TotalRounds + (I * 5) do 
			local Angle = (G/TotalRounds) * 360
			local ProjectedPosition = RotatePointAtDist2(Origin, Angle, Distance) + RotatePointAtDist2(Vector3.zero, math.random(1, 360), Distance/2) 
	
			ProjectedPosition += ThisRandom:NextUnitVector() * Vector3.new(1,0,1) * 5
			
			local RaycastResult : RaycastResult = game.Workspace:Raycast(ProjectedPosition+YOffset,-Vector3.yAxis * 10,self.RaycastParams) 

			if RaycastResult then 
				
				
				local Impact = self:CreateImpact(RaycastResult.Position  , TelegraphTime + (math.random() * TelegraphRandom) )
				Impact.HitPosition = RaycastResult.Position + self.MoverGroundOffset
				Impact.Radius = 7
				Impact.Telegraphed = true
				Impact.Name = "TreeSpike"
				Impact.Damage = self.Damage * 0.25
				Impact.ImpactEffector = Vector3.new(1, 0, 1)

				warn(self.Damage)
			end
		end

		task.wait(JumpDuration)
		if self.TargetHRP then 
			self:LookAt(self.TargetHRP.Position)
		end
		task.wait(Cooldown)
	end

	self.ShouldReplicatePosition = true
	self:SetState("Spawn")
end


Boss.AIStates.WalkStomp = Boss.State.new() 
function Boss.AIStates.WalkStomp:Switch() 
	local JumpDuration = 1.5	
	local WalkDuration = 1
	local Waves = 4 

	task.wait(0.1) 
	
	self:SendState("SetManualMode", "Run")

	for _=1,Waves do 

		self.Mover.BodyVelocity.Velocity =  Vector3.new() 
		self.ShouldReplicatePosition = false 

		local YOffset = Vector3.yAxis * 3
		local ProjectedPositon = self.Mover.Position
		local RaycastResult : RaycastResult = game.Workspace:Raycast(ProjectedPositon+YOffset,-Vector3.yAxis * 10,self.RaycastParams) 
		if not RaycastResult then 
			self:SetState("Spawn")
			return 
		end

		self:SendState("SetManualMode", "Run")

		local Impact = self:CreateImpact(RaycastResult.Position ,JumpDuration)
		Impact.HitPosition = RaycastResult.Position + self.MoverGroundOffset
		Impact.Radius = 17
		Impact.Telegraphed = true
		Impact.Name = "Jump"
		Impact.Damage = self.Damage
		Impact.ImpactEffector = Vector3.new(1, 0, 1)

		task.wait(JumpDuration + 0.8)

		if not self.Target then 
			warn("literally no fkn target!")
			
			self.ShouldReplicatePosition = true
			self:SetState("Spawn")
			return 
		end

		self.ShouldReplicatePosition = true 
		local TargetPosition = self:GetProjectedTargetPosition() 
		local Offset = (TargetPosition-self.Mover.Position)*Vector3.new(1,0,1)
		local Direction : Vector3= Offset.Unit
		self:LookAt(self.TargetHRP.Position)
		self.Mover.BodyVelocity.Velocity = Direction  * self.SideSpeed

		task.wait(WalkDuration)
	end


	self.Mover.BodyVelocity.Velocity =  Vector3.new() 

	self.ShouldReplicatePosition = true
	self:SetState("Spawn")
end

function Boss.AIStates.WalkStomp:Update(Delta)
	if self.Target and self.TargetHRP.Position then
		self:AutoLook() 
	end
end


return Boss