local PushPop = {}

function PushPop.Register(InterfaceHandler)
	function InterfaceHandler.Push() 
		if not InterfaceHandler.PushObject then 
			local Pusher = "__Push"
			local ScreenGui = Instance.new("ScreenGui", InterfaceHandler.PlayerGui)
			ScreenGui.ResetOnSpawn = false	
			ScreenGui.Name = Pusher

			local PsudeoFrame = Instance.new("Frame", ScreenGui)
			PsudeoFrame.Name = "MainFrame" 
			PsudeoFrame.Visible = false 
			InterfaceHandler.PushObject = InterfaceHandler:Get(Pusher)
		end
		
		
		local Current = InterfaceHandler.DefaultStack:GetTop()
		if InterfaceHandler.DefaultStack:GetTop() ~= InterfaceHandler.PushObject then 
			InterfaceHandler.PushObject:Stack(true) 
			InterfaceHandler.PushObject.SuperPriority = true 
		end
	end

	function InterfaceHandler.Pop() 
		if InterfaceHandler.PushObject then
			InterfaceHandler.DefaultStack:RemoveInPlace(InterfaceHandler.PushObject)
		end
	end

end

return PushPop 