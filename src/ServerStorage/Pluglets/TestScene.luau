return function(plugin)
	-- Write any code here, don't worry about returning anything.
	local Selection = game:GetService("Selection") 
	local Items = Selection:Get() 
	if #Items == 0 or #Items > 1 then
		warn(`Incorrect amount of instances selected!`)
		return
	end
	
	local ThisScene : Configuration = Items[1] 
	if not ThisScene:IsA("Configuration") then
		warn("This should be a configuration NGL!")
		return
	end
	
	local Time = ThisScene:GetAttribute("Time") or 1 
	
	local TotalCFrames = {} 
	local Position = 0 
	repeat Position += 1 
		local FoundOne = false 
		local ThisValue = ThisScene:FindFirstChild(`Part{Position}`) 
		if ThisValue and ThisValue:IsA("CFrameValue") then 
			table.insert(TotalCFrames, ThisValue.Value)
			FoundOne = true 
		end
	until not FoundOne 
	
	local Workspace = game:GetService("Workspace")
	local RunService = game:GetService('RunService')
	
	local function bezier(points, t)
		local temp = points
		while #temp > 1 do
			local newTemp = {}
			for i = 1, #temp - 1 do
				newTemp[i] = temp[i]:Lerp(temp[i + 1], t)
			end
			temp = newTemp
		end
		return temp[1]
	end
	
	local function tweenCameraBezier(controlPoints, duration)
		local CurrentCamera = Workspace.CurrentCamera
		local timeElapsed = 0 
		while timeElapsed < duration do
			timeElapsed += RunService.RenderStepped:Wait()
			timeElapsed = math.min(duration, timeElapsed)
			CurrentCamera.CFrame = bezier(controlPoints, timeElapsed / duration)
		end
	end
	
	
	
	tweenCameraBezier(TotalCFrames, Time)
	
	
	warn(TotalCFrames)
end
