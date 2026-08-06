-- Small polling preventor to check if and when something loads.?
local LoadInstance = Instance.new("BindableEvent")
local ServerLoadInstance = Instance.new("BindableEvent")
local LoadingPoint = {
	ServerIsLoaded = false, 
	ServerLoaded = ServerLoadInstance.Event,
	IsLoaded = false, 
	Loaded = LoadInstance.Event 
} 
function LoadingPoint.ServerLoadSignal() 
	LoadingPoint.ServerIsLoaded = true 
	ServerLoadInstance:Fire()
end

function LoadingPoint.WaitUntilServerLoaded() 
	if not LoadingPoint.ServerIsLoaded then 
		ServerLoadInstance.Event:Wait()
	end
end

function LoadingPoint.WaitUntilLoaded() 
	if not LoadingPoint.IsLoaded then
		LoadInstance.Event:Wait()
	end
end

function LoadingPoint.LoadSignal() 
	LoadingPoint.IsLoaded = true 
	LoadInstance:Fire() 	
end
function LoadingPoint.UponLoad(OnLoadFunction) 
	if not LoadingPoint.IsLoaded then 
		LoadInstance.Event:Wait()-- This prevents us from doing 
	end
	task.wait()
	OnLoadFunction()
end
return LoadingPoint