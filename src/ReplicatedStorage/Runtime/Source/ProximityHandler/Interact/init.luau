local TweenService = game:GetService("TweenService")

local CustomProximity = {
	Name = "Interact",
	TweenIn = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	TweenOut = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Popup = TweenInfo.new(0.2, Enum.EasingStyle.Quint),
	HoldIn = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
	HoldOut = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
}

function CustomProximity:Appear()
	local Size = self.ProximityPrompt:GetAttribute("SizeMultipler") or 1
	local ActionText = self.ProximityPrompt.ObjectText
	self.Billboard =  script.prompt:Clone() 
	self.Billboard.Adornee = self.ProximityPrompt.Parent 
	self.Billboard.Parent = self.ScreenGui
	self.Billboard.Size = UDim2.fromScale(self.Billboard.Size.X.Scale*Size,self.Billboard.Size.Y.Scale*Size)
	self.Billboard.Container.Action.Text = ActionText
	self:Update()

	self.OrginalButtonSize = self.Billboard.Container.Button.Button.Size
	self.OrginalActionSize = self.Billboard.Container.Action.Size 
	self.Billboard.Container.Action.Size =  UDim2.fromScale(self.OrginalActionSize.X.Scale,0)
	TweenService:Create(self.Billboard.Container.Action, CustomProximity.Popup, {
		Size = self.OrginalActionSize
	}):Play()

	self.Billboard.Container.Button.Button.Size = UDim2.fromScale(0,0) 
	TweenService:Create(self.Billboard.Container.Button.Button, self.TweenIn, {
		Size = self.OrginalButtonSize,
	}):Play()

	local baseButton = self.Billboard.Container.Button:FindFirstChild("Button")
	self.BaseButton = baseButton

	local holdContainer = self.Billboard.Container.Button
	local holdBg = Instance.new("Frame")
	holdBg.Name = "HoldBarBG"
	holdBg.AnchorPoint = Vector2.new(0.5, 0)
	holdBg.Position = UDim2.new(0.5, 0, 0, -6)
	holdBg.Size = UDim2.new(0.7, 0, 0.08, 0)
	holdBg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	holdBg.BackgroundTransparency = 0.65
	holdBg.BorderSizePixel = 0
	holdBg.Visible = false
	holdBg.Parent = holdContainer
	local holdBgCorner = Instance.new("UICorner")
	holdBgCorner.CornerRadius = UDim.new(0, 6)
	holdBgCorner.Parent = holdBg

	local holdFill = Instance.new("Frame")
	holdFill.Name = "HoldBarFill"
	holdFill.AnchorPoint = Vector2.new(0, 0.5)
	holdFill.Position = UDim2.new(0, 0, 0.5, 0)
	holdFill.Size = UDim2.new(0, 0, 1, 0)
	holdFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
	holdFill.BackgroundTransparency = 0.1
	holdFill.BorderSizePixel = 0
	holdFill.Visible = false
	holdFill.Parent = holdBg
	local holdFillCorner = Instance.new("UICorner")
	holdFillCorner.CornerRadius = UDim.new(0, 6)
	holdFillCorner.Parent = holdFill

	self.HoldBarBG = holdBg
	self.HoldBarFill = holdFill

	self.InstancingMaid:Add(self.Billboard.Container.Button.Trigger.MouseButton1Down:Connect(function()
		self.ProximityPrompt:InputHoldBegin()
	end))

	self.InstancingMaid:Add(self.Billboard.Container.Button.Trigger.MouseButton1Up:Connect(function()
		self.ProximityPrompt:InputHoldEnd()
	end))

	self.InstancingMaid:Add(self.Billboard.Container.Button.Trigger.MouseLeave:Connect(function()
		self:Simulate("TriggerEnded")
	end))

	local DefaultSize = script.prompt.Container.Button.Size 
	self.DefaultButtonSize = DefaultSize
	self.DefaultButtonPosition = self.Billboard.Container.Button.Position
	self.Tweens = {
		Default = TweenService:Create(self.Billboard.Container.Button, self.TweenOut,{
			Size = DefaultSize
		}),
		Pressed = TweenService:Create(self.Billboard.Container.Button, self.TweenIn,{
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
	self:HoldEnded()
end

function CustomProximity:TriggerEnded()
	self:HoldEnded()
	self.Tweens.Default:Play()
end

function CustomProximity:HoldBegan()
	if not self.Billboard then return end
	if self._holdSizeTween then
		self._holdSizeTween:Cancel()
		self._holdSizeTween = nil
	end
	local duration = 0
	if self.ProximityPrompt and typeof(self.ProximityPrompt.HoldDuration) == "number" then
		duration = self.ProximityPrompt.HoldDuration
	end
	if duration <= 0 then
		duration = 0.15
	end
	if self.HoldBarFill then
		if self.HoldBarBG then
			self.HoldBarBG.Visible = true
		end
		self.HoldBarFill.Size = UDim2.new(0, 0, 1, 0)
		self.HoldBarFill.Visible = true
		if self._holdFillTween then
			self._holdFillTween:Cancel()
			self._holdFillTween = nil
		end
		self._holdFillTween = TweenService:Create(self.HoldBarFill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
			Size = UDim2.new(1, 0, 1, 0),
		})
		self._holdFillTween:Play()
	end
	local DefaultSize = self.DefaultButtonSize or self.Billboard.Container.Button.Size
	self._holdSizeTween = TweenService:Create(self.Billboard.Container.Button, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Size = UDim2.new(DefaultSize.X.Scale * 0.85, 0, DefaultSize.Y.Scale * 0.85, 0),
	})
	self._holdSizeTween:Play()
end

function CustomProximity:HoldEnded()
	if self._holdSizeTween then
		self._holdSizeTween:Cancel()
		self._holdSizeTween = nil
	end
	if self._holdFillTween then
		self._holdFillTween:Cancel()
		self._holdFillTween = nil
	end
	if self.HoldBarFill then
		self.HoldBarFill.Size = UDim2.new(0, 0, 1, 0)
		self.HoldBarFill.Visible = false
		if self.HoldBarBG then
			self.HoldBarBG.Visible = false
		end
	end
	if self.DefaultButtonSize then
		TweenService:Create(self.Billboard.Container.Button, CustomProximity.HoldOut, {
			Size = self.DefaultButtonSize,
		}):Play()
	end
end

function CustomProximity:Hidden() 
	self:HoldEnded()
	TweenService:Create(self.Billboard.Container.Action, CustomProximity.Popup, {
		Size = UDim2.fromScale(self.OrginalActionSize.X.Scale,0)
	}):Play()  

	TweenService:Create(self.Billboard.Container.Button.Button, self.TweenIn, {
		Size = UDim2.fromScale(0,0),
	}):Play()

	task.wait(1)

	self.Billboard:Destroy()
end


return CustomProximity