local AIStateEnemy = require(script.Parent):inherit()
AIStateEnemy.__index = AIStateEnemy

AIStateEnemy.State = require(script.State)

function AIStateEnemy.new(Proto) 
	local NewEnemy = setmetatable(Proto or {}, AIStateEnemy)
	NewEnemy:Init() 
	NewEnemy:AIStateEnemyInit()
	return NewEnemy
end


function AIStateEnemy:AIStateEnemyInit()
	self.Started = false 
	self.AIStates = self.AIStates or  {}
	self.StateMemory = {} 
	table.insert(self.UpdateStack, self.StateUpdate)
end

function AIStateEnemy:GetStateMemory(State) 
	self.StateMemory[State] = self.StateMemory[State] or {} 
	return self.StateMemory[State]
end

function AIStateEnemy:SetState(Name, ...) 
	if self.Dead then return end
	
	
	
	local ActualState = self.AIStates[Name] 
	if not ActualState then 
		warn(("There is no state by the name of '%s'."):format(Name))
		return 
	end
	
	local StateMemory = self:GetStateMemory(ActualState) 

	local Param = {...}

	-- If there actually is a State then make sure it isnt currrent async-locked.
	if self.SwitchLock then
		warn("Cannot switch enemy state whilst locked!")	
		return 
	end 

	if coroutine.running() == self.__StateSwitchThread or 
		coroutine.running() == self.__StateUpdateThread then 
		task.spawn(function() 
			self:SetState(Name,table.unpack(Param))
		end)
		coroutine.yield()
		return 
	end
	
	--warn("---->SetState-->", Name, ...)

	if self.CurrentState then 
		local CurrentStateMemory = self:GetStateMemory(self.CurrentState)
		task.spawn(self.CurrentState.Exit,self) -- Set the exit !
		CurrentStateMemory.Ready = false -- This will prevent it form updating immdeitaly!
	end

	self.CurrentState = nil -- Completely remove the reference to the state.
	self.SwitchLock = true  
	StateMemory.Ready = false 


	-- Kill Any outgoing state related threads. 
	if self.__StateSwitchThread then 
		--task.cancel(self.__StateSwitchThread)
	end
	-- Update Threads dont get closed, state is prevented from switching but Update simply stops.
	task.wait() -- Giving one frame to switch will make sure that any (switch attempts), go through now aswell. 
	if not StateMemory.Initialized  then 
		ActualState.Init(self)
		StateMemory.Initialized = true 
	end

	self.CurrentState = ActualState
	self.SwitchLock = false  -- This will make it so that the state can switch immedatly
	self.__StateSwitchThread = task.spawn(function() 
		local Success , Result = pcall(function() 
			return ActualState.Switch(self,table.unpack(Param))
		end)
		
		if not Success then 
			warn(("Error during enemy state '%s'. (Switch)."):format(Name)) 
			warn(Result)
			self:SetState("OnError",Result)
		end
	end)
	task.wait()
	-- Next freame actually allow the currentstate:update to be switchable and acutally run !

	if self.CurrentState == ActualState then 
		StateMemory.Ready = true
	end
end

function AIStateEnemy:Start() 
	self:SetState("Spawn")
	self.Started = true 
end


function AIStateEnemy:StateUpdate(DeltaTime) 
	if not self.Started then return end 
	if self.CurrentState then 
		local CurrentStateMemory = self:GetStateMemory(self.CurrentState)
		if self.CurrentState.Enabled and CurrentStateMemory.Ready then  
			self.__StateUpdateThread = coroutine.running() 
			self.CurrentState.Update(self,DeltaTime)
		end
	end
end

return AIStateEnemy
