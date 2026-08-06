local Scheduler = {} 

local RunService = game:GetService("RunService")
local StepEvent = RunService:IsServer() and RunService.Heartbeat or RunService.RenderStepped

function Scheduler.new(List) 
	local NewScheduler = {
		Rate = 1/24, -- 24 times per second 
		BaseRate = 1/24, -- this is the maximum
		Size = 10, -- Size will be setup from AutoSchedule() 
		Position = 0, -- The Current position 
		Time = 0, -- Time elapsed
		TargetPeriod = 2, -- The amount of seconds to iterate the entire list.
		
		List = List,
		ListSize = #List,
		LastListSize = List,
		
		ProcessFnList = {},
		RemovalStack = {},
		
		UpdateUponChanges = true, 
		AutoAdjustRate = true,
		
		__IsRemoving = false,
	} 
	
	NewScheduler.SetList = function(List,Reset) 
		NewScheduler.List = List 
		NewScheduler.ListSize = #List	
		if Reset then 
			NewScheduler.Time = 0 
			NewScheduler.Position = 0
		end
	end
	
	NewScheduler.SetRate = function(BaseRate) 
		NewScheduler.BaseRate = BaseRate 
		NewScheduler.Rate = BaseRate
	end
	
	NewScheduler.AutoSchedule = function(TargetPeriod) 
		if NewScheduler.AutoAdjustRate then 
			NewScheduler.ListSize = #NewScheduler.List
			local MinimumRate = TargetPeriod/NewScheduler.ListSize -- The amount of iterations at minimum it would take to reach the target peroid 
			if NewScheduler.ListSize == 0 then MinimumRate = TargetPeriod end 
			NewScheduler.Rate = math.max(MinimumRate,NewScheduler.BaseRate) -- Dont let the rate get lower below this number, beacuse this would mean more iterations then needed. Slower is fine, faster is not.

		end
		NewScheduler.Size = math.max(1,math.round((NewScheduler.ListSize * NewScheduler.Rate) * (TargetPeriod or 1)))
	end
	
	NewScheduler.SetTargetPeroid = function(TargetPeroid)
		NewScheduler.TargetPeriod = TargetPeroid
		NewScheduler.AutoSchedule(TargetPeroid)
	end
	
	NewScheduler.Update = StepEvent:Connect(function(DeltaTime) 
		NewScheduler.Time += DeltaTime 
		
		if NewScheduler.Time > NewScheduler.Rate then
			NewScheduler.Time = 0 
			local Iterations , ListSize = 0 , #NewScheduler.List
			if ListSize == 0 then return end 
			NewScheduler.ListSize = ListSize 
			
			if NewScheduler.ListSize ~= NewScheduler.LastListSize then 
				if NewScheduler.UpdateUponChanges then 
					NewScheduler.AutoSchedule(NewScheduler.TargetPeriod)
				end
			end
			
			local RemovalStack = NewScheduler.RemovalStack 
			
			-- Due the pending iterations.
			repeat 
				Iterations += 1 
				NewScheduler.Position += 1 
				if NewScheduler.Position > ListSize then 
					NewScheduler.Position = 1 
				end
				local CurrentValue = NewScheduler.List[NewScheduler.Position]
				
				for _,ProcessFn in NewScheduler.ProcessFnList do 
					ProcessFn(CurrentValue,NewScheduler.Position,function(UponRemovalFn) 
						table.insert(RemovalStack,{
							Position = NewScheduler.Position, 
							UponRemovalFn = UponRemovalFn
						})
					end)
				end

			until Iterations >= math.min(NewScheduler.Size,NewScheduler.ListSize)
			
			NewScheduler.__IsRemoving = true 
			
			-- Due to pending removals.
			for Position = #RemovalStack, 1, -1 do
				local RemovalItem = RemovalStack[Position]
				table.remove(NewScheduler.List, RemovalItem.Position)
				
				if RemovalItem.UponRemovalFn then RemovalItem.UponRemovalFn() end 
			end
			
			NewScheduler.RemovalStack = {} 
			NewScheduler.__IsRemoving = false
			NewScheduler.LastListSize = ListSize
		end 
	end)
	
	NewScheduler.AddManualRemoval = function(Value)
		task.spawn(function() 
			local Start = os.clock()
			repeat task.wait() until not NewScheduler.__IsRemoving
			
			local ValuePosition = table.find(NewScheduler.List,Value)
			if ValuePosition then 
				NewScheduler.Time = NewScheduler.Rate -- This will essentially turn this into a defer, as it will resume the next cycle.
				table.insert(NewScheduler.RemovalStack,{
					Position = ValuePosition, 
					UponRemovalFn = function() 
						warn("Manual removal time:",Start-os.clock())
					end,
				})
			end
		end)
	end	
	
	NewScheduler.Add = function(ProcessFn) 
		table.insert(NewScheduler.ProcessFnList,ProcessFn)
	end
	
	NewScheduler.Destroy = function() 
		NewScheduler.Update:Disconnect() 
		task.wait() 
		NewScheduler = nil 
	end
	
	NewScheduler.AutoSchedule(NewScheduler.TargetPeriod)
	
	return NewScheduler
end

return Scheduler

