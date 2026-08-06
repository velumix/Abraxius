local Task = {
	Descriptor = "Task.Descriptor", 
	Worker = function(Progress,Finish) 
		Progress(1)
		Finish() 
	end,
} 
Task.__index = Task 

function Task.New(Object) 
	return setmetatable(Object or {},Task)
end

return Task 