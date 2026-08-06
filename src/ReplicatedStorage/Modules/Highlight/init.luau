--- Modules // Services -- 
local TweenService = game:GetService("TweenService")

local Highlight = {
	Location = script.Instances,

	Humanoid = {},

	Prototype = {
		Position = 0, 

		Color = Color3.new(0.670588, 0.545098, 0.0509804) , 
		OutlineColor = Color3.new(1,1,1),  

		PulseTween = TweenInfo.new(0.6,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,-1,true), 

		AdorneeAll = true, 

		ClearLast = true, 

		DoesFlash = true, 
		HasOutline = true,

		ActiveTweens = {},
	}
} 

function Highlight.highlightModel(Model : Model)
	local CheckHumanoid = Model:FindFirstChildWhichIsA("Humanoid")
	if not CheckHumanoid then
		Instance.new("Humanoid", Model)
	end
end 

function Highlight.Prototype:__CreateHighlight() 
	local ThisHighlight = Instance.new("Highlight") 
	ThisHighlight.OutlineColor = self.OutlineColor
	ThisHighlight.OutlineTransparency = self.HasOutline and 0.5 or 1  

	ThisHighlight.FillColor = self.Color 
	ThisHighlight.FillTransparency = 1 
	ThisHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop 

	ThisHighlight.Parent = Highlight.Location 

	if self.DoesFlash then 
		local tween = TweenService:Create(ThisHighlight, self.PulseTween, {
			FillTransparency = 0.5
		})
		tween:Play()
		self.ActiveTweens[ThisHighlight] = tween
	else 
		ThisHighlight.FillTransparency = 0.5 
	end

	return ThisHighlight
end

function Highlight.Prototype:GetNext()
	debug.profilebegin("Highlight :: GetNext")
	self.Position += 1 
	self.Items[self.Position] = self.Items[self.Position] or self:__CreateHighlight()  

	local NewHighlight 
	NewHighlight = function(Highlight : Highlight, Parent) 	
		if Parent and Parent.Parent ~= nil then Highlight.Parent = Parent end
		Highlight.Destroying:Connect(function() 
			local PreviousIndication = self.Indicated[Highlight]
			NewHighlight(self:__CreateHighlight(), PreviousIndication)
		end)
	end

	local ThisHighlight : Highlight = self.Items[self.Position] 
	NewHighlight(ThisHighlight)

	debug.profileend()
	return ThisHighlight
end

function Highlight.Prototype:Activate(ItemToHighlight : Instance)
	if not self.DoesFlash then return end

	local ThisHighlight = self.Indicated[ItemToHighlight]
	if ThisHighlight and ThisHighlight.Parent then
		if self.ActiveTweens[ThisHighlight] then
			self.ActiveTweens[ThisHighlight]:Cancel()
		end

		local tween = TweenService:Create(ThisHighlight, self.PulseTween, {
			FillTransparency = 0.5
		})
		tween:Play()
		self.ActiveTweens[ThisHighlight] = tween
	end
end

function Highlight.Prototype:Refresh()
	for _, ThisHighlight : Highlight in self.Items do 
		ThisHighlight.OutlineColor = self.OutlineColor
		ThisHighlight.OutlineTransparency = self.HasOutline and 0.5 or 1 
		ThisHighlight.FillColor = self.Color

		if self.DoesFlash and ThisHighlight.Parent then
			if self.ActiveTweens[ThisHighlight] then
				self.ActiveTweens[ThisHighlight]:Cancel()
			end

			local tween = TweenService:Create(ThisHighlight, self.PulseTween, {
				FillTransparency = 0.5
			})
			tween:Play()
			self.ActiveTweens[ThisHighlight] = tween
		end
	end
end

function Highlight.Prototype:Set(ItemToHighlight : Instance) 
	debug.profilebegin("Highlight :: Set")
	if typeof(ItemToHighlight) == "table" then 
		if next(ItemToHighlight) then 
			for _, Sub in ItemToHighlight do 
				self:Set(Sub)
			end
		end
		return debug.profileend()
	end

	if not ItemToHighlight then return debug.profileend() end 
	if self.Indicated[ItemToHighlight] then return debug.profileend() end 

	if ItemToHighlight:IsA("Model") then Highlight.highlightModel(ItemToHighlight) end 

	local ThisHighlight : Highlight = self:GetNext() 
	if self.AdorneeAll or ItemToHighlight:IsA("BasePart") then 
		if self.ClearLast then self:Clear() end

		ThisHighlight.Parent = Highlight.Location -- Default 
		ThisHighlight.Adornee = ItemToHighlight 
	elseif ItemToHighlight:IsA("Model") then 
		if self.ClearLast then self:Clear() end


		ThisHighlight.Parent = ItemToHighlight 
		ThisHighlight.Adornee = nil
	else 
		warn(`Impossible highlight instance type:{typeof(ItemToHighlight) == "Instance" and ItemToHighlight.ClassName or typeof(ItemToHighlight)}`)
		return debug.profileend()
	end

	self:Activate(ItemToHighlight)

	self.Indicated[ItemToHighlight] = ThisHighlight 
	self.Indicated[ThisHighlight] = ItemToHighlight 

	debug.profileend()
end

function Highlight.Prototype:Clear() 
	debug.profilebegin("Highlight :: Clear")
	self.Position = 0 
	self.Indicated = {} 

	for _, ThisHighlight : Highlight in self.Items do 
		if self.ActiveTweens[ThisHighlight] then
			self.ActiveTweens[ThisHighlight]:Cancel()
			self.ActiveTweens[ThisHighlight] = nil
		end

		ThisHighlight.Adornee = nil  
		ThisHighlight.Parent = Highlight.Location 
	end
	debug.profileend()
end

function Highlight.Prototype:Expire(Time : number)
	local LocalHeader = os.clock()
	self.ExpiringHeader = LocalHeader
	task.delay(Time, function()
		if self.ExpiringHeader == LocalHeader then
			self:Clear()
		end
	end)
end

function Highlight.Prototype:SetPulsing(enabled : boolean)
	self.DoesFlash = enabled

	if not enabled then
		for highlight, tween in pairs(self.ActiveTweens) do
			tween:Cancel()
			self.ActiveTweens[highlight] = nil
		end
	end

	self:Refresh()
end

function Highlight.Prototype:SetColor(color : Color3)
	self.Color = color
	self:Refresh()
end

function Highlight.Prototype:SetOutlineColor(color : Color3)
	self.OutlineColor = color
	self:Refresh()
end

function Highlight.Prototype:Pulse(duration : number?)
	duration = duration or 0.6
	self.PulseTween = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, true)

	for _, highlight : Highlight in self.Items do
		if highlight.Parent then
			if self.ActiveTweens[highlight] then
				self.ActiveTweens[highlight]:Cancel()
			end

			local tween = TweenService:Create(highlight, self.PulseTween, {
				FillTransparency = 0.5
			})
			tween:Play()
			self.ActiveTweens[highlight] = tween
		end
	end
end

function Highlight.newSet(Proto) 
	local HighlightSet = setmetatable(Proto or {}, {
		__index =  Highlight.Prototype
	})

	HighlightSet.Items = {}
	HighlightSet.Indicated = {}
	HighlightSet.ActiveTweens = {}

	return HighlightSet
end

return Highlight