local LightRunner = _G.LightRunner 
local ExistanceHooker = {
	Runners = {
		["StarterGui"] = {function() 
			return game:GetService("StarterGui")
		end},
		["TweenService"] = {function() 
			return game:GetService("TweenService")
		end,},
		["ReplicatedStorage"] = {function() 
			return game:GetService("ReplicatedStorage")			
		end},
		["Mince"] = {function()
			return require(LightRunner:Get("Runner"):Get("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Mince")) 
		end,}, 
		["PlayerGui"] = {function() 
			return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
		end,}
	} 
}


function ExistanceHooker:Get(RunnerName) 
	local ThisRunner = self.Runners[RunnerName]
	if not ThisRunner then
		warn(`No runner by the name of '{RunnerName}'!`)
		return nil
	end

	if not ThisRunner.IsReady then 
		ThisRunner.Ready:Wait() 
	end

	return ThisRunner.Value
end

function ExistanceHooker:When(RunnerName, CallbackFn) 
	local ThisRunner = self.Runners[RunnerName]
	if not ThisRunner then
		warn(`No runner by the name of '{RunnerName}'!`)
		return nil
	end

	if not ThisRunner.IsReady then 
		ThisRunner.Ready:Connect(function() 
			CallbackFn(ThisRunner.Value)
		end)
	else
		CallbackFn(ThisRunner.Value)
	end
end

for RunnerIndex, RunnerObject in ExistanceHooker.Runners do 
	RunnerObject.IsReady = false 
	RunnerObject.Ready = LightRunner.Signal.new() 

	task.defer(function() 
		RunnerObject.Value = RunnerObject[1]() 
		RunnerObject.IsReady = true 
		RunnerObject.Ready:Fire() 
	end)
end

return ExistanceHooker
