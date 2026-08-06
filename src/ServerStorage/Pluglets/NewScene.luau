return function(plugin)
	-- Write any code here, don't worry about returning anything.
	-- Write any code here, don't worry about returning anything.
	local Selection = game:GetService("Selection") 
	local Items = Selection:Get() 
	if #Items == 0 or #Items > 1 then
		warn(`Incorrect amount of instances selected!`)
		return
	end
	
	local ThisSceneFolder : Configuration = Items[1] 
	if not ThisSceneFolder:IsA("Folder") then
		warn("This should be a Folder NGL!")
		return
	end
	
	
	local NewScene = Instance.new("Configuration", ThisSceneFolder)
	NewScene.Name = "NEWSCENE" 
	NewScene:SetAttribute("Time", 2)
end
