local TweenService = game:GetService("TweenService")

local CustomProximity = {
	Name = "Radial",
	TweenIn = TweenInfo.new(0.2,Enum.EasingStyle.Bounce),
	TweenOut = TweenInfo.new(0.1)
} 


function CustomProximity:Appear() 
	local Size = self.ProximityPrompt:GetAttribute("SizeMultipler") or 1
	local ActionText = self.ProximityPrompt.ObjectText
	self.Billboard =  script.prompt:Clone() 
	self.Billboard.Adornee = self.ProximityPrompt.Parent 
	self.Billboard.Parent = self.ScreenGui
	self.Billboard.Size = UDim2.fromScale(self.Billboard.Size.X.Scale*Size,self.Billboard.Size.Y.Scale*Size)
	self.Billboard.Container.Button.Action.Text = ActionText
	self.Billboard.Container.Button.SubAction.Text = self.ProximityPrompt:GetAttribute("SubAction") or ""
	self:Update()

	self.Billboard.Container.Button.Pressed.Visible = false
	
	self.InstancingMaid:Add(self.Billboard.Container.Button.Trigger.MouseButton1Down:Connect(function() 
		self.ProximityPrompt:InputHoldBegin()
	end))
	
	self.InstancingMaid:Add(self.Billboard.Container.Button.Trigger.MouseButton1Up:Connect(function() 
		self.ProximityPrompt:InputHoldEnd() 
	end))

	self.InstancingMaid:Add(self.Billboard.Container.Button.Trigger.MouseLeave:Connect(function() 
		self:Simulate("TriggerEnded") 
	end))

	local DefaultSize = script.prompt.Container.Size 
	self.Tweens = {
		Default = TweenService:Create(self.Billboard .Container, self.TweenOut,{
			Size = DefaultSize
		}),
		Pressed = TweenService:Create(self.Billboard .Container, self.TweenIn,{
			Size = UDim2.new(DefaultSize.X.Scale*0.8,0,DefaultSize.Y.Scale*0.8,0),
		}),
	} 
end

function CustomProximity:InputsChanged() 
	self:Update() 
end

function CustomProximity:Update() 
	if self.InputObject.Type == "String" then 
		self.Billboard.Container.Button.Button.Visible = false
		self.Billboard.Container.Button.Key.Visible = true 
		self.Billboard.Container.Button.Key.Text = self.InputObject.Value
	elseif self.InputObject.Type == "Image" then 
		self.Billboard.Container.Button.Button.Visible = true 
		self.Billboard.Container.Button.Key.Visible = false	
		self.Billboard.Container.Button.Button.Image = self.InputObject.Value
	end
end

function CustomProximity:Triggered() 
	self.Tweens.Pressed:Play() 
	self.Billboard.Container.Button.Pressed.Visible = true 
end

function CustomProximity:TriggerEnded() 
	self.Tweens.Default:Play()
	self.Billboard.Container.Button.Pressed.Visible = false

end

function CustomProximity:Hidden() 
	self.Billboard:Destroy()
end


return CustomProximity