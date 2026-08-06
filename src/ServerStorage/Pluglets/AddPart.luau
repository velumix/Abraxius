return function(plugin)
	-- Write any code here, don't worry about returning anything.
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
	local CurrentCamera = Workspace.CurrentCamera
	
	
	local NextPartName = `Part{#TotalCFrames+1}`
	local CFrameValue = Instance.new("CFrameValue", ThisScene)
	CFrameValue.Value = CurrentCamera.CFrame
	CFrameValue.Name = NextPartName
end
