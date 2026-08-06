return function(plugin)
	-- Write any code here, don't worry about returning anything.
	
	
	local Selected = game:GetService("Selection"):Get() 
	
	for _, Selection in Selected do 
		if Selection:IsA("Model") then 
			local Model : Model = Selection 
			local PCFrame, Size = Model:GetBoundingBox() 
	
			local Collider = Instance.new("Part") 
			Collider.Name = "Collider"
			Collider.Transparency = 1 
			Collider.CanCollide = false 
			Collider.CanTouch = false 
	
			Collider.CFrame = PCFrame 
			Collider.Size = Size * 0.9
	
			Collider.Parent = Selection
			Collider.Anchored = true
		end
	end
	
end
