local Runner
local LightRunner = _G.LightRunner 
local DEFAULT_TASK_TIMEOUT = 60
local WAIT_POLL_INTERVAL = 0.1
local LoadingManager = {
	TaskChanged = LightRunner.Signal.new(), 
	ProgressChanged = LightRunner.Signal.new(), 
	Loaded = LightRunner.Signal.new(), 
	Completed = LightRunner.Signal.new(), 

	CurrentProgress = 0
} 

local Progressor = {}
Progressor.__index = Progressor

function Progressor.new(List, Index)
	local self = setmetatable({
		Task = List[Index], 
		Position = Index, 
		StepArray = List, 

		ProgressDecimal = 0, 

		DidFinish =  LightRunner.Signal.new()
	}, Progressor) 
	return self 
end

function Progressor:Execute() 
	local DoExecution = function() 
		local Success, Result = pcall(function() 
			self.Task.Worker(function(...)
				self:Progress(...)
			end, function(...)
				self:Finish()
			end, LoadingManager, self.Task) 
		end)

		if not Success then
			self:Finish()
			warn(`Finishing the task {self.Task.Descriptor}! Because it errored.`)
			warn(Result)
		end
	end

	task.spawn(DoExecution)	
end

function Progressor:Finish() 
	if self.Finished then
		return
	end
	self.Finished = true 
	self.DidFinish:Fire() 
end

function Progressor:WaitUntilCompleted(timeoutSeconds) 
	if self.Finished then
		return
	end

	local timeout = timeoutSeconds or self.Task.Timeout or DEFAULT_TASK_TIMEOUT
	local startTime = os.clock()
	while not self.Finished do
		if timeout and timeout > 0 and (os.clock() - startTime) >= timeout then
			warn(`Loading task timed out: {self.Task.Descriptor}`)
			self:Finish()
			break
		end
		task.wait(WAIT_POLL_INTERVAL)
	end
end

function Progressor:Focus()
	local ProgressPosition = self.Position/(#self.StepArray+1) 
	LoadingManager:SetProgress(ProgressPosition)
	LoadingManager.CurrentTask = self.Task
	LoadingManager.TaskChanged:Fire(self.Task) 
end

function Progressor:Progress(Decimal) 
	if LoadingManager.CurrentTask == self.Task then 
		if Decimal > self.ProgressDecimal and self.ProgressDecimal <= 1 then 
			self.ProgressDecimal = Decimal 
		end

		local AdditionalProgress = ((self.Position + self.ProgressDecimal) / (#self.StepArray + 1))
		LoadingManager:SetProgress(AdditionalProgress)
	end
end


function LoadingManager:SetProgress(Decimal) 
	local Clamped = math.max(math.min(1, Decimal),0)

	if LoadingManager.CurrentProgress ~= Clamped then
		LoadingManager.CurrentProgress = Clamped
		LoadingManager.ProgressChanged:Fire(Clamped)
	end
end

function LoadingManager:ExecuteSteps(StepArray)
	local Progressors = {} 
	for Position, Task in StepArray do
		local ThisProgressor = Progressor.new(StepArray, Position)
		Progressors[Position] = ThisProgressor

		if ThisProgressor.Task.StartEarly then 
			ThisProgressor:Execute()
		end
	end

	for _, ThisProgressor in Progressors do
		ThisProgressor:Focus()
		if not ThisProgressor.Task.StartEarly then
			ThisProgressor:Execute()
		end

		ThisProgressor:WaitUntilCompleted(ThisProgressor.Task.Timeout)
	end

	LoadingManager:SetProgress(1)
	LoadingManager.Loaded:Fire()
	LoadingManager.IsLoaded = true
end

function LoadingManager:HideAll()
	Runner:Get("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	Runner:Get("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end

function LoadingManager:ShowAll() 
	Runner:Get("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	Runner:Get("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) 
end

function LoadingManager:Start() 
	LoadingManager:HideAll() 
	LoadingManager:ExecuteSteps(require(script.LoadingTasks))
	LoadingManager:ShowAll() 
	LoadingManager.IsCompleted = true 
	LoadingManager.Completed:Fire() 
end

function LoadingManager:WaitUntilLoadingScreenIsCompleted() 
	if not LoadingManager.IsCompleted then 
		LoadingManager.Completed:Wait() 
	end
end

function LoadingManager:WhenLoaded() 
	Runner = LightRunner:Get("Runner") -- Runner just 
end

return LoadingManager 