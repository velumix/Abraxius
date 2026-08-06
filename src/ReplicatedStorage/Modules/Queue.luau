local Queue = {} 
Queue.__index = Queue

function Queue.new()
	local self = setmetatable({
		List = {},

		ShouldExhaust = false,
		QueueIsBusy = true, 
	}, Queue)

	return self 
end

function Queue:Clear() 
	self.List = {}  
end

function Queue:Push(Item)
	table.insert(self.List,Item)
end

function Queue:Length() 
	return #self.List 
end

function Queue:WaitAndGetResume() 
	local FinalExit = false 
	local ActiveThread = coroutine.running()
	local Solved = false 
	self:Push(function() 
		task.spawn(ActiveThread)
		Solved = true
		
		repeat task.wait() until FinalExit 
	end)
	
	if not Solved then coroutine.yield() end
	
	return function() 
		FinalExit = true 
	end
end

function Queue:PushAndWait()
	self:RunPushedFunctions() 

	local Begin = os.clock() 
	local ActiveThread = coroutine.running()
	local Solved = false 
	self:Push(function() 
		task.spawn(ActiveThread)
		Solved = true 
	end)

	if not Solved then coroutine.yield() end

	return os.clock() - Begin
end

function Queue:Pop() 
	if self:IsEmpty() then 
		warn("Cannot use .Pop() on a empty queue.")
		return 
	end

	return table.remove(self.List)
end

function Queue:IsEmpty() 
	return #self.List == 0 
end

function Queue:Exhaust(ExhaustFn)
	assert(type(ExhaustFn) == "function",".Exhaust(ExhaustFn : ()->(). Invalid paramaters.")
	if not self.ShouldExhaust then 
		self.ShouldExhaust = true 
		

		self.ExhaustThread = task.spawn(function()
			while true do 
				if not self:IsEmpty() then 
					pcall(ExhaustFn, self:Pop())
					task.wait(self.Step or 0)
				else 
					task.wait() 
				end
			end
		end)
	end
end

function Queue:RunPushedFunctions(MaxFail) 
	self.Rememberance = {} 
	self:Exhaust(function(PushedItem)
		assert(typeof(PushedItem) == "function","You used .RunPushedFunctions() only .Push() functions.")
		
		local Success, Result = pcall(function() 
			return PushedItem()
		end)
		
		if not Success then 
			warn("Fail:Queue:RunPushedFunctions:", Success, Result)
			self.Rememberance[PushedItem] = self.Rememberance[PushedItem] or 0 
			self.Rememberance[PushedItem] += 1 
			
			if self.Rememberance[PushedItem] >  MaxFail or 100 then 
				warn("Fail:Queue:RunPushedFunctions: Failure Exceeded Maximum! ", PushedItem)
				return
			end
			self:Push(PushedItem)
		else 
			self.Rememberance[PushedItem] = nil 
		end
	end)
end


function Queue:GetList() 
	return self.List 
end

return Queue